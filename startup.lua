-- AEGIS REACTOR SHIELD v6.0
-- "Vault Protocol: Absolute Containment"

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.find("turbineValve")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. CINEMATIC VAULT ANIMATION ===
local function vaultStartup()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    local midX, midY = math.floor(w/2), math.floor(h/2)
    local wheel = {"|", "/", "-", "\\"}
    
    -- Locking Wheel Spin
    for i = 1, 12 do
        term.setCursorPos(midX, midY)
        term.setTextColor(colors.gray)
        term.write("[" .. wheel[(i % 4) + 1] .. "]")
        term.setCursorPos(midX - 7, midY + 1)
        term.setTextColor(colors.blue)
        term.write("UNLOCKING VAULT")
        sleep(0.1)
    end

    -- Jagged Doors (As sketched in Untitled.png)
    for offset = 0, midX do
        term.clear()
        term.setTextColor(colors.gray)
        for y = 1, h do
            local jagged = (y % 4 == 0) and 2 or 0
            term.setCursorPos(midX - offset - jagged, y)
            term.write("#")
            term.setCursorPos(midX + offset + jagged, y)
            term.write("#")
        end
        term.setTextColor(colors.blue)
        term.setCursorPos(midX - 5, midY)
        term.write("AEGIS ONLINE")
        sleep(0.05)
    end
end

-- === 2. SAFE DATA FETCHERS (Fixes image_ca09ae.png) ===
local function getSafeSteam()
    if not reactor then return 0 end
    -- Tries multiple API names to prevent "nil value" crashes
    local f = reactor.getSteam or reactor.getSteamStored or reactor.getFluidStored
    return f and f() or 0
end

local function criticalScram(reason)
    if reactor and reactor.getStatus() then reactor.scram() end --
    modem.transmit(CHANNEL, CHANNEL, {alert = reason, scram = true, t = os.date("%H:%M:%S")})
    term.setBackgroundColor(colors.red)
    term.clear()
    term.setCursorPos(1,1)
    print("!!! VAULT BREACH: CRITICAL SCRAM !!!")
    print("REASON: " .. reason) --
    error("AEGIS_HALT")
end

-- === 3. MAIN EXECUTION ===
vaultStartup()
local steamHistory = {}

while true do
    if not reactor or not matrix then criticalScram("Link Lost") end

    local status = reactor.getStatus()
    local dmg = reactor.getDamagePercent() or 0
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local steam = getSafeSteam()
    local energyPct = math.floor(((matrix.getEnergy() or 0) / (matrix.getMaxEnergy() or 1)) * 100)
    
    table.insert(steamHistory, steam)
    if #steamHistory > 120 then table.remove(steamHistory, 1) end
    local sDelta = (#steamHistory >= 120) and (steamHistory[#steamHistory] - steamHistory[1]) or 0

    if status and (tempC > MAX_TEMP or energyPct > 98 or dmg > 0) then
        criticalScram("Safety Violation")
    end

    -- Dashboard
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v6.0 ] ==")
    term.setCursorPos(1,3)
    term.setTextColor(colors.white)
    print("HEAT:   " .. tempC .. " C    ")
    print("STEAM:  " .. math.floor(steam) .. " mB")
    term.write("TREND:  ")
    term.setTextColor(sDelta > 1000 and colors.orange or colors.lime)
    print(string.format("%+.1fk mB/m", sDelta/1000) .. "      ")
    term.setTextColor(colors.yellow)
    print("\nGRID:   " .. energyPct .. " %")

    modem.transmit(CHANNEL, CHANNEL, {t=os.date("%H:%M:%S"), temp=tempC, dmg=dmg, batt=energyPct, p=steam})
    sleep(REFRESH)
end