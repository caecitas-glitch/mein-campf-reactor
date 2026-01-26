-- AEGIS-OS v7.0.0: TOTAL CONTAINMENT
local VERSION = "7.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

local w, h = 0, 0
if monitor then w, h = monitor.getSize() end
local sidebarW = 12

-- Logging & Trends
local LOG_FILE = "blackbox.log"
local hist = { mE = 0, rF = 0, time = os.epoch("utc") }
local trends = { energy = 0, fuel = 0 }

-- --- BLACKBOX LOGGING ---
local function logEvent(msg)
    local timestamp = os.date("%H:%M:%S")
    local epoch = os.epoch("utc")
    local f = fs.open(LOG_FILE, "a")
    f.writeLine(epoch .. "|" .. timestamp .. " [LOG] " .. msg)
    f.close()
end

local function cleanLogs()
    if not fs.exists(LOG_FILE) then return end
    local now = os.epoch("utc")
    local lines = {}
    local f = fs.open(LOG_FILE, "r")
    local line = f.readLine()
    while line do
        local time = tonumber(line:match("^(%d+)|"))
        if time and (now - time) < 3600000 then table.insert(lines, line) end
        line = f.readLine()
    end
    f.close()
    local wf = fs.open(LOG_FILE, "w")
    for _, l in ipairs(lines) do wf.writeLine(l) end
    wf.close()
end

-- --- SINGULARITY BOOT (Your Sketch) ---
local function playSingularity()
    term.redirect(monitor or term)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    local cx, cy = math.floor((w - sidebarW) / 2), math.floor(h / 2)
    
    -- Stage 1-4: Condensing Rings
    for r = 8, 1, -2 do
        term.clear()
        term.setTextColor(colors.white)
        for a = 0, 360, 10 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 2))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and y > 0 and x < (w - sidebarW) then
                term.setCursorPos(x, y)
                term.write("o")
            end
        end
        sleep(0.15)
    end
    
    -- Stage 5: The Blue Explosion
    term.clear()
    term.setCursorPos(cx, cy)
    term.setTextColor(colors.blue)
    term.write("@")
    sleep(0.2)
    
    for r = 1, 12 do
        term.setTextColor(colors.blue)
        for a = 0, 360, 20 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and y > 0 and x < (w - sidebarW) then
                term.setCursorPos(x, y)
                term.write("*")
            end
        end
        sleep(0.05)
    end
    
    sleep(0.5)
    term.clear() -- Clean boot complete
end

-- --- CRASH-PROOF PROTECTION ---
local function getSafeData(obj, func)
    local success, result = pcall(function() return obj[func]() end)
    return success and result or nil
end

local function coreProtection()
    if reactor then
        local dmg = getSafeData(reactor, "getDamage") or 0
        local temp = getSafeData(reactor, "getTemperature") or 0
        if dmg > 0 or temp > 1150 then
            pcall(function() reactor.setBurnRate(0) end)
            pcall(function() reactor.scram() end)
            logEvent("CRITICAL FAILSAFE: DMG " .. dmg .. "% TEMP " .. temp .. "K")
            return true
        end
    end
    return false
end

-- --- UI LOGIC ---
local function drawSidebar()
    term.setBackgroundColor(colors.gray)
    for i = 1, h do term.setCursorPos(w - sidebarW + 1, i) term.write(" ") end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.setCursorPos(w - 9, 2) term.write("AEGIS")
    term.setTextColor(colors.blue)
    term.setCursorPos(w - 10, 4) term.write("  /--\\  ")
    term.setCursorPos(w - 10, 5) term.write(" / || \\ ")
    term.setCursorPos(w - 10, 6) term.write(" | -- | ")
    term.setCursorPos(w - 10, 7) term.write(" \\ -- / ")
    term.setCursorPos(w - 10, 8) term.write("  \\--/  ")
end

local function run()
    while true do
        cleanLogs()
        local isScram = coreProtection()
        local now = os.epoch("utc")
        local dt = (now - hist.time) / 60000
        
        local mE = getSafeData(matrix, "getEnergy") or 0
        local rF_data = getSafeData(reactor, "getFuel")
        local rF = rF_data and rF_data.amount or 0
        
        if dt > 0.01 then
            trends.energy = (mE - hist.mE) / dt
            trends.fuel = (rF - hist.rF) / dt
            hist.mE, hist.rF, hist.time = mE, rF, now
        end

        drawSidebar()
        term.setTextColor(colors.white)
        term.setCursorPos(1, 1)
        term.setBackgroundColor(isScram and colors.red or colors.blue)
        term.clearLine()
        term.write(" CORE STATUS: " .. (isScram and "EMERGENCY SCRAM" or "STABLE"))
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(2, 3) term.clearLine()
        term.write("FUEL TREND: ")
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write(string.format("%.1fk/min", trends.fuel/1000))
        
        term.setTextColor(colors.white)
        term.setCursorPos(2, 5) term.clearLine()
        term.write("NET GAIN: ")
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write(string.format("%.1fM/min", trends.energy/1000000))
        term.setTextColor(colors.white)

        sleep(1)
    end
end

-- --- COMMAND HANDLING ---
local args = {...}
if args[1] == "logs" then
    if fs.exists(LOG_FILE) then
        local f = fs.open(LOG_FILE, "r")
        print(f.readAll())
        f.close()
    else print("No logs found.") end
    return
end

playSingularity()
run()
