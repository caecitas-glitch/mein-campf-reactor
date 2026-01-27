-- THE BRAIN: Manages AI, Monitor, and Wireless PDA
rednet.open("right") -- SET THIS to the side with your Wireless Modem
local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
    monitor.setCursorPos(1,1)
    monitor.write("Jarvis Neural Link Online...")
end

-- This helper function wraps text so it doesn't break your monitor
function display(text)
    if not monitor then print(text) return end
    monitor.clear()
    monitor.setCursorPos(1,1)
    local w, h = monitor.getSize()
    local x, y = 1, 1
    for word in text:gmatch("%S+") do
        if x + #word > w then x = 1 y = y + 1 end
        if y <= h then
            monitor.setCursorPos(x, y)
            monitor.write(word .. " ")
            x = x + #word + 1
        end
    end
end

-- Your existing AI function (Ollama)
function askAI(question)
    local payload = { model = "llama3", prompt = question, stream = false }
    local response = http.post("http://127.0.0.1:11434/api/generate", textutils.serialiseJSON(payload))
    if response then
        local data = textutils.unserialiseJSON(response.readAll())
        response.close()
        return data.response
    end
    return "Error: Brain offline."
end

print("Brain Online. Waiting for PDA signal...")

while true do
    local id, message = rednet.receive()
    print("PDA #" .. id .. " sent: " .. message)
    
    local answer = askAI(message)
    display(answer) -- This sends it to the monitor!
end
