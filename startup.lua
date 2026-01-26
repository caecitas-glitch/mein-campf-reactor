-- === POCKET CLICKER EXAMPLE ===
-- This is a simple example of handling touch inputs on a Pocket Computer.

local count = 0
local w, h = term.getSize() -- Pocket computers usually have w=26, h=20

-- --- Helper Function to Draw Colored Boxes/Buttons ---
-- x, y: starting coordinates
-- width, height: size of the button
-- bgCol, textCol: colors
-- text: what to write inside
local function drawButton(x, y, width, height, bgCol, textCol, text)
    term.setBackgroundColor(bgCol)
    term.setTextColor(textCol)
    for i = 0, height - 1 do
        term.setCursorPos(x, y + i)
        -- Draw a solid line of the background color
        term.write(string.rep(" ", width))
    end
    -- Center the text inside the button box
    local textX = x + math.floor((width - #text) / 2)
    local textY = y + math.floor(height / 2)
    term.setCursorPos(textX, textY)
    term.write(text)
    -- Reset colors back to black/white standard
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- --- The Main Drawing Routine ---
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- 1. Header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    -- Center the title
    local title = "POCKET CLICKER"
    term.setCursorPos(math.floor((w-#title)/2) + 1, 1)
    term.write(title)
    term.setBackgroundColor(colors.black)

    -- 2. The Big Number Display
    local countStr = tostring(count)
    term.setTextColor(colors.yellow)
    -- Center the number roughly in the middle of the screen
    term.setCursorPos(math.floor((w-#countStr)/2) + 1, 7)
    -- Make it look "bold" by drawing it twice slightly offset (optional trick)
    term.write(countStr)
    term.setCursorPos(math.floor((w-#countStr)/2) + 2, 7)
    term.write(countStr)
    term.setTextColor(colors.white)


    -- 3. The Buttons (Defining their locations)
    -- We define these coordinates here so we can check them later in the main loop
    -- Button Layout: [ - ]   [ RESET ]   [ + ]
    
    -- Minus Button (Red): X=2, Y=12, Width=6, Height=3
    drawButton(2, 12, 6, 3, colors.red, colors.white, "-")

    -- Reset Button (Gray): X=10, Y=12, Width=8, Height=3
    drawButton(10, 12, 8, 3, colors.gray, colors.white, "RESET")

    -- Plus Button (Green): X=20, Y=12, Width=6, Height=3
    drawButton(20, 12, 6, 3, colors.green, colors.white, "+")
end

-- --- Main Program Loop ---
while true do
    -- Draw the screen with current count
    drawUI()

    -- Wait for input. Pocket Computers send "mouse_click" when tapped in hand.
    -- event: the type of event (e.g., "mouse_click")
    -- button: 1 for left click, 2 for right, etc.
    -- x, y: The coordinates on screen where you tapped.
    local event, button, x, y = os.pullEvent("mouse_click")

    -- Check if the click happened inside our button definition areas.
    -- We check if Y is between the top (12) and bottom (14) rows first.
    if y >= 12 and y <= 14 then
        -- Now check X coordinates for specific buttons
        
        -- Minus Button Area (X is between 2 and 7 inclusive)
        if x >= 2 and x <= 2 + 6 - 1 then
            count = count - 1
        
        -- Reset Button Area (X is between 10 and 17 inclusive)
        elseif x >= 10 and x <= 10 + 8 - 1 then
            count = 0
            
        -- Plus Button Area (X is between 20 and 25 inclusive)
        elseif x >= 20 and x <= 20 + 6 - 1 then
            count = count + 1
        end
    end
    -- The loop immediately repeats, redrawing the UI with the new count number.
end
