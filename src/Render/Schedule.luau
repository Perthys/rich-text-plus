--!strict
--!native
--!optimize 2

const RunService = game:GetService("RunService")

const Config = require("../Config")
const Types = require("../Types")
const Profiler = require("../Utility/Profiler")
const Lifetime = require("../Utility/Lifetime")

type Runner = (State: Types.Fields, Stage: number) -> ()
type Merger = (Current: number, Incoming: number) -> number

type Entry = {
	State: Types.Fields;
	Stage: number;
	Tier: number;
	Slot: number;
	Frame: number;
	Gate: Instance?;
	Signal: string?;
}

type Watch = {
	Connection: RBXScriptConnection?;
	Waiting: { [Entry]: boolean };
	Count: number;
}

const Visible: number = 1
const Offscreen: number = 2
const Hidden: number = 3

const DefaultBudget: number = Config.Schedule.FRAME_BUDGET
const StarveFrames: number = Config.Schedule.STARVE_FRAMES
const CostWeight: number = Config.Schedule.COST_WEIGHT
const OutlierRatio: number = Config.Schedule.OUTLIER_RATIO
const CompactFloor: number = Config.Schedule.COMPACT_FLOOR
const AncestrySignal: string = "AncestryChanged"

const Entries = Lifetime.Track("Schedule.Entries", {} :: { [Types.Fields]: Entry })
const Parked = Lifetime.Own("Schedule.Parked", {} :: { [Types.Fields]: Entry })
const Queues: { { Entry } } = {{}, {}}
const Heads: { number } = {1, 1}
const Watches = Lifetime.Track("Schedule.Watches", {} :: { [Instance]: { [string]: Watch } })
const Costs: { [number]: number } = {}

local Run: Runner? = nil
local Merge: Merger? = nil
local Worker: thread? = nil
local Deferrer: thread? = nil
local Connection: RBXScriptConnection? = nil
local Budget: number = DefaultBudget
local Spent: number = 0
local Fresh: boolean = true
local Frame: number = 0
local Live: number = 0
local Deferred: boolean = false
local Lingering: boolean = false

const function Classify(State: Types.Fields): (number, Instance?, string?)
	if not State.Rendering.Culling then return Visible, nil, nil end

	local Current: Instance? = State.Label

	while Current do
		const Node: Instance = Current :: Instance

		if Node:IsA("LayerCollector") then
			if not (Node :: LayerCollector).Enabled then return Hidden, Node, "Enabled" end

			return if State.Cull.Culled then Offscreen else Visible, nil, nil
		end

		if Node:IsA("GuiObject") and not (Node :: GuiObject).Visible then return Hidden, Node, "Visible" end

		Current = Node.Parent
	end

	return Hidden, State.Label, AncestrySignal
end

const function Unwatch(Entry: Entry): ()
	const Gate: Instance? = Entry.Gate; if not Gate then return end
	const Signal: string = Entry.Signal :: string
	const Signals: { [string]: Watch }? = Watches[Gate :: Instance]
	const Found: Watch? = if Signals then (Signals :: { [string]: Watch })[Signal] else nil

	Entry.Gate = nil
	Entry.Signal = nil
	if not Found then return end

	const Active: Watch = Found :: Watch

	Active.Waiting[Entry] = nil
	Active.Count -= 1
	if Active.Count > 0 then return end

	(Signals :: { [string]: Watch })[Signal] = nil
	if next(Signals :: { [string]: Watch }) == nil then Watches[Gate :: Instance] = nil end

	const Linked: RBXScriptConnection? = Active.Connection
	if Linked then (Linked :: RBXScriptConnection):Disconnect() end
end

const function Leave(Entry: Entry): ()
	const Tier: number = Entry.Tier

	Entry.Tier = 0

	if Entry.Gate then Unwatch(Entry) end
	if not (Tier == Visible or Tier == Offscreen) then return end

	Live -= 1
	if Live > 0 then return end

	for Index: number, Queue: { Entry } in (Queues) do
		table.clear(Queue)
		Heads[Index] = 1
	end
end

const function Remove(Entry: Entry): ()
	const State: Types.Fields = Entry.State

	Leave(Entry)
	Entries[State] = nil

	if not State.Destroyed then Parked[State] = Entry end
end

const function Learn(Stage: number, Cost: number): ()
	const Previous: number? = Costs[Stage]
	if not Previous then Costs[Stage] = Cost; return end

	const Estimate: number = Previous :: number
	const Sample: number = math.min(Cost, math.max(Estimate * OutlierRatio, Budget))

	Costs[Stage] = Estimate + (Sample - Estimate) * CostWeight
