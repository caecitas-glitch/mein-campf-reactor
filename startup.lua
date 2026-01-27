-- TITAN-X: OMEGA PROTOCOL v3.0
-- "The Heavy Industry Update"

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         -- Kelvin (Scram if higher)
local MAX_WASTE = 0.90         -- 90% (Scram if higher)
local MIN_COOLANT = 0.15       -- 15% (Scram if lower)
local BURN_STEP = 10.0         -- Rate change per click
local REFRESH_RATE = 0.5       -- Seconds between updates

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort")
local mon     = peripheral.find("monitor")

-- ================= COLORS =================
local C_BG      = colors.black
local C_PANEL   = colors.gray
local C_HEADER  = colors.blue
local C_TEXT    = colors.white
local C_LABEL   = colors.lightGray
local C_GOOD    = colors.lime
local C_WARN    = colors.orange
local C_BAD     = colors.red
local C_DATA    = colors.cyan

-- ================= INIT CHECKS =================
if not reactor then error("ERR: NO REACTOR ADAPTER") end
if not mon then error("ERR: NO MONITOR") end
mon.setTextScale(0.5) -- High Resolution
local w, h = mon.getSize()

-- Global State
local isRunning = false
local scramTriggered = false
local scramReason = "NONE"
local targetBurn = reactor.getBurnRate() -- Sync with reactor on boot

-- ================= FORMATTING TOOLS =================
local function formatNum(num)
    if not num then return "0" end
    if num >= 1e12 then return string.format("%.2f T", num/1e12) end
    if num >= 1e9 then return string.format("%.2f G", num/1e9) end
    if num >= 1e6 then return string.format("%.2f M", num/1e6) end
    if num >= 1e3 then return string.format("%.1f k", num/1e3) end
    return string.format("%.1f", num)
end

local function drawBox(x, y, width, height, color)
    mon.setBackgroundColor(color)
    for i = 0, height-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function centerText(y, text, fg, bg)
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(fg)
    mon.setBackgroundColor(bg)
    mon.write(text)
end

local function drawBar(x, y, width, percent, color, label)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(C_BG)
    mon.setTextColor(C_LABEL)
    mon.write(label)
    
    local barW = width
    local filled = math.floor(percent * barW)
    if filled > barW then filled = barW end
    if filled < 0 then filled = 0 end
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW))
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(color)
    mon.write(string.rep(" ", filled))
end

-- ================= ANIMATION =================
local function drawDoor(percent)
    mon.setBackgroundColor(colors.gray)
    local center = math.floor(w/2)
    local openWidth = math.floor((w/2) * percent)
    
    -- Left Door
    for y=1, h do
        mon.setCursorPos(1, y)
        mon.write(string.rep(" ", center - openWidth))
    end
    -- Right Door
    for y=1, h do
        mon.setCursorPos(center + openWidth, y)
        mon.write(string.rep(" ", (w - (center + openWidth))))
    end
    
    -- Clamps
    if percent < 0.1 then
        mon.setBackgroundColor(colors.orange)
        mon.setCursorPos(center-2, h/2 - 2)
        mon.write("LOCK")
        mon.setCursorPos(center-2, h/2 + 2)
        mon.write("LOCK")
    end
end

local function bootSequence()
    mon.setTextScale(1)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    centerText(h/2, "SYSTEM BOOT", colors.cyan, colors.black)
    sleep(1)
    
    -- Close Doors
    for i=10, 0, -1 do
        drawDoor(i/10)
        sleep(0.05)
    end
    
    mon.setBackgroundColor(colors.gray)
    centerText(h/2, "DIAGNOSTIC...", colors.lime, colors.gray)
    sleep(0.5)
    centerText(h/2, "CONNECTING...", colors.lime, colors.gray)
    sleep(0.5)
    
    -- Open Doors
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setTextScale(0.5) -- High Res for dashboard
    local newW, newH = mon.getSize()
    w, h = newW, newH -- Update global size vars
end

-- ================= UI DRAWING =================

