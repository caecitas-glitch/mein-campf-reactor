-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local UPDATE_INTERVAL = 3600 -- Check for updates every hour (if script stays running)
local VERSION = "1.0.2"

-- Peripheral Wrapping
local reactor = peripheral.find("fission_reactor_logic_adapter")
local turbine = peripheral.find("turbine_valve")
local matrix = peripheral.find("induction_port")
local monitor = peripheral.find("monitor") -- Optional: will use terminal if no monitor

local termObj = monitor or term
if monitor then monitor.setTextScale(0.5) end

-- --- AUTO-UPDATER LOGIC ---
local function updateScript()
    print("Checking for updates...")
    if not http then
        print("Error: HTTP API not enabled.")
        return
    end

    local response = http.get(GITHUB_URL)
    if response then
        local newCode = response.readAll()
        response.close()

        -- Simple check: if the file size or content is different
        local f = fs.open("startup.lua", "r")
        local oldCode = f.readAll()
        f.close()

        if newCode ~= oldCode and #newCode > 100 then
            print("New version found! Updating...")
            local wf = fs.open("startup.lua", "w")
            wf.write(newCode)
            wf.close()
            sleep(1)
            os.reboot()
        else
            print("Already up to date.")
        end
    else
        print("Failed to reach GitHub.")
    end
end

-- --- UTILS ---
local function formatNum(n)
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

local function drawStat(label, value, y, unit, color)
    termObj.setCursorPos(2, y)
    termObj.setTextColor(colors.lightGray)
    termObj.write(label .. ": ")
    termObj.setTextColor(color or colors.white)
    termObj.write(value .. " " .. (unit or ""))
end

-- --- MAIN LOOP ---
local function main()
    while true do
        termObj.setBackgroundColor(colors.black)
        termObj.clear()
        
        -- 1. Safety Logic
        local status = "OPERATIONAL"
        local statusColor = colors.green
        local scramReason = ""

        if reactor then
            local damage = reactor.getDamage()
            local temp = reactor.getTemperature()
            local waste = reactor.getWaste().amount
            local wasteMax = reactor.getWasteCapacity()

            if damage > 0 or temp > 1150 or (waste / wasteMax) > 0.90 then
                reactor.setBurnRate(0)
                -- reactor.scram() -- Uncomment if your version supports direct SCRAM
                status = "EMERGENCY SHUTDOWN"
                statusColor = colors.red
                if damage > 0 then scramReason = "CORE DAMAGE"
                elseif temp > 1150 then scramReason = "OVERHEAT"
                else scramReason = "WASTE OVERFLOW" end
            end
        end

        -- 2. Display Header
        drawHeader("SYSTEM CONTROL v" .. VERSION .. " | " .. status, 1, statusColor)
        if scramReason ~= "" then
            termObj.setCursorPos(2, 2)
            termObj.setTextColor(colors.red)
            termObj.write("!! " .. scramReason .. " !!")
        end

        -- 3. Reactor Stats
        drawHeader("FISSION REACTOR", 4, colors.gray)
        if reactor then
            drawStat("Status", reactor.getStatus() and "ONLINE" or "OFFLINE", 5, "", reactor.getStatus() and colors.green or colors.red)
            drawStat("Temp", math.floor(reactor.getTemperature()), 6, "K", reactor.getTemperature() > 1000 and colors.orange or colors.yellow)
            drawStat("Damage", reactor.getDamage(), 7, "%", reactor.getDamage() > 0 and colors.red or colors.green)
            drawStat("Fuel", formatNum(reactor.getFuel().amount), 8, "mB")
            drawStat("Burn Rate", reactor.getBurnRate(), 9, "mB/t")
        else
            termObj.setCursorPos(2, 5)
            termObj.write("NOT FOUND")
        end

        -- 4. Turbine Stats
        drawHeader("INDUSTRIAL TURBINE", 11, colors.gray)
        if turbine then
            drawStat("Energy", formatNum(turbine.getEnergy()), 12, "FE")
            drawStat("Flow Rate", formatNum(turbine.getFlowRate()), 13, "mB/t")
            drawStat("Production", formatNum(turbine.getProductionRate()), 14, "FE/t", colors.cyan)
            local fill = (turbine.getEnergy() / turbine.getMaxEnergy()) * 100
            drawStat("Storage", string.format("%.1f", fill), 15, "%")
        else
            termObj.setCursorPos(2, 12)
            termObj.write("NOT FOUND")
        end

        -- 5. Matrix Stats
        drawHeader("INDUCTION MATRIX", 17, colors.gray)
        if matrix then
            drawStat("Stored", formatNum(matrix.getEnergy()), 18, "FE")
            drawStat("Input", formatNum(matrix.getLastInput()), 19, "FE/t", colors.green)
            drawStat("Output", formatNum(matrix.getLastOutput()), 20, "FE/t", colors.red)
            local mFill = (matrix.getEnergy() / matrix.getMaxEnergy()) * 100
            drawStat("Charge", string.format("%.1f", mFill), 21, "%", colors.magenta)
        else
            termObj.setCursorPos(2, 18)
            termObj.write("NOT FOUND")
        end

        sleep(1)
    end
end

-- Run update check once on start
updateScript()

-- Run Main loop with error handling
local status, err = pcall(main)
if not status then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    print("Program crashed: " .. err)
end
