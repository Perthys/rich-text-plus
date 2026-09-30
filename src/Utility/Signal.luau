--!strict
--!optimize 2

export type Connection = {
	Connected: boolean;
	Disconnect: (self: Connection) -> ();
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection;
	Once: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection;
	Wait: (self: Signal<T...>) -> T...;
	Fire: (self: Signal<T...>, T...) -> ();
	DisconnectAll: (self: Signal<T...>) -> ();
	Destroy: (self: Signal<T...>) -> ();
}

type Handler = {
	Connected: boolean;
	Callback: (...any) -> ();
	Owner: State;
	Once: boolean;
	Spent: boolean;
}

type State = {
	Handlers: { Handler };
	Destroyed: boolean;
}

--[=[
	A handler connected to a [Signal].

	@class Connection
]=]
--[=[
	Whether the handler is still connected.

	@within Connection
	@prop Connected boolean
	@readonly
]=]
--[=[
	A signal. Handlers run deferred, after the code that fired it.

	@class Signal
]=]
const ConnectionClass = {}; ConnectionClass.__index = ConnectionClass
const SignalClass = {}; SignalClass.__index = SignalClass

const function Detach(Entry: Handler): ()
	if not Entry.Connected then return end
	Entry.Connected = false

	const Handlers: { Handler } = Entry.Owner.Handlers
	const Index: number? = table.find(Handlers, Entry)
	if Index then table.remove(Handlers, Index :: number) end
end

const function Invoke(Entry: Handler, ...: any): ()
	if not Entry.Connected then return end
	if Entry.Once then Detach(Entry) end

	Entry.Callback(...)
end

const function Attach(Owner: State, Callback: (...any) -> (), Once: boolean): Connection
	if type(Callback) ~= "function" then error("Signal handlers must be functions", 3) end

	const Entry: Handler = {Connected = not Owner.Destroyed, Callback = Callback, Owner = Owner, Once = Once, Spent = false}
	if Entry.Connected then table.insert(Owner.Handlers, Entry) end

	return setmetatable(Entry, ConnectionClass) :: any
end

--[=[
	Disconnects the handler. Safe to call more than once.

	@within Connection
	@method Disconnect
]=]
function ConnectionClass.Disconnect(self: any): ()
	Detach(self :: Handler)
end

--[=[
	Connects a handler.

	@within Signal
	@method Connect
	@param Callback (T...) -> ()
	@return Connection
]=]
function SignalClass.Connect(self: any, Callback: (...any) -> ()): Connection
	return Attach(self :: State, Callback, false)
end

--[=[
	Connects a handler that disconnects after its first call.

	@within Signal
	@method Once
	@param Callback (T...) -> ()
	@return Connection
]=]
function SignalClass.Once(self: any, Callback: (...any) -> ()): Connection
	return Attach(self :: State, Callback, true)
end

--[=[
	Yields until the next fire and returns its arguments.

	@within Signal
	@method Wait
	@yields
	@return T...
]=]
function SignalClass.Wait(self: any): ...any
	const Thread: thread = coroutine.running()

	Attach(self :: State, function(...: any)
		task.spawn(Thread, ...)
	end, true)

	return coroutine.yield()
end

--[=[
	Calls every connected handler with the arguments. Renderer signals are fired by the library.

	@within Signal
	@method Fire
	@param ... T...
]=]
function SignalClass.Fire(self: any, ...: any): ()
	const Owner: State = self :: State
	if Owner.Destroyed then return end

	for _, Entry: Handler in (Owner.Handlers) do
		if Entry.Spent then continue end
		if Entry.Once then Entry.Spent = true end

		task.defer(Invoke, Entry, ...)
	end
end

--[=[
	Disconnects every handler.

	@within Signal
	@method DisconnectAll
]=]
function SignalClass.DisconnectAll(self: any): ()
	const Handlers: { Handler } = (self :: State).Handlers

	for _, Entry: Handler in (Handlers) do Entry.Connected = false end
	table.clear(Handlers)
end

--[=[
	Disconnects every handler and ignores later connects and fires.

	@within Signal
	@method Destroy
]=]
function SignalClass.Destroy(self: any): ()
	const Owner: State = self :: State

	Owner.Destroyed = true
	SignalClass.DisconnectAll(Owner)
end

const function New<T...>(): Signal<T...>
	return setmetatable({Handlers = {}, Destroyed = false} :: State, SignalClass) :: any
end

return {
	new = New;
}