end

const function Invoke(State: Types.Fields, Stage: number): ()
	const Acquired: thread? = Worker
	const Target: Runner = Run :: Runner

	Worker = nil
	Target(State, Stage)
	Worker = Acquired
end

const function Serve(): ()
	while true do Invoke(coroutine.yield()) end
end

const function Spawn(State: Types.Fields, Stage: number): ()
	if not Worker then
		const Created: thread = coroutine.create(Serve)
		coroutine.resume(Created)
		Worker = Created
	end

	task.spawn(Worker :: thread, State, Stage)
end

const function Execute(Entry: Entry): ()
	const State: Types.Fields = Entry.State
	const Stage: number = Entry.Stage
	if State.Destroyed then return end

	const Start: number = os.clock()
	Spawn(State, Stage)
	const Cost: number = os.clock() - Start

	Spent += Cost
	Fresh = false

	Learn(Stage, Cost)
end

const function Peek(Tier: number): Entry?
	const Queue: { Entry } = Queues[Tier]
	local Head: number = Heads[Tier]

	while Head <= #Queue do
		const Entry: Entry? = Queue[Head]

		if Entry and Entry.Tier == Tier and Entry.Slot == Head and Entries[Entry.State] == Entry then
			Heads[Tier] = Head

			return Entry
		end

		Head += 1
	end

	table.clear(Queue)
	Heads[Tier] = 1

	return nil
end

const function Pick(): Entry?
	const First: Entry? = Peek(Visible)
	const Second: Entry? = Peek(Offscreen)

	if not Second then return First end
	if not First or (Fresh and Frame - (Second :: Entry).Frame >= StarveFrames) then return Second end

	return First
end

const function Flush(): ()
	Deferred = false

	const Profiling: boolean = Profiler.Enabled and Live > 0
	if Profiling then Profiler.Begin("RTP:Schedule") end

	while Live > 0 do
		const Entry: Entry? = Pick(); if not Entry then break end
		if not Fresh and Spent + (Costs[(Entry :: Entry).Stage] or 0) > Budget then break end

		Remove(Entry :: Entry)
		Execute(Entry :: Entry)
	end

	if Profiling then Profiler.End() end
end

const function Step(): ()
	Frame += 1
	Spent = 0
	Fresh = true

	if Live > 0 then Flush(); return end
	if not Connection then return end

	(Connection :: RBXScriptConnection):Disconnect()
	Connection = nil
end

const function Pulse(): ()
	if Connection then return end

	Spent = 0
	Fresh = true
	Connection = RunService.Heartbeat:Connect(Step)
end

const function Linger(): ()
	while true do
		Lingering = false
		Flush()
		coroutine.yield()
	end
end

const function Arm(): ()
	if not Deferred then
		Deferred = true

		if not Lingering then
			if not Deferrer or coroutine.status(Deferrer :: thread) == "dead" then Deferrer = coroutine.create(Linger) end

			Lingering = true
			task.defer(Deferrer :: thread)
		end
	end

	Pulse()
end

const function Compact(Tier: number): ()
	const Queue: { Entry } = Queues[Tier]
	const Kept: { Entry } = {}

	for Index = Heads[Tier], #Queue do
		const Found: Entry? = Queue[Index]
		if not (Found and Found.Tier == Tier and Found.Slot == Index and Entries[Found.State] == Found) then continue end

		const Entry: Entry = Found :: Entry
		Entry.Slot = #Kept + 1
		Kept[Entry.Slot] = Entry
	end

	Queues[Tier] = Kept
	Heads[Tier] = 1
end

const function Enqueue(Entry: Entry, Tier: number): ()
	if #Queues[Tier] >= CompactFloor and #Queues[Tier] > Live * 2 then Compact(Tier) end

	const Queue: { Entry } = Queues[Tier]
	const Slot: number = #Queue + 1

	Queue[Slot] = Entry
	Entry.Tier = Tier
	Entry.Slot = Slot
	Live += 1

	Arm()
end

const function Front(Entry: Entry): ()
	const Slot: number = Heads[Visible] - 1

	Queues[Visible][Slot] = Entry
	Heads[Visible] = Slot
	Entry.Tier = Visible
	Entry.Slot = Slot
	Live += 1

	Arm()
end

const function Promote(Entry: Entry): ()
	Pulse()

	if not Fresh and Spent + (Costs[Entry.Stage] or 0) > Budget then Front(Entry); return end

	Entries[Entry.State] = nil
	Parked[Entry.State] = Entry
	Execute(Entry)
end

local Place: (Entry: Entry) -> ()

