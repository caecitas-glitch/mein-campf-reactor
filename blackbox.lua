local monitor = peripheral.find("monitor")
if not monitor then error("No monitor found!") end

-- 1. INCREASE SCALE (Set to 1 or 2 for giant buttons)
monitor.setTextScale(1) 
monitor.clear()

local w, h = monitor.getSize()
local currentInput = ""
local aiResponse = "Jarvis: Ready for input..."

-- Keyboard Layout (Added SPACE)
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENT", "CLR"} -- Big control buttons
}

function drawUI()
    monitor.clear()
    
    -- Draw Response Area (Top)
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.cyan)
    monitor.write(aiResponse:sub(1, w * 3))

    -- Draw Input Bar
    monitor.setCursorPos(1, h - 6)
    monitor.setTextColor(colors.yellow)
    monitor.write("> " .. currentInput .. "_")

    -- Draw Keyboard Grid
    monitor.setTextColor(colors.white)
    for r, row in ipairs(layout) do
        for c, key in ipairs(row) do
            -- Larger spacing: 4 characters per button
            local xPos = (c - 1) * 5 + 1
            local yPos = (h - 5) + r
            monitor.setCursorPos(xPos, yPos)
            monitor.write("[" .. key .. "]")
        end
    end
end

-- Your Ollama Connection
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
    
    -- Improved Touch Detection Logic
    local rowIdx = y - (h - 5)
    local colIdx = math.ceil(x / 5)
    
    if layout[rowIdx] and layout[rowIdx][colIdx] then
        local key = layout[rowIdx][colIdx]
        
        if key == "ENT" then
            aiResponse = "Thinking..."
            drawUI()
            aiResponse = askAI(currentInput)
            currentInput = ""
        elseif key == "BS" then
            currentInput = currentInput:sub(1, -2)
        elseif key == "SPACE" then
            currentInput = currentInput .. " "
        elseif key == "CLR" then
            currentInput = ""
        else
            currentInput = currentInput .. key
        end
    end
    drawUI()
end
