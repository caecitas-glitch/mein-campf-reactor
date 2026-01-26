-- AEGIS REACTOR SHIELD v9.5 
-- "Vault Protocol: Deep Scan Edition"

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. THE DEEP SCAN BUG-SLAYER ===
-- This function extracts the number NO MATTER WHAT Mekanism sends
local function getNum(val)
    if val == nil then return 0 end
    if type(val) == "number" then return val end
    if type(val) == "table" then
        return tonumber(val.amount) or 0 -- Pulls the .amount from the table
    end
    return 0
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
    -- Force everything to numbers immediately
    local status = reactor.getStatus()
    local tempC  = math.floor(getNum(reactor.getTemperature()) - 273.15)
    local dmg    = getNum(reactor.getDamagePercent())
    local burn   = getNum(reactor.getBurnRate())
    
    -- Resource Gathering (Using getNum on everything)
    local fuel       = getNum(reactor.getFuel())
    local fuelMax    = getNum(reactor.getFuelCapacity())
    local waste      = getNum(reactor.getWaste())
    local wasteMax   = getNum(reactor.getWasteCapacity())
    local coolant    = getNum(reactor.getCoolant())
    local coolantMax = getNum(reactor.getCoolantCapacity())
    local steam      = getNum(reactor.getSteam())
    local steamMax   = getNum(reactor.getSteamCapacity())

    -- Grid Stats
    local energy    = getNum(matrix.getEnergy())
    local energyMax = getNum(matrix.getMaxEnergy())
    local energyPct = (energyMax > 0) and math.floor((energy / energyMax) * 100) or 0
    local netFlow   = getNum(matrix.getLastInput()) - getNum(matrix.getLastOutput())

    -- Failsafes
    local wastePct = (wasteMax > 0) and (waste / wasteMax) or 0
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or wastePct > 0.9) then
        reactor.scram()
        incrementScram()
        error("SCRAM TRIGGERED: SAFETY LIMITS EXCEEDED")
    end

    -- UI Rendering
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    term.write("== [ AEGIS VAULT v9.5 ] ==")
    
    term.setCursorPos(22, 1)
    term.setTextColor(colors.red)
    term.write("MELTDOWNS STOPPED: " .. getScramCount())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- CORE DIAGNOSTICS ---")
    term.setTextColor(colors.white)
    print("FUEL:    " .. ((fuelMax > 0) and math.floor((fuel/fuelMax)*100) or 0) .. "%")
    print("WASTE:   " .. math.floor(wastePct * 100) .. "%")
    print("COOLANT: " .. ((coolantMax > 0) and math.floor((coolant/coolantMax)*100) or 0) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID DYNAMICS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. " %")
    term.setTextColor(colors.white)
    print("NET:     " .. math.floor(netFlow) .. " FE/t")

    term.setCursorPos(1, 19)
    term.setTextColor(colors.gray)
    term.write("STEAM: " .. math.floor(steam) .. " / " .. math.floor(steamMax))

    sleep(REFRESH)
end
