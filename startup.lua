-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local VERSION = "1.3.0"

-- Explicit Peripheral Wrapping
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

-- Redirect all output to the monitor immediately
if monitor then
    term.redirect(monitor)
    monitor.setTextScale(0.5)
    term.setBackgroundColor(colors.black)
    term.clear()
else
    print("CRITICAL ERROR: monitor_0 not found!")
    return
end

-- --- AUTO-UPDATER ---
local function checkForUpdates()
    if not http then return end
    local response = http.get(GITHUB_URL)
    if response then
        local remoteContent = response.readAll()
        response.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localContent = f.readAll()
        f.close()
        if remoteContent ~= localContent and #remoteContent > 100 then
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteContent)
            wf.close()
            os.reboot()
        end
    end
end

-- --- FORMATTING ---
local function formatNum(n)
    if not n or n == 0 then return "0" end
    if n >= 1e12 then return string.format("%.2f T", n/1e12) end
    if n >= 1e9 then return string.format("%.2f G", n/1e9) end
    if n >= 1e6 then return string.format("%.2f M", n/1e6) end
    if n >= 1e3 then return string.format("%.2f k", n/1e3) end
    return tostring(math.floor(n))
end

local function drawHeader(title, y, color)
    term.setCursorPos(1, y)
    term.setBackgroundColor(color)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write(" " .. title)
    term.setBackgroundColor(colors.black)
end

-- --- MAIN LOOP ---
local function main()
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()

        -- Safety Logic First
        local status = "OPERATIONAL"
        local statusCol = colors.green
        if reactor then
            if reactor.getDamage() > 0 or reactor.getTemperature() > 1150 then
                reactor.setBurnRate(0) -- Emergency Cutoff
                status = "!!! SCRAM !!!"
                statusCol = colors.red
            end
        end

        -- Header
        drawHeader("SYSTEM MONITOR v" .. VERSION .. " | " .. status, 1, statusCol)

        -- 1. Reactor Stats
        drawHeader("FISSION REACTOR", 3, colors.gray)
        if reactor then
            term.setCursorPos(2, 4)
            term.write("Temp: " .. math.floor(reactor.getTemperature()) .. "K")
            term.setCursorPos(2, 5)
            term.write("Damage: " .. reactor.getDamage() .. "%")
            term.setCursorPos(2, 6)
            term.write("Burn: " .. reactor.getBurnRate() .. " mB/t")
            term.setCursorPos(2, 7)
            term.write("Fuel: " .. formatNum(reactor.getFuel().amount) .. " mB")
        else
            term.setCursorPos(2, 4)
            term.setTextColor(colors.red)
            term.write("Reactor Logic Adapter Missing")
        end

        -- 2. Turbine Stats
        drawHeader("INDUSTRIAL TURBINE", 9, colors.gray)
        if turbine then
            term.setTextColor(colors.white)
            term.setCursorPos(2, 10)
            term.write("Gen: " .. formatNum(turbine.getProductionRate()) .. " FE/t")
            term.setCursorPos(2, 11)
            term.write("Flow: " .. formatNum(turbine.getFlowRate()) .. " mB/t")
            term.setCursorPos(2, 12)
            term.write("Steam: " .. formatNum(turbine.getSteam().amount) .. " mB")
        else
            term.setCursorPos(2, 10)
            term.setTextColor(colors.red)
            term.write("Turbine Valve Missing")
        end

        -- 3. Matrix Stats
        drawHeader("INDUCTION MATRIX", 14, colors.gray)
        if matrix then
            term.setTextColor(colors.white)
            term.setCursorPos(2, 15)
            term.write("Stored: " .. formatNum(matrix.getEnergy()) .. " FE")
            term.setCursorPos(2, 16)
            term.setTextColor(colors.green)
            term.write("Input:  " .. formatNum(matrix.getLastInput()) .. " FE/t")
            term.setCursorPos(2, 17)
            term.setTextColor(colors.red)
            term.write("Output: " .. formatNum(matrix.getLastOutput()) .. " FE/t")
        else
            term.setCursorPos(2, 15)
            term.setTextColor(colors.red)
            term.write("Induction Port Missing")
        end

        sleep(1)
    end
end

-- Execution
checkForUpdates()
main()
