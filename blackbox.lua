local monitor = peripheral.find("monitor")
if not monitor then error("No monitor found! Check your wired connection.") end

monitor.setTextScale(0.5)
local w, h = monitor.getSize()
local currentInput = ""
local aiResponse = "Waiting for input..."

-- Define Keyboard Layout
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS", "ENT"}
}

function drawUI()
    monitor.clear()
    -- Draw AI Response Area (Top)
    monitor.setCursorPos(1,1)
    monitor.setTextColor(colors.cyan)
    monitor.write("Jarvis: " .. aiResponse:sub(1, w * 5)) -- Basic wrap/cut

    -- Draw Current Input Line
    monitor.setCursorPos(1, h - 5)
    monitor.setTextColor(colors.yellow)
    monitor.write("> " .. currentInput .. "_")

    -- Draw Keyboard
    monitor.setTextColor(colors.white)
    for rowIdx, row in ipairs(layout) do
        for colIdx, key in ipairs(row) do
            monitor.setCursorPos(colIdx * 3, h - 4 + rowIdx)
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
    return "Error: Local AI not reached."
end

-- Start
drawUI()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Check which key was hit (simplistic coordinate mapping)
    local row = y - (h - 4)
    local col = math.floor(x / 3)
    
    if layout[row] and layout[row][col] then
        local key = layout[row][col]
        if key == "ENT" then
            aiResponse = "Thinking..."
            drawUI()
            aiResponse = askAI(currentInput)
            currentInput = ""
        elseif key == "BS" then
            currentInput = currentInput:sub(1, -2)
        else
            currentInput = currentInput .. key
        end
    end
    drawUI()
end
