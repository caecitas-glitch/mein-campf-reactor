-- AEGIS VAULT v6.5 
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

-- === 1. AUTO-UPDATER ===
local function autoUpdate()
    term.clear()
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

-- === 2. CINEMATIC VAULT REVEAL (Based on Sketch) ===
local function vaultStartup()
    autoUpdate()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    local midX, midY = math.floor(w/2), math.floor(h/2)
    
    -- Phase 1: Jagged Door Slide
    for offset = 0, midX do
        term.clear()
        term.setTextColor(colors.gray)
        for y = 1, h do
            -- Create interlocking teeth every 4 blocks
            local tooth = ((y-1) % 4 < 2) and 2 or 0 
            term.setCursorPos(midX - offset - tooth, y)
            term.write("#")
            term.setCursorPos(midX + offset + tooth, y)
            term.write("#")
        end
        
        -- Reveal Centered AEGIS Text
        term.setTextColor(colors.blue)
        local msg = "<< AEGIS ONLINE >>"
        term.setCursorPos(midX - (#msg/2), midY)
        term.write(msg)
        sleep(0.05)
    end
    sleep(0.8)
end

-- === 3. SAFE DATA FETCHERS ===
local function getSafeSteam()
    if not reactor then return 0 end
    local f = reactor.getSteam or reactor.getSteamStored or reactor.getFluidStored
    return f and f() or 0
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
    -- Acquisition
    local status = reactor.getStatus()
    local tempC = math.floor((reactor.getTemperature() or 273.15) - 273.15)
    local dmg = reactor.getDamagePercent() or 0
    local burn = reactor.getBurnRate() or 0
    local steam = getSafeSteam()
    local energyPct = math.floor(((matrix.getEnergy() or 0) / (matrix.getMaxEnergy() or 1)) * 100)
    local netFlow = (matrix.getLastInput() or 0) - (matrix.getLastOutput() or 0)

    -- Steam Trend Calculation
    table.insert(steamHistory, steam)
    if #steamHistory > 60 then table.remove(steamHistory, 1) end
    local sDelta = (#steamHistory >= 60) and (steamHistory[#steamHistory] - steamHistory[1]) or 0

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98) then
        reactor.scram()
        modem.transmit(CHANNEL, CHANNEL, {alert="SAFETY BREACH", scram=true})
        error("SCRAM: CRITICAL LIMIT EXCEEDED")
    end

    -- Dashboard UI
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v6.5 ] ==")
    
    term.setTextColor(colors.white)
    print("STATUS: " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:   " .. tempC .. " C")
    print("DAMAGE: " .. dmg .. " %")
    print("BURN:   " .. burn .. " mB/t")
    
    term.setTextColor(colors.gray)
    print("\n--- THERMAL ANALYTICS ---")
    term.setTextColor(colors.white)
    print("STEAM:  " .. formatNum(steam) .. " mB")
    term.write("TREND:  ")
    term.setTextColor(sDelta > 1000 and colors.orange or colors.lime)
    print(string.format("%+.1fk mB/m", sDelta/1000))

    term.setTextColor(colors.gray)
    print("\n--- GRID TELEMETRY ---")
    term.setTextColor(colors.yellow)
    print("MATRIX: " .. energyPct .. " %")
    term.setTextColor(colors.white)
    term.write("FLOW:   ")
    term.setTextColor(netFlow >= 0 and colors.lime or colors.orange)
    print(formatNum(netFlow) .. " FE/t")

    sleep(REFRESH)
end
