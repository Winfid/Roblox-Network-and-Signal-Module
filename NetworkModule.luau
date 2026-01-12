--!strict

--// SERVICES

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

--// VARIABLES

--Dependancies
local Signal = require(ReplicatedStorage.Modules.Signal)

--Constants
local REMOTE_NAME = 'NetworkRemote'
local UNRELIABLE_REMOTE_NAME = 'NetworkUnreliable'
local DEFAULT_REQUEST_TIMEOUT = 10

--State
local isServer = RunService:IsServer()
local handlers: {[string]: Signal.Signal} = {}
local remote: RemoteEvent
local unreliableRemote: UnreliableRemoteEvent

--// SETUP

if isServer then
	remote = Instance.new('RemoteEvent')
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage

	unreliableRemote = Instance.new('UnreliableRemoteEvent')
	unreliableRemote.Name = UNRELIABLE_REMOTE_NAME
	unreliableRemote.Parent = ReplicatedStorage
else
	remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 10) :: RemoteEvent
	unreliableRemote = ReplicatedStorage:WaitForChild(UNRELIABLE_REMOTE_NAME, 10) :: UnreliableRemoteEvent
end

--// PRIVATE FUNCTIONS

--Serialization
local function serialize(data: {any}): string
	local success, result = pcall(HttpService.JSONEncode, HttpService, data)
	if not success then
		error('[Network] Failed to serialize data: ' .. tostring(result), 2)
	end
	return result
end

local function deserialize(jsonString: string): any
	local success, result = pcall(HttpService.JSONDecode, HttpService, jsonString)
	if not success then
		error('[Network] Failed to deserialize data: ' .. tostring(result), 2)
	end
	return result
end

local function handleIncomingMessage(playerOrEventName: any, eventNameOrArgs: any, jsonString: any)
	local player: Player?
	local eventName: string
	local serializedData: string

	if isServer then
		player = playerOrEventName :: Player
		eventName = eventNameOrArgs :: string
		serializedData = jsonString
	else
		eventName = playerOrEventName :: string
		serializedData = eventNameOrArgs
	end

	if type(eventName) ~= 'string' then return end

	local signal = handlers[eventName]
	if not signal then return end
	
	local args = deserialize(serializedData)

	if isServer and player then
		signal:fire(player, table.unpack(args))
	else
		signal:fire(table.unpack(args))
	end
end

if isServer then
	remote.OnServerEvent:Connect(handleIncomingMessage)
	unreliableRemote.OnServerEvent:Connect(handleIncomingMessage)
else
	remote.OnClientEvent:Connect(handleIncomingMessage)
	unreliableRemote.OnClientEvent:Connect(handleIncomingMessage)
end

--// API

local Network = {}

function Network:get(eventName: string): Signal.Signal
	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end

	local signal = handlers[eventName]
	if not signal then
		signal = Signal.new()
		handlers[eventName] = signal
	end

	return signal
end

function Network:send(eventName: string, ...: any)
	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end
	
	local data = {...}
	data = serialize(data)

	if isServer then
		remote:FireAllClients(eventName, data)
	else
		remote:FireServer(eventName, data)
	end
end

function Network:sendTo(player: Player, eventName: string, ...: any)
	if not isServer then
		error('[Network] sendTo can only be called on the server', 2)
	end

	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end
	
	local data = {...}
	data = serialize(data)

	remote:FireClient(player, eventName, data)
end

function Network:sendUnreliable(eventName: string, ...: any)
	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end
	
	local data = {...}
	data = serialize(data)

	if isServer then
		unreliableRemote:FireAllClients(eventName, data)
	else
		unreliableRemote:FireServer(eventName, data)
	end
end

function Network:sendToUnreliable(player: Player, eventName: string, ...: any)
	if not isServer then
		error('[Network] sendToUnreliable can only be called on the server', 2)
	end

	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end
	
	local data = {...}
	data = serialize(data)

	unreliableRemote:FireClient(player, eventName, data)
end

function Network:request(eventName: string, timeoutSeconds: number?, ...: any): ...any
	if isServer then
		error('[Network] request can only be called on the client', 2)
	end

	if type(eventName) ~= 'string' then
		error('[Network] Event name must be a string', 2)
	end

	local timeout = timeoutSeconds or DEFAULT_REQUEST_TIMEOUT
	local requestId = HttpService:GenerateGUID(false)
	local responseSignal = Signal.new()
	local hasResponded = false

	local connection = self:get(requestId):once(function(...)
		hasResponded = true
		responseSignal:fire(...)
	end)

	self:send(eventName, requestId, ...)

	local startTime = os.clock()
	while not hasResponded and (os.clock() - startTime) < timeout do
		local success, result = pcall(function()
			return {responseSignal:wait()}
		end)

		if success and hasResponded then
			responseSignal:destroy()
			return table.unpack(result)
		end

		task.wait()
	end

	connection:disconnect()
	responseSignal:destroy()

	return nil
end

function Network:respond(player: Player, requestId: string, ...: any)
	if not isServer then
		error('[Network] respond can only be called on the server', 2)
	end

	if type(requestId) ~= 'string' then
		error('[Network] Request ID must be a string', 2)
	end

	self:sendTo(player, requestId, ...)
end

return Network