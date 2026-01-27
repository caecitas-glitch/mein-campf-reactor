-- TITAN-X: OMEGA PROTOCOL v4.0
-- "The Stable Core Update"

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
-- Defined locally to prevent nil errors
local C_BG      = colors.black
local C_PANEL   = colors.gray
local C_HEADER  = colors.blue
local C_TEXT    = colors.white
local C_LABEL   = colors.lightGray
local C_GOOD    = colors.lime
local C_WARN    = colors.orange
local C_BAD     = colors.red
local C_DATA    = colors.cyan
local C_WASTE   = colors.magenta -- explicit definition

-- ================= INIT CHECKS =================
if not reactor then error("ERR: NO REACTOR ADAPTER") end
if not mon then error("ERR: NO MONITOR") end
mon.setTextScale(0.5) -- High Resolution
local w, h = mon.getSize()

-- Global State
local isRunning = false
local scramTriggered = false
local scramReason = "NONE"
local targetBurn = reactor.getBurnRate()

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
    if color == nil then color = C_PANEL end -- Safety
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

-- CRASH FIX: Added safety check for 'color'
local function drawBar(x, y, width, percent, color, label)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(C_PANEL)
    mon.setTextColor(C_LABEL)
    mon.write(label)
    
    local barW = width
    -- Ensure percent is a number between 0 and 1
    if percent == nil then percent = 0 end
    if percent < 0 then percent = 0 end
    if percent > 1 then percent = 1 end

    local filled = math.floor(percent * barW)
    
    -- Draw Track
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW))
    
    -- Draw Fill (Safety Check Here)
    if color == nil then color = C_TEXT end 
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(color)
    if filled > 0 then
        mon.write(string.rep(" ", filled))
    end
end

-- ================= ANIMATION =================
local function bootSequence()
    mon.setTextScale(1)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    centerText(h/2, "SYSTEM BOOT", C_DATA, colors.black)
    sleep(0.5)
    
    -- Flash effect
    mon.setBackgroundColor(colors.white)
    mon.clear()
    sleep(0.1)
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
    mon.setCursorPos(4, 6)
    mon.setTextColor(C_TEXT)
    mon.write("REACTOR CORE")
    
    -- Column 2: Output
    drawBox(28, 5, 24, h-8, C_PANEL)
    mon.setCursorPos(30, 6)
    mon.write("TURBINE & MATRIX")
    
    -- Column 3: Status
    drawBox(54, 5, w-55, h-8, C_PANEL)
    mon.setCursorPos(56, 6)
    mon.write("SYSTEM STATUS")
    
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
    
    -- Rate Controls
    drawBox(w-20, h-3, 8, 3, colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(w-19, h-2)
    mon.write("- " .. math.floor(BURN_STEP))
    
    drawBox(w-10, h-3, 8, 3, colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(w-9, h-2)
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
    
    -- Turbine Data
    local t_flow = 0
    local t_prod = 0
    if turbine then
        t_flow = turbine.getFlowRate()
        t_prod = turbine.getProductionRate()
    end
    
    -- Matrix Data
    local m_energy = 0
    local m_max = 1
    local m_in = 0
    local m_out = 0
    if matrix then
        m_energy = matrix.getEnergy()
        m_max = matrix.getMaxEnergy()
        m_in = matrix.getLastInput()
        m_out = matrix.getLastOutput()
    end
    if m_max == 0 then m_max = 1 end -- Prevent div by zero

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
    
    -- Waste (Using safe C_WASTE)
    local wasteCol = r_wast > 0.8 and C_WARN or C_WASTE
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
    
    -- Matrix
    mon.setCursorPos(29, 12); mon.setTextColor(colors.green); mon.write("INDUCTION MATRIX")
    local matPct = m_energy / m_max
    
    drawBar(29, 13, 22, matPct, colors.green, "Chg: " .. math.floor(matPct*100) .. "%")
    
    mon.setCursorPos(29, 16); mon.setTextColor(C_LABEL); mon.write("Store: ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_energy) .. " FE")
    
    mon.setCursorPos(29, 17); mon.setTextColor(C_LABEL); mon.write("In:    ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_in) .. " FE/t")

    -- === COLUMN 3: STATUS ===
    mon.setCursorPos(56, 8)
    if scramTriggered then
        mon.setTextColor(C_BAD)
        mon.write("!!! SCRAMMED !!!")
        mon.setCursorPos(56, 9)
        mon.write(scramReason)
    elseif r_stat then
        mon.setTextColor(C_GOOD)
        mon.write("ONLINE - NOMINAL")
    else
        mon.setTextColor(C_WARN)
        mon.write("OFFLINE - STANDBY")
    end
    
    -- Target Setting
    mon.setCursorPos(56, 12)
    mon.setTextColor(C_LABEL)
    mon.write("TARGET RATE:")
    mon.setCursorPos(56, 13)
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
            scramTriggered = false 
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
        drawControls() 
    end
end

parallel.waitForAny(loopCore, loopTouch)
