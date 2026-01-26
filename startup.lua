-- AEGIS-OS: Core Containment & Fusion Management
local VERSION = "3.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

-- Trend Tracking
local history = { matrixE = 0, reactorF = 0, reactorW = 0, time = os.epoch("utc") }
local trends = { energy = 0, fuel = 0, waste = 0 }

-- UI Layout Constants
local w, h = 0, 0
if monitor then w, h = monitor.getSize() end
local sidebarWidth = 12
local mainWidth = w - sidebarWidth

-- --- UTILS ---
local function safeCall(obj, func, ...)
    if obj and obj[func] then return obj[func](...) end
    return nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    local absN = math.abs(n)
    local suffix = n < 0 and "-" or ""
    if absN >= 1e12 then return string.format("%s%.1fT", suffix, absN/1e12) end
    if absN >= 1e9 then return string.format("%s%.1fG", suffix, absN/1e9) end
    if absN >= 1e6 then return string.format("%s%.1fM", suffix, absN/1e6) end
    if absN >= 1e3 then return string.format("%s%.1fk", suffix, absN/1e3) end
    return suffix .. tostring(math.floor(absN))
end

-- --- ANIMATION: PARTICLE ACCELERATOR ---
local function bootSequence()
    term.redirect(monitor or term)
    monitor.setTextScale(0.5)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    local centerX, centerY = math.floor(w/2), math.floor(h/2)
    local chars = {"-", "\\", "|", "/"}
    
    -- Animation: Spinning ring to form Logo
    for radius = 1, 5 do
        for angle = 0, 360, 15 do
            local rad = math.rad(angle)
            local x = math.floor(centerX + math.cos(rad) * radius)
            local y = math.floor(centerY + math.sin(rad) * (radius/2))
            term.setCursorPos(x, y)
            term.setTextColor(colors.cyan)
            term.write(chars[(angle/15 % 4) + 1])
            sleep(0.01)
        end
    end
    
    sleep(0.5)
    term.clear()
end

-- --- UI COMPONENTS ---
local function drawSidebar()
    -- Draw AEGIS Logo and Name
    term.setBackgroundColor(colors.gray)
    for i = 1, h do
        term.setCursorPos(mainWidth + 1, i)
        term.write(" ")
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.setCursorPos(mainWidth + 3, 2) term.write("AEGIS")
    term.setCursorPos(mainWidth + 3, 3) term.write(" v3.0")
    
    -- Logo symbol
    term.setCursorPos(mainWidth + 4, 5) term.write("/--\\")
    term.setCursorPos(mainWidth + 4, 6) term.write("|<>|")
    term.setCursorPos(mainWidth + 4, 7) term.write("\\--/")
    
    term.setTextColor(colors.red)
    term.setCursorPos(mainWidth + 2, h - 1) term.write("PROT: ON")
end

local function drawHeader(title, y, bg)
    term.setCursorPos(1, y)
    term.setBackgroundColor(bg or colors.blue)
    term.setTextColor(colors.white)
    term.write(" " .. string.sub(title .. string.rep(" ", mainWidth), 1, mainWidth - 1))
    term.setBackgroundColor(colors.black)
end

-- --- MAIN LOOP ---
local function run()
    while true do
        local now = os.epoch("utc")
        local dt = (now - history.time) / 1000
        
        -- Data Refresh
        local mE = safeCall(matrix, "getEnergy") or 0
        local rF = (safeCall(reactor, "getFuel") or {amount=0}).amount
        local rW = (safeCall(reactor, "getWaste") or {amount=0}).amount
        if dt > 0 then
            trends.energy = (mE - history.matrixE) / dt
            trends.fuel = (rF - history.reactorF) / dt
            trends.waste = (rW - history.reactorW) / dt
        end
        history.matrixE, history.reactorF, history.reactorW, history.time = mE, rF, rW, now

        -- Rendering
        drawSidebar()
        
        -- Reactor Section
        drawHeader("CORE CONTAINMENT", 1, colors.red)
        local rTemp = safeCall(reactor, "getTemperature") or 0
        local rDmg = safeCall(reactor, "getDamage") or 0
        term.setCursorPos(2, 2) term.clearLine() term.write("HEAT: " .. math.floor(rTemp) .. "K | DMG: " .. rDmg .. "%")
        term.setCursorPos(2, 3) term.clearLine() term.write("FUEL: " .. formatNum(rF))
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write(" (" .. formatNum(trends.fuel) .. "/s)")
        term.setTextColor(colors.white)

        -- Turbine Section
        drawHeader("TURBINE STATUS", 5, colors.blue)
        local tGen = safeCall(turbine, "getProductionRate") or 0
        term.setCursorPos(2, 6) term.clearLine() term.write("GEN RATE: " .. formatNum(tGen) .. " FE/t")

        -- Matrix Section
        drawHeader("STORAGE GRID", 8, colors.purple)
        local mMax = safeCall(matrix, "getMaxEnergy") or 1
        term.setCursorPos(2, 9) term.clearLine() term.write("CAP: " .. string.format("%.1f%%", (mE/mMax)*100))
        term.setCursorPos(2, 10) term.clearLine() 
        term.write("NET: ")
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write(formatNum(trends.energy) .. " FE/s")
        term.setTextColor(colors.white)

        -- Safety Logic
        if rDmg > 0 or rTemp > 1180 then safeCall(reactor, "setBurnRate", 0) end
        
        sleep(1)
    end
end

bootSequence()
run()
