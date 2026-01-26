-- AEGIS REACTOR SHIELD v11.9 (ATM10 FIXED)
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local REFRESH = 0.5

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- 1. Helper (Mekanism ATM10 uses tables for resources)
local function safe(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
end

-- 2. Auto-Updater
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

-- 3. Startup Animation (Must be defined BEFORE calling it)
local function vaultStartup()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("<< AEGIS ONLINE >>")
    sleep(1)
end

-- === MAIN EXECUTION ===
autoUpdate()
vaultStartup()

while true do
    if not reactor then
        term.clear()
        print("Error: Reactor not found!")
        break
    end

    -- ATM10 Fix: Fetch full tables directly
    local fuelT  = reactor.getFuel() or {amount=0, max=1}
    local steamT = reactor.getSteam() or {amount=0, max=1}
    local wasteT = reactor.getWaste() or {amount=0, max=1}
    
    local tempC = math.floor(safe(reactor.getTemperature()) - 273.15)
    local energyVal = matrix and safe(matrix.getEnergy()) or 0
    local energyMax = matrix and safe(matrix.getMaxEnergy()) or 1
    local energyPct = energyVal / energyMax

    -- UI Rendering
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== AEGIS CORE v11.9 ==")
    term.setTextColor(colors.white)
    print("STATUS: " .. (reactor.getStatus() and "ACTIVE" or "IDLE"))
    print("TEMP:   " .. tempC .. " C")
    print("STEAM:  " .. math.floor((steamT.amount/steamT.max)*100) .. "%")
    print("WASTE:  " .. math.floor((wasteT.amount/wasteT.max)*100) .. "%")
    print("MATRIX: " .. math.floor(energyPct * 100) .. "%")

    -- Safety SCRAM
    if tempC > 1000 or (wasteT.amount / wasteT.max) > 0.9 or energyPct > 0.98 then
        reactor.scram()
    end

    sleep(REFRESH)
end
