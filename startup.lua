-- TITAN-X: DEUS EX MACHINA (v13.0)
-- Update: Total FE Conversion (All Joules removed)
-- Ratio: 2.5 Joules = 1 FE

-- ================= CONFIGURATION =================
local SAFE_TEMP_K = 1200       -- Scram Limit (Kelvin)
local MAX_WASTE = 0.90         -- 90% Waste
local MIN_COOLANT = 0.15       -- 15% Coolant
local REFRESH_RATE = 1.0       
local J_TO_FE = 0.4            -- 1 J = 0.4 FE

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort") 
local mon     = peripheral.find("monitor")

if not reactor then error("No Reactor Adapter found!") end
if not mon then error("No Monitor found!") end

mon.setTextScale(0.5)
local w, h = mon.getSize()

-- ================= STATE & HISTORY =================
local scramTriggered = false
local scramReason = "None"
local targetBurn = 50.0 
local actionLog = {}

local history = {
    temp = {}, burn = {}, heat = {},
    flow = {}, prod = {}, energy = {}
}

-- Sync burn rate safely
local ok, rate = pcall(function() return reactor.getBurnRate() end)
if ok and rate and rate > 0.1 then targetBurn = rate end

-- ================= DATA TOOLS =================
local function getVal(func)
    if not func then return 0 end
    local success, result = pcall(func)
    if success and result then return tonumber(result) or 0 end
    return 0 
end

local function toCelsius(k) return k - 273.15 end

-- Universal Conversion Helper
local function toFE(joules) 
    if not joules then return 0 end
    return joules * J_TO_FE 
end

local function formatNum(num)
    if not num then num = 0 end
    local absNum = math.abs(num)
    if absNum >= 1e12 then return string.format("%.2f T", num/1e12) end
    if absNum >= 1e9 then return string.format("%.2f G", num/1e9) end
    if absNum >= 1e6 then return string.format("%.2f M", num/1e6) end
    if absNum >= 1e3 then return string.format("%.1f k", num/1e3) end
    return string.format("%.1f", num)
end

local function addLog(msg)
    local timeStr = textutils.formatTime(os.time("local"), true)
    table.insert(actionLog, 1, "["..timeStr.."] " .. msg)
    if #actionLog > 12 then table.remove(actionLog) end
end

-- ================= TREND ENGINE =================
local function updateTrend(key, value)
    local now = os.epoch("utc")
    table.insert(history[key], {t = now, v = value})
    while #history[key] > 0 and (now - history[key][1].t > 60000) do
        table.remove(history[key], 1)
    end
end

