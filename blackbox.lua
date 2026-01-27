-- JARVIS v4.0 - Edge-to-Edge Keyboard Layout
local kbMon = peripheral.wrap("monitor_3")   -- Touchscreen keyboard
local dispMon = peripheral.wrap("monitor_5") -- AI response display

if not kbMon or not dispMon then 
    error("Check monitor connections! monitor_3 and monitor_5 required.") 
end

-- Set scale to 1 for a balanced look on a 3x2 monitor
kbMon.setTextScale(1)
dispMon.setTextScale(1)

local currentInput = ""
local aiResponse = "Jarvis: Ready for command."

-- Keyboard Layout
local layout = {
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
    {"Z", "X", "C", "V", "B", "N", "M", "BS"},
    {"SPACE", "ENTER", "CLEAR"}
}

function drawUI()
    -- --- KEYBOARD (monitor_3) ---
    kbMon.clear()
    local kw, kh = kbMon.getSize()
    
    -- Calculate width for 10 keys across the whole monitor
    local btnW = math.floor(kw / 10)
    local yStart = 4 -- Starts lower to leave room for the input line

    -- Draw Input Bar at the top of the keyboard monitor
    kbMon.setCursorPos(2, 2)
    kbMon.setTextColor(colors.yellow)
    kbMon.write("TYPING: " .. currentInput .. "_")

    for r, row in ipairs(layout) do
        -- For the last row (special keys), we space them differently
        local rowCount = #row
        local rowBtnW = math.floor(kw / rowCount)

        for c, key in ipairs(row) do
            local x = (c - 1) * rowBtnW + 1
            local y = r + yStart
            
            kbMon.setCursorPos(x, y)
            
            -- Styling with '.' as a separator for a mechanical look
            kbMon.setTextColor(colors.gray)
            kbMon.write(".") 
            
            if key == "ENTER" then kbMon.setTextColor(colors.green)
            elseif key == "CLEAR" or key == "BS" then kbMon.setTextColor(colors.red)
            else kbMon.setTextColor(colors.white) end
            
            kbMon.write(key)
        end
    end

    -- --- DISPLAY (monitor_5) ---
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
    return "Error: Local AI offline."
end

drawUI()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    if side == "monitor_3" then
        local kw, kh = kbMon.getSize()
        local yStart = 4
        local rIdx = y - yStart
        
        if layout[rIdx] then
            local rowCount = #layout[rIdx]
            local rowBtnW = math.floor(kw / rowCount)
            local cIdx = math.floor((x - 1) / rowBtnW) + 1
            
            local key = layout[rIdx][cIdx]
            
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
end
