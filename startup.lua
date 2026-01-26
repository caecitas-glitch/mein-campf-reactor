-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local VERSION = "1.2.0"

-- Peripheral wrapping
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix  = peripheral.find("induction_port")
local monitor = peripheral.find("monitor")

local termObj = monitor or term
if monitor then termObj.setTextScale(0.5) end

-- --- AUTO-UPDATER ---
local function checkForUpdates()
    if not http then return end
    local response = http.get(GITHUB_URL)
    if response then
        local remoteContent = response.readAll()
        response.close()
        local currentFile = fs.open(shell.getRunningProgram(), "r")
        local localContent = currentFile.readAll()
        currentFile.close()
        if remoteContent ~= localContent and #remoteContent > 100 then
            local file = fs.open(shell.getRunningProgram(), "w")
            file.write(remoteContent)
            file.close()
            os.reboot()
        end
    end
end

-- --- FORMATTING UTILS ---
local function formatNum(n)
    if not n then return "0" end
    if n >= 1e12 then return string.format("%.2f T", n/1e12) end
    if n >= 1e9 then return string.format("%.2f G", n/1e9) end
    if n >= 1e6 then return string.format("%.2f M", n/1e6) end
    if n >= 1e3 then return string.format("%.2f k", n/1e3) end
    return tostring(math.floor(n))
end

local function drawHeader(title, y, color)
    termObj.setCursorPos(1, y)
    termObj.setBackgroundColor(color)
    termObj.setTextColor(colors.white)
    termObj.clearLine()
    termObj.write(" " .. title)
    termObj.setBackgroundColor(colors.black)
end

-- --- MAIN LOOP ---
local function main()
    while true do
        termObj.setBackgroundColor(colors.black)
        termObj.clear()

        -- 1. Fission Reactor Stats
        drawHeader("FISSION REACTOR", 1, colors.gray)
        if reactor then
            local fuel = reactor.getFuel()
            local waste = reactor.getWaste()
            local temp = reactor.getTemperature()
            local damage = reactor.getDamage()
            
            -- SCRAM Logic
            local status = reactor.getStatus() and "ONLINE" or "OFFLINE"
            local sCol = reactor.getStatus() and colors.green or colors.red
            if damage > 0 or temp > 1150 or (waste.amount / reactor.getWasteCapacity()) > 0.9 then
                reactor.setBurnRate(0)
                status = "!!! SCRAM !!!"
                sCol = colors.red
            end

            termObj.setTextColor(sCol)
            termObj.setCursorPos(2, 2)
            termObj.write("Status: " .. status)
            termObj.setTextColor(colors.white)
            termObj.setCursorPos(2, 3)
            termObj.write("Temp: " .. math.floor(temp) .. "K")
            termObj.setCursorPos(2, 4)
            termObj.write("Damage: " .. damage .. "%")
            termObj.setCursorPos(2, 5)
            termObj.write("Burn: " .. reactor.getBurnRate() .. " / " .. reactor.getMaxBurnRate() .. " mB/t")
            termObj.setCursorPos(2, 6)
            termObj.write("Fuel: " .. formatNum(fuel.amount) .. " mB")
            termObj.setCursorPos(2, 7)
            termObj.write("Waste: " .. formatNum(waste.amount) .. " mB")
        else
            termObj.setCursorPos(2, 2)
            termObj.write("REACTOR NOT FOUND")
        end

        -- 2. Industrial Turbine Stats
        drawHeader("INDUSTRIAL TURBINE", 9, colors.gray)
        if turbine then
            termObj.setCursorPos(2, 10)
            termObj.write("Energy: " .. formatNum(turbine.getEnergy()) .. " FE")
            termObj.setCursorPos(2, 11)
            termObj.write("Prod: " .. formatNum(turbine.getProductionRate()) .. " FE/t")
            termObj.setCursorPos(2, 12)
            termObj.write("Flow: " .. formatNum(turbine.getFlowRate()) .. " / " .. turbine.getMaxFlowRate() .. " mB/t")
            termObj.setCursorPos(2, 13)
            termObj.write("Steam: " .. formatNum(turbine.getSteam().amount) .. " mB")
        else
            termObj.setCursorPos(2, 10)
            termObj.write("TURBINE NOT FOUND")
        end

        -- 3. Induction Matrix Stats
        drawHeader("INDUCTION MATRIX", 15, colors.gray)
        if matrix then
            local energy = matrix.getEnergy()
            local maxE = matrix.getMaxEnergy()
            local filled = (energy / maxE) * 100
            
            termObj.setCursorPos(2, 16)
            termObj.write("Stored: " .. formatNum(energy) .. " FE (" .. string.format("%.1f", filled) .. "%)")
            termObj.setCursorPos(2, 17)
            termObj.setTextColor(colors.green)
            termObj.write("Input:  " .. formatNum(matrix.getLastInput()) .. " FE/t")
            termObj.setCursorPos(2, 18)
            termObj.setTextColor(colors.red)
            termObj.write("Output: " .. formatNum(matrix.getLastOutput()) .. " FE/t")
            termObj.setTextColor(colors.white)
        else
            termObj.setCursorPos(2, 16)
            termObj.write("MATRIX NOT FOUND")
        end

        sleep(1)
    end
end

checkForUpdates()
main()
