```lua
local Chatbot = Chatbot.new({
    APIKey = "sk-",
    Model = "gpt-3.5-turbo",
    MaxSetContext = 3, -- bad at naming
    MaxTokens = 80,
    BaseURL = "https://api.openai.com"
})

Chatbot.OnResponse:Connect(function(Response)
    warn("WAOW!!! -", Response)
end)

Chatbot:SetMainPrompt("you are the swaggeriest ai in the world")

Chatbot:DefineFunction({
    Name = "RespondWithEmotions",
    Description = "Call this function to describe how you feel",
    Callback = function(Data)
        warn(Data.Response, Data.Emotion)
    end,
    Arguments = {
        Response = {
            Required = false,
            Type = "string",
            Description = "Your textual response"
        },
        Emotion = {
            Required = true,
            Type = "string",
            Enum = {"rage", "joy", "sadness"},
            Description = "The type of emotion you're experiencing"
        }
    }
})


```