const function Observe(Entry: Entry, Target: Instance, Signal: string): ()
	const Signals: { [string]: Watch } = Watches[Target] or {}
	const Active: Watch = Signals[Signal] or {Connection = nil; Waiting = {}; Count = 0}

	Watches[Target] = Signals

	if not Active.Connection then
		Signals[Signal] = Active

		const Source: RBXScriptSignal = if Signal == AncestrySignal then Target.AncestryChanged else Target:GetPropertyChangedSignal(Signal)

		Active.Connection = Source:Connect(function()
			const Waiting: { Entry } = {}
			for Waiter: Entry in (Active.Waiting) do table.insert(Waiting, Waiter) end

			for _, Waiter: Entry in (Waiting) do
				if Entries[Waiter.State] == Waiter then Place(Waiter) end
			end
		end)
	end

	Entry.Gate = Target
	Entry.Signal = Signal
	Active.Waiting[Entry] = true
	Active.Count += 1
end

Place = function(Entry: Entry): ()
	const Tier: number, Gate: Instance?, Signal: string? = Classify(Entry.State)
	const Previous: number = Entry.Tier

	if Tier == Previous and Gate == Entry.Gate and Signal == Entry.Signal then return end

	Leave(Entry)

	if Tier == Visible and Previous > Visible then Promote(Entry); return end
	if Tier ~= Hidden then Enqueue(Entry, Tier); return end

	Entry.Tier = Hidden
	if Gate then Observe(Entry, Gate :: Instance, Signal :: string) end
end

const function Queue(State: Types.Fields, Stage: number): ()
	if State.Destroyed then return end

	const Existing: Entry? = Entries[State]

	if Existing then
		const Found: Entry = Existing :: Entry

		Found.Stage = (Merge :: Merger)(Found.Stage, Stage)
		Place(Found)

		return
	end

	const Reused = Parked[State]
	const Created: Entry = Reused or {State = State; Stage = Stage; Tier = 0; Slot = 0; Frame = Frame; Gate = nil; Signal = nil}

	if Reused then
		Parked[State] = nil
		Created.Stage = Stage
		Created.Tier = 0
		Created.Slot = 0
		Created.Frame = Frame
		Created.Gate = nil
		Created.Signal = nil
	end

	Entries[State] = Created
	Place(Created)
end

const function Raise(State: Types.Fields, Stage: number): ()
	const Existing: Entry? = Entries[State]
	if not Existing then Queue(State, Stage); return end

	const Found: Entry = Existing :: Entry
	Found.Stage = (Merge :: Merger)(Found.Stage, Stage)
end

const function Take(State: Types.Fields): number?
	const Existing: Entry? = Entries[State]; if not Existing then return nil end

	Remove(Existing :: Entry)

	return (Existing :: Entry).Stage
end

const function Pending(State: Types.Fields): number?
	const Existing: Entry? = Entries[State]

	return if Existing then (Existing :: Entry).Stage else nil
end

const function Touch(State: Types.Fields): ()
	const Existing: Entry? = Entries[State]
	if not Existing or (Existing :: Entry).Tier == Visible then return end

	Place(Existing :: Entry)
end

const function Drain(): ()
	const Ordered: { Entry } = {}
	for _, Entry: Entry in (Entries) do table.insert(Ordered, Entry) end

	table.sort(Ordered, function(Left: Entry, Right: Entry): boolean
		if Left.Tier ~= Right.Tier then return Left.Tier < Right.Tier end

		return Left.Frame < Right.Frame
	end)

	for _, Entry: Entry in (Ordered) do
		if Entries[Entry.State] ~= Entry then continue end

		Remove(Entry)
		if Entry.State.Destroyed then continue end

		const Ok: boolean, Problem: any = pcall(Run :: Runner, Entry.State, Entry.Stage)
		if not Ok then task.spawn(error, Problem, 0) end
	end
end

const function Size(): number
	return #Queues[Visible] + #Queues[Offscreen]
end

const function SetBudget(Milliseconds: number): ()
	if typeof(Milliseconds) ~= "number" or Milliseconds ~= Milliseconds or Milliseconds < 0 then
		error("RichTextPlus frame budget must be a non-negative number of milliseconds", 3)
	end

	Budget = Milliseconds / 1000
end

const function Bind(Runner: Runner, Merger: Merger): ()
	Run = Runner
	Merge = Merger
end

return {
	Bind = Bind;
	SetBudget = SetBudget;
	Queue = Queue;
	Raise = Raise;
	Take = Take;
	Pending = Pending;
	Touch = Touch;
	Step = Step;
	Drain = Drain;
	Size = Size;
}
