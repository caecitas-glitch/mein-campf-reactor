-- AEGIS REACTOR SHIELD v11.6 (FIXED)
local REFRESH = 0.5
local MAX_TEMP = 1000
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

local function safe(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
end

-- Updated Auto-Updater with error handling
local function autoUpdate()
    print("Checking Vault for updates...")
    local ok, response = pcall(http.get, GITHUB_URL)
    if ok and response then
        local remoteCode = response.readAll()
        response.close()
        
        local f = fs.open(shell.getRunningProgram(), "r")
        local localCode = f and f.readAll() or ""
        if f then f.close() end
        
        if remoteCode ~= "" and remoteCode ~= localCode then
            print("Update Found. Syncing...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            print("Update applied. Rebooting...")
            sleep(1)
            os.reboot()
        end
    else
        print("Update Server unreachable. Starting AEGIS...")
        sleep(1)
    end
end

-- [ ... vaultStartup and scram functions remain the same ... ]

-- === MAIN LOOP ===
-- COMMENT OUT THE LINE BELOW IF YOU WANT TO STOP IT FROM REVERTING TO GITHUB
-- autoUpdate() 
vaultStartup()

while true do
    -- Get status and temps
    local status = reactor.getStatus()
    local tempC  = math.floor(safe(reactor.getTemperature()) - 273.15)
    local dmg    = safe(reactor.getDamagePercent())
    local burn   = safe(reactor.getBurnRate())

    -- NEW ATM10 METHOD: Get tables directly
    -- We do NOT call getSteamCapacity() anymore.
    local fuel    = reactor.getFuel() or {amount = 0, max = 1}
    local waste   = reactor.getWaste() or {amount = 0, max = 1}
    local coolant = reactor.getCoolant() or {amount = 0, max = 1}
    local steam   = reactor.getSteam() or {amount = 0, max = 1}

    local fuelP    = fuel.amount / fuel.max
    local wasteP   = waste.amount / waste.max
    local coolantP = coolant.amount / coolant.max
    local steamP   = steam.amount / steam.max

    local eMax = safe(matrix.getMaxEnergy())
    local energyPct = (eMax > 0) and (safe(matrix.getEnergy()) / eMax) or 0

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 0.98 or wasteP > 0.9) then
        reactor.scram()
        error("SCRAM: SAFETY LIMITS EXCEEDED")
    end

    -- Rendering (Simplified for clarity)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v11.6 ] ==")
    
    term.setTextColor(colors.white)
    term.setCursorPos(1, 3)
    print("STATUS: " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:   " .. tempC .. " C")
    print("DAMAGE: " .. dmg .. " %")
    print("STEAM:  " .. math.floor(steamP * 100) .. " %")
    print("MATRIX: " .. math.floor(energyPct * 100) .. " %")

    sleep(REFRESH)
end
