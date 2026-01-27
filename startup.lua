-- PROMETHEUS: ETERNAL FIRE v11.0
-- "God of Fire" Edition
-- Features: 60-Second Trends, Full Matrix Analytics, Crash Report

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         
local MAX_WASTE = 0.90         
local MIN_COOLANT = 0.15       
local REFRESH_RATE = 1.0 

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort") 
local mon     = peripheral.find("monitor")

if not reactor then error("No Reactor Adapter found!") end
if not mon then error("No Monitor found!") end

mon.setTextScale(0.5)
local w, h = mon.getSize()

-- ================= STATE & TRENDS =================
local scramTriggered = false
local scramReason = "None"
local targetBurn = 50.0 
local actionLog = {}

-- Trend History
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
    local r_stat = getVal(reactor.getStatus)
    local r_temp = getVal(reactor.getTemperature)
    local r_cool = getVal(reactor.getCoolantFilledPercentage)
    local r_wast = getVal(reactor.getWasteFilledPercentage)
    local r_burn = getVal(reactor.getBurnRate)
    local r_heat = getVal(reactor.getHeatingRate)
    local r_dmg  = getVal(reactor.getDamagePercent)
    
    local t_flow, t_prod = 0, 0
    if turbine then 
        t_flow = getVal(turbine.getFlowRate)
        t_prod = getVal(turbine.getProductionRate)
    end
    
    local m_eng, m_max = 0, 1
    if matrix then
        m_eng = getVal(matrix.getEnergy)
        m_max = getVal(matrix.getMaxEnergy)
    end
    if m_max <= 0 then m_max = 1 end

    -- 2. Update Trends
    updateTrend("temp", r_temp)
    updateTrend("burn", r_burn)
    updateTrend("heat", r_heat)
    updateTrend("flow", t_flow)
    updateTrend("prod", t_prod)
    updateTrend("energy", m_eng)

    -- 3. Safety Logic
    local safeReason = nil
    if r_dmg > 0 then safeReason = "DAMAGE DETECTED" end
    if r_temp >= SAFE_TEMP then safeReason = "OVERHEAT" end
    if r_wast >= MAX_WASTE then safeReason = "WASTE FULL" end
    if r_cool < MIN_COOLANT then safeReason = "LOSS OF COOLANT" end

    if safeReason then
        if reactor.getStatus() then pcall(reactor.scram) end
        scramTriggered = true
        scramReason = safeReason
        addLog("CRITICAL: " .. safeReason)
    end

    -- 4. RENDER
    mon.setBackgroundColor(colors.black)
    
    if scramTriggered then
        -- CRASH MODE
        drawBox(1, 1, w, 3, colors.red)
        centerText(2, "!!! CORE FAILURE !!!", colors.yellow, colors.red)
        writeText(2, 5, "CAUSE: " .. scramReason, colors.red)
        writeText(2, 7, "DAMAGE: " .. r_dmg .. "%", colors.orange)
        writeText(2, 9, "EVENT LOG:", colors.lightGray)
        for i, msg in ipairs(actionLog) do
            if i <= 8 then writeText(2, 9+i, msg, colors.white) end
        end
    else
        -- DASHBOARD MODE
        drawBox(1, 1, w, 3, colors.orange)
        centerText(2, "PROMETHEUS :: ETERNAL FIRE", colors.black, colors.orange)

        -- === COLUMN 1: REACTOR ===
        writeText(2, 5, "REACTOR CORE", colors.orange)
        
        -- Status
        writeText(2, 6, "Status:", colors.lightGray)
        if r_stat then writeText(10, 6, "ACTIVE", colors.lime)
        else writeText(10, 6, "IDLE", colors.gray) end
        
        -- Temp + Trend
        local t_trend = getTrend("temp")
        local t_col = (r_temp > 1000) and colors.red or colors.white
        writeText(2, 7, "Temp:   "..math.floor(r_temp).." K", t_col)
        writeText(20, 7, formatTrend(t_trend, "K"), (t_trend > 0 and colors.red or colors.green))
        
        -- Heating Rate
        writeText(2, 8, "Heat:   "..formatNum(r_heat), colors.white)
        writeText(20, 8, formatTrend(getTrend("heat"), ""), colors.gray)

        -- Burn Rate
        writeText(2, 9, "Burn:   "..r_burn.." mB/t", colors.white)
        writeText(20, 9, formatTrend(getTrend("burn"), ""), colors.gray)
        
        -- Damage
        writeText(2, 10, "Integrity: "..(100-r_dmg).."%", (r_dmg > 0 and colors.red or colors.green))

        -- Bars
        local coolC = (r_cool < 0.2) and colors.red or colors.cyan
        drawBar(2, 12, 22, r_cool, coolC, "Coolant: "..math.floor(r_cool*100).."%")
        
        local wasteC = (r_wast > 0.8) and colors.orange or colors.magenta
        drawBar(2, 14, 22, r_wast, wasteC, "Waste: "..math.floor(r_wast*100).."%")

        -- === COLUMN 2: POWER ===
        local col2 = 32
        writeText(col2, 5, "GRID & MATRIX", colors.yellow)
        
        -- Turbine Stats
        writeText(col2, 6, "Flow:   "..formatNum(t_flow).." mB/t", colors.white)
        writeText(col2+20, 6, formatTrend(getTrend("flow"), ""), colors.gray)
        
        writeText(col2, 7, "Prod:   "..formatNum(t_prod).." FE/t", colors.lime)
        writeText(col2+20, 7, formatTrend(getTrend("prod"), ""), colors.gray)
        
        -- Matrix Stats
        local m_trend = getTrend("energy")
        local m_pct = m_eng / m_max
        
        writeText(col2, 9, "Matrix Charge:", colors.green)
        drawBar(col2, 10, 22, m_pct, colors.green, "")
        
        writeText(col2, 12, "Stored: "..formatNum(m_eng).." FE", colors.white)
        writeText(col2, 13, "Cap:    "..formatNum(m_max).." FE", colors.gray)
        
        -- Calculated Power Change
        writeText(col2, 14, "Net Change:", colors.lightGray)
        local changeCol = (m_trend >= 0) and colors.lime or colors.red
        writeText(col2+12, 14, formatTrend(m_trend, " /m"), changeCol)
    end

    -- CONTROLS
    local bY = h - 4
    if not scramTriggered then
        writeText(2, bY, "TARGET: " .. targetBurn .. " mB/t   ", colors.cyan)
    else
        writeText(2, bY, "SYSTEM HALTED - RESTART REQUIRED", colors.red)
    end
    
    drawButton("m10", 2, bY+1, 5, 3, colors.gray, "-10", colors.white)
    drawButton("p10", 8, bY+1, 5, 3, colors.gray, "+10", colors.white)
    drawButton("start", 14, bY+1, 8, 3, colors.green, "IGNITE", colors.black)
    drawButton("stop",  23, bY+1, 8, 3, colors.red,   "SCRAM",  colors.white)
end

-- ================= INPUT =================
local function handleTouch(x, y)
    for name, b in pairs(buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            if name == "start" then
                if not scramTriggered then
                    if not reactor.getStatus() then reactor.activate(); addLog("Ignition Seq") end
                    reactor.setBurnRate(targetBurn)
                else addLog("ERR: Clear Alarm") end
            elseif name == "stop" then
                if reactor.getStatus() then reactor.scram(); addLog("Manual SCRAM") end
                if scramTriggered then scramTriggered = false; scramReason = "None"; mon.clear() end
            elseif name == "p10" then 
                targetBurn = targetBurn + 10; addLog("Rate +10")
            elseif name == "m10" then 
                targetBurn = targetBurn - 10; addLog("Rate -10")
            end
            if targetBurn < 0.1 then targetBurn = 0.1 end
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
centerText(h/2, "PROMETHEUS ONLINE", colors.orange, colors.black)
sleep(1)
parallel.waitForAny(
    function() while true do drawGUI(); sleep(REFRESH_RATE) end end,
    function() while true do local _,_,x,y = os.pullEvent("monitor_touch"); handleTouch(x,y) end end
)