local function drawStaticUI()
    mon.setBackgroundColor(C_BG)
    mon.clear()
    
    -- Header
    drawBox(1, 1, w, 3, C_HEADER)
    centerText(2, "TITAN-X OMEGA :: DASHBOARD", colors.white, C_HEADER)
    
    -- Panel Frames
    mon.setBackgroundColor(C_PANEL)
    
    -- Column 1: Reactor
    drawBox(2, 5, 24, h-8, C_PANEL)
    centerText(6, " REACTOR CORE ", C_TEXT, C_PANEL) -- Fake center relative to box? No, manual:
    mon.setCursorPos(3, 6); mon.write("REACTOR CORE")
    
    -- Column 2: Output
    drawBox(28, 5, 24, h-8, C_PANEL)
    mon.setCursorPos(29, 6); mon.write("TURBINE & MATRIX")
    
    -- Column 3: Status & Log
    drawBox(54, 5, w-55, h-8, C_PANEL)
    mon.setCursorPos(55, 6); mon.write("SYSTEM STATUS")
    
    -- Footer/Controls
    drawBox(1, h-4, w, 4, colors.darkGray)
end

local function drawControls()
    -- Start
    drawBox(2, h-3, 10, 3, C_GOOD)
    mon.setTextColor(colors.black)
    mon.setCursorPos(4, h-2)
    mon.write("ENGAGE")
    
    -- Stop
    drawBox(14, h-3, 10, 3, C_BAD)
    mon.setTextColor(colors.white)
    mon.setCursorPos(16, h-2)
    mon.write("SCRAM")
    
    -- Rate -
    drawBox(w-20, h-3, 8, 3, colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(w-18, h-2)
    mon.write("- " .. math.floor(BURN_STEP))
    
    -- Rate +
    drawBox(w-10, h-3, 8, 3, colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(w-8, h-2)
    mon.write("+ " .. math.floor(BURN_STEP))
end

local function updateStats()
    -- Fetch Data
    local r_stat = reactor.getStatus()
    local r_temp = reactor.getTemperature()
    local r_burn = reactor.getBurnRate()
    local r_cool = reactor.getCoolantFilledPercentage()
    local r_wast = reactor.getWasteFilledPercentage()
    local r_fuel = reactor.getFuelFilledPercentage()
    local r_heat = reactor.getHeatingRate()
    
    local t_flow = 0
    local t_prod = 0
    if turbine then
        t_flow = turbine.getFlowRate()
        t_prod = turbine.getProductionRate()
    end
    
    local m_energy = 0
    local m_max = 0
    local m_in = 0
    local m_out = 0
    if matrix then
        m_energy = matrix.getEnergy()
        m_max = matrix.getMaxEnergy()
        m_in = matrix.getLastInput()
        m_out = matrix.getLastOutput()
    end

    -- === COLUMN 1: REACTOR ===
    mon.setBackgroundColor(C_PANEL)
    
    -- Temp
    local tempCol = r_temp > 1000 and C_BAD or C_DATA
    drawBar(3, 8, 22, r_temp/SAFE_TEMP, tempCol, "Temp: " .. math.floor(r_temp) .. " K")
    
    -- Coolant
    local coolCol = r_cool < 0.2 and C_BAD or C_DATA
    drawBar(3, 11, 22, r_cool, coolCol, "Coolant: " .. math.floor(r_cool*100) .. "%")
    
    -- Fuel
    drawBar(3, 14, 22, r_fuel, C_GOOD, "Fuel: " .. math.floor(r_fuel*100) .. "%")
    
    -- Waste
    local wasteCol = r_wast > 0.8 and C_WARN or colors.magenta
    drawBar(3, 17, 22, r_wast, wasteCol, "Waste: " .. math.floor(r_wast*100) .. "%")
    
    -- Stats text
    mon.setCursorPos(3, 20); mon.setTextColor(C_LABEL); mon.write("Burn: ")
    mon.setTextColor(colors.white); mon.write(r_burn .. " mB/t")
    
    mon.setCursorPos(3, 21); mon.setTextColor(C_LABEL); mon.write("Heat: ")
    mon.setTextColor(colors.white); mon.write(formatNum(r_heat) .. "")

    -- === COLUMN 2: POWER ===
    -- Turbine
    mon.setCursorPos(29, 8); mon.setTextColor(colors.yellow); mon.write("TURBINE")
    mon.setCursorPos(29, 9); mon.setTextColor(C_LABEL); mon.write("Prod: "); 
    mon.setTextColor(colors.white); mon.write(formatNum(t_prod) .. " FE/t")
    mon.setCursorPos(29, 10); mon.setTextColor(C_LABEL); mon.write("Flow: "); 
    mon.setTextColor(colors.white); mon.write(formatNum(t_flow) .. " mB/t")
    
    -- Matrix
    mon.setCursorPos(29, 12); mon.setTextColor(colors.green); mon.write("INDUCTION MATRIX")
    local matPct = 0
    if m_max > 0 then matPct = m_energy / m_max end
    
    drawBar(29, 13, 22, matPct, colors.green, "Chg: " .. math.floor(matPct*100) .. "%")
    
    mon.setCursorPos(29, 16); mon.setTextColor(C_LABEL); mon.write("Store: ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_energy) .. " FE")
    
    mon.setCursorPos(29, 17); mon.setTextColor(C_LABEL); mon.write("In:    ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_in) .. " FE/t")

    mon.setCursorPos(29, 18); mon.setTextColor(C_LABEL); mon.write("Out:   ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_out) .. " FE/t")

    -- === COLUMN 3: STATUS ===
    mon.setCursorPos(55, 8)
    if scramTriggered then
        mon.setTextColor(C_BAD)
        mon.write("!!! SCRAMMED !!!")
        mon.setCursorPos(55, 9)
        mon.write("REASON: " .. scramReason)
    elseif r_stat then
        mon.setTextColor(C_GOOD)
        mon.write("ONLINE - NOMINAL")
    else
        mon.setTextColor(C_WARN)
        mon.write("OFFLINE - STANDBY")
    end
    
    -- Target Setting
    mon.setCursorPos(55, 12)
    mon.setTextColor(C_LABEL)
    mon.write("TARGET RATE:")
    mon.setCursorPos(55, 13)
    mon.setTextColor(colors.cyan)
    mon.setTextScale(1) -- Big text for setting
    mon.write(targetBurn .. "  ")
    mon.setTextScale(0.5) -- Restore
    
    return {temp=r_temp, waste=r_wast, cool=r_cool, damage=reactor.getDamagePercent()}
end

-- ================= LOGIC & SAFETY =================
local function safetyCheck(stats)
    local trigger = false
    local reason = ""
    
    if stats.damage > 0 then trigger = true; reason = "CASING DAMAGE" end
    if stats.temp >= SAFE_TEMP then trigger = true; reason = "OVERHEAT" end
    if stats.waste >= MAX_WASTE then trigger = true; reason = "WASTE FULL" end
    if stats.cool < MIN_COOLANT then trigger = true; reason = "NO COOLANT" end
    
    if trigger then
        reactor.scram()
        scramTriggered = true
        scramReason = reason
    end
end

local function handleTouch(x, y)
    -- BUTTONS are in y range h-3 to h-1
    if y >= h-3 and y <= h-1 then
        -- ENGAGE (2 to 12)
        if x >= 2 and x <= 12 then
            if not scramTriggered then
                reactor.activate()
                reactor.setBurnRate(targetBurn)
            end
        end
        -- SCRAM (14 to 24)
        if x >= 14 and x <= 24 then
            reactor.scram()
            scramTriggered = false -- Reset alarm (allows restart)
            scramReason = "MANUAL"
        end
        -- MINUS (w-20 to w-12)
        if x >= w-20 and x <= w-12 then
            targetBurn = targetBurn - BURN_STEP
            if targetBurn < 0.1 then targetBurn = 0.1 end
            reactor.setBurnRate(targetBurn)
        end
        -- PLUS (w-10 to w-2)
        if x >= w-10 and x <= w-2 then
            targetBurn = targetBurn + BURN_STEP
            reactor.setBurnRate(targetBurn)
        end
    end
end

-- ================= MAIN LOOPS =================
bootSequence()
drawStaticUI()
drawControls()

local function loopCore()
    while true do
        local stats = updateStats()
        safetyCheck(stats)
        sleep(REFRESH_RATE)
    end
end

local function loopTouch()
    while true do
        local _, _, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
        drawControls() -- Redraw buttons to give visual feedback if needed
    end
end

parallel.waitForAny(loopCore, loopTouch)
