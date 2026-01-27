-- SETTINGS & PERIPHERALSs
local kbMon = peripheral.wrap("monitor_3")
local dispMon = peripheral.wrap("monitor_5")
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.wrap("turbineValve_0") -- Specific ID for your valve

if not kbMon or not dispMon or not reactor or not turbine then 
    error("Hardware missing! Check Monitor 3, Monitor 5, Reactor, and Turbine Valve.") 
end

kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Fission Reactor and Industrial Turbine links established."

-- KEYBOARD LAYOUT
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

-- POWER SYSTEM CONTROL LOGIC
function processCommands(response)
    local text = response:upper()
    local action = ""
    
    -- Reactor Commands
    if text:find("SCRAM") or text:find("SHUTDOWN") then
        reactor.scram()
        action = "\n[SYSTEM: EMERGENCY SCRAM INITIATED]"
    elseif text:find("ACTIVATE") then
        reactor.activate()
        action = "\n[SYSTEM: REACTOR ACTIVATED]"
    elseif text:find("BURN RATE") then
        local rate = text:match("SET TO (%d+%.?%d*)")
        if rate then
            reactor.setBurnRate(tonumber(rate))
            action = "\n[SYSTEM: BURN RATE SET TO " .. rate .. "]"
        end
    end

    -- Turbine Commands
    if text:find("DUMP STEAM") then
        turbine.setDumpMode("DUMPING")
        action = action .. "\n[SYSTEM: TURBINE DUMPING STEAM]"
    elseif text:find("IDLE TURBINE") then
        turbine.setDumpMode("IDLE")
        action = action .. "\n[SYSTEM: TURBINE IDLING]"
    end
    
    return action
end

-- UI DRAWING
function displayWrap(text)
    dispMon.clear()
    dispMon.setCursorPos(1, 1)
    local w, h = dispMon.getSize()
    local x, y = 1, 1
    for word in text:gmatch("%S+") do
        if x + #word > w then x = 1 y = y + 1 end
        if y <= h then
            dispMon.setCursorPos(x, y)
            dispMon.write(word .. " ")
            x = x + #word + 1
        end
    end
end

function drawKeyboard()
    kbMon.clear()
    local kw, kh = kbMon.getSize()
    kbMon.setCursorPos(math.floor(kw/2 - 10), 2)
    kbMon.setTextColor(colors.yellow)
    kbMon.write("CMD> " .. currentInput .. "_")

    for r, row in ipairs(layout) do
        local rowBtnW = math.floor(kw / #row)
        for c, key in ipairs(row) do
            local x = (c - 1) * rowBtnW + 1
            local y = r + 4
            kbMon.setCursorPos(x, y)
            kbMon.setTextColor(colors.gray)
            kbMon.write(".") 
            
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            local offset = math.floor((rowBtnW - #key) / 2)
            kbMon.setCursorPos(x + offset, y)
            kbMon.write(key)
        end
    end
end

-- AI CONNECTION WITH INTEGRATED POWER STATS
function askAI(prompt)
    -- Jarvis reads Reactor AND Turbine stats
    local stats = string.format(
        "CORE: Temp %.1fK, Damage %.1f%%. TURBINE: Energy %d RF, Steam %d/%d. ",
        reactor.getTemperature(),
        reactor.getDamagePercent(),
        turbine.getEnergy(),
        turbine.getSteam(),
        turbine.getSteamCapacity()
    )
    
    local systemMsg = "Context: You are Jarvis. Manage the Reactor and Turbine. " ..
                      "To stop core: 'SCRAM'. To vent turbine: 'DUMP STEAM'. "
                      
    local payload = {
        model = "llama3",
        prompt = stats .. "\n" .. systemMsg .. "\nUser: " .. prompt .. "\nJarvis:",
        stream = false
    }
    
    local res = http.post("http://127.0.0.1:11434/api/generate", textutils.serialiseJSON(payload))
    if res then
        local data = textutils.unserialiseJSON(res.readAll())
        res.close()
        return data.response
    end
    return "Error: Local AI communication failed."
end

-- STARTUP
drawKeyboard()
displayWrap(aiResponse)

-- MAIN LOOP
while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if side == "monitor_3" then
        local rIdx = y - 4
        if layout[rIdx] then
            local rowBtnW = math.floor(kbMon.getSize() / #layout[rIdx])
            local cIdx = math.floor((x - 1) / rowBtnW) + 1
            local key = layout[rIdx][cIdx]
            
            if key then
                if key == "ENTER" then
                    displayWrap("Jarvis: Synchronizing Power Systems...")
                    local answer = askAI(currentInput)
                    local note = processCommands(answer)
                    aiResponse = answer .. note
                    displayWrap(aiResponse)
                    currentInput = ""
                elseif key == "BS" then currentInput = currentInput:sub(1, -2)
                elseif key == "SPACE" then currentInput = currentInput .. " "
                elseif key == "CLEAR" then currentInput = ""
                else currentInput = currentInput .. key end
                drawKeyboard()
            end
        end
    end
end