local function getTrend(key)
    local data = history[key]
    if #data < 2 then return 0 end
    return data[#data].v - data[1].v
end

local function formatTrend(val, suffix)
    local sym = (val >= 0) and "+" or ""
    return "(" .. sym .. formatNum(val) .. suffix .. ")"
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
    if filled > 0 then mon.write(string.rep(" ", filled)) end
    mon.setBackgroundColor(colors.black)
end

local function drawButton(name, x, y, width, height, color, label, textColor)
    drawBox(x, y, width, height, color)
    mon.setTextColor(textColor or colors.black)
    local tx = x + math.floor((width - #label)/2)
    local ty = y + math.floor(height/2)
    mon.setCursorPos(tx, ty)
    mon.write(label)
    return {name=name, x=x, y=y, w=width, h=height}
end

-- ================= MAIN UI =================
local buttons = {} 

local function drawGUI()
    buttons = {} 
    
    -- 1. Get Data (RAW JOULES)
    local r_stat = getVal(reactor.getStatus)
    local r_tempK = getVal(reactor.getTemperature)
    local r_cool = getVal(reactor.getCoolantFilledPercentage)
    local r_wast = getVal(reactor.getWasteFilledPercentage)
    local r_burn = getVal(reactor.getBurnRate)
    local r_heat = getVal(reactor.getHeatingRate)
    local r_dmg  = getVal(reactor.getDamagePercent)
    
    local t_flow = 0
    local t_prod_j = 0 -- Joules
    if turbine then 
        t_flow = getVal(turbine.getFlowRate)
        t_prod_j = getVal(turbine.getProductionRate)
    end
    
    local m_eng_j, m_max_j = 0, 1 -- Joules
    if matrix then
        m_eng_j = getVal(matrix.getEnergy)
        m_max_j = getVal(matrix.getMaxEnergy)
    end
    if m_max_j <= 0 then m_max_j = 1 end

    -- 2. Convert Data to FE
    local r_tempC = toCelsius(r_tempK)
    local t_prod  = toFE(t_prod_j) -- Converted
    local m_eng   = toFE(m_eng_j)  -- Converted
    local m_max   = toFE(m_max_j)  -- Converted

    -- 3. Update Trends (Using FE Values)
    updateTrend("temp", r_tempC) 
    updateTrend("burn", r_burn)
    updateTrend("heat", r_heat)
    updateTrend("flow", t_flow)
    updateTrend("prod", t_prod) -- Storing FE trend
    updateTrend("energy", m_eng) -- Storing FE trend

    -- 4. Safety Logic (Kelvin)
    local safeReason = nil
    if r_dmg > 0 then safeReason = "HULL DAMAGE DETECTED" end
    if r_tempK >= SAFE_TEMP_K then safeReason = "CORE MELTDOWN IMMINENT" end
    if r_wast >= MAX_WASTE then safeReason = "WASTE CONTAINMENT FULL" end
    if r_cool < MIN_COOLANT then safeReason = "COOLANT LOSS DETECTED" end

    if safeReason then
        if reactor.getStatus() then pcall(reactor.scram) end
        scramTriggered = true
        scramReason = safeReason
        addLog("CRITICAL: " .. safeReason)
    end

    -- 5. RENDER
    mon.setBackgroundColor(colors.black)
    
    if scramTriggered then
        -- CRASH MODE
        drawBox(1, 1, w, 3, colors.red)
        centerText(2, "!!! DEUS EX MACHINA FAILED !!!", colors.yellow, colors.red)
        writeText(2, 5, "FAILURE CAUSE: " .. scramReason, colors.red)
        writeText(2, 7, "INTEGRITY: " .. (100 - r_dmg) .. "%", colors.orange)
        writeText(2, 9, "BLACK BOX LOGS:", colors.lightGray)
        for i, msg in ipairs(actionLog) do
            if i <= 8 then writeText(2, 9+i, msg, colors.white) end
        end
    else
        -- DASHBOARD MODE
        drawBox(1, 1, w, 3, colors.blue)
        centerText(2, "TITAN-X: DEUS EX MACHINA", colors.white, colors.blue)

        -- LEFT: REACTOR
        writeText(2, 5, "CORE STATUS", colors.cyan)
        
        if r_stat then writeText(14, 5, "ONLINE", colors.lime)
        else writeText(14, 5, "OFFLINE", colors.gray) end
        
        -- Temp
        local t_trend = getTrend("temp")
        local t_col = (r_tempK > 1000) and colors.red or colors.white
        writeText(2, 7, "Temp:   "..math.floor(r_tempC).." \127C", t_col) 
        writeText(20, 7, formatTrend(t_trend, "\127"), (t_trend > 0 and colors.orange or colors.green))
        
        -- Heat
        writeText(2, 8, "Heat:   "..formatNum(r_heat), colors.white)
        writeText(20, 8, formatTrend(getTrend("heat"), ""), colors.gray)

        -- Burn
        writeText(2, 9, "Burn:   "..r_burn.." mB/t", colors.white)
        writeText(20, 9, formatTrend(getTrend("burn"), ""), colors.gray)
        
        -- Damage
        writeText(2, 10, "Damage: "..r_dmg.."%", (r_dmg > 0 and colors.red or colors.green))

        -- Bars
        local coolC = (r_cool < 0.2) and colors.red or colors.lime
        drawBar(2, 12, 22, r_cool, coolC, "Coolant: "..math.floor(r_cool*100).."%")
        
        local wasteC = (r_wast > 0.8) and colors.orange or colors.magenta
        drawBar(2, 14, 22, r_wast, wasteC, "Waste: "..math.floor(r_wast*100).."%")

        -- RIGHT: POWER
        local col2 = 32
        writeText(col2, 5, "ENERGY GRID (FE)", colors.yellow)
        
        -- Turbine
        writeText(col2, 6, "Flow:   "..formatNum(t_flow).." mB/t", colors.white)
        writeText(col2+20, 6, formatTrend(getTrend("flow"), ""), colors.gray)
        
        writeText(col2, 7, "Prod:   "..formatNum(t_prod).." FE/t", colors.lime)
        writeText(col2+20, 7, formatTrend(getTrend("prod"), ""), colors.gray)
        
        -- Matrix
        local m_trend = getTrend("energy")
        local m_pct = m_eng / m_max
        
        writeText(col2, 9, "Matrix Charge:", colors.green)
        drawBar(col2, 10, 22, m_pct, colors.green, "")
        
        writeText(col2, 12, "Stored: "..formatNum(m_eng).." FE", colors.white)
        writeText(col2, 13, "Cap:    "..formatNum(m_max).." FE", colors.gray)
        
        -- Change
        writeText(col2, 14, "Delta:  ", colors.lightGray)
        local changeCol = (m_trend >= 0) and colors.lime or colors.red
        writeText(col2+8, 14, formatNum(m_trend).." FE/m", changeCol)
    end

    -- CONTROLS
    local bY = h - 4
    if not scramTriggered then
        writeText(2, bY, "TARGET: " .. targetBurn .. " mB/t   ", colors.cyan)
    else
        writeText(2, bY, "FATAL ERROR - MANUAL RESET REQUIRED", colors.red)
    end
    
    local b1 = drawButton("m10", 2, bY+1, 5, 3, colors.gray, "-10", colors.white)
    local b2 = drawButton("p10", 8, bY+1, 5, 3, colors.gray, "+10", colors.white)
    local b3 = drawButton("start", 14, bY+1, 8, 3, colors.green, "START", colors.black)
    local b4 = drawButton("stop",  23, bY+1, 8, 3, colors.red,   "STOP",  colors.white)
    
    table.insert(buttons, b1); table.insert(buttons, b2)
    table.insert(buttons, b3); table.insert(buttons, b4)
end

-- ================= INPUT =================
local function handleTouch(x, y)
    for _, b in ipairs(buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            if b.name == "start" then
                if not scramTriggered then
                    if not reactor.getStatus() then reactor.activate(); addLog("System Engaged") end
                    reactor.setBurnRate(targetBurn)
                else addLog("ERR: Clear Alarm") end
            elseif b.name == "stop" then
                if reactor.getStatus() then reactor.scram(); addLog("Manual Override") end
                if scramTriggered then scramTriggered = false; scramReason = "None"; mon.clear() end
            elseif b.name == "p10" then 
                targetBurn = targetBurn + 10; addLog("Burn Rate +10")
            elseif b.name == "m10" then 
                targetBurn = targetBurn - 10; addLog("Burn Rate -10")
            end
            if targetBurn < 0.1 then targetBurn = 0.1 end
            if b.name ~= "stop" and b.name ~= "start" and not scramTriggered then
                reactor.setBurnRate(targetBurn)
            end
            return
        end
    end
end

-- ================= RUN =================
mon.setBackgroundColor(colors.black)
mon.clear()

mon.setTextScale(1)
centerText(h/2, "AWAKENING", colors.red, colors.black)
sleep(1)
centerText(h/2, "THE MACHINE GOD...", colors.red, colors.black)
sleep(1)
mon.setTextScale(0.5)
w, h = mon.getSize()
mon.clear()

parallel.waitForAny(
    function() while true do drawGUI(); sleep(REFRESH_RATE) end end,
    function() while true do local _,_,x,y = os.pullEvent("monitor_touch"); handleTouch(x,y) end end
)
