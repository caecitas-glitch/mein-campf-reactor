-- Configuration
local SAFE_TEMP = 1200 -- Kelvin (Mekanism meltdown is usually higher, this is safe)
local MAX_WASTE_PERCENT = 0.90 -- Scram if waste > 90%
local MIN_COOLANT_PERCENT = 0.10 -- Scram if coolant < 10%
local TARGET_BURN_RATE = 1.0 -- Default start burn rate
local BURN_STEP = 1.0 -- How much + / - buttons change rate

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve") -- Optional, but recommended
local mon = peripheral.find("monitor")

-- Colors
local C_BG = colors.gray
local C_TEXT = colors.white
local C_ACCENT = colors.cyan
local C_DANGER = colors.red
local C_SAFE = colors.lime
local C_WARN = colors.orange

-- State
local isRunning = false
local autoScramTriggered = false
local scramReason = "None"
local currentBurn = TARGET_BURN_RATE

-- Validation
if not reactor then error("No Fission Reactor Adapter found!") end
if not mon then error("No Advanced Monitor found!") end

mon.setTextScale(1)
local w, h = mon.getSize()

-- Helper: Center Text
local function centerText(y, text, color, bg)
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(color)
    mon.setBackgroundColor(bg or C_BG)
    mon.write(text)
end

-- Helper: Draw Bar
local function drawBar(y, label, val, maxVal, color)
    mon.setCursorPos(2, y)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(C_BG)
    mon.write(label)
    
    local barWidth = w - 4
    local filled = math.floor((val / maxVal) * barWidth)
    if filled < 0 then filled = 0 end
    if filled > barWidth then filled = barWidth end
    
    mon.setCursorPos(2, y + 1)
    mon.setBackgroundColor(colors.black)
    mon.write(string.rep(" ", barWidth)) -- Clear background
    mon.setCursorPos(2, y + 1)
    mon.setBackgroundColor(color)
    mon.write(string.rep(" ", filled))
end

-- ANIMATION: Super Cool Startup
local function startupAnimation()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setTextScale(1)
    
    local logos = {
        "INITIALIZING CORE...",
        "CONNECTING TO REACTOR...",
        "CHECKING CONTAINMENT...",
        "CALIBRATING TURBINE...",
        "LOADING GUI..."
    }
    
    for i, text in ipairs(logos) do
        centerText(h/2, text, C_ACCENT, colors.black)
        
        -- Hex dump effect
        mon.setTextColor(colors.green)
        for k=1, 5 do
            mon.setCursorPos(2, h - 2)
            mon.write(string.format("0x%X 0x%X 0x%X", math.random(1000,9999), math.random(1000,9999), math.random(1000,9999)))
            sleep(0.1)
        end
        sleep(0.2)
        mon.clear()
    end
    
    -- Flash effect
    mon.setBackgroundColor(colors.white)
    mon.clear()
    sleep(0.05)
    mon.setBackgroundColor(C_BG)
    mon.clear()
end

-- SAFETY: The Watchdog
local function checkSafety()
    local status = reactor.getStatus() -- true if active
    local damage = reactor.getDamagePercent()
    local temp = reactor.getTemperature()
    
    local coolantFilled = reactor.getCoolantFilledPercentage()
    local wasteFilled = reactor.getWasteFilledPercentage()
    
    -- 1. Check Damage
    if damage > 0 then
        reactor.scram()
        return true, "CASING DAMAGE DETECTED"
    end

    -- 2. Check Temp
    if temp >= SAFE_TEMP then
        reactor.scram()
        return true, "OVERHEAT: " .. math.floor(temp) .. "K"
    end

    -- 3. Check Coolant
    if coolantFilled < MIN_COOLANT_PERCENT then
        reactor.scram()
        return true, "LOW COOLANT"
    end

    -- 4. Check Waste
    if wasteFilled >= MAX_WASTE_PERCENT then
        reactor.scram()
        return true, "WASTE FULL"
    end

    return false, "SYSTEM NOMINAL"
