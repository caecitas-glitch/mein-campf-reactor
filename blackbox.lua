-- JARVIS: LOCAL AI BASE COMMANDER
local ollama_url = "http://127.0.0.1:11434/api/generate"
local monitor = peripheral.find("monitor") -- Optional: set up a big screen!

print("Connecting to Llama 3...")

function askAI(question)
    local payload = {
        model = "llama3",
        prompt = question,
        stream = false
    }
    
    local response = http.post(ollama_url, textutils.serialiseJSON(payload))
    
    if response then
        local data = textutils.unserialiseJSON(response.readAll())
        response.close()
        return data.response
    else
        return "Error: Cannot reach Ollama. Is OLLAMA_HOST set?"
    end
end

while true do
    term.setTextColor(colors.cyan)
    write("\nJarvis > ")
    local input = read()
    
    print("Processing...")
    local answer = askAI(input)
    
    term.setTextColor(colors.white)
    print("\n" .. answer)
    
    -- If you have a monitor, show it there too!
    if monitor then
        monitor.clear()
        monitor.setCursorPos(1,1)
        monitor.write(answer)
    end
end
