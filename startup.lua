-- TITAN-X: v8.0 BLACKBOX EDITION
-- Updates: Crash Fix, Action Log Restored, Red Alert Mode

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         
local MAX_WASTE = 0.90         
local MIN_COOLANT = 0.15       
local REFRESH_RATE = 0.5       

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort") 
local mon     = peripheral.find("monitor")

if not reactor then error("No Reactor Adapter found!") end
if not mon then error("No Monitor found!") end

mon.setTextScale(0.5)
local w, h = mon.getSize()

-- ================= STATE =================
local scramTriggered = false
local scramReason = "None"
local targetBurn = 50.0 
local actionLog = {} -- Stores history

-- Sync burn rate safely
local ok, rate = pcall(function() return reactor.getBurnRate() end)
if ok and rate and rate > 0.1 then targetBurn = rate end

-- ================= LOGGING =================
local function addLog(msg)
    local time = os.time()
    -- Format nice timestamp (optional, keeping it simple for space)
    table.insert(actionLog, 1, "> " .. msg)
    -- Keep only last 6 messages
    if #actionLog > 6 then table.remove(actionLog) end
end

addLog("System Initialized.")

-- ================= SAFETY TOOLS =================
local function getVal(func)
    if not func then return 0 end
    local success, result = pcall(func)
    if success and result then 
        return tonumber(result) or 0 
    end
    return 0 
end

local function formatNum(num)
    if not num then num = 0 end
    if num >= 1e12 then return string.format("%.2f T", num/1e12) end
    if num >= 1e9 then return string.format("%.2f G", num/1e9) end
    if num >= 1e6 then return string.format("%.2f M", num/1e6) end
    if num >= 1e3 then return string.format("%.1f k", num/1e3) end
    return string.format("%.1f", num)
end

-- CRASH FIX: Safe Scram
local function safeScram(reason)
    -- Only scram if active to avoid "reactor must be active" error
    if reactor.getStatus() then
        pcall(reactor.scram)
    end
    scramTriggered = true
    scramReason = reason
    addLog("CRITICAL: " .. reason)
end

-- ================= DRAWING TOOLS =================
local function drawBox(x, y, width, height, color)
    mon.setBackgroundColor(color or colors.gray)
    for i = 0, height-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function writeText(x, y, text, color, bg)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(bg or colors.black) 
    mon.setTextColor(color or colors.white)
    mon.write(text)
end

local function centerText(y, text, fg, bg)
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(fg or colors.white)
    mon.setBackgroundColor(bg or colors.black)
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
    
    local barW = width
    local filled = math.floor(percent * barW)
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW)) 
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(color or colors.blue)
    if filled > 0 then
        mon.write(string.rep(" ", filled))
    end
    mon.setBackgroundColor(colors.black)
end

