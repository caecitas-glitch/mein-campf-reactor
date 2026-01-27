-- TITAN-X REACTOR CONTROLLER
-- Version: 2.0 (Stable/Animation)

-- Configuration
local SAFE_TEMP = 1200         -- Kelvin
local MAX_WASTE_PERCENT = 0.90 -- 90%
local MIN_COOLANT_PERCENT = 0.10 -- 10%
local TARGET_BURN_RATE = 1.0   -- Default
local BURN_STEP = 0.5          -- Precision adjustment

-- Colors
local C_BG = colors.black
local C_FRAME = colors.gray
local C_DOOR = colors.lightGray
local C_TEXT = colors.white
local C_ACCENT = colors.cyan
local C_DANGER = colors.red
local C_SAFE = colors.lime
local C_WARN = colors.orange

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local mon = peripheral.find("monitor")

-- Validation
if not reactor then error("CRITICAL: NO REACTOR ADAPTER") end
if not mon then error("CRITICAL: NO MONITOR") end

mon.setTextScale(0.5) -- High Res Mode
local w, h = mon.getSize()

-- Variables
local isRunning = false
local autoScramTriggered = false
local scramReason = "NONE"
local currentBurn = TARGET_BURN_RATE
local logBuffer = {"System Initialized.", "Waiting for input..."}

-- ================= HELPER FUNCTIONS =================

local function centerText(y, text, color, bg)
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(color)
    mon.setBackgroundColor(bg or C_BG)
    mon.write(text)
end

local function drawBox(x, y, width, height, color)
    mon.setBackgroundColor(color)
    for i = 0, height-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function addLog(msg)
    table.insert(logBuffer, 1, "> " .. msg)
    if #logBuffer > 6 then table.remove(logBuffer) end
end

-- ================= ANIMATION SYSTEM =================

local function drawClamp(x, y, locked)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(locked and C_DANGER or C_SAFE)
    if locked then
        mon.write("[[ LOCKED ]]")
    else
        mon.write(" [[ OPEN ]] ")
    end
end

local function startupAnimation()
    mon.setTextScale(1) -- Big text for impact
    local aw, ah = mon.getSize()
    
    -- 1. Slam Doors Shut
    mon.setBackgroundColor(C_DOOR)
    mon.clear()
    centerText(ah/2, "SEALING CONTAINMENT", colors.black, C_DOOR)
    sleep(1)
    
    -- 2. Lock Clamps
    mon.setBackgroundColor(C_DOOR)
    drawClamp(aw/2 - 5, ah/2 - 2, true)
    drawClamp(aw/2 - 5, ah/2 + 2, true)
    sleep(0.5)
    
    -- 3. Pressurize (Flash background)
    centerText(ah/2, "PRESSURIZING...", colors.red, C_DOOR)
    sleep(0.5)
    centerText(ah/2, "PRESSURIZING...", colors.orange, C_DOOR)
    sleep(0.5)
    centerText(ah/2, "ATMOSPHERE STABLE", colors.green, C_DOOR)
    
    -- 4. Unlock
    drawClamp(aw/2 - 5, ah/2 - 2, false)
    drawClamp(aw/2 - 5, ah/2 + 2, false)
    sleep(0.5)
    
    -- 5. Open Doors (Slide effect)
    local center = math.floor(aw/2)
    for i = 0, center do
        -- Clear from center out
        mon.setBackgroundColor(colors.black)
        
        -- Left side retracting
        mon.setCursorPos(center - i, 1)
        for y=1, ah do
            mon.setCursorPos(center - i, y)
            mon.write(" ")
        end
        
        -- Right side retracting
        mon.setCursorPos(center + i + 1, 1)
        for y=1, ah do
            mon.setCursorPos(center + i, y)
            mon.write(" ")
        end
        sleep(0.01)
    end
    
    mon.setTextScale(0.5) -- Back to High Res
end

-- ================= INTERFACE RENDERING =================

-- Draws the unchanging parts of the UI (Frames, Labels)
local function drawStaticInterface()
    mon.setBackgroundColor(C_BG)
    mon.clear()
    
    -- Header
    drawBox(1, 1, w, 3, colors.gray)
    centerText(2, "TITAN-X: OMEGA PROTOCOL", C_ACCENT, colors.gray)
    
    -- Frames
    drawBox(2, 5, w-2, 1, colors.blue) -- Separator
    
    -- Labels
    mon.setBackgroundColor(C_BG)
    mon.setTextColor(colors.lightGray)
    mon.setCursorPos(2, 7)
    mon.write("CORE TEMP:")
    mon.setCursorPos(2, 10)
    mon.write("COOLANT LVL:")
    mon.setCursorPos(2, 13)
    mon.write("WASTE LVL:")
    mon.setCursorPos(2, 16)
    mon.write("BURN RATE:")
    
    -- Button Frames
    -- START
    drawBox(2, h-4, 10, 3, C_SAFE)
    mon.setTextColor(colors.black)
    mon.setCursorPos(4, h-3)
    mon.write("ENGAGE")
    
    -- STOP
    drawBox(14, h-4, 10, 3, C_DANGER)
    mon.setTextColor(colors.white)
    mon.setCursorPos(17, h-3)
    mon.write("SCRAM")
    
    -- RATE CONTROL
    drawBox(w-16, h-4, 4, 3, colors.lightGray) -- Minus
    mon.setCursorPos(w-15, h-3)
    mon.setTextColor(colors.black)
    mon.write("-")
    
    drawBox(w-5, h-4, 4, 3, colors.lightGray) -- Plus
    mon.setCursorPos(w-4, h-3)
    mon.write("+")
