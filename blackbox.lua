-- JARVIS v8.0 - FULL AUTONOMY
-- Run: wget https://raw.githubusercontent.com/caecitas-glitch/mein-campf-reactor/refs/heads/main/blackbox.lua jarvis

-- --- PERIPHERALS ---
local kbMon = peripheral.wrap("monitor_3")
local dispMon = peripheral.wrap("monitor_5")
local reactor = peripheral.find("fissionReactorLogicAdapter")
local turbine = peripheral.wrap("turbineValve_0")
local matrix = peripheral.find("inductionPort") -- Connects to your battery
local chatBox = peripheral.find("chatBox")      -- Optional: For real chat messages

if not kbMon or not dispMon or not reactor or not turbine then 
    error("Critical Hardware Missing! Check connections.") 
end

kbMon.setTextScale(1)
dispMon.setTextScale(1)

-- --- CONFIGURATION ---
local TARGET_BURN_RATE = 10.0 -- Default rate when active. Change this via keyboard!
local IDLE_BURN_RATE = 0.1    -- Rate when battery is full
local MAX_TEMP = 1000         -- Kelvin safety limit
local FULL_PCT = 0.95         -- 95% = Slow down
local LOW_PCT = 0.80          -- 80% = Speed up back to target

local currentState = "INIT"
local currentInput = ""
local aiResponse = "Jarvis: Auto-Pilot Engaged. Monitoring Grid Power."

-- --- LAYOUT ---
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

-- --- HELPER FUNCTIONS ---
function getSafeNum(val)
    if type(val) == "number" then return val end
    if type(val) == "table" then return val[1] or val.amount or 0 end
    return 0
end

function sendChat(msg)
    if chatBox then 
        chatBox.sendMessage(msg, "Jarvis") 
    else
        -- Fallback: Just print to the screen log if no ChatBox exists
        aiResponse = "CHAT: " .. msg
    end
end

-- --- AUTONOMOUS LOGIC LOOP ---
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

    -- 1. CRITICAL SAFETY CHECK
    if temp > MAX_TEMP then
        if reactor.getStatus() then
            reactor.scram()
            sendChat("EMERGENCY: Core Temp Critical! SCRAM Activated!")
            statusUpdate = " [SCRAM: HIGH TEMP]"
        end
        return statusUpdate
    end

    -- 2. BATTERY MANAGEMENT
    if pct >= FULL_PCT and currentState ~= "IDLE" then
        -- Battery is Full -> Slow Down
        reactor.setBurnRate(IDLE_BURN_RATE)
        currentState = "IDLE"
        sendChat("Power Grid Full ("..math.floor(pct*100).."%). Idling reactor.")
        statusUpdate = " [GRID FULL - IDLING]"

    elseif pct <= LOW_PCT and currentState ~= "ACTIVE" then
        -- Battery Low -> Ramp Up
        reactor.setBurnRate(TARGET_BURN_RATE)
        reactor.activate()
        currentState = "ACTIVE"
        sendChat("Power Grid Low ("..math.floor(pct*100).."%). Resuming normal burn.")
        statusUpdate = " [GRID LOW - ACTIVE]"
    end

    return statusUpdate
end

-- --- UI & INPUT HANDLING ---
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
    
    -- Status Line at bottom of keyboard
    kbMon.setCursorPos(2, kh)
    kbMon.setTextColor(colors.orange)
    kbMon.write("TARGET: " .. TARGET_BURN_RATE .. " mB/t | STATE: " .. currentState)

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

function processUserCommands(text)
    local upperText = text:upper()
    if upperText:find("SET BURN") or upperText:find("SET TO") then
        local rate = upperText:match("(%d+%.?%d*)")
        if rate then
            TARGET_BURN_RATE = tonumber(rate)
            reactor.setBurnRate(TARGET_BURN_RATE)
            return " [TARGET UPDATED: " .. rate .. "]"
        end
    end
    return ""
end

function askAI(prompt)
    local rTemp = getSafeNum(reactor.getTemperature())
    local tSteam = getSafeNum(turbine.getSteam())
    local mPct = 0
    if matrix then 
        mPct = getSafeNum(matrix.getEnergy()) / getSafeNum(matrix.getMaxEnergy()) * 100 
    end

    local stats = string.format("Temp:%.0fK Steam:%d Battery:%.1f%% State:%s", rTemp, tSteam, mPct, currentState)
    local payload = {
        model = "llama3",
        prompt = stats .. "\nUser: " .. prompt .. "\nJarvis:",
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

-- --- MAIN EVENT LOOP ---
drawKeyboard()
displayWrap(aiResponse)
os.startTimer(5) -- Start the first check timer

while true do
    local event, p1, p2, p3 = os.pullEvent()

    -- 1. TIMER EVENT (Auto-Pilot Check)
    if event == "timer" then
        local status = runAutoPilot()
        if status ~= "" then 
            aiResponse = "AUTO: " .. status 
            displayWrap(aiResponse)
        end
        drawKeyboard() -- Refresh status line
        os.startTimer(5) -- Schedule next check in 5 seconds

    -- 2. TOUCH EVENT (User Input)
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
                    local sysMsg = processUserCommands(currentInput)
                    if sysMsg == "" then
                        local answer = askAI(currentInput)
                        aiResponse = "Jarvis: " .. answer
                    else
                        aiResponse = "SYS: " .. sysMsg
                    end
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
