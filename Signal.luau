--!strict

--// TYPES

export type Connection = {
	disconnect: (self: Connection) -> (),
	_connected: boolean
}

export type Signal = {
	connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	once: (self: Signal, callback: (...any) -> ()) -> Connection,
	fire: (self: Signal, ...any) -> (),
	wait: (self: Signal) -> ...any,
	disconnectAll: (self: Signal) -> (),
	destroy: (self: Signal) -> (),
	hasListeners: (self: Signal) -> boolean
}

type Callback = (...any) -> ()

type InternalSignal = {
	_connections: {Callback},
	_yieldingThreads: {thread}
}

--// API

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new(): Signal
	local self: InternalSignal = {
		_connections = {},
		_yieldingThreads = {}
	}
	return setmetatable(self, Signal) :: any
end

function Signal:connect(callback: Callback): Connection
	local selfInternal = self :: InternalSignal

	if type(callback) ~= 'function' then
		error('[Signal] Argument #1 must be a function', 2)
	end

	table.insert(self._connections, callback)

	local connection = setmetatable({
		_connected = true
	}, Connection) :: Connection

	function connection:disconnect()
		if not self._connected then return end
		self._connected = false

		local index = table.find(selfInternal._connections, callback)
		if index then
			table.remove(selfInternal._connections, index)
		end
	end

	return connection
end

function Signal:once(callback: Callback): Connection
	local connection: Connection?

	connection = self:connect(function(...)
		if connection then
			connection:disconnect()
			connection = nil
		end
		callback(...)
	end)

	return connection
end

function Signal:fire(...: any)
	local self = self :: InternalSignal

	for i = 1, #self._connections do
		task.spawn(self._connections[i], ...)
	end

	for i = 1, #self._yieldingThreads do
		task.spawn(self._yieldingThreads[i], ...)
	end

	table.clear(self._yieldingThreads)
end

function Signal:wait(): ...any
	local self = self :: InternalSignal
	local thread = coroutine.running()

	table.insert(self._yieldingThreads, thread)

	return coroutine.yield()
end

function Signal:disconnectAll()
	local self = self :: InternalSignal

	table.clear(self._connections)
	table.clear(self._yieldingThreads)
end

function Signal:destroy()
	self:disconnectAll()
end

function Signal:hasListeners(): boolean
	local self = self :: InternalSignal
	return #self._connections > 0
end

return Signal