end

-- Updates only the numbers and dynamic bars
local function updateInterface()
    local temp = reactor.getTemperature()
    local waste = reactor.getWasteFilledPercentage()
    local coolant = reactor.getCoolantFilledPercentage()
    local activeRate = reactor.getBurnRate()
    local status = reactor.getStatus()
    
    -- 1. Update Values (Text)
    mon.setBackgroundColor(C_BG)
    
    -- Temp
    mon.setCursorPos(15, 7)
    mon.setTextColor(temp > 1000 and C_DANGER or C_ACCENT)
    mon.write(string.format("%4.0f K   ", temp))
    
    -- Coolant
    mon.setCursorPos(15, 10)
    mon.setTextColor(coolant < 0.2 and C_DANGER or C_SAFE)
    mon.write(string.format("%3.0f %%   ", coolant * 100))
    
    -- Waste
    mon.setCursorPos(15, 13)
    mon.setTextColor(waste > 0.8 and C_WARN or colors.purple)
    mon.write(string.format("%3.0f %%   ", waste * 100))
    
    -- Burn Rate Display
    mon.setCursorPos(15, 16)
    mon.setTextColor(colors.white)
    mon.write(string.format("%.1f mB/t (Target: %.1f)   ", activeRate, currentBurn))
    
    -- 2. Status Indicator
    mon.setCursorPos(w-15, 2)
    mon.setBackgroundColor(colors.gray)
    if autoScramTriggered then
        mon.setTextColor(C_DANGER)
        mon.write("CRITICAL FAILURE")
    elseif status then
        mon.setTextColor(C_SAFE)
        mon.write("SYSTEM ONLINE   ")
    else
        mon.setTextColor(C_WARN)
        mon.write("SYSTEM STANDBY  ")
    end
    
    -- 3. Log Window
    mon.setBackgroundColor(colors.black)
    for i, msg in ipairs(logBuffer) do
        mon.setCursorPos(w/2 + 2, 6 + i)
        mon.setTextColor(colors.lightGray)
        mon.clearLine() -- Only clear the log line
        mon.setCursorPos(w/2 + 2, 6 + i)
        if i == 1 then mon.setTextColor(colors.white) end
        mon.write(msg)
    end
end

-- ================= LOGIC KERNEL =================

local function checkSafety()
    local temp = reactor.getTemperature()
    local coolant = reactor.getCoolantFilledPercentage()
    local waste = reactor.getWasteFilledPercentage()
    local damage = reactor.getDamagePercent()
    
    if damage > 0 then return true, "CONTAINMENT BREACH" end
    if temp >= SAFE_TEMP then return true, "CORE OVERHEAT" end
    if coolant < MIN_COOLANT_PERCENT then return true, "COOLANT CRITICAL" end
    if waste >= MAX_WASTE_PERCENT then return true, "WASTE FULL" end
    
    return false, "OK"
end

local function handleTouch(x, y)
    -- START (ENGAGE)
    if y >= h-4 and y <= h-2 and x >= 2 and x <= 12 then
        if not autoScramTriggered then
            reactor.activate()
            reactor.setBurnRate(currentBurn)
            addLog("Sequence Initiated.")
        else
            addLog("ERR: Clear Alarm First")
        end
    end
    
    -- STOP (SCRAM)
    if y >= h-4 and y <= h-2 and x >= 14 and x <= 24 then
        reactor.scram()
        autoScramTriggered = false
        addLog("MANUAL SCRAM")
    end
    
    -- DECREASE RATE
    if y >= h-4 and y <= h-2 and x >= w-16 and x <= w-12 then
        currentBurn = math.max(0.1, currentBurn - BURN_STEP)
        reactor.setBurnRate(currentBurn)
        addLog("Rate set: " .. currentBurn)
    end
    
    -- INCREASE RATE
    if y >= h-4 and y <= h-2 and x >= w-5 and x <= w-1 then
        currentBurn = currentBurn + BURN_STEP
        reactor.setBurnRate(currentBurn)
        addLog("Rate set: " .. currentBurn)
    end
end

-- ================= MAIN THREADS =================

local function loopMonitor()
    drawStaticInterface()
    while true do
        local danger, reason = checkSafety()
        
        if danger then
            if not autoScramTriggered then
                reactor.scram()
                autoScramTriggered = true
                scramReason = reason
                addLog("AUTO-SCRAM: " .. reason)
            end
        end
        
        updateInterface()
        sleep(0.2) -- Faster refresh for smoother numbers
    end
end

local function loopInput()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
    end
end

-- START
startupAnimation()
parallel.waitForAny(loopMonitor, loopInput)
