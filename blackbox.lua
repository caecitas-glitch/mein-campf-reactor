-- JARVIS v9.0 - RESTORED CONTROL & MANUAL OVERRIDE
-- Run: wget https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/blackbox.lua jarvis

local kbMon = peripheral.wrap("monitor_3")
local dispMon = peripheral.wrap("monitor_5")
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.wrap("turbineValve_0")
local matrix = peripheral.find("inductionPort") 
local chatBox = peripheral.find("chatBox")

if not kbMon or not dispMon or not reactor or not turbine then 
    error("Hardware missing! Check monitors, reactor, and turbine.") 
end

kbMon.setTextScale(1)
dispMon.setTextScale(1)

-- CONFIG
local TARGET_BURN_RATE = 10.0 
local IDLE_BURN_RATE = 0.1
local MAX_TEMP = 1200
local FULL_PCT = 0.95
local LOW_PCT = 0.80

local currentState = "INIT"
local currentInput = ""
local aiResponse = "Jarvis: Control Links Restored. Manual Overrides Available."

-- LAYOUT (Added Manual START/STOP keys)
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"START", "SPACE", "STOP", "ENTER", "CLR"} -- New direct control buttons
}

-- HELPER: Safe Number Extraction
function getSafeNum(val)
    if type(val) == "number" then return val end
    if type(val) == "table" then return val[1] or val.amount or 0 end
    return 0
end

function sendChat(msg)
    if chatBox then chatBox.sendMessage(msg, "Jarvis") end
end

-- 1. COMMAND PARSER (The missing link!)
function parseAIResponse(response)
    local text = response:upper()
    local action = ""

    if text:find("SCRAM") or text:find("SHUTDOWN") then
        if reactor.getStatus() then
            reactor.scram()
            action = "\n[SYS: SCRAM EXECUTED]"
        end
    elseif text:find("ACTIVATE") or text:find("START") then
        if not reactor.getStatus() then
            reactor.activate()
            action = "\n[SYS: REACTOR ACTIVATED]"
        end
    elseif text:find("BURN RATE") or text:find("SET TO") then
        local rate = text:match("(%d+%.?%d*)")
        if rate then
            local rNum = tonumber(rate)
            reactor.setBurnRate(rNum)
            TARGET_BURN_RATE = rNum -- Update our auto-pilot target too
            action = "\n[SYS: BURN RATE " .. rNum .. "]"
        end
    elseif text:find("VENT") or text:find("DUMP") then
        turbine.setDumpMode("DUMPING")
        action = "\n[SYS: VENTING STEAM]"
    end
    return action
end

-- 2. AUTO-PILOT LOOP
function runAutoPilot()
    local temp = getSafeNum(reactor.getTemperature())
    local energy = 0
    local maxEnergy = 1
    
    if matrix then
        energy = getSafeNum(matrix.getEnergy())
        maxEnergy = getSafeNum(matrix.getMaxEnergy())
    end
    
    local pct = energy / maxEnergy
    local statusUpdate = ""

    -- Safety SCRAM
    if temp > MAX_TEMP then
        if reactor.getStatus() then
            reactor.scram()
            sendChat("CRITICAL TEMP! SCRAM!")
            statusUpdate = " [SCRAM: HIGH TEMP]"
        end
        return statusUpdate
    end

    -- Battery Logic
    if pct >= FULL_PCT and currentState ~= "IDLE" then
        reactor.setBurnRate(IDLE_BURN_RATE)
        currentState = "IDLE"
        statusUpdate = " [GRID FULL - IDLE]"
    elseif pct <= LOW_PCT and currentState ~= "ACTIVE" then
        reactor.setBurnRate(TARGET_BURN_RATE)
        reactor.activate()
        currentState = "ACTIVE"
        statusUpdate = " [GRID LOW - ACTIVE]"
    end

    return statusUpdate
end

-- UI
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
    
    kbMon.setCursorPos(2, kh)
    kbMon.setTextColor(colors.orange)
    kbMon.write("TGT: " .. TARGET_BURN_RATE .. " | " .. currentState)

    for r, row in ipairs(layout) do
        local numKeys = #row
        local btnWidth = math.floor(kw / numKeys)
        local yPos = r + 4

        for c, key in ipairs(row) do
            local xPos = (c - 1) * btnWidth + 1
            kbMon.setCursorPos(xPos, yPos)
            kbMon.setTextColor(colors.gray)
            kbMon.write(".") 
            
            if key == "ENTER" or key == "START" then kbMon.setTextColor(colors.green)
            elseif key == "STOP" or key == "CLR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            local textOffset = math.floor((btnWidth - #key) / 2)
            kbMon.setCursorPos(xPos + textOffset, yPos)
            kbMon.write(key)
        end
    end
end

function askAI(prompt)
    local rTemp = getSafeNum(reactor.getTemperature())
    local tSteam = getSafeNum(turbine.getSteam())
    local mPct = 0
    if matrix then mPct = getSafeNum(matrix.getEnergy()) / getSafeNum(matrix.getMaxEnergy()) * 100 end

    local stats = string.format("Temp:%.0fK Steam:%d Bat:%.1f%% State:%s", rTemp, tSteam, mPct, currentState)
    local payload = {
        model = "llama3",
        prompt = stats .. "\nSystem: To start say 'ACTIVATE'. To stop say 'SCRAM'. To set rate say 'SET TO [num]'.\nUser: " .. prompt .. "\nJarvis:",
        stream = false
    }
    local res = http.post("http://127.0.0.1:11434/api/generate", textutils.serialiseJSON(payload))
    if res then
        local data = textutils.unserialiseJSON(res.readAll())
        res.close()
        return data.response
    end
    return "Offline"
end

-- MAIN LOOP
drawKeyboard()
displayWrap(aiResponse)
os.startTimer(5)

while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" then
        local status = runAutoPilot()
        if status ~= "" then 
            aiResponse = "AUTO: " .. status 
            displayWrap(aiResponse)
        end
        drawKeyboard()
        os.startTimer(5)

    elseif event == "monitor_touch" and p1 == "monitor_3" then
        local x, y = p2, p3
        local rIdx = y - 4
        if layout[rIdx] then
            local kw = kbMon.getSize()
            local btnW = math.floor(kw / #layout[rIdx])
            local cIdx = math.floor((x - 1) / btnW) + 1
            local key = layout[rIdx][cIdx]
            
            if key then
                if key == "ENTER" then
                    displayWrap("Jarvis: Thinking...")
                    local answer = askAI(currentInput)
                    -- THIS LINE WAS MISSING IN v8.0:
                    local sysAction = parseAIResponse(answer) 
                    
                    aiResponse = "Jarvis: " .. answer .. sysAction
                    displayWrap(aiResponse)
                    currentInput = ""
                
                -- MANUAL OVERRIDES
                elseif key == "START" then
                    reactor.activate()
                    displayWrap("MANUAL: REACTOR ACTIVATED")
                elseif key == "STOP" then
                    reactor.scram()
                    displayWrap("MANUAL: SCRAM EXECUTED")
                    
                elseif key == "BS" then currentInput = currentInput:sub(1, -2)
                elseif key == "SPACE" then currentInput = currentInput .. " "
                elseif key == "CLR" then currentInput = ""
                else currentInput = currentInput .. key end
                drawKeyboard()
            end
        end
    end
end
