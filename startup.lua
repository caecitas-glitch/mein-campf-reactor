-- AEGIS REACTOR SHIELD v11.6
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/main/startup.lua"
local reactor = peripheral.find("fissionReactorLogicAdapter")
local matrix = peripheral.find("inductionPort")

-- Fixed Resource Gathering for ATM10
local function getStats()
    local fuel = reactor.getFuel() or {amount = 0, max = 1}
    local steam = reactor.getSteam() or {amount = 0, max = 1}
    local waste = reactor.getWaste() or {amount = 0, max = 1}
    return fuel, steam, waste
end

while true do
    local fuel, steam, waste = getStats()
    local temp = math.floor(reactor.getTemperature() - 273.15)
    
    term.clear()
    term.setCursorPos(1,1)
    print("== AEGIS ONLINE (ATM10) ==")
    print("Temp:   " .. temp .. " C")
    print("Steam:  " .. math.floor((steam.amount/steam.max)*100) .. "%")
    print("Waste:  " .. math.floor((waste.amount/waste.max)*100) .. "%")
    
    -- Auto-Update Check
    local res = http.get(GITHUB_URL)
    if res then
        local remote = res.readAll()
        res.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localCode = f.readAll()
        f.close()
        if remote ~= localCode then os.reboot() end
    end
    
    sleep(1)
end
