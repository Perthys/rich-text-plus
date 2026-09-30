--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Registry = require("../Render/Registry")
const Culling = require("../Render/Culling")
const Animate = require("../Render/Animate")
const Schedule = require("../Render/Schedule")
const Profiler = require("../Utility/Profiler")
const Stage = require("./Stage")
const Pipeline = require("./Pipeline")
const Watch = require("./Watch")

type Fields = Types.Fields

const MAXIMUM_FRAME_DELTA: number = Config.Renderer.MAXIMUM_FRAME_DELTA

const Join = Stage.Join
const Refresh = Pipeline.Refresh
const Poll = Watch.Poll

const function Due(State: Fields): number?
	const Queued: number? = Schedule.Take(State)
	const Polled: number? = Poll(State)

	return if Polled then Join(Queued, Polled :: number) else Queued
end

const function Now(State: Fields, From: number): ()
	Refresh(State, Join(Due(State), From))
end

const function Consume(State: Fields, From: number): ()
	Refresh(State, Join(Schedule.Take(State), From))
end

const function Settle(State: Fields): ()
	const Pending: number? = Due(State)

	if Pending then Refresh(State, Pending :: number) end
end

const function Gather(): ()
	for _, State: Fields in (Registry.List()) do
		const Ok: boolean, From: any = pcall(Poll, State)

		if not Ok then task.spawn(error, From, 0) elseif From then Schedule.Queue(State, From :: number) end
	end
end

const function Drain(): ()
	if not Profiler.Enabled then Gather(); Schedule.Drain(); return end

	const Depth: number = Profiler.Depth()

	Profiler.Begin("RTP:Drain")
	Gather()
	Schedule.Drain()
	Profiler.Unwind(Depth)
end

const function Tick(State: Fields, DeltaTime: number): boolean
	if State.Destroyed or State.Native.Active then return false end

	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Cull") end

	const Shown: boolean = Culling.Step(State)
	const Animation: Types.AnimationData = State.Animation

	if Profiling then Profiler.End() end

	Schedule.Touch(State)

	if not (Shown and (#Animation.Animated > 0 or #Animation.Moving > 0)) then return State.Cull.Dirty end

	Animation.Clock += math.min(DeltaTime, MAXIMUM_FRAME_DELTA)

	if Profiling then Profiler.Begin("RTP:Animate") end
	Animate.Step(State, Animation.Clock)
	if Profiling then Profiler.End() end

	return true
end

Schedule.Bind(Refresh, Stage.Merge)

Registry.Bind(function(Label: TextLabel, DeltaTime: number): boolean
	const State: Fields? = Registry.Get(Label)

	return State ~= nil and Tick(State :: Fields, DeltaTime)
end)

return {
	Due = Due;
	Now = Now;
	Consume = Consume;
	Settle = Settle;
	Drain = Drain;
	Tick = Tick;
}
