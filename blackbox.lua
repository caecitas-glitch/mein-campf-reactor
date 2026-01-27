local apiKey = "YOUR_OPENAI_API_KEY"
local url = "https://api.openai.com/v1/chat/completions"

print("AI Terminal Initialized. Ask me anything:")

while true do
    term.setTextColor(colors.yellow)
    write("> ")
    local input = read()
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. apiKey
    }
    
    local body = textutils.serialiseJSON({
        model = "gpt-3.5-turbo", -- or gpt-4
        messages = {{role = "user", content = input}}
    })

    print("Thinking...")
    local response = http.post(url, body, headers)
    
    if response then
        local data = textutils.unserialiseJSON(response.readAll())
        response.close()
        term.setTextColor(colors.white)
        print(data.choices[1].message.content)
    else
        print("Error: Could not reach the AI.")
    end
end
