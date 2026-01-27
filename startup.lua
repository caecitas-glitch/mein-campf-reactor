-- TITAN-X: STABLE + MATRIX EDITION
-- Features: Crash protection, Matrix support, Advanced Rate Controls

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         
local MAX_WASTE = 0.90         
local MIN_COOLANT = 0.15       
local REFRESH_RATE = 0.5       

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort") -- Matrix is back!
local mon     = peripheral.find("monitor")

if not reactor then error("No Reactor Adapter found!") end
if not mon then error("No Monitor found!") end

mon.setTextScale(0.5)
local w, h = mon.getSize()

-- ================= STATE =================
local scramTriggered = false
local scramReason = "None"
local targetBurn = 0.1

-- Sync burn rate on startup
local success, currentRate = pcall(reactor.getBurnRate)
if success and currentRate then targetBurn = currentRate end

-- ================= SAFETY TOOLS =================
-- Prevents "attempt to call nil" or "number expected" errors

local function getVal(func)
    if not func then return 0 end
    local ok, ret = pcall(func)
    if ok and ret then return ret end
    return 0
end

local function formatNum(num)
    if not num then return "0" end
    if num >= 1e12 then return string.format("%.2f T", num/1e12) end
    if num >= 1e9 then return string.format("%.2f G", num/1e9) end
    if num >= 1e6 then return string.format("%.2f M", num/1e6) end
    if num >= 1e3 then return string.format("%.1f k", num/1e3) end
    return string.format("%.1f", num)
end

-- ================= DRAWING TOOLS =================

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
    
    if not percent then percent = 0 end
    if percent < 0 then percent = 0 end
    if percent > 1 then percent = 1 end
    if not color then color = colors.blue end 

    local barW = width
    local filled = math.floor(percent * barW)
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW)) 
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(color)
    if filled > 0 then
        mon.write(string.rep(" ", filled))
    end
end

-- ================= BUTTONS LOGIC =================
-- We define button zones here so we can check clicks easily
local buttons = {}

