-- AEGIS REACTOR SHIELD v12.0 (STABLE)
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"

-- === 1. DEFINE FUNCTIONS FIRST ===
local function safe(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
end

local function autoUpdate()
    print("Checking GitHub...")
    local ok, response = pcall(http.get, GITHUB_URL)
    if ok and response then
        local remoteCode = response.readAll()
        response.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localCode = f and f.readAll() or ""
        if f then f.close() end
        if remoteCode ~= "" and remoteCode ~= localCode then
            print("Syncing...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            os.reboot()
        end
    end
end

local function vaultStartup()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("<< AEGIS ONLINE >>")
    sleep(1)
end

-- === 2. INITIALIZE PERIPHERALS ===
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- === 3. EXECUTION BEGINS HERE ===
autoUpdate()
vaultStartup()

while true do
    if not reactor then
        term.clear()
        term.setTextColor(colors.red)
        print("CRITICAL ERROR: Reactor Logic Adapter not found!")
        print("Check cables and modem status.")
        sleep(5)
        os.reboot()
    end

    -- ATM10 Method calls
    local fuelT  = reactor.getFuel() or {amount=0, max=1}
    local steamT = reactor.getSteam() or {amount=0, max=1}
    local wasteT = reactor.getWaste() or {amount=0, max=1}
    
    local tempC = math.floor(safe(reactor.getTemperature()) - 273.15)
    local energyPct = 0
    if matrix then
        energyPct = safe(matrix.getEnergy()) / (safe(matrix.getMaxEnergy()) or 1)
    end

    -- UI Rendering
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== AEGIS CORE v12.0 ==")
    term.setTextColor(colors.white)
    print("STATUS: " .. (reactor.getStatus() and "ACTIVE" or "IDLE"))
    print("TEMP:   " .. tempC .. " C")
    print("STEAM:  " .. math.floor((steamT.amount/steamT.max)*100) .. "%")
    print("MATRIX: " .. math.floor(energyPct * 100) .. "%")

    -- Failsafes
    if tempC > 1000 or (wasteT.amount / wasteT.max) > 0.9 then
        reactor.scram()
    end

    sleep(0.5)
end
