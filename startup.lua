-- AEGIS REACTOR SHIELD v11.0
-- "Vault Protocol: Zero-Fail Edition"

local REFRESH = 0.5
local MAX_TEMP = 1000
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- === 1. THE DUAL-SAFETY WRAPPER ===
-- Forces EVERYTHING to a number to stop the table/nil crashes
local function n(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
end

-- === 2. AUTO-UPDATER ===
-- Change this string on GitHub to test the update:
local bootMessage = "<< AEGIS ONLINE >>" 

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
            print("Update Detected. Syncing...")
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
        term.setCursorPos(midX - (#bootMessage/2), midY)
        term.write(bootMessage)
        sleep(0.04)
    end
end

-- === 4. MAIN LOOP ===
vaultStartup()

while true do
    -- Force numeric conversion on EVERY API call
    local status = reactor.getStatus()
    local tempC  = math.floor(n(reactor.getTemperature()) - 273.15)
    local dmg    = n(reactor.getDamagePercent())
    local burn   = n(reactor.getBurnRate())
    
    local fuelPct    = (n(reactor.getFuelCapacity()) > 0) and (n(reactor.getFuel()) / n(reactor.getFuelCapacity())) or 0
    local wastePct   = (n(reactor.getWasteCapacity()) > 0) and (n(reactor.getWaste()) / n(reactor.getWasteCapacity())) or 0
    local coolantPct = (n(reactor.getCoolantCapacity()) > 0) and (n(reactor.getCoolant()) / n(reactor.getCoolantCapacity())) or 0
    local steamPct   = (n(reactor.getSteamCapacity()) > 0) and (n(reactor.getSteam() or reactor.getFluidStored())) / n(reactor.getSteamCapacity()) or 0

    local energyPct = (n(matrix.getMaxEnergy()) > 0) and (n(matrix.getEnergy()) / n(matrix.getMaxEnergy())) or 0

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 0.98 or wastePct > 0.9) then
        reactor.scram()
        error("SCRAM: SAFETY LIMITS EXCEEDED")
    end

    -- UI Rendering
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v11.0 ] ==")

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- CORE DIAGNOSTICS ---")
    term.setTextColor(colors.white)
    print("FUEL:    " .. math.floor(fuelPct * 100) .. "%")
    print("WASTE:   " .. math.floor(wastePct * 100) .. "%")
    print("COOLANT: " .. math.floor(coolantPct * 100) .. "%")
    print("STEAM:   " .. math.floor(steamPct * 100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID STATUS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. math.floor(energyPct * 100) .. " %")

    sleep(REFRESH)
end
