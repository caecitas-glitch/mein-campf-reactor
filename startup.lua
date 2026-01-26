-- AEGIS REACTOR SHIELD v8.0 
-- "Vault Protocol: Dreadnought Edition"

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. PERSISTENCE LAYER ===
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

-- === 2. BUG CRUSHER: SAFE DATA FETCHERS ===
-- Fixes the "Arithmetic on table value" error
local function getAmount(func)
    if not func then return 0 end
    local val = func()
    if type(val) == "table" then return val.amount or 0 end
    return val or 0
end

-- Fixes the "getSteam is nil" error
local function getSafeSteam()
    local f = reactor.getSteam or reactor.getSteamStored or reactor.getFluidStored
    return getAmount(f)
end

-- === 3. AUTO-UPDATER KERNEL ===
local function autoUpdate()
    term.clear()
    term.setCursorPos(1,1)
    print("Checking Vault for updates...")
    local response = http.get(GITHUB_URL)
    if response then
        local remoteCode = response.readAll()
        response.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localCode = f.readAll()
        f.close()
        if remoteCode ~= localCode then
            print("New Protocol Found. Updating...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            os.reboot()
        end
    end
end

-- === 4. CINEMATIC JAGGED VAULT STARTUP ===
local function vaultStartup()
    autoUpdate()
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

local function formatNum(n)
    if n >= 10^9 then return string.format("%.2fG", n / 10^9) end
    if n >= 10^6 then return string.format("%.2fM", n / 10^6) end
    if n >= 10^3 then return string.format("%.1fk", n / 10^3) end
    return tostring(math.floor(n))
end

-- === 5. MAIN LOOP ===
vaultStartup()
local steamHistory = {}

while true do
    -- Core Stats
    local status = reactor.getStatus()
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local dmg = reactor.getDamagePercent() or 0
    local burn = reactor.getBurnRate() or 0
    local maxBurn = reactor.getMaxBurnRate() or 0
    
    -- Fixed Resource Logic
    local steam = getSafeSteam()
    local steamMax = getAmount(reactor.getSteamCapacity or reactor.getFluidCapacity) or 1
    local coolant = getAmount(reactor.getCoolant)
    local coolantMax = getAmount(reactor.getCoolantCapacity) or 1
    local waste = getAmount(reactor.getWaste)
    local wasteMax = getAmount(reactor.getWasteCapacity) or 1
    local fuel = getAmount(reactor.getFuel)
    local fuelMax = getAmount(reactor.getFuelCapacity) or 1

    -- Grid Stats
    local energy = matrix.getEnergy() or 0
    local energyMax = matrix.getMaxEnergy() or 1
    local energyPct = math.floor((energy / energyMax) * 100)
    local netFlow = (matrix.getLastInput() or 0) - (matrix.getLastOutput() or 0)

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or waste/wasteMax > 0.9) then
        reactor.scram()
        incrementScram()
        modem.transmit(CHANNEL, CHANNEL, {alert="SAFETY BREACH", scram=true})
        error("SCRAM: SYSTEM SECURED")
    end

    -- UI Rendering (Zero Dead Space)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    term.write("== [ AEGIS VAULT v8.0 ] ==")
    
    term.setCursorPos(21, 1)
    term.setTextColor(colors.red)
    term.write("BLOWING UP STOPPED: " .. getScramCount())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " / " .. maxBurn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- CHEMICAL BALANCES ---")
    term.setTextColor(colors.white)
    print("FUEL:    " .. math.floor((fuel/fuelMax)*100) .. "% (" .. formatNum(fuel) .. " mB)")
    term.write("WASTE:   ")
    term.setTextColor(waste/wasteMax > 0.8 and colors.orange or colors.lime)
    print(math.floor((waste/wasteMax)*100) .. "% (" .. formatNum(waste) .. " mB)")
    term.setTextColor(colors.white)
    print("COOLANT: " .. math.floor((coolant/coolantMax)*100) .. "% (" .. formatNum(coolant) .. " mB)")

    term.setTextColor(colors.gray)
    print("\n--- GRID DYNAMICS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. "% (" .. formatNum(energy) .. " FE)")
    term.setTextColor(colors.white)
    term.write("NET:     ")
    term.setTextColor(netFlow >= 0 and colors.lime or colors.orange)
    print(formatNum(netFlow) .. " FE/t")

    term.setCursorPos(1, 19)
    term.setTextColor(colors.gray)
    term.write("STEAM: " .. formatNum(steam) .. " / " .. formatNum(steamMax))

    sleep(REFRESH)
end
