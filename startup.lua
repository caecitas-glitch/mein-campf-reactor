-- AEGIS-OS: Core Containment v6.0.0
local VERSION = "6.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
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
        if time and (now - time) < 3600000 then -- 1 hour in ms
            table.insert(lines, line)
        end
        line = f.readLine()
    end
    f.close()
    local wf = fs.open(LOG_FILE, "w")
    for _, l in ipairs(lines) do wf.writeLine(l) end
    wf.close()
end

-- --- NEW ANIMATION 5: COLLAPSE & EXPLODE ---
local function animSingularity()
    term.clear()
    -- Wave from edges
    for i = 0, math.floor(w/2) do
        term.setCursorPos(1+i, 1) term.write("V")
        term.setCursorPos(w-sidebarW-i, h) term.write("^")
        sleep(0.02)
    end
    -- Condense to ball
    local cx, cy = math.floor((w-sidebarW)/2), math.floor(h/2)
    term.clear()
    term.setTextColor(colors.white)
    term.setCursorPos(cx, cy) term.write("@")
    sleep(0.5)
    -- Blue Explosion
    term.setTextColor(colors.blue)
    for r = 1, 10 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * r/2)
            if x > 0 and y > 0 and x < w-sidebarW then
                term.setCursorPos(x, y) term.write("*")
            end
        end
        sleep(0.03)
    end
end

-- --- FAILSAFE ---
local function coreProtection()
    if reactor then
        local dmg = reactor.getDamage() or 0
        local temp = reactor.getTemperature() or 0
        if dmg > 0 or temp > 1150 then
            reactor.setBurnRate(0)
            reactor.scram() -- Double safety
            logEvent("CRITICAL FAILSAFE TRIGGERED. Damage: " .. dmg .. "% Temp: " .. temp)
            return true
        end
    end
    return false
end

-- --- MAIN UI ---
local function drawSidebar()
    term.setBackgroundColor(colors.gray)
    for i = 1, h do term.setCursorPos(w-sidebarW+1, i) term.write(" ") end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.setCursorPos(w-9, 2) term.write("AEGIS")
    term.setCursorPos(w-10, 5) term.write("  /--\\  ")
    term.setCursorPos(w-10, 6) term.write(" / || \\ ")
    term.setCursorPos(w-10, 7) term.write(" | -- | ")
    term.setCursorPos(w-10, 8) term.write(" \\ -- / ")
    term.setCursorPos(w-10, 9) term.write("  \\--/  ")
end

local function run()
    logEvent("System Booted. AEGIS-CCP v" .. VERSION .. " Active.")
    while true do
        cleanLogs()
        local isScram = coreProtection()
        
        local now = os.epoch("utc")
        local dt = (now - hist.time) / 60000 -- Trend per Minute
        local mE = (matrix and matrix.getEnergy()) or 0
        local rF = (reactor and (reactor.getFuel() or {amount=0}).amount) or 0
        
        if dt > 0.01 then
            trends.energy = (mE - hist.mE) / dt
            trends.fuel = (rF - hist.rF) / dt
            hist.mE, hist.rF, hist.time = mE, rF, now
        end

        drawSidebar()
        term.setCursorPos(1, 1) 
        term.setBackgroundColor(isScram and colors.red or colors.blue)
        term.clearLine() term.write(" CORE STATUS: " .. (isScram and "SCRAM" or "STABLE"))
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(2, 3) term.clearLine()
        term.write("FUEL TREND: ")
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write(formatNum(trends.fuel) .. "/min")
        
        term.setTextColor(colors.white)
        term.setCursorPos(2, 5) term.clearLine()
        term.write("NET GAIN: ")
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write(formatNum(trends.energy) .. " FE/min")
        term.setTextColor(colors.white)

        sleep(1)
    end
end

-- --- ARGUMENTS ---
local args = {...}
if args[1] == "logs" then
    if not fs.exists(LOG_FILE) then print("No logs found.") return end
    local f = fs.open(LOG_FILE, "r")
    print(f.readAll())
    f.close()
    return
elseif args[1] == "anim" and args[2] == "5" then
    term.redirect(monitor)
    animSingularity()
    return
end

term.redirect(monitor)
animSingularity()
run()
