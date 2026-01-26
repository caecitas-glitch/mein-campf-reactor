-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local VERSION = "1.1.0"

-- Peripheral wrapping with safety checks
local function getPeripheral(type)
    local p = peripheral.find(type)
    if not p then print("Warning: " .. type .. " not found!") end
    return p
end

local reactor = getPeripheral("fission_reactor_logic_adapter")
local turbine = getPeripheral("turbine_valve")
local matrix  = getPeripheral("induction_port")
local monitor = getPeripheral("monitor")

local termObj = monitor or term
if monitor then termObj.setTextScale(0.5) end

-- --- AUTO-UPDATER ---
local function checkForUpdates()
    termObj.clear()
    termObj.setCursorPos(1,1)
    print("Checking GitHub for updates...")
    
    if not http then
        print("Error: HTTP API is disabled in the server config.")
        sleep(2)
        return
    end

    local response = http.get(GITHUB_URL)
    if response then
        local remoteContent = response.readAll()
        response.close()

        local currentFile = fs.open(shell.getRunningProgram(), "r")
        local localContent = currentFile.readAll()
        currentFile.close()

        if remoteContent ~= localContent and #remoteContent > 100 then
            print("New version detected! Updating...")
            local file = fs.open(shell.getRunningProgram(), "w")
            file.write(remoteContent)
            file.close()
            print("Update complete. Rebooting...")
            sleep(1)
            os.reboot()
        else
            print("System up to date.")
            sleep(1)
        end
    else
        print("Could not connect to GitHub. Starting local version...")
        sleep(2)
    end
end

-- --- UI UTILS ---
local function formatNum(n)
    if n >= 1e12 then return string.format("%.2f T", n/1e12) end
    if n >= 1e9 then return string.format("%.2f G", n/1e9) end
    if n >= 1e6 then return string.format("%.2f M", n/1e6) end
    if n >= 1e3 then return string.format("%.2f k", n/1e3) end
    return tostring(math.floor(n))
end

local function drawProgressBar(y, current, max, color)
    local width, _ = termObj.getSize()
    local barWidth = width - 4
    local fill = math.floor((current / max) * barWidth)
    
    termObj.setCursorPos(2, y)
    termObj.write("[")
    termObj.setBackgroundColor(color)
    termObj.write(string.rep(" ", fill))
    termObj.setBackgroundColor(colors.black)
    termObj.write(string.rep("-", barWidth - fill))
    termObj.write("]")
end

-- --- MONITORING LOOP ---
local function run()
    while true do
        termObj.setBackgroundColor(colors.black)
        termObj.clear()
        
        -- 1. Reactor Safety Logic
        local status = "STABLE"
        local statusColor = colors.green
        if reactor then
            local dmg = reactor.getDamage()
            local temp = reactor.getTemperature()
            local waste = reactor.getWaste().amount / reactor.getWasteCapacity()
            
            if dmg > 0 or temp > 1100 or waste > 0.85 then
                reactor.setBurnRate(0)
                status = "SCRAM - EMERGENCY"
                statusColor = colors.red
            end
        end

        -- Header
        termObj.setCursorPos(1,1)
        termObj.setBackgroundColor(statusColor)
        termObj.clearLine()
        termObj.write(" SYSTEM MONITOR v" .. VERSION .. " | " .. status)
        termObj.setBackgroundColor(colors.black)

        -- Reactor Section
        if reactor then
            termObj.setTextColor(colors.yellow)
            termObj.setCursorPos(1, 3)
            termObj.write(">> FISSION REACTOR")
            termObj.setTextColor(colors.white)
            termObj.setCursorPos(2, 4)
            termObj.write("Temp: " .. math.floor(reactor.getTemperature()) .. "K")
            termObj.setCursorPos(2, 5)
            termObj.write("Damage: " .. reactor.getDamage() .. "%")
            termObj.setCursorPos(2, 6)
            termObj.write("Burn: " .. reactor.getBurnRate() .. " mB/t")
        end

        -- Matrix Section
        if matrix then
            termObj.setTextColor(colors.magenta)
            termObj.setCursorPos(1, 8)
            termObj.write(">> INDUCTION MATRIX")
            termObj.setTextColor(colors.white)
            local energy = matrix.getEnergy()
            local maxEnergy = matrix.getMaxEnergy()
            termObj.setCursorPos(2, 9)
            termObj.write("Storage: " .. formatNum(energy) .. "FE")
            drawProgressBar(10, energy, maxEnergy, colors.magenta)
        end

        -- Turbine Section
        if turbine then
            termObj.setTextColor(colors.cyan)
            termObj.setCursorPos(1, 12)
            termObj.write(">> INDUSTRIAL TURBINE")
            termObj.setTextColor(colors.white)
            termObj.setCursorPos(2, 13)
            termObj.write("Gen: " .. formatNum(turbine.getProductionRate()) .. " FE/t")
            termObj.setCursorPos(2, 14)
            termObj.write("Flow: " .. formatNum(turbine.getFlowRate()) .. " mB/t")
        end

        sleep(1)
    end
end

-- Start Execution
checkForUpdates()
run()
