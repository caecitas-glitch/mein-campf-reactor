-- AEGIS REACTOR SHIELD v9.7
-- "Vault Protocol: Absolute Zero Error"

local REFRESH = 0.5
local MAX_TEMP = 1000
local CHANNEL = 15
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")
local modem = peripheral.find("modem") or error("No Modem Found")

-- === 1. THE LOGIC SHIELD (Fixes the table error) ===
local function toNum(val)
    if not val then return 0 end
    if type(val) == "table" then
        return tonumber(val.amount) or 0 -- Forces extraction of the 'amount' field
    end
    return tonumber(val) or 0
end

-- === 2. AUTO-UPDATER KERNEL ===
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
            print("Update Found. Overwriting...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            os.reboot()
        end
    end
end

-- === 3. CINEMATIC VAULT STARTUP ===
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
    -- Force everything to numbers BEFORE math
    local status = reactor.getStatus()
    local tempC  = math.floor(toNum(reactor.getTemperature()) - 273.15)
    local dmg    = toNum(reactor.getDamagePercent())
    local burn   = toNum(reactor.getBurnRate())
    
    local fuel       = toNum(reactor.getFuel())
    local fuelMax    = toNum(reactor.getFuelCapacity())
    local waste      = toNum(reactor.getWaste())
    local wasteMax   = toNum(reactor.getWasteCapacity())
    local coolant    = toNum(reactor.getCoolant())
    local coolantMax = toNum(reactor.getCoolantCapacity())

    local energyPct  = math.floor((toNum(matrix.getEnergy()) / toNum(matrix.getMaxEnergy())) * 100)
    local netFlow    = toNum(matrix.getLastInput()) - toNum(matrix.getLastOutput())

    -- Failsafes
    local wastePct = (wasteMax > 0) and (waste / wasteMax) or 0
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 98 or wastePct > 0.9) then
        reactor.scram()
        error("SCRAM TRIGGERED")
    end

    -- Full-Screen Dashboard
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v9.7 ] ==")

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS:  " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:    " .. tempC .. " C")
    print("BURN:    " .. burn .. " mB/t")
    print("DAMAGE:  " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- THERMAL DATA ---")
    term.setTextColor(colors.white)
    print("COOLANT: " .. ((coolantMax > 0) and math.floor((coolant/coolantMax)*100) or 0) .. "%")
    print("WASTE:   " .. math.floor(wastePct * 100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID STATUS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. energyPct .. " %")
    term.setTextColor(colors.white)
    print("NET:     " .. math.floor(netFlow) .. " FE/t")

    sleep(REFRESH)
end
