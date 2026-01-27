-- TITAN-X: BARE BONES EDITION
-- No animation, no matrix, maximum stability.

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         
local MAX_WASTE = 0.90         
local MIN_COOLANT = 0.15       
local BURN_STEP = 1.0         
local REFRESH_RATE = 0.5       

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local mon     = peripheral.find("monitor")

-- Crash if hardware is missing
if not reactor then error("No Reactor Adapter found!") end
if not mon then error("No Monitor found!") end

mon.setTextScale(0.5)
local w, h = mon.getSize()

-- ================= STATE =================
local scramTriggered = false
local scramReason = "None"
local targetBurn = 0.1

-- Try to get current burn rate safely
local success, currentRate = pcall(reactor.getBurnRate)
if success and currentRate then targetBurn = currentRate end

-- ================= SAFETY HELPERS =================
-- These functions guarantee a number/color is returned, preventing crashes.

local function getVal(func)
    local ok, ret = pcall(func)
    if ok and ret then return ret end
    return 0 -- Default to 0 if sensor fails
end

local function drawBox(x, y, width, height, color)
    if not color then color = colors.gray end
    mon.setBackgroundColor(color)
    for i = 0, height-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function centerText(y, text, fg, bg)
    if not fg then fg = colors.white end
    if not bg then bg = colors.black end
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(fg)
    mon.setBackgroundColor(bg)
    mon.write(text)
end

local function drawBar(x, y, width, percent, color, label)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.write(label)
    
    -- Safety checks
    if not percent then percent = 0 end
    if percent < 0 then percent = 0 end
    if percent > 1 then percent = 1 end
    if not color then color = colors.blue end -- Default color if nil

    local barW = width
    local filled = math.floor(percent * barW)
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW)) -- Empty track
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(color)
    if filled > 0 then
        mon.write(string.rep(" ", filled))
    end
end

-- ================= MAIN UI =================

local function drawGUI()
    -- 1. Gather Data (Safely)
    local r_status = getVal(reactor.getStatus)
    local r_temp   = getVal(reactor.getTemperature)
    local r_cool   = getVal(reactor.getCoolantFilledPercentage)
    local r_waste  = getVal(reactor.getWasteFilledPercentage)
    local r_burn   = getVal(reactor.getBurnRate)
    local r_damage = getVal(reactor.getDamagePercent)
    
    local t_prod = 0
    if turbine then t_prod = getVal(turbine.getProductionRate) end

    -- 2. Check Safety
    local isDanger = false
    if r_damage > 0 then isDanger = true; scramReason = "DAMAGE" end
    if r_temp >= SAFE_TEMP then isDanger = true; scramReason = "OVERHEAT" end
    if r_waste >= MAX_WASTE then isDanger = true; scramReason = "WASTE FULL" end
    if r_cool < MIN_COOLANT then isDanger = true; scramReason = "NO COOLANT" end

    if isDanger then
        reactor.scram()
        scramTriggered = true
    end

    -- 3. Draw Screen
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Header
    drawBox(1, 1, w, 3, colors.blue)
    centerText(2, "TITAN-X SIMPLE", colors.white, colors.blue)

    -- Status
    mon.setCursorPos(2, 5)
    mon.setBackgroundColor(colors.black)
    if scramTriggered then
        mon.setTextColor(colors.red)
        mon.write("STATUS: SCRAMMED (" .. scramReason .. ")")
    elseif r_status then
        mon.setTextColor(colors.lime)
        mon.write("STATUS: ONLINE")
    else
        mon.setTextColor(colors.orange)
        mon.write("STATUS: IDLE")
    end

    -- Bars
    -- Temp
    local tempColor = colors.cyan
    if r_temp > 1000 then tempColor = colors.red end
    drawBar(2, 7, w-4, r_temp / SAFE_TEMP, tempColor, "Temp: " .. math.floor(r_temp) .. " K")

    -- Coolant
    local coolColor = colors.lime
    if r_cool < 0.2 then coolColor = colors.red end
    drawBar(2, 10, w-4, r_cool, coolColor, "Coolant: " .. math.floor(r_cool * 100) .. "%")

    -- Waste
    local wasteColor = colors.purple
    if r_waste > 0.8 then wasteColor = colors.orange end
    drawBar(2, 13, w-4, r_waste, wasteColor, "Waste: " .. math.floor(r_waste * 100) .. "%")

    -- Info Stats
    mon.setCursorPos(2, 16)
    mon.setTextColor(colors.lightGray)
    mon.setBackgroundColor(colors.black)
    mon.write("Burn Rate: " .. r_burn .. " mB/t")
    
    mon.setCursorPos(2, 17)
    mon.write("Turbine:   " .. math.floor(t_prod) .. " FE/t")
    
    mon.setCursorPos(2, 19)
    mon.setTextColor(colors.white)
    mon.write("TARGET: " .. targetBurn .. " mB/t")

    -- Buttons
    local btnY = h - 3
    drawBox(2, btnY, 8, 3, colors.green)
    mon.setTextColor(colors.black); mon.setCursorPos(3, btnY+1); mon.write("START")

    drawBox(11, btnY, 8, 3, colors.red)
    mon.setTextColor(colors.white); mon.setCursorPos(12, btnY+1); mon.write("STOP")

    drawBox(w-12, btnY, 5, 3, colors.gray)
    mon.setTextColor(colors.white); mon.setCursorPos(w-10, btnY+1); mon.write("-")

    drawBox(w-6, btnY, 5, 3, colors.gray)
    mon.setTextColor(colors.white); mon.setCursorPos(w-4, btnY+1); mon.write("+")
end

local function handleTouch(x, y)
    local btnY = h - 3
    if y >= btnY and y <= btnY + 2 then
        -- Start
        if x >= 2 and x <= 10 then
            if not scramTriggered then
                reactor.activate()
                reactor.setBurnRate(targetBurn)
            end
        end
        -- Stop
        if x >= 11 and x <= 19 then
            reactor.scram()
            scramTriggered = false
        end
        -- Minus
        if x >= w-12 and x <= w-8 then
            targetBurn = targetBurn - BURN_STEP
            if targetBurn < 0.1 then targetBurn = 0.1 end
            reactor.setBurnRate(targetBurn)
        end
        -- Plus
        if x >= w-6 and x <= w-1 then
            targetBurn = targetBurn + BURN_STEP
            reactor.setBurnRate(targetBurn)
        end
    end
end

-- ================= LOOPS =================

local function loopGUI()
    while true do
        drawGUI()
        sleep(0.5)
    end
end

local function loopInput()
    while true do
        local _, _, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
    end
end

parallel.waitForAny(loopGUI, loopInput)
