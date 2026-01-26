-- AEGIS-OS v17.0.0: THE FINAL PROTOCOL
local VERSION = "17.0.0"

-- 1. HARDWARE LINKING
local device = term.current() -- Prevents redirect error on tablets
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix  = peripheral.find("induction_port")

local w, h = device.getSize()
local isScrammed = false
local scramReason = "STABLE"

-- 2. TRIPLE-SAFE DIAGNOSTICS
local function getSafe(obj, func)
    if not obj then return nil end
    local ok, res = pcall(obj[func])
    return ok and res or nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e9 then return string.format("%.1fG", n/1e9) end
    if n >= 1e6 then return string.format("%.1fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

-- 3. THE SINGULARITY BOOT (Your Sketch Design)
local function playSingularity()
    device.setBackgroundColor(colors.black)
    device.clear()
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    
    -- Collapse Sequence (Rings condensing)
    for r = 8, 1, -2 do
        device.clear()
        device.setTextColor(colors.white)
        for a = 0, 360, 20 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 2))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("o") end
        end
        sleep(0.12)
    end
    
    -- Blue Detonation
    device.clear()
    device.setTextColor(colors.blue)
    device.setCursorPos(cx, cy) device.write("@")
    sleep(0.15)
    for r = 1, 10 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("*") end
        end
        sleep(0.04)
    end
    device.clear()
end

-- 4. RENDERING ENGINE
local function drawUI(data)
    device.setBackgroundColor(colors.black)
    device.clear()

    -- Header
    device.setCursorPos(1, 1)
    device.setBackgroundColor(isScrammed and colors.red or colors.blue)
    device.clearLine()
    device.write(" AEGIS OS v" .. VERSION .. " | " .. (isScrammed and scramReason or "ACTIVE"))
    device.setBackgroundColor(colors.black)

    -- Stats Array
    device.setTextColor(colors.white)
    device.setCursorPos(2, 3) device.write("HEAT: " .. math.floor(data.temp or 0) .. "K")
    device.setCursorPos(2, 4) device.write("DMG:  " .. (data.dmg or 0) .. "%")
    device.setCursorPos(2, 5) device.write("BURN: " .. (data.burn or 0) .. " mB/t")
    
    -- Resource Backups
    device.setTextColor(colors.cyan)
    device.setCursorPos(2, 7) device.write("STM: " .. string.format("%.1f%%", (data.steam/data.sMax)*100))
    device.setTextColor(colors.green)
    device.setCursorPos(2, 8) device.write("PWR: " .. string.format("%.1f%%", (data.stored/data.maxE)*100))

    -- 5. TOUCH BUTTONS
    device.setCursorPos(2, 11)
    device.setBackgroundColor(colors.gray) device.setTextColor(colors.white)
    device.write(" [-10] ")
    device.setCursorPos(12, 11)
    device.write(" [+10] ")
    
    device.setCursorPos(2, 13)
    device.setBackgroundColor(colors.red)
    device.write(" [STOP] ")
    device.setCursorPos(12, 13)
    device.setBackgroundColor(isScrammed and colors.orange or colors.gray)
    device.setTextColor(colors.black)
    device.write(" [RESET] ")
    device.setBackgroundColor(colors.black)
end

-- 6. MAIN EXECUTION
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
        if data.dmg > 0 then isScrammed = true scramReason = "DAMAGE"
        elseif data.temp > 1150 then isScrammed = true scramReason = "OVERHEAT"
        elseif data.waste / data.wMax > 0.95 then isScrammed = true scramReason = "WASTE FULL"
        elseif data.steam / data.sMax > 0.98 then isScrammed = true scramReason = "STEAM FULL"
        elseif data.stored / data.maxE > 0.99 then isScrammed = true scramReason = "GRID FULL"
        end

        if isScrammed then pcall(reactor.setBurnRate, 0) pcall(reactor.scram) end

        drawUI(data)

        -- TOUCH HANDLING
        local ev, button, x, y = os.pullEventTimeout(1)
        if ev == "mouse_click" or ev == "monitor_touch" then
            if y == 11 then
                if x >= 2 and x <= 8 then pcall(reactor.setBurnRate, math.max(0, data.burn - 10))
                elseif x >= 12 and x <= 18 then pcall(reactor.setBurnRate, data.burn + 10) end
            elseif y == 13 then
                if x >= 2 and x <= 9 then isScrammed = true scramReason = "MANUAL"
                elseif x >= 12 and x <= 20 and data.dmg == 0 then 
                    isScrammed = false 
                    pcall(reactor.activate) 
                end
            end
        end
    end
end

playSingularity()
main()
