-- Jarvis dual-monitor control system
local kbMon = peripheral.wrap("monitor_3")   -- Touchscreen keyboard
local dispMon = peripheral.wrap("monitor_4") -- AI response display

if not kbMon or not dispMon then 
    error("One or more monitors not found. Check modem connections!") 
end

-- Force larger text for easier clicking
kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Dual-link established."

-- Layout with Spacebar and Utility keys
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

function drawUI()
    -- Draw Keyboard Monitor
    kbMon.clear()
    local kw, kh = kbMon.getSize()
    local btnW = math.floor(kw / 10)
    
    kbMon.setCursorPos(1, 1)
    kbMon.setTextColor(colors.yellow)
    kbMon.write("INPUT: " .. currentInput .. "_")

    for r, row in ipairs(layout) do
        for c, key in ipairs(row) do
            local x = (c - 1) * btnW + 1
            local y = kh - 5 + r
            kbMon.setCursorPos(x, y)
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            kbMon.write("[" .. key .. "]")
        end
    end

    -- Draw Display Monitor
    dispMon.clear()
    dispMon.setCursorPos(1,1)
    dispMon.setTextColor(colors.cyan)
    
    -- Basic text wrapping logic for the main screen
    local dw, dh = dispMon.getSize()
    local line = 1
    for i = 1, #aiResponse, dw do
        if line <= dh then
            dispMon.setCursorPos(1, line)
            dispMon.write(aiResponse:sub(i, i + dw - 1))
            line = line + 1
        end
    end
end

function askAI(prompt)
    local payload = { model = "llama3", prompt = prompt, stream = false }
    local res = http.post("http://127.0.0.1:11434/api/generate", textutils.serialiseJSON(payload))
    if res then
        local data = textutils.unserialiseJSON(res.readAll())
        res.close()
        return data.response
    end
    return "Error: Brain offline."
end

drawUI()

while true do
    -- Filter touches to ONLY the keyboard monitor (monitor_3)
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    if side == "monitor_3" then
        local kw, kh = kbMon.getSize()
        local btnW = math.floor(kw / 10)
        local rIdx = y - (kh - 5)
        local cIdx = math.floor((x - 1) / btnW) + 1
        
        local key = layout[rIdx] and layout[rIdx][cIdx]
        
        if key then
            if key == "ENTER" then
                aiResponse = "Jarvis: Thinking..."
                drawUI()
                aiResponse = "Jarvis: " .. askAI(currentInput)
                currentInput = ""
            elseif key == "BS" then currentInput = currentInput:sub(1, -2)
            elseif key == "SPACE" then currentInput = currentInput .. " "
            elseif key == "CLEAR" then currentInput = ""
            else currentInput = currentInput .. key end
            drawUI()
        end
    end
end
