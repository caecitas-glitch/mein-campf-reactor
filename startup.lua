-- TITAN-X: v9.0 ULTIMATE DASHBOARD
-- Mode 1: Full Data (Normal)
-- Mode 2: Crash Report (Scram)

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
    local timeStr = textutils.formatTime(os.time("local"), true)
    table.insert(actionLog, 1, "["..timeStr.."] " .. msg)
    -- Keep last 12 messages for the crash report
    if #actionLog > 12 then table.remove(actionLog) end
end

addLog("System Booted.")

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

local function safeScram(reason)
    -- Only scram if active (prevents crash on offline scram)
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

    -- 3. RENDER LOGIC
    mon.setBackgroundColor(colors.black)
    -- mon.clear() -- Optimized: Don't clear every frame to prevent flicker

    if scramTriggered then
        -- === MODE: CRASH REPORT ===
        drawBox(1, 1, w, 3, colors.red)
        centerText(2, "!!! MELTDOWN PREVENTED !!!", colors.yellow, colors.red)
        
        -- Draw Report
        writeText(2, 5, "CAUSE: " .. scramReason, colors.red)
        writeText(2, 7, "--- EVENT LOG HISTORY ---", colors.lightGray)
        
        for i, msg in ipairs(actionLog) do
            local yPos = 8 + i
            if yPos < h - 4 then
                mon.setCursorPos(2, yPos)
                mon.clearLine()
                if string.find(msg, "CRITICAL") then
                    mon.setTextColor(colors.red)
                else
                    mon.setTextColor(colors.white)
                end
                mon.write(msg)
            end
        end

    else
        -- === MODE: FULL DASHBOARD ===
        drawBox(1, 1, w, 3, colors.blue)
        centerText(2, "TITAN-X :: COMMAND", colors.white, colors.blue)

        -- LEFT: REACTOR STATS
        writeText(2, 5, "REACTOR CORE", colors.cyan)
        
        local tempC = (r_temp > 1000) and colors.red or colors.cyan
        drawBar(2, 7, 24, r_temp/SAFE_TEMP, tempC, "Temp: " .. math.floor(r_temp) .. " K")
        
        local coolC = (r_cool < 0.2) and colors.red or colors.lime
        drawBar(2, 10, 24, r_cool, coolC, "Coolant: " .. math.floor(r_cool*100) .. "%")
        
        local wasteC = (r_waste > 0.8) and colors.orange or colors.magenta
        drawBar(2, 13, 24, r_waste, wasteC, "Waste: " .. math.floor(r_waste*100) .. "%")

        writeText(2, 16, "Burn Rate: ", colors.lightGray)
        writeText(13, 16, r_burn .. " mB/t", colors.white)

        -- RIGHT: POWER STATS (Restored Full Info)
        local col2 = 30
        writeText(col2, 5, "POWER GRID", colors.yellow)
        
        writeText(col2, 7, "Turbine:", colors.lightGray)
        writeText(col2+9, 7, formatNum(t_prod).." FE/t", colors.lime)
        
        -- Matrix Bar
        local matPct = m_eng / m_max
        drawBar(col2, 9, 24, matPct, colors.green, "Matrix: "..math.floor(matPct*100).."%")
        
        -- Detailed I/O
        writeText(col2, 12, "Store: ", colors.lightGray)
        writeText(col2+7, 12, formatNum(m_eng).." FE", colors.white)
        
        writeText(col2, 13, "Input: ", colors.lightGray)
        writeText(col2+7, 13, formatNum(m_in).." FE/t", colors.green)
        
        writeText(col2, 14, "Output:", colors.lightGray)
        writeText(col2+8, 14, formatNum(m_out).." FE/t", colors.red)

        -- SYSTEM STATUS
        writeText(col2, 16, "STATUS: ", colors.lightGray)
        if r_status then
            writeText(col2+8, 16, "ONLINE", colors.lime)
        else
            writeText(col2+8, 16, "STANDBY", colors.orange)
        end
    end

    -- CONTROLS (Always visible)
    local bY = h - 4
    if not scramTriggered then
        writeText(2, bY, "TARGET: " .. targetBurn .. " mB/t   ", colors.cyan)
    else
        writeText(2, bY, "SYSTEM HALTED - RESTART REQUIRED", colors.red)
    end
    
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
                        addLog("Manual Start")
                    end
                    reactor.setBurnRate(targetBurn)
                else
                    addLog("ERR: Clear Alarm First")
                end
            elseif name == "stop" then
                if reactor.getStatus() then
                    reactor.scram()
                    addLog("Manual Scram")
                end
                -- RESET SCRAM STATE
                if scramTriggered then
                    scramTriggered = false
                    scramReason = "None"
                    addLog("Alarms Reset")
                    mon.clear() -- Clear the red screen
                end
            elseif name == "p10" then 
                targetBurn = targetBurn + 10
                addLog("Rate +10 -> " .. targetBurn)
            elseif name == "p25" then 
                targetBurn = targetBurn + 25
                addLog("Rate +25 -> " .. targetBurn)
            elseif name == "m10" then 
                targetBurn = targetBurn - 10
                addLog("Rate -10 -> " .. targetBurn)
            elseif name == "m25" then 
                targetBurn = targetBurn - 25
                addLog("Rate -25 -> " .. targetBurn)
            end
            
            -- Bounds check
            if targetBurn < 0.1 then targetBurn = 0.1 end
            
            -- Apply immediately if running
            if name ~= "stop" and name ~= "start" and not scramTriggered then
                reactor.setBurnRate(targetBurn)
            end
            return
        end
    end
end

-- ================= RUN =================
mon.setBackgroundColor(colors.black)
mon.clear()
centerText(h/2, "SYSTEM RELOADED", colors.lime, colors.black)
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
