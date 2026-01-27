-- SETTINGS & PERIPHERALS
local kbMon = peripheral.wrap("monitor_3")
local dispMon = peripheral.wrap("monitor_5")
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.wrap("turbineValve_0")

if not kbMon or not dispMon or not reactor or not turbine then 
    error("Hardware missing! Check monitors and reactor connections.") 
end

kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Safety protocols updated. Waiting for command."

-- LAYOUT
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

-- HELPER: Fixes the "got table" error by extracting the number safely
function getSafeNum(val)
    if type(val) == "number" then return val end
    if type(val) == "table" then 
        -- Checks for common Mekanism table formats (index 1 or .amount)
        return val[1] or val.amount or 0 
    end
    return 0
end

-- CONTROL LOGIC (With Crash Prevention)
function processCommands(response)
    local text = response:upper()
    local action = ""
    
    -- SAFETY CHECK: Only SCRAM if the reactor is actually active
    if text:find("SCRAM") or text:find("SHUTDOWN") then
        if reactor.getStatus() == true then 
            reactor.scram()
            action = "\n[SYSTEM: SCRAM EXECUTED]"
        else
            action = "\n[SYSTEM: REACTOR ALREADY STOPPED]"
        end
        
    elseif text:find("ACTIVATE") then
        if reactor.getStatus() == false then
            reactor.activate()
            action = "\n[SYSTEM: REACTOR ACTIVATED]"
        else
            action = "\n[SYSTEM: ALREADY ACTIVE]"
        end
        
    elseif text:find("BURN RATE") then
        local rate = text:match("SET TO (%d+%.?%d*)")
        if rate then
            reactor.setBurnRate(tonumber(rate))
            action = "\n[SYSTEM: BURN RATE SET TO " .. rate .. "]"
        end
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
        local numKeys = #row
        local btnWidth = math.floor(kw / numKeys)
        local yPos = r + 4

        for c, key in ipairs(row) do
            local xPos = (c - 1) * btnWidth + 1
            kbMon.setCursorPos(xPos, yPos)
            kbMon.setTextColor(colors.gray)
            kbMon.write(".") 
            
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            local textOffset = math.floor((btnWidth - #key) / 2)
            kbMon.setCursorPos(xPos + textOffset, yPos)
            kbMon.write(key)
        end
    end
end

-- AI CONNECTION
function askAI(prompt)
    -- Safe data gathering using our helper function
    local rTemp = getSafeNum(reactor.getTemperature())
    local rDmg = getSafeNum(reactor.getDamagePercent())
    local tEnergy = getSafeNum(turbine.getEnergy())
    local tSteam = getSafeNum(turbine.getSteam())

    local stats = string.format(
        "CORE: Temp %.1fK, Damage %.1f%%. TURBINE: Energy %d, Steam %d. ",
        rTemp, rDmg, tEnergy, tSteam
    )
    
    local systemMsg = "Context: You are Jarvis. Manage the Reactor. " ..
                      "To stop core: 'SCRAM'. To start: 'ACTIVATE'."
                      
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
    return "Error: Brain offline."
end

-- MAIN LOOP
drawKeyboard()
displayWrap(aiResponse)

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if side == "monitor_3" then
        local rIdx = y - 4
        if layout[rIdx] then
            local kw = kbMon.getSize()
            local btnW = math.floor(kw / #layout[rIdx])
            local cIdx = math.floor((x - 1) / btnW) + 1
            local key = layout[rIdx][cIdx]
            
            if key then
                if key == "ENTER" then
                    displayWrap("Jarvis: Processing...")
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
