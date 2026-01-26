-- AEGIS: SIMPLE TABLET TEST
local VERSION = "16.0.0"

-- 1. SETUP (Using term.current to prevent the redirect error)
local device = term.current() --
local w, h = device.getSize()
local reactor = peripheral.find("fission_reactor_logic_adapter")

-- 2. THE SINGULARITY BOOT (Your Sketch)
local function playSingularity()
    device.setBackgroundColor(colors.black)
    device.clear()
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    
    -- Wave Condensation
    for r = 8, 1, -2 do
        device.clear()
        device.setTextColor(colors.white)
        for a = 0, 360, 20 do
            local x = math.floor(cx + math.cos(math.rad(a)) * (r * 2))
            local y = math.floor(cy + math.sin(math.rad(a)) * r)
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("o") end
        end
        sleep(0.1)
    end
    
    -- Blue Core Detonation
    device.clear()
    device.setTextColor(colors.blue)
    device.setCursorPos(cx, cy) device.write("@")
    sleep(0.15)
    for r = 1, 10 do
        for a = 0, 360, 30 do
            local x = math.floor(cx + math.cos(math.rad(a)) * r)
            local y = math.floor(cy + math.sin(math.rad(a)) * (r/2))
            if x > 0 and x <= w then device.setCursorPos(x, y) device.write("*") end
        end
        sleep(0.04)
    end
    device.clear() -- Wipe animation for a clean UI
end

-- 3. THE UI & INPUT
local function main()
    local burnRate = 0
    while true do
        device.setBackgroundColor(colors.black)
        device.clear()
        
        -- Header
        device.setCursorPos(1, 1)
        device.setBackgroundColor(colors.blue)
        device.clearLine()
        device.write(" AEGIS TEST | BURN: " .. burnRate)
        device.setBackgroundColor(colors.black)
        
        -- The Buttons
        device.setCursorPos(2, 5)
        device.setBackgroundColor(colors.gray) device.write(" [ -10 ] ")
        device.setCursorPos(15, 5)
        device.setBackgroundColor(colors.gray) device.write(" [ +10 ] ")
        
        device.setCursorPos(2, 8)
        device.setBackgroundColor(colors.red) device.setTextColor(colors.white)
        device.write(" [ STOP ] ")
        device.setBackgroundColor(colors.black)

        -- Input Listener
        local event, button, x, y = os.pullEvent("mouse_click")
        
        if y == 5 then
            if x >= 2 and x <= 9 then
                burnRate = math.max(0, burnRate - 10)
            elseif x >= 15 and x <= 22 then
                burnRate = burnRate + 10
            end
        elseif y == 8 and x >= 2 and x <= 10 then
            burnRate = 0
        end

        -- Sync with actual reactor if it exists
        if reactor then
            pcall(function() reactor.setBurnRate(burnRate) end) --
        end
    end
end

-- Start
playSingularity()
main()
