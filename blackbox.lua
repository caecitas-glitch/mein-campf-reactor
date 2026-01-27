-- JARVIS v3.0 - Dual Monitor / Scaled Keyboard
local kbMon = peripheral.wrap("monitor_3")   -- Touchscreen keyboard
local dispMon = peripheral.wrap("monitor_5") -- AI response display

if not kbMon or not dispMon then 
    error("Monitors not found! Check monitor_3 and monitor_5.") 
end

-- Force Scale 1 for clarity
kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Neural link active."

-- Layout with Spacebar and Utility keys
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

function drawUI()
    -- --- KEYBOARD MONITOR (monitor_3) ---
    kbMon.clear()
    local kw, kh = kbMon.getSize()
    
    -- SHRINK LOGIC: Center the keyboard with 50% width and height padding
    local btnW = math.floor((kw / 10) * 0.6) -- 60% of original width
    local xOffset = math.floor(kw * 0.2)     -- 20% left padding
    local yOffset = math.floor(kh * 0.4)     -- 40% top padding

    kbMon.setCursorPos(xOffset, yOffset - 2)
    kbMon.setTextColor(colors.yellow)
    kbMon.write("TYPING: " .. currentInput .. "_")

    for r, row in ipairs(layout) do
        for c, key in ipairs(row) do
            local x = (c - 1) * btnW + xOffset
            local y = r + yOffset
            
            kbMon.setCursorPos(x, y)
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            kbMon.write("[" .. key .. "]")
        end
    end

    -- --- DISPLAY MONITOR (monitor_5) ---
    dispMon.clear()
    dispMon.setCursorPos(1,1)
    dispMon.setTextColor(colors.cyan)
    
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
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    if side == "monitor_3" then
        local kw, kh = kbMon.getSize()
        local btnW = math.floor((kw / 10) * 0.6)
        local xOffset = math.floor(kw * 0.2)
        local yOffset = math.floor(kh * 0.4)
        
        -- Inverse math to find the key from coordinates
        local cIdx = math.floor((x - xOffset) / btnW) + 1
        local rIdx = y - yOffset
        
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