end

-- GUI: Main Interface
local function drawGUI()
    mon.setBackgroundColor(C_BG)
    mon.clear()
    
    -- Header
    mon.setCursorPos(1,1)
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.white)
    mon.clearLine()
    centerText(1, "ATM10 FISSION CONTROLLER", colors.white, colors.blue)
    
    -- Stats Fetch
    local temp = reactor.getTemperature()
    local waste = reactor.getWasteFilledPercentage()
    local coolant = reactor.getCoolantFilledPercentage()
    local actBurn = reactor.getBurnRate()
    
    -- Display Stats
    drawBar(3, "Temperature (" .. math.floor(temp) .. "K)", temp, SAFE_TEMP, (temp > 1000 and C_DANGER or C_ACCENT))
    drawBar(6, "Coolant (" .. math.floor(coolant*100) .. "%)", coolant, 1, (coolant < 0.2 and C_DANGER or C_SAFE))
    drawBar(9, "Waste (" .. math.floor(waste*100) .. "%)", waste, 1, (waste > 0.8 and C_WARN or colors.purple))
    
    -- Status Box
    mon.setCursorPos(2, 13)
    mon.setBackgroundColor(C_BG)
    mon.setTextColor(colors.lightGray)
    mon.write("Status: ")
    
    if autoScramTriggered then
        mon.setTextColor(C_DANGER)
        mon.write("SCRAMMED! " .. scramReason)
    elseif reactor.getStatus() then
        mon.setTextColor(C_SAFE)
        mon.write("ONLINE - Rate: " .. actBurn .. " mB/t")
    else
        mon.setTextColor(C_WARN)
        mon.write("OFFLINE")
    end

    -- Turbine Stats (if connected)
    if turbine then
        local tEnergy = turbine.getProductionRate()
        mon.setCursorPos(2, 14)
        mon.setTextColor(colors.yellow)
        mon.write("Turbine: " .. math.floor(tEnergy) .. " FE/t")
    end

    -- Buttons
    -- START
    mon.setCursorPos(2, h-2)
    mon.setBackgroundColor(C_SAFE)
    mon.setTextColor(colors.black)
    mon.write(" START ")
    
    -- STOP
    mon.setCursorPos(10, h-2)
    mon.setBackgroundColor(C_DANGER)
    mon.setTextColor(colors.black)
    mon.write(" STOP ")
    
    -- RATE CONTROLS
    mon.setCursorPos(w-12, h-2)
    mon.setBackgroundColor(colors.lightGray)
    mon.write(" - ")
    mon.setCursorPos(w-8, h-2)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    mon.write(string.format("%4.1f", currentBurn))
    mon.setCursorPos(w-2, h-2)
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.black)
    mon.write(" + ")
end

-- LOGIC: Touch Handler
local function handleTouch(x, y)
    -- Start Button (Approx coords, adjust based on your monitor size)
    if y == h-2 and x >= 2 and x <= 8 then
        if not autoScramTriggered then
            reactor.activate()
        end
    end
    
    -- Stop Button
    if y == h-2 and x >= 10 and x <= 15 then
        reactor.scram()
        autoScramTriggered = false -- Reset alarm manually
    end
    
    -- Rate -
    if y == h-2 and x >= w-12 and x <= w-10 then
        currentBurn = math.max(0.1, currentBurn - BURN_STEP)
        reactor.setBurnRate(currentBurn)
    end
    
    -- Rate +
    if y == h-2 and x >= w-2 and x <= w then
        currentBurn = currentBurn + BURN_STEP
        reactor.setBurnRate(currentBurn)
    end
end

-- MAIN LOOPS
startupAnimation()

local function loopStats()
    while true do
        local danger, reason = checkSafety()
        if danger then
            autoScramTriggered = true
            scramReason = reason
        end
        drawGUI()
        sleep(0.5)
    end
end

local function loopTouch()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
    end
end

-- Run threads
parallel.waitForAny(loopStats, loopTouch)
