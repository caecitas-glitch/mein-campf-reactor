-- AEGIS-OS v21.0.1: OBSIDIAN PRIME (PATCHED)
local VERSION = "21.0.1"

-- 1. HARDWARE LINKING
local device = term.current() 
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix  = peripheral.find("induction_port")

local w, h = device.getSize()
local isScrammed = false
local scramReason = "STABLE"

-- 2. SAFE DATA RETRIEVAL
local function getSafe(obj, func)
    if not obj then return nil end
    local ok, res = pcall(obj[func])
    return ok and res or nil
end

-- 3. THE SINGULARITY BOOT
local function playSingularity()
    device.setBackgroundColor(colors.black)
    device.clear()
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    for r = 6, 1, -1 do
        device.clear()
        device.setTextColor(colors.white)
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 1.5))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("o") end
        end
        sleep(0.1)
    end
    device.clear()
    device.setTextColor(colors.blue)
    device.setCursorPos(cx, cy) device.write("@")
    sleep(0.15)
    for r = 1, 8 do
        for a = 0, 360, 45 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("*") end
        end
        sleep(0.04)
    end
    device.clear()
end

-- 4. RENDERING
local function drawUI(data)
    device.setBackgroundColor(colors.black)
    device.clear()
    device.setCursorPos(1, 1)
    device.setBackgroundColor(isScrammed and colors.red or colors.blue)
    device.clearLine()
    device.write(" AEGIS OS v" .. VERSION .. " | " .. (isScrammed and scramReason or "OK"))
    device.setBackgroundColor(colors.black)
    device.setTextColor(colors.white)
    device.setCursorPos(1, 3) device.write("TEMP: " .. math.floor(data.temp or 0) .. "K")
    device.setCursorPos(1, 4) device.write("DMG:  " .. (data.dmg or 0) .. "%")
    device.setCursorPos(1, 5) device.write("BURN: " .. (data.burn or 0))
    device.setCursorPos(1, 7) device.setTextColor(colors.cyan)
    device.write("STM: " .. math.floor((data.steam/data.sMax)*100) .. "%")
    device.setCursorPos(1, 8) device.setTextColor(colors.green)
    device.write("PWR: " .. math.floor((data.stored/data.maxE)*100) .. "%")
    device.setTextColor(colors.white)
    device.setCursorPos(18, 3) device.setBackgroundColor(colors.gray) device.write(" [-10] ")
    device.setCursorPos(18, 5) device.setBackgroundColor(colors.gray) device.write(" [+10] ")
    device.setCursorPos(1, 11)
    device.setBackgroundColor(colors.red) device.setTextColor(colors.white)
    device.write("     [ STOP ]     ")
    device.setCursorPos(1, 13)
    device.setBackgroundColor(isScrammed and colors.orange or colors.gray)
    device.setTextColor(colors.black)
    device.write("     [ RESET ]    ")
end

-- 5. THE IRON SENTRY (Failsafe Logic)
local function monitorCore()
    while true do
        -- Refresh peripheral links in case they were lost
        reactor = reactor or peripheral.find("fission_reactor_logic_adapter")
        turbine = turbine or peripheral.find("turbine_valve")
        matrix  = matrix or peripheral.find("induction_port")

        local data = {
            temp = getSafe(reactor, "getTemperature") or 0,
            dmg = getSafe(reactor, "getDamage") or 0,
            burn = getSafe(reactor, "getBurnRate") or 0,
            steam = (turbine and getSafe(turbine, "getSteam")) and turbine.getSteam().amount or 0,
            sMax = getSafe(turbine, "getSteamCapacity") or 1,
            stored = getSafe(matrix, "getEnergy") or 0,
            maxE = getSafe(matrix, "getMaxEnergy") or 1,
            waste = (reactor and getSafe(reactor, "getWaste")) and reactor.getWaste().amount or 0,
            wMax = getSafe(reactor, "getWasteCapacity") or 1
        }

        if data.dmg > 0 then isScrammed = true scramReason = "DMG!"
        elseif data.temp > 1150 then isScrammed = true scramReason = "HEAT!"
        elseif data.waste / data.wMax > 0.95 then isScrammed = true scramReason = "WASTE"
        elseif data.steam / data.sMax > 0.98 then isScrammed = true scramReason = "STEAM"
        elseif data.stored / data.maxE > 0.99 then isScrammed = true scramReason = "POWER"
        end

        if isScrammed and reactor then 
            pcall(reactor.setBurnRate, 0) 
            pcall(reactor.scram) 
        end

        drawUI(data)
        sleep(0.5) 
    end
end

-- 6. THE TOUCH SENSOR
local function touchListener()
    while true do
        local _, _, x, y = os.pullEvent("mouse_click")
        if not reactor then reactor = peripheral.find("fission_reactor_logic_adapter") end
        local burn = getSafe(reactor, "getBurnRate") or 0
        
        if x >= 18 and x <= 24 then
            if y == 3 and reactor then pcall(reactor.setBurnRate, math.max(0, burn - 10))
            elseif y == 5 and reactor then pcall(reactor.setBurnRate, burn + 10) end
        elseif x >= 1 and x <= 18 then
            if y == 11 then isScrammed = true scramReason = "MANUAL"
            elseif y == 13 and (getSafe(reactor, "getDamage") or 0) == 0 then 
                isScrammed = false 
                if reactor then pcall(reactor.activate) end
            end
        end
    end
end

-- EXECUTION
playSingularity()
parallel.waitForAny(monitorCore, touchListener)
