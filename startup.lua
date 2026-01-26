-- AEGIS-OS v19.0.0: ULTIMATE POCKET EDITION
local VERSION = "19.0.0"

-- 1. HARDWARE LINKING
local device = term.current() -- Prevents redirect error
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix  = peripheral.find("induction_port")

local w, h = device.getSize()
local isScrammed = false
local scramReason = "OK"

-- 2. SAFE DATA UTILS
local function getSafe(obj, func)
    if not obj then return nil end
    local ok, res = pcall(obj[func])
    return ok and res or nil
end

-- 3. THE SINGULARITY BOOT (Your Sketch Design)
local function playSingularity()
    device.setBackgroundColor(colors.black)
    device.clear()
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    
    -- Collapse Sequence
    for r = 6, 1, -1 do
        device.clear()
        device.setTextColor(colors.white)
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 1.5))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("o") end
        end
        sleep(0.12)
    end
    -- Blue Explosion
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

-- 4. RENDERING (Pocket-Optimized Grid)
local function drawUI(data)
    device.setBackgroundColor(colors.black)
    device.clear()

    -- Header
    device.setCursorPos(1, 1)
    device.setBackgroundColor(isScrammed and colors.red or colors.blue)
    device.clearLine()
    device.write(" AEGIS OS v" .. VERSION .. " | " .. (isScrammed and scramReason or "OK"))
    
    device.setBackgroundColor(colors.black)
    device.setTextColor(colors.white)
    
    -- LEFT COLUMN: STATISTICS
    device.setCursorPos(1, 3) device.write("TEMP: " .. math.floor(data.temp or 0) .. "K")
    device.setCursorPos(1, 4) device.write("DMG:  " .. (data.dmg or 0) .. "%")
    device.setCursorPos(1, 5) device.write("BURN: " .. (data.burn or 0))
    device.setCursorPos(1, 7) 
    device.setTextColor(colors.cyan)
    device.write("STM: " .. math.floor((data.steam/data.sMax)*100) .. "%")
    device.setCursorPos(1, 8)
    device.setTextColor(colors.green)
    device.write("PWR: " .. math.floor((data.stored/data.maxE)*100) .. "%")

    -- RIGHT COLUMN: CONTROLS
    device.setTextColor(colors.white)
    -- Burn Adjust
    device.setCursorPos(16, 3) device.setBackgroundColor(colors.gray) device.write(" [-10] ")
    device.setCursorPos(16, 5) device.setBackgroundColor(colors.gray) device.write(" [+10] ")
    
    -- Main Commands
    device.setCursorPos(1, 11)
    device.setBackgroundColor(colors.red) device.setTextColor(colors.white)
    device.write("    [ STOP ]    ")
    
    device.setCursorPos(1, 13)
    device.setBackgroundColor(isScrammed and colors.orange or colors.gray)
    device.setTextColor(colors.black)
    device.write("    [ RESET ]   ")
    
    device.setBackgroundColor(colors.black)
end

-- 5. MAIN LOGIC & PROTECTION
local function main()
    while true do
        local data = {
            temp = getSafe(reactor, "getTemperature") or 0,
            dmg = getSafe(reactor, "getDamage") or 0,
            burn = getSafe(reactor, "getBurnRate") or 0,
            steam = getSafe(turbine, "getSteam") and turbine.getSteam().amount or 0,
            sMax = getSafe(turbine, "getSteamCapacity") or 1,
            stored = getSafe(matrix, "getEnergy") or 0,
            maxE = getSafe(matrix, "getMaxEnergy") or 1,
            waste = getSafe(reactor, "getWaste") and reactor.getWaste().amount or 0,
            wMax = getSafe(reactor, "getWasteCapacity") or 1
        }

        -- IRON-STRICT FAILSAFE
        if data.dmg > 0 then isScrammed = true scramReason = "DMG!"
        elseif data.temp > 1150 then isScrammed = true scramReason = "HEAT!"
        elseif data.waste / data.wMax > 0.95 then isScrammed = true scramReason = "WASTE"
        elseif data.steam / data.sMax > 0.98 then isScrammed = true scramReason = "STEAM"
        elseif data.stored / data.maxE > 0.99 then isScrammed = true scramReason = "POWER"
        end

        if isScrammed then pcall(reactor.setBurnRate, 0) pcall(reactor.scram) end

        drawUI(data)

        -- TOUCH HANDLING
        local ev, button, x, y = os.pullEventTimeout(1)
        if ev == "mouse_click" or ev == "monitor_touch" then
            -- Burn Controls (Right Side)
            if x >= 16 and x <= 23 then
                if y == 3 then pcall(reactor.setBurnRate, math.max(0, data.burn - 10))
                elseif y == 5 then pcall(reactor.setBurnRate, data.burn + 10) end
            -- System Controls (Bottom)
            elseif x >= 1 and x <= 16 then
                if y == 11 then isScrammed = true scramReason = "MANUAL"
                elseif y == 13 and data.dmg == 0 then 
                    isScrammed = false 
                    pcall(reactor.activate) 
                end
            end
        end
    end
end

playSingularity()
main()
