-- AEGIS: Core Containment Protocol (CCP) - Cinema Edition
local VERSION = "5.0.0"
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- Peripherals
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

local w, h = 0, 0
if monitor then w, h = monitor.getSize() end
local sidebarW = 12

-- History for Per-Minute Trends
local hist = { mE = 0, rF = 0, time = os.epoch("utc") }
local trends = { energy = 0, fuel = 0 }

-- --- UTILS ---
local function safeCall(obj, f, ...) if obj and obj[f] then return obj[f](...) end end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    local absN = math.abs(n)
    if absN >= 1e12 then return string.format("%.1fT", absN/1e12) end
    if absN >= 1e9 then return string.format("%.1fG", absN/1e9) end
    if absN >= 1e6 then return string.format("%.1fM", absN/1e6) end
    return tostring(math.floor(absN))
end

-- --- THE 5 ANIMATIONS ---

local anims = {
    -- 1. Particle Accelerator
    function()
        local cx, cy = math.floor(w/2) - 6, math.floor(h/2)
        for r = 1, 6 do
            for a = 0, 360, 25 do
                local x, y = math.floor(cx + math.cos(math.rad(a))*r*1.5), math.floor(cy + math.sin(math.rad(a))*r*0.8)
                term.setCursorPos(x, y)
                term.setTextColor(colors.cyan)
                term.write("o")
                if r > 4 then sleep(0.01) end
            end
        end
    end,
    -- 2. Core Scan
    function()
        for i = 1, h do
            term.setCursorPos(1, i)
            term.setBackgroundColor(colors.green)
            term.clearLine()
            sleep(0.05)
            term.setBackgroundColor(colors.black)
            term.clearLine()
        end
    end,
    -- 3. Neural Net (Matrix)
    function()
        for i = 1, 40 do
            term.setCursorPos(math.random(1, w-sidebarW), math.random(1, h))
            term.setTextColor(colors.lime)
            term.write(string.char(math.random(33, 96)))
            if i % 4 == 0 then sleep(0.05) end
        end
    end,
    -- 4. Horizon Pulse
    function()
        local cy = math.floor(h/2)
        for i = 1, math.floor(w/2) do
            term.setCursorPos(w/2 - i, cy) term.write("<")
            term.setCursorPos(w/2 + i, cy) term.write(">")
            sleep(0.03)
        end
    end,
    -- 5. Singularity
    function()
        for r = 8, 1, -1 do
            term.clear()
            local cx, cy = math.floor(w/2), math.floor(h/2)
            term.setCursorPos(cx-r, cy) term.write("[")
            term.setCursorPos(cx+r, cy) term.write("]")
            sleep(0.1)
        end
    end
}

local function playBoot(idx)
    term.redirect(monitor or term)
    term.setBackgroundColor(colors.black)
    term.clear()
    local i = idx or math.random(1, #anims)
    anims[i]()
    term.setTextColor(colors.white)
    term.setCursorPos(2, h-2)
    textutils.slowWrite("AEGIS-OS: V" .. VERSION .. " INITIALIZED", 30)
    sleep(1)
end

-- --- SIDEBAR & UI ---
local function drawSidebar()
    term.setBackgroundColor(colors.gray)
    for i = 1, h do term.setCursorPos(w-sidebarW+1, i) term.write(" ") end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.setCursorPos(w-9, 2) term.write("AEGIS")
    term.setTextColor(colors.blue)
    term.setCursorPos(w-10, 4) term.write("  /--\\  ")
    term.setCursorPos(w-10, 5) term.write(" / || \\ ")
    term.setCursorPos(w-10, 6) term.write(" | -- | ")
    term.setCursorPos(w-10, 7) term.write(" \\ -- / ")
    term.setCursorPos(w-10, 8) term.write("  \\--/  ")
end

-- --- MAIN LOOP ---
local function run()
    while true do
        local now = os.epoch("utc")
        local dt = (now - hist.time) / 60000 -- Convert ms to minutes
        
        local mE = safeCall(matrix, "getEnergy") or 0
        local rF = (safeCall(reactor, "getFuel") or {amount=0}).amount
        
        if dt > 0.01 then -- Update trends roughly every second, but calc per minute
            trends.energy = (mE - hist.mE) / dt
            trends.fuel = (rF - hist.rF) / dt
            hist.mE, hist.rF, hist.time = mE, rF, now
        end

        drawSidebar()
        
        -- Reactor
        term.setCursorPos(1, 1) term.setBackgroundColor(colors.red) term.write(" CORE PROTOCOL ")
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 2) term.clearLine()
        term.write("TEMP: " .. math.floor(safeCall(reactor, "getTemperature") or 0) .. "K")
        term.setCursorPos(2, 3) term.clearLine()
        term.write("FUEL: " .. formatNum(rF) .. " (")
        term.setTextColor(trends.fuel < 0 and colors.red or colors.green)
        term.write(formatNum(trends.fuel) .. "/min")
        term.setTextColor(colors.white) term.write(")")

        -- Storage
        term.setCursorPos(1, 6) term.setBackgroundColor(colors.blue) term.write(" ENERGY GRID ")
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 7) term.clearLine()
        term.write("STORED: " .. formatNum(mE) .. " FE")
        term.setCursorPos(2, 8) term.clearLine()
        term.setTextColor(trends.energy >= 0 and colors.green or colors.red)
        term.write("NET: " .. formatNum(trends.energy) .. " FE/min")
        term.setTextColor(colors.white)

        if (safeCall(reactor, "getDamage") or 0) > 0 then safeCall(reactor, "setBurnRate", 0) end
        sleep(1)
    end
end

-- --- ARGUMENT HANDLING ---
local args = {...}
if args[1] == "anim" and args[2] then
    playBoot(tonumber(args[2]))
    return
end

playBoot()
run()
