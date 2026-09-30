--!strict
--!native
--!optimize 2

type Stack = { string }
type Packed = { n: number, [number]: any }

const Stacks: { [thread]: Stack } = setmetatable({}, {__mode = "k"}) :: any

local Owner: thread? = nil
local Current: Stack = {}

const function Peek(Thread: thread): Stack?
	return if Thread == Owner then Current else Stacks[Thread]
end

const function Select(Thread: thread): Stack
	if Thread == Owner then return Current end

	const Found: Stack = Stacks[Thread] or {}
	Stacks[Thread] = Found

	Owner = Thread
	Current = Found

	return Found
end

const function Begin(Name: string): ()
	const Found: Stack = Select(coroutine.running())

	Found[#Found + 1] = Name
	debug.profilebegin(Name)
end

const function End(): ()
	const Found: Stack = Select(coroutine.running())
	const Count: number = #Found
	if Count == 0 then return end

	Found[Count] = nil
	debug.profileend()
end

const function Depth(): number
	const Found: Stack? = Peek(coroutine.running())

	return if Found then #Found else 0
end

const function Unwind(Level: number): ()
	const Found: Stack = Select(coroutine.running())

	for Index = #Found, Level + 1, -1 do
		Found[Index] = nil
		debug.profileend()
	end
end

const function Suspend(): Stack?
	const Thread: thread = coroutine.running()
	const Found: Stack? = Peek(Thread)
	if not Found or #Found == 0 then return nil end

	Stacks[Thread] = nil
	Owner = nil

	for _ = 1, #(Found :: Stack) do debug.profileend() end

	return Found
end

const function Resume(Held: Stack?): ()
	if not Held then return end

	const Thread: thread = coroutine.running()

	Stacks[Thread] = Held
	Owner = Thread
	Current = Held :: Stack

	for _, Name: string in (Held :: Stack) do debug.profilebegin(Name) end
end

const function Await<A..., R...>(Callback: (A...) -> R..., ...: A...): R...
	const Caller: thread = coroutine.running()

	local Results: Packed? = nil
	local Waiting: boolean = false

	task.spawn(function(...: A...)
		Results = table.pack(pcall(Callback, ...))
		if Waiting then task.spawn(Caller) end
	end, ...)

	if not Results then
		Waiting = true

		const Held: Stack? = Suspend()
		coroutine.yield()
		Resume(Held)
	end

	const Finished: Packed = Results :: Packed
	if not Finished[1] then error(Finished[2], 0) end

	return table.unpack(Finished, 2, Finished.n)
end

return {
	Enabled = false;
	Begin = Begin;
	End = End;
	Depth = Depth;
	Unwind = Unwind;
	Suspend = Suspend;
	Resume = Resume;
	Await = Await;
}
