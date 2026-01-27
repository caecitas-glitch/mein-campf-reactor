-- TITAN-X: OMEGA PROTOCOL v5.0
-- "Paranoid Edition" - Crash Proofing

-- ================= CONFIGURATION =================
local SAFE_TEMP = 1200         
local MAX_WASTE = 0.90         
local MIN_COOLANT = 0.15       
local BURN_STEP = 10.0         
local REFRESH_RATE = 0.5       

-- ================= PERIPHERALS =================
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix  = peripheral.find("inductionPort")
local mon     = peripheral.find("monitor")

if not reactor then error("ERR: NO REACTOR") end
if not mon then error("ERR: NO MONITOR") end

mon.setTextScale(0.5) 
local w, h = mon.getSize()

-- ================= SAFETY TOOLS =================
-- These functions prevent the "number expected, got nil" error

local function safeNum(n)
    return tonumber(n) or 0
end

local function safeColor(c, default)
    if c == nil then return default or colors.white end
    return c
end

-- ================= COLORS =================
local C_BG      = safeColor(colors.black, colors.black)
local C_PANEL   = safeColor(colors.gray, colors.gray)
local C_HEADER  = safeColor(colors.blue, colors.blue)
local C_TEXT    = safeColor(colors.white, colors.white)
local C_LABEL   = safeColor(colors.lightGray, colors.white)
local C_GOOD    = safeColor(colors.lime, colors.green)
local C_WARN    = safeColor(colors.orange, colors.yellow)
local C_BAD     = safeColor(colors.red, colors.red)
local C_DATA    = safeColor(colors.cyan, colors.blue)
local C_WASTE   = safeColor(colors.magenta, colors.purple)

-- ================= STATE =================
local scramTriggered = false
local scramReason = "NONE"
local targetBurn = safeNum(reactor.getBurnRate()) 
if targetBurn < 0.1 then targetBurn = 0.1 end -- Prevent 0 burn rate

-- ================= FORMATTING =================
local function formatNum(num)
    num = safeNum(num)
    if num >= 1e12 then return string.format("%.2f T", num/1e12) end
    if num >= 1e9 then return string.format("%.2f G", num/1e9) end
    if num >= 1e6 then return string.format("%.2f M", num/1e6) end
    if num >= 1e3 then return string.format("%.1f k", num/1e3) end
    return string.format("%.1f", num)
end

