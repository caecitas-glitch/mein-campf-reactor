-- AEGIS REACTOR SHIELD v9.0 
-- "Vault Protocol: Bug-Slayer Edition"

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. THE ULTIMATE BUG SLAYER ===
-- This function is specifically designed to kill the "Arithmetic on Table" error
local function safeVal(val)
    if not val then return 0 end
    if type(val) == "table" then
        return val.amount or 0 -- Extract amount from Mekanism gas/liquid table
    end
    return tonumber(val) or 0
end

-- Persisted Scram Counter
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

-- === 2. CINEMATIC VAULT REVEAL ===
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

-- === 3. MAIN LOOP ===
vaultStartup()

while true do
    -- Force numeric values for everything
    local status = reactor.getStatus()
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local dmg = reactor.getDamagePercent() or 0
    local burn = reactor.getBurnRate() or 0
    
    -- Using the Bug-Slayer wrapper on ALL reactor calls
    local fuel = safeVal(reactor.getFuel())
    local fuelMax = safeVal(reactor.getFuelCapacity()) or 1
    local waste = safeVal(reactor.getWaste())
    local wasteMax = safeVal(reactor.getWasteCapacity()) or 1
    local coolant = safeVal(reactor.getCoolant())
    local coolantMax = safeVal(reactor.getCoolantCapacity()) or 1
    local steam = safeVal(reactor.getSteam() or reactor.getFluidStored())
    local steamMax = safeVal(reactor.getSteamCapacity() or reactor.getFluidCapacity()) or 1

    -- Grid Stats
    local energyPct = math.floor(((matrix.getEnergy() or 0) / (matrix.getMaxEnergy() or 1)) * 100)
    local netFlow = (matrix.getLastInput() or 0) - (matrix.getLastOutput() or 0)

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or (waste/wasteMax) > 0.9) then
        reactor.scram()
        incrementScram()
        error("SCRAM TRIGGERED: SAFETY LIMITS EXCEEDED")
    end

    -- Full-Screen UI
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    term.write("== [ AEGIS VAULT v9.0 ] ==")
    
    term.setCursorPos(22, 1)
    term.setTextColor(colors.red)
    term.write("BLOWING UP STOPPED: " .. getScramCount())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- CHEMICAL BUFFER LEVELS ---")
    term.setTextColor(colors.white)
    print("FUEL:    " .. math.floor((fuel/fuelMax)*100) .. "%")
    print("WASTE:   " .. math.floor((waste/wasteMax)*100) .. "%")
    print("COOLANT: " .. math.floor((coolant/coolantMax)*100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID TELEMETRY ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. " %")
    term.setTextColor(colors.white)
    print("NET:     " .. math.floor(netFlow) .. " FE/t")

    term.setCursorPos(1, 19)
    term.setTextColor(colors.gray)
    term.write("STEAM: " .. math.floor(steam) .. " / " .. math.floor(steamMax))

    sleep(REFRESH)
end
