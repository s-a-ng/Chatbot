local HTTPService = game:GetService("HttpService")

local Chatbot = {}
local function req(...)
	if game.RunService:IsServer() then 
		return HttpService:RequestAsync(...)
	end
	return request(...)
end



local function Merge(...)
	local New = {}
	for _, table in pairs({...}) do 
		for index, value in table do
			table.insert(New, value)
		end
	end
	return New
end

function Chatbot:AddUserMessage(Message)
	table.insert(self.ChatbotMemory, {role = "user", content = Message})
end

function Chatbot:AddSystemMessage(Message)
	table.insert(self.ChatbotMemory, {role = "system", content = Message})
end

function Chatbot:AddChatbotMessage(Message)
	table.insert(self.ChatbotMemory, {role = "assistant", content = Message})

	if #self.ChatbotMemory > self.MaxSetContext then
		table.remove(self.ChatbotMemory, 1)
		table.remove(self.ChatbotMemory, 1)
	end
end

------------------------------------------------------

local function FixInvalidJSON(JSON)
	if JSON:sub(#JSON, #JSON) ~= "}" then 
		return JSON .. "}"
	end
	return JSON 
end

function __HandleToolCalls(self, ToolCalls)
	for _, ToolCall in ToolCalls  do
		local Type = ToolCall.type
		if Type ~= "function" then 
			print("[Chatbot] - Unknown type of tool")
			continue	
		end

		local Function = ToolCall["function"]

		local FunctionName = Function["name"]

		print(Function)
		local Arguments = FixInvalidJSON(Function["arguments"]) -- Sometimes the model provides messed up JSON
		local FunctionArguments = HTTPService:JSONDecode(Arguments)

		self.FunctionNameToCallback[FunctionName](FunctionArguments)
	end
end

function Chatbot:GenerateCompletion()
	local Success, Result = pcall(function()
		return req({
			Url = self.BaseURL .. "/v1/chat/completions", 
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = `Bearer {self.APIKey}`
			},
			Body = HTTPService:JSONEncode({
				model = self.Model, 
				messages = Merge({{role = "system", content = self.MainPrompt}}, self.ChatbotMemory),
				tools = self.Tools,
				max_tokens = self.MaxTokens,
				temperature = 0.7
			}),
		})
	end)

	if not Success then 
		warn("Request to AI Provider failed", Result)
		return 
	end
	warn(Result.Body)
	Result = HTTPService:JSONDecode(Result.Body)

	warn(Result, type(Result))
	local Message = Result.choices[1].message
	local Content = Message.content

	if Content then 
		self:AddChatbotMessage(Content)
	end

	local ToolCalls = Message.tool_calls
	if ToolCalls then
		__HandleToolCalls(self, ToolCalls)
	end


	return Content or not ToolCalls and "..."
end


------------------------------------------------------
function Chatbot:Chat(Message)
	self:AddUserMessage(Message)

	local Completion = self:GenerateCompletion()
	if Completion then 
		self.OnResponseBindable:Fire(Completion)
	end
end

function Chatbot:ChatAsSystem(Message)
	self:AddSystemMessage(Message)

	local Completion = self:GenerateCompletion()
	if Completion then 
		self.OnResponseBindable:Fire(Completion)
	end
end

function Chatbot:ChatAsChatbot(Message)
	self:AddChatbotMessage(Message)

	local Completion = self:GenerateCompletion()
	if Completion then 
		self.OnResponseBindable:Fire(Completion)
	end
end
------------------------------------------------------

function Chatbot:DefineFunction(Function)
	local FunctionName = Function.Name
	local FunctionDescription = Function.Description


	local FunctionCallback = Function.Callback

	self.FunctionNameToCallback[FunctionName] = FunctionCallback

	local Arguments = Function.Arguments

	local RequiredArgs = {}


	local Properties = {

	}

	for ArgumentName, ArgumentData in Arguments do
		local DataType = ArgumentData.Type
		local Enums = ArgumentData.Enum
		local Description = ArgumentData.Description

		Properties[ArgumentName] = {
			enum = Enums,
			description = Description,
			["type"] = DataType
		}

		local Required = ArgumentData.Required
		if Required then
			table.insert(RequiredArgs, ArgumentName)
		end
	end

	local NewFunction = {
		name = FunctionName,
		description = FunctionDescription,
		parameters = {
			["type"] = "object",
			["properties"] = Properties
		},
		required = RequiredArgs
	}

	table.insert(self.Tools, {
		["type"] = "function",
		["function"] = NewFunction
	})
end

function Chatbot:WipeMemory()
	table.clear(self.ChatbotMemory)
end


------------------------------------------------------
function Chatbot:SetMainPrompt(Prompt)
	self.MainPrompt = Prompt
end



function Chatbot.new(Data)
	local self = setmetatable({}, {
		__index = Chatbot,
	})
	self.MaxSetContext = Data.MaxSetContext
	self.FunctionNameToCallback = {

	}
	self.Tools = {}

	self.ChatbotMemory = {}

	self.OnResponseBindable = Instance.new("BindableEvent")
	self.OnResponse = self.OnResponseBindable.Event

	self.APIKey = Data.APIKey
	self.BaseURL = Data.BaseURL
	self.Model = Data.Model
	self.MaxTokens = Data.MaxTokens 

	return self
end

return Chatbot
