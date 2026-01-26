-- AEGIS-OS v15.0.0: IRON SENTRY (TOUCH FIXED)
local VERSION = "15.0.0"

-- 1. PERIPHERALS
local monitor = peripheral.find("monitor")
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix  = peripheral.find("induction_port")

-- 2. REDIRECT FIX (Prevents the "term is not recommended" crash)
local deviceTerm = monitor or term.current() -- Use term.current for the pocket computer
local w, h = deviceTerm.getSize()

-- Safety State
local isScrammed = false
local scramReason = "STABLE"

-- 3. SINGULARITY BOOT (Your Sketch Design)
local function playSingularity()
    deviceTerm.setBackgroundColor(colors.black)
    deviceTerm.clear()
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    
    -- White ring collapse
    for r = 8, 1, -2 do
        deviceTerm.clear()
        deviceTerm.setTextColor(colors.white)
        for a = 0, 360, 20 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 2))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x <= w then deviceTerm.setCursorPos(x, y) deviceTerm.write("o") end
        end
        sleep(0.12)
    end
    
    -- Blue Core Detonation
    deviceTerm.clear()
    deviceTerm.setTextColor(colors.blue)
    deviceTerm.setCursorPos(cx, cy) deviceTerm.write("@")
    sleep(0.1)
    for r = 1, 10 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x <= w then deviceTerm.setCursorPos(x, y) deviceTerm.write("*") end
        end
        sleep(0.04)
    end
    deviceTerm.clear() -- Clear the animation before UI load
end

-- 4. THE STRICT FAILSAFE LOGIC
local function getSafe(obj, func)
    if not obj then return nil end
    local ok, res = pcall(obj[func])
    return ok and res or nil
end

-- 5. THE MAIN INTERFACE
local function main()
    while true do
        -- Data Retrieval
        local rData = {
            temp = getSafe(reactor, "getTemperature") or 0,
            dmg = getSafe(reactor, "getDamage") or 0,
            burn = getSafe(reactor, "getBurnRate") or 0,
            waste = getSafe(reactor, "getWaste") and reactor.getWaste().amount or 0,
            wasteMax = getSafe(reactor, "getWasteCapacity") or 1
        }
        local tData = {
            steam = getSafe(turbine, "getSteam") and turbine.getSteam().amount or 0,
            steamMax = getSafe(turbine, "getSteamCapacity") or 1
        }
        local mData = {
            stored = getSafe(matrix, "getEnergy") or 0,
            maxE = getSafe(matrix, "getMaxEnergy") or 1
        }

        -- Iron-Strict Check
        if rData.dmg > 0 then isScrammed = true scramReason = "DAMAGE"
        elseif rData.temp > 1150 then isScrammed = true scramReason = "OVERHEAT"
        elseif (rData.waste / rData.wasteMax) > 0.95 then isScrammed = true scramReason = "WASTE FULL"
        elseif (tData.steam / tData.steamMax) > 0.98 then isScrammed = true scramReason = "STEAM BACKUP"
        elseif (mData.stored / mData.maxE) > 0.99 then isScrammed = true scramReason = "GRID FULL"
        end

        if isScrammed then 
            pcall(reactor.setBurnRate, 0)
            pcall(reactor.scram) 
        end

        -- Render UI
        deviceTerm.setBackgroundColor(colors.black)
        deviceTerm.clear()
        deviceTerm.setCursorPos(1, 1)
        deviceTerm.setBackgroundColor(isScrammed and colors.red or colors.blue)
        deviceTerm.clearLine()
        deviceTerm.write(" AEGIS-OS | " .. (isScrammed and "SCRAM: " .. scramReason or "CORE STABLE"))
        deviceTerm.setBackgroundColor(colors.black)

        -- Statistics Display
        deviceTerm.setTextColor(colors.white)
        deviceTerm.setCursorPos(2, 3) deviceTerm.write("Temp: " .. math.floor(rData.temp) .. "K")
        deviceTerm.setCursorPos(2, 4) deviceTerm.write("Dmg:  " .. rData.dmg .. "%")
        deviceTerm.setCursorPos(2, 5) deviceTerm.write("Burn: " .. rData.burn .. " mB/t")
        deviceTerm.setCursorPos(2, 6) deviceTerm.write("Pwr:  " .. math.floor((mData.stored/mData.maxE)*100) .. "%")

        -- Touch Buttons
        deviceTerm.setCursorPos(2, 8)
        deviceTerm.setBackgroundColor(colors.gray) deviceTerm.write(" [-10] ")
        deviceTerm.setCursorPos(12, 8)
        deviceTerm.setBackgroundColor(colors.gray) deviceTerm.write(" [+10] ")
        deviceTerm.setCursorPos(2, 10)
        deviceTerm.setBackgroundColor(colors.red) deviceTerm.write(" [STOP] ")
        deviceTerm.setCursorPos(12, 10)
        deviceTerm.setBackgroundColor(colors.orange) deviceTerm.write(" [RESET] ")
        deviceTerm.setBackgroundColor(colors.black)

        -- Input Event
        local ev, side, x, y = os.pullEventTimeout(1)
        if ev == "monitor_touch" or ev == "mouse_click" then
            if y == 8 then
                if x >= 2 and x <= 8 then pcall(reactor.setBurnRate, math.max(0, rData.burn - 10))
                elseif x >= 12 and x <= 18 then pcall(reactor.setBurnRate, rData.burn + 10) end
            elseif y == 10 then
                if x >= 2 and x <= 8 then isScrammed = true scramReason = "MANUAL"
                elseif x >= 12 and x <= 19 and rData.dmg == 0 then isScrammed = false pcall(reactor.activate) end
            end
        end
    end
end

-- Run
playSingularity()
main()
