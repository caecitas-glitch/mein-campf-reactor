local monitor = peripheral.find("monitor")
if not monitor then error("No monitor found!") end

-- 1. SET THE SCALE (1 is standard, 0.5 is tiny. Try 1 first!)
monitor.setTextScale(1)
monitor.clear()

local w, h = monitor.getSize()
local currentInput = ""
local aiResponse = "Jarvis: Ready for input..."

-- Keyboard Layout with Spacebar and Utilities
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"} 
}

function drawUI()
    monitor.clear()
    
    -- Draw AI Response Area (Top)
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.cyan)
    -- We wrap the text roughly so it stays in the top 60% of the screen
    print(aiResponse) 

    -- Draw Input Bar (Just above the keyboard)
    monitor.setCursorPos(2, h - 6)
    monitor.setTextColor(colors.yellow)
    monitor.write("CMD> " .. currentInput .. "_")

    -- Draw Keyboard Grid
    for r, row in ipairs(layout) do
        for c, key in ipairs(row) do
            -- Button spacing: 5 characters wide per key
            local xPos = (c - 1) * 5 + 2
            local yPos = (h - 5) + r
            monitor.setCursorPos(xPos, yPos)
            
            -- Color code the special keys
            if key == "ENTER" then monitor.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then monitor.setTextColor(colors.red)
            else monitor.setTextColor(colors.white) end
            
            monitor.write("[" .. key .. "]")
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
    return "Error: Local AI offline."
end

drawUI()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Simplified Touch Detection
    local rowIdx = y - (h - 5)
    local colIdx = math.ceil((x - 1) / 5)
    
    if layout[rowIdx] and layout[rowIdx][colIdx] then
        local key = layout[rowIdx][colIdx]
        
        if key == "ENTER" then
            aiResponse = "Thinking..."
            drawUI()
            aiResponse = askAI(currentInput)
            currentInput = ""
        elseif key == "BS" then
            currentInput = currentInput:sub(1, -2)
        elseif key == "SPACE" then
            currentInput = currentInput .. " "
        elseif key == "CLEAR" then
            currentInput = ""
        else
            currentInput = currentInput .. key
        end
    end
    drawUI()
end
