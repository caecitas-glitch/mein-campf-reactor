-- AEGIS BLACKBOX v6.0
-- Remote Sentinel Data Logger

local CHANNEL = 15
local modem = peripheral.find("modem") or error("No Modem Found")
modem.open(CHANNEL)

term.clear()
term.setTextColor(colors.blue)
print("AEGIS SENTINEL: STANDING BY...")

while true do
    -- Fixes image_ca0895.png: Properly naming all variables
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == CHANNEL and type(message) == "table" then
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.blue)
        print("== [ AEGIS REMOTE SENTINEL ] ==")
        
        if message.scram then
            term.setTextColor(colors.red)
            print("\n!!! CRITICAL SCRAM !!!")
            print("REASON: " .. (message.alert or "UNKNOWN"))
        else
            term.setTextColor(colors.white)
            print("\nCORE TEMP: " .. (message.temp or 0) .. " C")
            print("GRID CAP:  " .. (message.batt or 0) .. " %")
            print("STEAM:     " .. (message.p or 0) .. " mB")
        end
        term.setCursorPos(1, 12)
        term.setTextColor(colors.gray)
        print("Last Sync: " .. (message.t or "N/A"))
    end
end