local function drawButton(name, x, y, width, height, color, label, textColor)
    drawBox(x, y, width, height, color)
    mon.setTextColor(textColor or colors.black)
    mon.setCursorPos(x + math.floor((width - #label)/2), y + math.floor(height/2))
    mon.write(label)
    buttons[name] = {x=x, y=y, w=width, h=height}
end

-- ================= MAIN UI =================

local function drawGUI()
    -- 1. Gather Data 
    local r_status = getVal(reactor.getStatus)
    local r_temp   = getVal(reactor.getTemperature)
    local r_cool   = getVal(reactor.getCoolantFilledPercentage)
    local r_waste  = getVal(reactor.getWasteFilledPercentage)
    local r_burn   = getVal(reactor.getBurnRate)
    local r_damage = getVal(reactor.getDamagePercent)
    
    local t_prod = 0
    if turbine then t_prod = getVal(turbine.getProductionRate) end
    
    local m_eng, m_max, m_in, m_out = 0, 1, 0, 0
    if matrix then
        m_eng = getVal(matrix.getEnergy)
        m_max = getVal(matrix.getMaxEnergy)
        m_in  = getVal(matrix.getLastInput)
        m_out = getVal(matrix.getLastOutput)
    end
    if m_max == 0 then m_max = 1 end

    -- 2. Safety Check
    local isDanger = false
    if r_damage > 0 then isDanger = true; scramReason = "DAMAGE" end
    if r_temp >= SAFE_TEMP then isDanger = true; scramReason = "OVERHEAT" end
    if r_waste >= MAX_WASTE then isDanger = true; scramReason = "WASTE FULL" end
    if r_cool < MIN_COOLANT then isDanger = true; scramReason = "NO COOLANT" end

    if isDanger then
        reactor.scram()
        scramTriggered = true
    end

    -- 3. Render
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- HEADER
    drawBox(1, 1, w, 3, colors.blue)
    centerText(2, "TITAN-X :: CORE & MATRIX", colors.white, colors.blue)

    -- LEFT COL: REACTOR
    mon.setCursorPos(2, 5); mon.setTextColor(colors.cyan); mon.setBackgroundColor(colors.black); mon.write("REACTOR STATUS")
    
    local tempColor = (r_temp > 1000) and colors.red or colors.cyan
    drawBar(2, 7, 24, r_temp/SAFE_TEMP, tempColor, "Temp: " .. math.floor(r_temp) .. " K")
    
    local coolColor = (r_cool < 0.2) and colors.red or colors.lime
    drawBar(2, 10, 24, r_cool, coolColor, "Coolant: " .. math.floor(r_cool*100) .. "%")
    
    local wasteColor = (r_waste > 0.8) and colors.orange or colors.magenta
    drawBar(2, 13, 24, r_waste, wasteColor, "Waste: " .. math.floor(r_waste*100) .. "%")
    
    mon.setCursorPos(2, 16); mon.setTextColor(colors.lightGray); mon.write("Actual Rate: ")
    mon.setTextColor(colors.white); mon.write(r_burn .. " mB/t")

    -- RIGHT COL: POWER
    local col2X = 30
    mon.setCursorPos(col2X, 5); mon.setTextColor(colors.yellow); mon.write("POWER GRID")
    
    -- Turbine
    mon.setCursorPos(col2X, 7); mon.setTextColor(colors.lightGray); mon.write("Turbine: ")
    mon.setTextColor(colors.lime); mon.write(formatNum(t_prod) .. " FE/t")
    
    -- Matrix
    local matPct = m_eng / m_max
    drawBar(col2X, 9, 24, matPct, colors.green, "Matrix: " .. math.floor(matPct*100) .. "%")
    
    mon.setCursorPos(col2X, 12); mon.setTextColor(colors.lightGray); mon.write("Stored: ")
    mon.setTextColor(colors.white); mon.write(formatNum(m_eng) .. " FE")
    
    mon.setCursorPos(col2X, 13); mon.setTextColor(colors.lightGray); mon.write("Input:  ")
    mon.setTextColor(colors.green); mon.write(formatNum(m_in) .. " FE/t")
    
    mon.setCursorPos(col2X, 14); mon.setTextColor(colors.lightGray); mon.write("Output: ")
    mon.setTextColor(colors.red); mon.write(formatNum(m_out) .. " FE/t")

    -- SYSTEM STATUS TEXT
    mon.setCursorPos(col2X, 16)
    if scramTriggered then
        mon.setTextColor(colors.red); mon.write("SCRAMMED: " .. scramReason)
    elseif r_status then
        mon.setTextColor(colors.lime); mon.write("SYSTEM ONLINE")
    else
        mon.setTextColor(colors.orange); mon.write("SYSTEM IDLE")
    end

    -- CONTROLS
    local bY = h - 4
    -- Target Display
    mon.setCursorPos(2, bY)
    mon.setTextColor(colors.cyan)
    mon.write("TARGET BURN: " .. targetBurn .. " mB/t")
    
    -- Buttons Row 1: Rate
    drawButton("m25", 2,  bY+1, 5, 3, colors.gray, "-25", colors.white)
    drawButton("m10", 8,  bY+1, 5, 3, colors.gray, "-10", colors.white)
    drawButton("p10", 14, bY+1, 5, 3, colors.gray, "+10", colors.white)
    drawButton("p25", 20, bY+1, 5, 3, colors.gray, "+25", colors.white)
    
    -- Buttons Row 2: Power
    drawButton("start", 30, bY+1, 8, 3, colors.green, "START", colors.black)
    drawButton("stop",  40, bY+1, 8, 3, colors.red,   "STOP",  colors.white)
end

-- ================= INPUT LOGIC =================

local function handleTouch(x, y)
    for name, data in pairs(buttons) do
        if x >= data.x and x < data.x + data.w and y >= data.y and y < data.y + data.h then
            
            if name == "start" then
                if not scramTriggered then
                    reactor.activate()
                    reactor.setBurnRate(targetBurn)
                end
            elseif name == "stop" then
                reactor.scram()
                scramTriggered = false -- Reset alarm
            elseif name == "p10" then
                targetBurn = targetBurn + 10
            elseif name == "p25" then
                targetBurn = targetBurn + 25
            elseif name == "m10" then
                targetBurn = math.max(0.1, targetBurn - 10)
            elseif name == "m25" then
                targetBurn = math.max(0.1, targetBurn - 25)
            end
            
            -- Apply new rate immediately if running
            if name ~= "stop" and name ~= "start" then
                reactor.setBurnRate(targetBurn)
            end
            
            return -- Click handled
        end
    end
end

-- ================= LOOPS =================

local function loopGUI()
    while true do
        drawGUI()
        sleep(REFRESH_RATE)
    end
end

local function loopInput()
    while true do
        local _, _, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
    end
end

parallel.waitForAny(loopGUI, loopInput)
