-- AEGIS REACTOR SHIELD v11.5 (FINAL STABILIZER)
-- Protocol: Absolute Containment

local REFRESH = 0.5
local MAX_TEMP = 1000
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"

local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- === 1. THE SAFETY SHIELD ===
-- Prevents "Arithmetic on table" and "nil value" errors
local function safe(val)
    if not val then return 0 end
    if type(val) == "table" then return tonumber(val.amount) or 0 end
    return tonumber(val) or 0
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
            print("Update Found. Syncing...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteCode)
            wf.close()
            os.reboot()
        end
    end
end

-- === 3. JAGGED VAULT STARTUP ===
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

-- === 4. PERSISTED SCRAMS ===
local function getScrams()
    if not fs.exists("scrams.txt") then return 0 end
    local f = fs.open("scrams.txt", "r")
    local c = tonumber(f.readAll()) or 0
    f.close()
    return c
end

local function addScram()
    local c = getScrams() + 1
    local f = fs.open("scrams.txt", "w")
    f.write(tostring(c))
    f.close()
end

-- === 5. MAIN LOOP ===
vaultStartup()

while true do
    -- Using the Safety Shield for every single call
    local status = reactor.getStatus()
    local tempC  = math.floor(safe(reactor.getTemperature()) - 273.15)
    local dmg    = safe(reactor.getDamagePercent())
    local burn   = safe(reactor.getBurnRate())
    
    local fMax = safe(reactor.getFuelCapacity())
    local wMax = safe(reactor.getWasteCapacity())
    local cMax = safe(reactor.getCoolantCapacity())
    local sMax = safe(reactor.getSteamCapacity())

    local fuelP    = (fMax > 0) and (safe(reactor.getFuel()) / fMax) or 0
    local wasteP   = (wMax > 0) and (safe(reactor.getWaste()) / wMax) or 0
    local coolantP = (cMax > 0) and (safe(reactor.getCoolant()) / cMax) or 0
    local steamP   = (sMax > 0) and (safe(reactor.getSteam() or reactor.getFluidStored()) / sMax) or 0

    local eMax = safe(matrix.getMaxEnergy())
    local energyPct = (eMax > 0) and (safe(matrix.getEnergy()) / eMax) or 0

    -- Failsafes
    if status and (tempC > MAX_TEMP or dmg > 0 or energyPct > 0.98 or wasteP > 0.9) then
        reactor.scram()
        addScram()
        error("SCRAM: SAFETY LIMITS EXCEEDED")
    end

    -- UI Rendering (v6.7 Layout Revived)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.blue)
    print("== [ AEGIS VAULT v11.5 ] ==")
    
    term.setCursorPos(22, 1)
    term.setTextColor(colors.red)
    term.write("SCRAMS: " .. getScrams())

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    print("STATUS: " .. (status and "ACTIVE" or "IDLE"))
    print("HEAT:   " .. tempC .. " C")
    print("BURN:   " .. burn .. " mB/t")
    print("DAMAGE: " .. dmg .. " %")

    term.setTextColor(colors.gray)
    print("\n--- THERMAL & WASTE ---")
    term.setTextColor(colors.white)
    print("COOLANT: " .. math.floor(coolantP * 100) .. "%")
    print("WASTE:   " .. math.floor(wasteP * 100) .. "%")
    print("STEAM:   " .. math.floor(steamP * 100) .. "%")

    term.setTextColor(colors.gray)
    print("\n--- GRID STATUS ---")
    term.setTextColor(colors.yellow)
    print("MATRIX:  " .. math.floor(energyPct * 100) .. " %")

    sleep(REFRESH)
end