local function drawBox(x, y, width, height, color)
    color = safeColor(color, C_PANEL)
    mon.setBackgroundColor(color)
    for i = 0, height-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function centerText(y, text, fg, bg)
    mon.setCursorPos(math.ceil((w - #text) / 2), y)
    mon.setTextColor(safeColor(fg, C_TEXT))
    mon.setBackgroundColor(safeColor(bg, C_BG))
    mon.write(text)
end

local function drawBar(x, y, width, percent, color, label)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(C_PANEL)
    mon.setTextColor(C_LABEL)
    mon.write(label)
    
    local barW = width
    percent = safeNum(percent)
    if percent < 0 then percent = 0 end
    if percent > 1 then percent = 1 end

    local filled = math.floor(percent * barW)
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", barW))
    
    mon.setCursorPos(x, y+1)
    mon.setBackgroundColor(safeColor(color, C_DATA))
    if filled > 0 then
        mon.write(string.rep(" ", filled))
    end
end

-- ================= ANIMATION =================
local function bootSequence()
    mon.setTextScale(1)
    mon.setBackgroundColor(C_BG)
    mon.clear()
    
    centerText(h/2, "SYSTEM INITIALIZING", C_DATA, C_BG)
    sleep(0.5)
    
    -- "Clamps" Animation
    mon.setBackgroundColor(C_PANEL)
    mon.clear()
    
    for i=0, h/2 do
        mon.setCursorPos(1, i)
        mon.setBackgroundColor(colors.black)
        mon.clearLine()
        
        mon.setCursorPos(1, h-i)
        mon.setBackgroundColor(colors.black)
        mon.clearLine()
        sleep(0.05)
    end
    
    mon.setTextScale(0.5) 
    local newW, newH = mon.getSize()
    w, h = newW, newH 
end

-- ================= UI DRAWING =================
local function drawStaticUI()
    mon.setBackgroundColor(C_BG)
    mon.clear()
    
    -- Header
    drawBox(1, 1, w, 3, C_HEADER)
    centerText(2, "TITAN-X OMEGA :: DASHBOARD", C_TEXT, C_HEADER)
    
    -- Panel Frames
    mon.setBackgroundColor(C_PANEL)
    drawBox(2, 5, 24, h-8, C_PANEL)   -- Reactor
    drawBox(28, 5, 24, h-8, C_PANEL)  -- Turbine
    drawBox(54, 5, w-55, h-8, C_PANEL)-- Status
    
    -- Labels
    mon.setTextColor(C_TEXT)
    mon.setCursorPos(4, 6); mon.write("REACTOR CORE")
    mon.setCursorPos(30, 6); mon.write("TURBINE & MATRIX")
    mon.setCursorPos(56, 6); mon.write("SYSTEM STATUS")
    
    -- Footer
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
    
    -- Rate
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
    -- Fetch & Sanitize Data
    local r_stat = reactor.getStatus()
    local r_temp = safeNum(reactor.getTemperature())
    local r_burn = safeNum(reactor.getBurnRate())
    local r_cool = safeNum(reactor.getCoolantFilledPercentage())
    local r_wast = safeNum(reactor.getWasteFilledPercentage())
    local r_fuel = safeNum(reactor.getFuelFilledPercentage())
    local r_heat = safeNum(reactor.getHeatingRate())
    local r_dmg  = safeNum(reactor.getDamagePercent())
    
    local t_flow = 0
    local t_prod = 0
    if turbine then
        t_flow = safeNum(turbine.getFlowRate())
        t_prod = safeNum(turbine.getProductionRate())
    end
    
    local m_energy = 0
    local m_max = 1
    local m_in = 0
    if matrix then
        m_energy = safeNum(matrix.getEnergy())
        m_max    = safeNum(matrix.getMaxEnergy())
        m_in     = safeNum(matrix.getLastInput())
    end
    if m_max <= 0 then m_max = 1 end 

    -- === COLUMN 1: REACTOR ===
    mon.setBackgroundColor(C_PANEL)
    
    local tempCol = r_temp > 1000 and C_BAD or C_DATA
    drawBar(3, 8, 22, r_temp/SAFE_TEMP, tempCol, "Temp: " .. math.floor(r_temp) .. " K")
    
    local coolCol = r_cool < 0.2 and C_BAD or C_DATA
    drawBar(3, 11, 22, r_cool, coolCol, "Coolant: " .. math.floor(r_cool*100) .. "%")
    
    drawBar(3, 14, 22, r_fuel, C_GOOD, "Fuel: " .. math.floor(r_fuel*100) .. "%")
    
    local wasteCol = r_wast > 0.8 and C_WARN or C_WASTE
    drawBar(3, 17, 22, r_wast, wasteCol, "Waste: " .. math.floor(r_wast*100) .. "%")
    
    mon.setCursorPos(3, 20); mon.setTextColor(C_LABEL); mon.write("Burn: ")
    mon.setTextColor(C_TEXT); mon.write(r_burn .. " mB/t")
    
    mon.setCursorPos(3, 21); mon.setTextColor(C_LABEL); mon.write("Heat: ")
    mon.setTextColor(C_TEXT); mon.write(formatNum(r_heat) .. "")

    -- === COLUMN 2: POWER ===
    mon.setCursorPos(29, 8); mon.setTextColor(colors.yellow); mon.write("TURBINE")
    mon.setCursorPos(29, 9); mon.setTextColor(C_LABEL); mon.write("Prod: "); 
    mon.setTextColor(C_TEXT); mon.write(formatNum(t_prod) .. " FE/t")
    
    mon.setCursorPos(29, 12); mon.setTextColor(colors.green); mon.write("INDUCTION MATRIX")
    local matPct = m_energy / m_max
    
    drawBar(29, 13, 22, matPct, colors.green, "Chg: " .. math.floor(matPct*100) .. "%")
    
    mon.setCursorPos(29, 16); mon.setTextColor(C_LABEL); mon.write("Store: ")
    mon.setTextColor(C_TEXT); mon.write(formatNum(m_energy) .. " FE")

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
    
    mon.setCursorPos(56, 12)
    mon.setTextColor(C_LABEL)
    mon.write("TARGET RATE:")
    mon.setCursorPos(56, 13)
    mon.setTextColor(C_DATA)
    mon.setTextScale(1) 
    mon.write(targetBurn .. "  ")
    mon.setTextScale(0.5) 
    
    return {temp=r_temp, waste=r_wast, cool=r_cool, damage=r_dmg}
end

-- ================= LOGIC =================
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
    if y >= h-3 and y <= h-1 then
        if x >= 2 and x <= 12 then
            if not scramTriggered then
                reactor.activate()
                reactor.setBurnRate(targetBurn)
            end
        end
        if x >= 14 and x <= 24 then
            reactor.scram()
            scramTriggered = false
            scramReason = "MANUAL"
        end
        if x >= w-20 and x <= w-12 then
            targetBurn = targetBurn - BURN_STEP
            if targetBurn < 0.1 then targetBurn = 0.1 end
            reactor.setBurnRate(targetBurn)
        end
        if x >= w-10 and x <= w-2 then
            targetBurn = targetBurn + BURN_STEP
            reactor.setBurnRate(targetBurn)
        end
    end
end

-- ================= RUN =================
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
