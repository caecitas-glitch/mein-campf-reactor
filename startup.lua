-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local VERSION = "1.3.2"

-- Explicit Peripheral Wrapping
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

if monitor then
    term.redirect(monitor)
    monitor.setTextScale(0.5)
end

-- --- SAFETY UTILS ---
-- This prevents the "nil value" crash by checking if the function exists
local function safeCall(obj, func, ...)
    if obj and obj[func] then
        return obj[func](...)
    end
    return nil
end

local function formatNum(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e12 then return string.format("%.2f T", n/1e12) end
    if n >= 1e9 then return string.format("%.2f G", n/1e9) end
    if n >= 1e6 then return string.format("%.2f M", n/1e6) end
    if n >= 1e3 then return string.format("%.2f k", n/1e3) end
    return tostring(math.floor(n))
end

-- --- DRAWING ---
local function drawHeader(title, y, color)
    term.setCursorPos(1, y)
    term.setBackgroundColor(color)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write(" " .. title)
    term.setBackgroundColor(colors.black)
end

local function main()
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()

        -- 1. Reactor Stats & Safety
        local dmg = safeCall(reactor, "getDamage") or 0
        local temp = safeCall(reactor, "getTemperature") or 0
        local burn = safeCall(reactor, "getBurnRate") or 0
        local status = safeCall(reactor, "getStatus") and "ONLINE" or "OFFLINE"
        
        if dmg > 0 or temp > 1150 then
            safeCall(reactor, "setBurnRate", 0)
            status = "!! SCRAM !!"
        end

        drawHeader("FISSION REACTOR | " .. status, 1, status == "!! SCRAM !!" and colors.red or colors.gray)
        term.setCursorPos(2, 2)
        term.write("Temp: " .. math.floor(temp) .. "K")
        term.setCursorPos(2, 3)
        term.write("Damage: " .. dmg .. "%")
        term.setCursorPos(2, 4)
        term.write("Burn: " .. burn .. " mB/t")

        -- 2. Turbine Stats
        drawHeader("INDUSTRIAL TURBINE", 6, colors.gray)
        local prod = safeCall(turbine, "getProductionRate") or 0
        local flow = safeCall(turbine, "getFlowRate") or 0
        term.setCursorPos(2, 7)
        term.write("Gen: " .. formatNum(prod) .. " FE/t")
        term.setCursorPos(2, 8)
        term.write("Flow: " .. formatNum(flow) .. " mB/t")

        -- 3. Matrix Stats
        drawHeader("INDUCTION MATRIX", 10, colors.gray)
        local energy = safeCall(matrix, "getEnergy") or 0
        local lastIn = safeCall(matrix, "getLastInput") or 0
        local lastOut = safeCall(matrix, "getLastOutput") or 0
        
        term.setCursorPos(2, 11)
        term.write("Stored: " .. formatNum(energy) .. " FE")
        term.setCursorPos(2, 12)
        term.setTextColor(colors.green)
        term.write("In:  " .. formatNum(lastIn) .. " FE/t")
        term.setCursorPos(2, 13)
        term.setTextColor(colors.red)
        term.write("Out: " .. formatNum(lastOut) .. " FE/t")
        term.setTextColor(colors.white)

        sleep(1)
    end
end

main()
