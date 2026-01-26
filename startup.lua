-- PROJECT CATACLYSM: Tactical Reactor OS (Flicker-Free)
local VERSION = "2.1.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

-- Trend Tracking
local history = { matrixE = 0, reactorF = 0, reactorW = 0, time = os.epoch("utc") }
local trends = { energy = 0, fuel = 0, waste = 0 }

-- --- UTILS ---
local function safeCall(obj, func, ...)
    if obj and obj[func] then return obj[func](...) end
    return nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    local absN = math.abs(n)
    local suffix = n < 0 and "-" or ""
    if absN >= 1e12 then return string.format("%s%.2fT", suffix, absN/1e12) end
    if absN >= 1e9 then return string.format("%s%.2fG", suffix, absN/1e9) end
    if absN >= 1e6 then return string.format("%s%.2fM", suffix, absN/1e6) end
    if absN >= 1e3 then return string.format("%s%.2fk", suffix, absN/1e3) end
    return suffix .. tostring(math.floor(absN))
end

-- --- ANIMATION & UI ---
local function bootSequence()
    term.redirect(monitor or term)
    monitor.setTextScale(0.5)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    local lines = {
        "INITIALIZING PROJECT CATACLYSM...",
        "LINKING NEURAL NETWORK... OK",
        "SYNCING CORE ADAPTERS... OK",
        "ESTABLISHING SUBSPACE LINK... OK",
        "READY."
    }
    
    for i, line in ipairs(lines) do
        term.setCursorPos(2, i + 2)
        textutils.slowWrite(line, 25)
        sleep(0.2)
    end
    sleep(1)
    term.clear() -- Clear once before the loop starts
end

local function drawHeader(title, y, bg, fg)
    term.setCursorPos(1, y)
    term.setBackgroundColor(bg or colors.gray)
    term.setTextColor(fg or colors.white)
    term.clearLine()
    term.write(" " .. title)
    term.setBackgroundColor(colors.black)
end

-- --- CORE LOOP ---
local function run()
    while true do
        local now = os.epoch("utc")
        local dt = (now - history.time) / 1000
        
        -- 1. DATA COLLECTION
        local mE = safeCall(matrix, "getEnergy") or 0
        local rF = (safeCall(reactor, "getFuel") or {amount=0}).amount
        local rW = (safeCall(reactor, "getWaste") or {amount=0}).amount
        
        -- Trend Calculation
        if dt > 0 then
            trends.energy = (mE - history.matrixE) / dt
            trends.fuel = (rF - history.reactorF) / dt
            trends.waste = (rW - history.reactorW) / dt
        end
        
        history.matrixE, history.reactorF, history.reactorW, history.time = mE, rF, rW, now

        -- 2. RENDERING (No term.clear here!)
        drawHeader("CATACLYSM OS v" .. VERSION .. " | SYSTEM STABLE", 1, colors.cyan, colors.black)

        -- REACTOR SECTION
        drawHeader("FISSION CORE", 3, colors.red)
        local rTemp = safeCall(reactor, "getTemperature") or 0
        local rDmg = safeCall(reactor, "getDamage") or 0
        local rStatus = safeCall(reactor, "getStatus") and "ONLINE" or "OFFLINE"
        
        term.setCursorPos(2, 4) term.clearLine() term.setTextColor(colors.white)
        term.write("STATUS: " .. rStatus)
        term.setCursorPos(2, 5) term.clearLine()
        term.write(string.format("CORE: %dK | DMG: %d%%", rTemp, rDmg))
        
        term.setCursorPos(2, 6) term.clearLine()
        term.write("FUEL: " .. formatNum(rF) .. " mB ")
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write("(" .. formatNum(trends.fuel) .. "/s)")
        
        term.setTextColor(colors.white)
        term.setCursorPos(2, 7) term.clearLine()
        term.write("WASTE: " .. formatNum(rW) .. " mB ")
        term.setTextColor(trends.waste > 0 and colors.orange or colors.green)
        term.write("(+" .. formatNum(trends.waste) .. "/s)")

        -- TURBINE SECTION
        drawHeader("TURBINE DYNAMICS", 9, colors.blue)
        term.setTextColor(colors.white)
        local tGen = safeCall(turbine, "getProductionRate") or 0
        local tFlow = safeCall(turbine, "getFlowRate") or 0
        local tSteam = (safeCall(turbine, "getSteam") or {amount=0}).amount
        term.setCursorPos(2, 10) term.clearLine() term.write("OUTPUT: " .. formatNum(tGen) .. " FE/t")
        term.setCursorPos(2, 11) term.clearLine() term.write("FLOW: " .. formatNum(tFlow) .. " mB/t")
        term.setCursorPos(2, 12) term.clearLine() term.write("STEAM: " .. formatNum(tSteam) .. " mB")

        -- MATRIX SECTION
        drawHeader("STORAGE GRID", 14, colors.purple)
        term.setTextColor(colors.white)
        local mMax = safeCall(matrix, "getMaxEnergy") or 1
        term.setCursorPos(2, 15) term.clearLine() term.write("STORE: " .. formatNum(mE) .. " / " .. formatNum(mMax))
        
        term.setCursorPos(2, 16) term.clearLine()
        term.write("TREND: ")
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write(formatNum(trends.energy) .. " FE/s")
        
        -- PROGRESS BAR
        local barWidth = 24
        local fill = math.floor((mE / mMax) * barWidth)
        term.setCursorPos(2, 17) term.clearLine()
        term.setTextColor(colors.white)
        term.write("[")
        term.setBackgroundColor(colors.purple)
        term.write(string.rep(" ", fill))
        term.setBackgroundColor(colors.black)
        term.write(string.rep("-", barWidth - fill))
        term.write("]")

        -- Safety SCRAM
        if rDmg > 0 or rTemp > 1180 then
            safeCall(reactor, "setBurnRate", 0)
        end

        sleep(1)
    end
end

bootSequence()
run()
