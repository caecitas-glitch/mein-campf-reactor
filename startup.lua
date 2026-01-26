-- AEGIS REACTOR SHIELD v7.0 
-- Protocol: Absolute Containment

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. PERSISTENCE LAYER (Scram Tracking) ===
local function getScramCount()
    if not fs.exists("scrams.txt") then return 0 end
    local f = fs.open("scrams.txt", "r")
    local count = tonumber(f.readAll()) or 0
    f.close()
    return count
end

local function incrementScram()
    local count = getScramCount() + 1
    local f = fs.open("scrams.txt", "w")
    f.write(tostring(count))
    f.close()
end

-- === 2. CINEMATIC JAGGED VAULT STARTUP ===
local function vaultStartup()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    local midX, midY = math.floor(w/2), math.floor(h/2)
    
    for offset = 0, midX do
        term.clear()
        term.setTextColor(colors.gray)
        for y = 1, h do
            local tooth = ((y-1) % 4 < 2) and 2 or 0 
            term.setCursorPos(midX - offset - tooth, y)
            term.write("#")
            term.setCursorPos(midX + offset + tooth, y)
            term.write("#")
        end
        term.setTextColor(colors.blue)
        local msg = "<< AEGIS ONLINE >>"
        term.setCursorPos(midX - (#msg/2), midY)
        term.write(msg)
        sleep(0.04)
    end
end

-- === 3. DATA HELPERS ===
local function formatNum(n)
    if n >= 10^9 then return string.format("%.2fG", n / 10^9) end
    if n >= 10^6 then return string.format("%.2fM", n / 10^6) end
    if n >= 10^3 then return string.format("%.1fk", n / 10^3) end
    return tostring(math.floor(n))
end

-- === 4. MAIN LOOP ===
vaultStartup()
local steamHistory = {}

while true do
    -- Deep Telemetry
    local status = reactor.getStatus()
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local dmg = reactor.getDamagePercent() or 0
    local burn = reactor.getBurnRate() or 0
    local maxBurn = reactor.getMaxBurnRate() or 0
    
    -- Fluids & Waste
    local fuel = reactor.getFuel() or 0
    local fuelMax = reactor.getFuelCapacity() or 1
    local waste = reactor.getWaste() or 0
    local wasteMax = reactor.getWasteCapacity() or 1
    local coolant = (reactor.getCoolant() or 0) / (reactor.getCoolantCapacity() or 1) * 100
    
    -- Grid Stats
    local energyPct = math.floor(((matrix.getEnergy() or 0) / (matrix.getMaxEnergy() or 1)) * 100)
    local netFlow = (matrix.getLastInput() or 0) - (matrix.getLastOutput() or 0)

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or waste/wasteMax > 0.9) then
        reactor.scram()
        incrementScram()
        modem.transmit(CHANNEL, CHANNEL, {alert="SAFETY BREACH", scram=true})
        error("SCRAM: SYSTEM SECURED")
    end

    -- UI Rendering (Full Screen Utilization)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v7.0 ] ==")
    
    term.setTextColor(colors.white)
    term.setCursorPos(26, 2)
    term.setTextColor(colors.red)
    term.write("MELTDOWNS STOPPED: " .. getScramCount())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS: " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:   " .. tempC .. " C")
    print("BURN:   " .. burn .. " / " .. maxBurn .. " mB/t")
    
    term.setTextColor(colors.gray)
    print("\n--- CRITICAL BUFFER TELEMETRY ---")
    term.setTextColor(colors.white)
    print("FUEL:   " .. formatNum(fuel) .. " / " .. formatNum(fuelMax))
    term.write("WASTE:  ")
    term.setTextColor(waste/wasteMax > 0.7 and colors.orange or colors.lime)
    print(formatNum(waste) .. " mB (" .. math.floor(waste/wasteMax*100) .. "%)")
    term.setTextColor(colors.white)
    term.write("COOLANT: ")
    term.setTextColor(coolant < 20 and colors.red or colors.lime)
    print(math.floor(coolant) .. " %")

    term.setTextColor(colors.gray)
    print("\n--- GRID DYNAMICS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX: " .. energyPct .. " %")
    term.setTextColor(colors.white)
    term.write("NET:    ")
    term.setTextColor(netFlow >= 0 and colors.lime or colors.orange)
    print(formatNum(netFlow) .. " FE/t")

    sleep(REFRESH)
end
