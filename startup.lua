-- AEGIS REACTOR SHIELD v10.0
-- "Vault Protocol: Indestructible Edition"

local REFRESH = 0.5
local MAX_TEMP = 1000
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- === 1. THE FOOLPROOF CONVERTER ===
-- Fixes EVERY crash in your screenshots
local function safe(val)
    if val == nil then return 0 end -- Fixes 'nil value' crashes
    if type(val) == "table" then 
        return tonumber(val.amount) or 0 -- Extracts number from Mekanism tables
    end
    return tonumber(val) or 0 -- Ensures it's a number
end

-- === 2. AUTO-UPDATER ===
local function autoUpdate()
    term.clear()
    term.setCursorPos(1,1)
    print("Checking Vault for updates...")
    local response = http.get(GITHUB_URL)
    if response then
        local remoteCode = response.readAll()
        response.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localCode = f and f.readAll() or ""
        if f then f.close() end
        if remoteCode ~= localCode then
            print("Update Found. Overwriting...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            os.reboot()
        end
    end
end

-- === 3. CINEMATIC JAGGED VAULT STARTUP ===
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

-- === 4. MAIN LOOP ===
vaultStartup()

while true do
    -- Force everything to numbers immediately
    local status = reactor.getStatus()
    local tempC  = math.floor(safe(reactor.getTemperature()) - 273.15)
    local dmg    = safe(reactor.getDamagePercent())
    local burn   = safe(reactor.getBurnRate())
    
    local fuel       = safe(reactor.getFuel())
    local fuelMax    = safe(reactor.getFuelCapacity()) or 1
    local waste      = safe(reactor.getWaste())
    local wasteMax   = safe(reactor.getWasteCapacity()) or 1
    local coolant    = safe(reactor.getCoolant())
    local coolantMax = safe(reactor.getCoolantCapacity()) or 1
    local steam      = safe(reactor.getSteam() or reactor.getFluidStored())
    local steamMax   = safe(reactor.getSteamCapacity()) or 1

    local energy    = safe(matrix.getEnergy())
    local energyMax = safe(matrix.getMaxEnergy()) or 1
    local energyPct = math.floor((energy / energyMax) * 100)

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or (waste/wasteMax) > 0.9) then
        reactor.scram()
        error("SCRAM TRIGGERED")
    end

    -- Full-Screen Dashboard
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v10.0 ] ==")

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- CORE TELEMETRY ---")
    term.setTextColor(colors.white)
    print("FUEL:    " .. math.floor((fuel/fuelMax)*100) .. "%")
    print("WASTE:   " .. math.floor((waste/wasteMax)*100) .. "%")
    print("COOLANT: " .. math.floor((coolant/coolantMax)*100) .. "%")
    print("STEAM:   " .. math.floor((steam/steamMax)*100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID TELEMETRY ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. " %")

    sleep(REFRESH)
end