-- ================= BUTTONS =================
local buttons = {}
local function drawButton(name, x, y, width, height, color, label, textColor)
    drawBox(x, y, width, height, color)
    mon.setTextColor(textColor or colors.black)
    local tx = x + math.floor((width - #label)/2)
    local ty = y + math.floor(height/2)
    mon.setCursorPos(tx, ty)
    mon.write(label)
    buttons[name] = {x=x, y=y, w=width, h=height}
end

-- ================= MAIN UI =================
local function drawGUI()
    -- 1. Get Data
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
    if m_max <= 0 then m_max = 1 end

    -- 2. Safety Logic
    if not scramTriggered then
        if r_damage > 0 then safeScram("DAMAGE DETECTED") end
        if r_temp >= SAFE_TEMP then safeScram("OVERHEAT: " .. math.floor(r_temp).."K") end
        if r_waste >= MAX_WASTE then safeScram("WASTE FULL") end
        if r_cool < MIN_COOLANT then safeScram("LOSS OF COOLANT") end
    end

    -- 3. Render
    mon.setBackgroundColor(colors.black)
    
    -- ALERT MODE: Change Header Color
    local headColor = colors.blue
    if scramTriggered then headColor = colors.red end
    
    drawBox(1, 1, w, 3, headColor)
    if scramTriggered then
        centerText(2, "!!! MELTDOWN PREVENTED !!!", colors.yellow, headColor)
    else
        centerText(2, "TITAN-X :: COMMAND", colors.white, headColor)
    end

    -- LEFT COLUMN: REACTOR
    writeText(2, 5, "REACTOR", colors.cyan)
    
    local tempC = (r_temp > 1000) and colors.red or colors.cyan
    drawBar(2, 7, 20, r_temp/SAFE_TEMP, tempC, "Temp: " .. math.floor(r_temp) .. " K")
    
    local coolC = (r_cool < 0.2) and colors.red or colors.lime
    drawBar(2, 10, 20, r_cool, coolC, "Coolant: " .. math.floor(r_cool*100) .. "%")
    
    local wasteC = (r_waste > 0.8) and colors.orange or colors.magenta
    drawBar(2, 13, 20, r_waste, wasteC, "Waste: " .. math.floor(r_waste*100) .. "%")

    writeText(2, 16, "Burn Rate: ", colors.lightGray)
    writeText(13, 16, r_burn .. " mB/t", colors.white)

    -- RIGHT COLUMN: LOGS & POWER
    local col2 = 28
    
    -- LOG WINDOW (The "History Part")
    writeText(col2, 5, "EVENT LOG", colors.lightGray)
    for i, msg in ipairs(actionLog) do
        local yPos = 6 + i
        if yPos < 14 then -- Safety clip
            -- Color code logs
            local logColor = colors.gray
            if string.find(msg, "CRITICAL") then logColor = colors.red 
            elseif string.find(msg, "Rate") then logColor = colors.white
            elseif string.find(msg, "Start") then logColor = colors.lime
            end
            
            mon.setCursorPos(col2, yPos)
            mon.setBackgroundColor(colors.black)
            mon.setTextColor(logColor)
            mon.clearLine() -- Clear old text
            mon.setCursorPos(col2, yPos)
            mon.write(msg)
        end
    end

    -- Quick Grid Stats (Compressed)
    writeText(col2, 14, "Grid: ", colors.yellow)
    writeText(col2+6, 14, formatNum(m_eng).." ("..math.floor((m_eng/m_max)*100).."%)", colors.green)
    writeText(col2, 15, "Prod: ", colors.yellow)
    writeText(col2+6, 15, formatNum(t_prod).." FE/t", colors.lime)

    -- CONTROLS
    local bY = h - 4
    writeText(2, bY, "TARGET: " .. targetBurn .. " mB/t   ", colors.cyan)
    
    -- Buttons
    drawButton("m25", 2, bY+1, 5, 3, colors.gray, "-25", colors.white)
    drawButton("m10", 8, bY+1, 5, 3, colors.gray, "-10", colors.white)
    
    drawButton("p10", 14, bY+1, 5, 3, colors.gray, "+10", colors.white)
    drawButton("p25", 20, bY+1, 5, 3, colors.gray, "+25", colors.white)
    
    drawButton("start", 30, bY+1, 8, 3, colors.green, "START", colors.black)
    drawButton("stop",  40, bY+1, 8, 3, colors.red,   "STOP",  colors.white)
end

-- ================= INPUT =================
local function handleTouch(x, y)
    for name, b in pairs(buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            
            if name == "start" then
                if not scramTriggered then
                    if not reactor.getStatus() then
                        reactor.activate()
                        addLog("System Started")
                    end
                    reactor.setBurnRate(targetBurn)
                else
                    addLog("ERR: CLEAR SCRAM")
                end
            elseif name == "stop" then
                if reactor.getStatus() then
                    reactor.scram()
                    addLog("Manual Stop")
                end
                scramTriggered = false -- Reset alarm state
                scramReason = "None"
                addLog("Alarms Cleared")
            elseif name == "p10" then 
                targetBurn = targetBurn + 10
                addLog("Rate set: " .. targetBurn)
            elseif name == "p25" then 
                targetBurn = targetBurn + 25
                addLog("Rate set: " .. targetBurn)
            elseif name == "m10" then 
                targetBurn = targetBurn - 10
                addLog("Rate set: " .. targetBurn)
            elseif name == "m25" then 
                targetBurn = targetBurn - 25
                addLog("Rate set: " .. targetBurn)
            end
            
            -- Bounds check
            if targetBurn < 0.1 then targetBurn = 0.1 end
            
            -- Apply immediately if running
            if name ~= "stop" and name ~= "start" then
                reactor.setBurnRate(targetBurn)
            end
            return
        end
    end
end

-- ================= RUN =================
-- Boot Animation (Shortened)
mon.setBackgroundColor(colors.black)
mon.clear()
centerText(h/2, "SYSTEM RECOVERED", colors.lime, colors.black)
sleep(1)

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
