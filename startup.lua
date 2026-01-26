-- Configuration
local GITHUB_URL = "https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/startup.lua"
local VERSION = "1.3.1"

-- Function: Diagnostic Print
local function log(msg)
    term.setTextColor(colors.yellow)
    print("[SYSTEM] " .. msg)
    term.setTextColor(colors.white)
end

-- 1. WRAPPING PERIPHERALS
log("Wrapping peripherals...")
local monitor = peripheral.wrap("monitor_0")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_1")
local turbine = peripheral.wrap("turbineValve_0")
local matrix  = peripheral.wrap("inductionPort_0")

-- 2. DIAGNOSTICS
if not monitor then error("monitor_0 NOT FOUND. Check your modems!") end
log("Monitor linked.")
if not reactor then log("Warning: Reactor not found.") end
if not turbine then log("Warning: Turbine not found.") end
if not matrix  then log("Warning: Matrix not found.") end

-- 3. AUTO-UPDATER (Silent fail if no internet)
local function checkForUpdates()
    log("Checking GitHub...")
    if not http then 
        log("HTTP disabled in config.")
        return 
    end
    local response = http.get(GITHUB_URL)
    if response then
        local remoteContent = response.readAll()
        response.close()
        local f = fs.open(shell.getRunningProgram(), "r")
        local localContent = f.readAll()
        f.close()
        if remoteContent ~= localContent and #remoteContent > 100 then
            log("Update found! Saving...")
            local wf = fs.open(shell.getRunningProgram(), "w")
            wf.write(remoteContent)
            wf.close()
            log("Rebooting in 3s...")
            sleep(3)
            os.reboot()
        end
    end
    log("Up to date.")
end

-- 4. FORMATTING
local function formatNum(n)
    if not n or n == 0 then return "0" end
    if n >= 1e12 then return string.format("%.2f T", n/1e12) end
    if n >= 1e9 then return string.format("%.2f G", n/1e9) end
    if n >= 1e6 then return string.format("%.2f M", n/1e6) end
    if n >= 1e3 then return string.format("%.2f k", n/1e3) end
    return tostring(math.floor(n))
end

-- 5. DRAWING LOGIC
local function drawUI()
    -- Switch output to monitor
    term.redirect(monitor)
    monitor.setTextScale(0.5)
    
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Header
        term.setCursorPos(1,1)
        term.setBackgroundColor(colors.green)
        term.clearLine()
        term.write(" SYSTEM MONITOR v" .. VERSION .. " | ONLINE")
        term.setBackgroundColor(colors.black)

        -- Reactor
        term.setCursorPos(1, 3)
        term.setTextColor(colors.yellow)
        term.write(">> FISSION REACTOR")
        if reactor then
            term.setTextColor(colors.white)
            term.setCursorPos(2, 4)
            term.write("Temp: " .. math.floor(reactor.getTemperature()) .. "K")
            term.setCursorPos(2, 5)
            term.write("Damage: " .. reactor.getDamage() .. "%")
            term.setCursorPos(2, 6)
            term.write("Burn: " .. reactor.getBurnRate() .. " mB/t")
            -- SCRAM Check
            if reactor.getDamage() > 0 or reactor.getTemperature() > 1150 then
                reactor.setBurnRate(0)
            end
        else
            term.setTextColor(colors.red)
            term.setCursorPos(2, 4)
            term.write("NO DATA")
        end

        -- Turbine
        term.setCursorPos(1, 8)
        term.setTextColor(colors.cyan)
        term.write(">> TURBINE")
        if turbine then
            term.setTextColor(colors.white)
            term.setCursorPos(2, 9)
            term.write("Gen: " .. formatNum(turbine.getProductionRate()) .. " FE/t")
        else
            term.setTextColor(colors.red)
            term.setCursorPos(2, 9)
            term.write("NO DATA")
        end

        -- Matrix
        term.setCursorPos(1, 11)
        term.setTextColor(colors.magenta)
        term.write(">> MATRIX")
        if matrix then
            term.setTextColor(colors.white)
            term.setCursorPos(2, 12)
            term.write("Store: " .. formatNum(matrix.getEnergy()) .. " FE")
            term.setCursorPos(2, 13)
            term.setTextColor(colors.green)
            term.write("In:  " .. formatNum(matrix.getLastInput()) .. " FE/t")
            term.setCursorPos(2, 14)
            term.setTextColor(colors.red)
            term.write("Out: " .. formatNum(matrix.getLastOutput()) .. " FE/t")
        else
            term.setCursorPos(2, 12)
            term.setTextColor(colors.red)
            term.write("NO DATA")
        end

        sleep(1)
    end
end

-- RUN
checkForUpdates()
log("Starting UI...")
sleep(1)
drawUI()
