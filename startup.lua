-- AEGIS-OS v10.0.0: IRON SENTRY (STRICT CONTAINMENT)
local VERSION = "10.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

local w, h = 0, 0
if monitor then w, h = monitor.getSize() end
local sidebarW = 12

-- Persistent SCRAM state and History
local isScrammed = false
local lastScramReason = "NONE"
local hist = { mE = 0, rF = 0, time = os.epoch("utc") }
local trends = { energy = 0, fuel = 0 }

-- --- UTILS ---
local function safeCall(obj, f)
    local success, result = pcall(function() return obj[f]() end)
    return success and result or nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e9 then return string.format("%.2fG", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.2fk", n/1e3) end
    return tostring(math.floor(n))
end

-- --- THE SINGULARITY BOOT ---
local function playSingularity()
    term.redirect(monitor or term)
    term.setBackgroundColor(colors.black)
    term.clear()
    local cx, cy = math.floor((w - sidebarW) / 2), math.floor(h / 2)
    
    -- Wave condensation
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
    -- Blue explosion
    term.clear()
    term.setTextColor(colors.blue)
    term.setCursorPos(cx, cy) term.write("@")
    sleep(0.15)
    for r = 1, 12 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x < (w - sidebarW) then term.setCursorPos(x, y) term.write("*") end
        end
        sleep(0.04)
    end
    term.clear()
end

-- --- MAIN UI ---
local function run()
    while true do
        -- 1. STRICT DATA COLLECTION
        local rData = {
            temp = safeCall(reactor, "getTemperature") or 0,
            dmg = safeCall(reactor, "getDamage") or 0,
            burn = safeCall(reactor, "getBurnRate") or 0,
            fuel = (safeCall(reactor, "getFuel") or {amount=0}).amount,
            waste = (safeCall(reactor, "getWaste") or {amount=0}).amount,
            wasteMax = safeCall(reactor, "getWasteCapacity") or 1,
            cool = (safeCall(reactor, "getCoolant") or {amount=0}).amount
        }
        local tData = {
            steam = (safeCall(turbine, "getSteam") or {amount=0}).amount,
            steamMax = safeCall(turbine, "getSteamCapacity") or 1,
            gen = safeCall(turbine, "getProductionRate") or 0
        }
        local mData = {
            stored = safeCall(matrix, "getEnergy") or 0,
            max = safeCall(matrix, "getMaxEnergy") or 1
        }

        -- 2. STRICT ENFORCEMENT PROTOCOL
        local currentReason = "NONE"
        if rData.dmg > 0 then currentReason = "CORE DAMAGE"
        elseif rData.temp > 1150 then currentReason = "OVERHEAT"
        elseif (rData.waste / rData.wasteMax) > 0.95 then currentReason = "WASTE FULL"
        elseif (tData.steam / tData.steamMax) > 0.98 then currentReason = "STEAM BACKUP"
        elseif (mData.stored / mData.max) > 0.99 then currentReason = "POWER GRID FULL"
        end

        if currentReason ~= "NONE" then
            pcall(function() reactor.setBurnRate(0) end)
            pcall(function() reactor.scram() end)
            isScrammed = true
            lastScramReason = currentReason
        else
            isScrammed = false
        end

        -- 3. TRENDS
        local now = os.epoch("utc")
        local dt = (now - hist.time) / 60000
        if dt > 0.05 then
            trends.energy = (mData.stored - hist.mE) / dt
            trends.fuel = (rData.fuel - hist.rF) / dt
            hist.mE, hist.rF, hist.time = mData.stored, rData.fuel, now
        end

        -- 4. RENDERING
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Header (Sticky SCRAM indicator)
        term.setCursorPos(1, 1)
        term.setBackgroundColor(isScrammed and colors.red or colors.blue)
        term.clearLine()
        term.write(" CORE: " .. (isScrammed and "LOCKED - " .. lastScramReason or "ACTIVE"))
        term.setBackgroundColor(colors.black)

        -- Stats Array
        term.setTextColor(colors.yellow)
        term.setCursorPos(1, 3) term.write(" [CORE STATS] ")
        term.setTextColor(colors.white)
        term.setCursorPos(2, 4) term.write("Temp: " .. math.floor(rData.temp) .. "K | Dmg: " .. rData.dmg .. "%")
        term.setCursorPos(2, 5) term.write("Fuel: " .. formatNum(rData.fuel) .. " | Cool: " .. formatNum(rData.cool))
        term.setCursorPos(2, 6) term.write("Waste: " .. formatNum(rData.waste) .. "/" .. formatNum(rData.wasteMax))

        term.setTextColor(colors.cyan)
        term.setCursorPos(1, 8) term.write(" [DYNAMICS] ")
        term.setTextColor(colors.white)
        term.setCursorPos(2, 9) term.write("Steam: " .. formatNum(tData.steam) .. " (" .. string.format("%.1f", (tData.steam/tData.steamMax)*100) .. "%)")
        term.setCursorPos(2, 10) term.write("Matrix: " .. formatNum(mData.stored) .. " (" .. string.format("%.1f", (mData.stored/mData.max)*100) .. "%)")

        term.setTextColor(colors.magenta)
        term.setCursorPos(1, 12) term.write(" [TRENDS] ")
        term.setCursorPos(2, 13) 
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write("Net Power: " .. formatNum(trends.energy) .. " FE/min")
        term.setCursorPos(2, 14)
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write("Fuel Delta: " .. formatNum(trends.fuel) .. " mB/min")

        sleep(1)
    end
end

playSingularity()
run()
