-- AEGIS REACTOR SHIELD v7.5 
-- "Vault Protocol: Iron Sentinel"

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

-- === 2. SAFE DATA FETCHERS (Fixes image_ca09ae & image_c85182) ===
local function getAmount(func)
    local val = func and func() or 0
    if type(val) == "table" then return val.amount or 0 end -- Fixes "arithmetic on table" error
    return val or 0
end

local function getSafeSteam()
    local f = reactor.getSteam or reactor.getSteamStored or reactor.getFluidStored
    return getAmount(f)
end

-- === 3. CINEMATIC JAGGED VAULT STARTUP ===
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
    -- Core Data
    local status = reactor.getStatus()
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local dmg = reactor.getDamagePercent() or 0
    local burn = reactor.getBurnRate() or 0
    
    -- Resource Fetching (Fixed Table Logic)
    local steam = getSafeSteam()
    local steamMax = getAmount(reactor.getSteamCapacity or reactor.getFluidCapacity) or 1
    local coolant = getAmount(reactor.getCoolant)
    local coolantMax = getAmount(reactor.getCoolantCapacity) or 1
    local waste = getAmount(reactor.getWaste)
    local wasteMax = getAmount(reactor.getWasteCapacity) or 1
    
    -- Steam Analytics
    table.insert(steamHistory, steam)
    if #steamHistory > 120 then table.remove(steamHistory, 1) end
    local sDelta = (#steamHistory >= 120) and (steamHistory[#steamHistory] - steamHistory[1]) or 0

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

    -- UI Rendering (Full Use of Screen)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v7.5 ] ==")
    
    term.setCursorPos(22, 1)
    term.setTextColor(colors.red)
    term.write("STOPPED MELTDOWNS: " .. getScramCount())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS: " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:   " .. tempC .. " C")
    print("BURN:   " .. burn .. " mB/t")

    term.setTextColor(colors.gray)
    print("\n--- THERMAL & WASTE ---")
    term.setTextColor(colors.white)
    print("STEAM:   " .. formatNum(steam) .. " / " .. formatNum(steamMax))
    term.write("TREND:   ")
    term.setTextColor(sDelta > 1000 and colors.orange or colors.lime)
    print(string.format("%+.1fk mB/m", sDelta/1000))
    term.setTextColor(colors.white)
    print("COOLANT: " .. math.floor((coolant/coolantMax)*100) .. "% (" .. formatNum(coolant) .. ")")
    print("WASTE:   " .. math.floor((waste/wasteMax)*100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID DYNAMICS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. " %")
    term.setTextColor(colors.white)
    term.write("NET:     ")
    term.setTextColor(netFlow >= 0 and colors.lime or colors.orange)
    print(formatNum(netFlow) .. " FE/t")

    sleep(REFRESH)
end
