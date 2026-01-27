-- SETTINGS & PERIPHERALS
local kbMon = peripheral.wrap("monitor_3")
local dispMon = peripheral.wrap("monitor_5")
local LAMP_SIDE = "top" -- Change this to the side your lamp is on

if not kbMon or not dispMon then error("Monitors not found!") end

kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Neural link and Redstone systems online."

-- KEYBOARD LAYOUT
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

-- REDSTONE LOGIC
function processCommands(response)
    local text = response:upper()
    local actionTaken = ""
    
    if text:find("TURN ON") or text:find("LIGHTS ON") or text:find("ACTIVATING") then
        redstone.setOutput(LAMP_SIDE, true)
        actionTaken = " [SYSTEM: REDSTONE HIGH]"
    elseif text:find("TURN OFF") or text:find("LIGHTS OFF") or text:find("DEACTIVATING") then
        redstone.setOutput(LAMP_SIDE, false)
        actionTaken = " [SYSTEM: REDSTONE LOW]"
    end
    return actionTaken
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
    local btnW = math.floor(kw / 10)
    
    -- Input Header
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

-- AI CONNECTION
function askAI(prompt)
    -- System instructions tell the AI how to trigger the redstone
    local systemMsg = "Context: You are Jarvis. You control the base redstone. " ..
                      "To turn on lights, use the word 'ACTIVATING'. " ..
                      "To turn them off, use 'DEACTIVATING'. "
                      
    local payload = {
        model = "llama3",
        prompt = systemMsg .. "\nUser: " .. prompt .. "\nJarvis:",
        stream = false
    }
    
    local res = http.post("http://127.0.0.1:11434/api/generate", textutils.serialiseJSON(payload))
    if res then
        local data = textutils.unserialiseJSON(res.readAll())
        res.close()
        return data.response
    end
    return "Error: Local AI connection lost."
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
