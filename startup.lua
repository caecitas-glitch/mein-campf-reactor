-- AEGIS-OS v8.0.0: TOTAL CONTAINMENT + BROADCAST
local VERSION = "8.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")
local modem   = peripheral.find("modem") or error("No Modem found for broadcasting!")

local w, h = 0, 0
if monitor then w, h = monitor.getSize() end
local sidebarW = 12
local LOG_FILE = "blackbox.log"

-- --- BROADCAST & LOGGING ---
if not fs.exists(LOG_FILE) then
    local f = fs.open(LOG_FILE, "w")
    f.writeLine(os.epoch("utc") .. "|INIT| AEGIS-OS Online.")
    f.close()
end

local function logAndBroadcast(data)
    local timestamp = os.date("%H:%M:%S")
    local packet = textutils.serialize(data)
    
    -- Write to local Blackbox
    local f = fs.open(LOG_FILE, "a")
    f.writeLine(os.epoch("utc") .. "|" .. timestamp .. "|" .. packet)
    f.close()
    
    -- Send to Secondary Computer
    rednet.open(peripheral.getName(modem))
    rednet.broadcast(data, "AEGIS_TELEMETRY")
end

-- --- SINGULARITY BOOT (The Sketch) ---
local function playSingularity()
    term.redirect(monitor or term)
    term.setBackgroundColor(colors.black)
    term.clear()
    local cx, cy = math.floor((w - sidebarW) / 2), math.floor(h / 2)
    
    for r = 10, 1, -2 do
        term.clear()
        term.setTextColor(colors.white)
        for a = 0, 360, 15 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 2))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x < (w - sidebarW) then term.setCursorPos(x, y) term.write("o") end
        end
        sleep(0.1)
    end
    term.clear()
    term.setTextColor(colors.blue)
    term.setCursorPos(cx, cy) term.write("@")
    sleep(0.1)
    for r = 1, 10 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x < (w - sidebarW) then term.setCursorPos(x, y) term.write("*") end
        end
        sleep(0.04)
    end
    term.clear()
end

-- --- DATA WRAPPERS ---
local function safeCall(obj, f)
    local success, result = pcall(function() return obj[f]() end)
    return success and result or nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e9 then return string.format("%.1fG", n/1e9) end
    if n >= 1e6 then return string.format("%.1fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

-- --- MAIN UI ---
local function run()
    local hist = { mE = 0, rF = 0, time = os.epoch("utc") }
    local trends = { energy = 0, fuel = 0 }

    while true do
        -- 1. DATA COLLECTION
        local rData = {
            temp = safeCall(reactor, "getTemperature") or 0,
            dmg = safeCall(reactor, "getDamage") or 0,
            burn = safeCall(reactor, "getBurnRate") or 0,
            fuel = (safeCall(reactor, "getFuel") or {amount=0}).amount,
            waste = (safeCall(reactor, "getWaste") or {amount=0}).amount,
            coolant = (safeCall(reactor, "getCoolant") or {amount=0}).amount
        }
        local tData = {
            gen = safeCall(turbine, "getProductionRate") or 0,
            flow = safeCall(turbine, "getFlowRate") or 0
        }
        local mData = {
            stored = safeCall(matrix, "getEnergy") or 0,
            max = safeCall(matrix, "getMaxEnergy") or 1
        }

        -- 2. TRENDS (PER MINUTE)
        local now = os.epoch("utc")
        local dt = (now - hist.time) / 60000
        if dt > 0.01 then
            trends.energy = (mData.stored - hist.mE) / dt
            trends.fuel = (rData.fuel - hist.rF) / dt
            hist.mE, hist.rF, hist.time = mData.stored, rData.fuel, now
            -- Send Every 5 Seconds (approx via loop timing)
            logAndBroadcast({reactor=rData, turbine=tData, matrix=mData, trends=trends})
        end

        -- 3. RENDERING
        term.setCursorPos(1, 1)
        local status = (rData.dmg > 0 or rData.temp > 1150) and "SCRAM" or "STABLE"
        if status == "SCRAM" then pcall(function() reactor.scram() end) end
        
        term.setBackgroundColor(status == "SCRAM" and colors.red or colors.blue)
        term.clearLine()
        term.write(" CORE: " .. status .. " | FUEL: " .. formatNum(trends.fuel) .. "/min")
        term.setBackgroundColor(colors.black)

        -- All Statistics
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, 3) term.write("TEMP: " .. math.floor(rData.temp) .. "K  DMG: " .. rData.dmg .. "%")
        term.setTextColor(colors.cyan)
        term.setCursorPos(2, 5) term.write("TURBINE: " .. formatNum(tData.gen) .. " FE/t")
        term.setTextColor(colors.green)
        term.setCursorPos(2, 7) term.write("MATRIX: " .. formatNum(mData.stored) .. " FE")
        term.setTextColor(colors.white)
        term.setCursorPos(2, 8) term.write("NET GAIN: " .. formatNum(trends.energy) .. " FE/min")

        sleep(1)
    end
end

playSingularity()
run()
