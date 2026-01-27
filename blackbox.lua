-- Configuration
local kbMon = peripheral.wrap("monitor_3")   -- The 3x2 Keyboard
local dispMon = peripheral.wrap("monitor_5") -- The Brain Display

if not kbMon or not dispMon then 
    error("Monitors not found! Check monitor_3 and monitor_5.") 
end

-- Force Scale 1 for the best look on large monitors
kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Neural link active."

-- Keyboard Layout
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
    
    -- Draw Input Bar centered at top
    kbMon.setCursorPos(math.floor(kw/2 - 10), 2)
    kbMon.setTextColor(colors.yellow)
    kbMon.write("TYPING: " .. currentInput .. "_")

    -- Draw Keys Edge-to-Edge
    for r, row in ipairs(layout) do
        local numKeys = #row
        local btnWidth = math.floor(kw / numKeys) -- Divide total width by keys in THIS row
        local yPos = r + 4 -- Start drawing row 4 to leave room for input header

        for c, key in ipairs(row) do
            local xPos = (c - 1) * btnWidth + 1
            kbMon.setCursorPos(xPos, yPos)
            
            -- Draw Separator and Key
            kbMon.setTextColor(colors.gray)
            kbMon.write(".") 
            
            -- Color code
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            -- Center the key text within its giant button area
            local textOffset = math.floor((btnWidth - #key) / 2)
            kbMon.setCursorPos(xPos + textOffset, yPos)
            kbMon.write(key)
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

-- Same detection logic used for drawing
function getKeyAt(tx, ty)
    local kw, kh = kbMon.getSize()
    local yStart = 5 -- This must match the draw loop (yPos start)
    local rIdx = ty - 4
    
    if layout[rIdx] then
        local numKeys = #layout[rIdx]
        local btnWidth = math.floor(kw / numKeys)
        local cIdx = math.floor((tx - 1) / btnWidth) + 1
        return layout[rIdx][cIdx]
    end
    return nil
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
        local key = getKeyAt(x, y)
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
