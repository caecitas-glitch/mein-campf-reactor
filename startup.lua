-- AEGIS REACTOR SHIELD v11.7 (ATM10 FIXED)
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local REFRESH = 0.5

-- Peripherals
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

local function safe(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
end

local function autoUpdate()
    print("Checking GitHub...")
    local response = http.get(GITHUB_URL)
    if response then
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

-- === MAIN LOOP ===
autoUpdate()
vaultStartup()

while true do
    if not reactor or not matrix then
        term.clear()
        print("Error: Missing Peripherals!")
        break
    end

    -- ATM10 API Fix
    local fuelT = reactor.getFuel() or {amount=0, max=1}
    local steamT = reactor.getSteam() or {amount=0, max=1}
    local wasteT = reactor.getWaste() or {amount=0, max=1}
    
    local tempC = math.floor(safe(reactor.getTemperature()) - 273.15)
    local energyPct = safe(matrix.getEnergy()) / (safe(matrix.getMaxEnergy()) or 1)

    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== AEGIS CORE v11.7 ==")
    term.setTextColor(colors.white)
    print("TEMP:   " .. tempC .. " C")
    print("STEAM:  " .. math.floor((steamT.amount/steamT.max)*100) .. "%")
    print("MATRIX: " .. math.floor(energyPct * 100) .. "%")

    if tempC > 1000 or energyPct > 0.95 then
        reactor.scram()
    end

    sleep(REFRESH)
end
