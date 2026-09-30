--!strict
--!native
--!optimize 2

const RunService = game:GetService("RunService")

const Types = require("../Types")
const Pool = require("./Pool")
const Elements = require("../Elements")
const Profiler = require("../Utility/Profiler")
const Lifetime = require("../Utility/Lifetime")

type Stepper = (Label: TextLabel, DeltaTime: number) -> boolean

const Active = Lifetime.Track("Registry.Active", {} :: { [TextLabel]: Types.Fields })
const Awake = Lifetime.Track("Registry.Awake", {} :: { [TextLabel]: boolean })
const Pending = Lifetime.Track("Registry.Pending", {} :: { [TextLabel]: boolean })

local Step: Stepper? = nil
local Connection: RBXScriptConnection? = nil
local Stepping: boolean = false

const function Get(Label: TextLabel): Types.Fields?
	return Active[Label]
end

const function Add(State: Types.Fields): ()
	Active[State.Label] = State
end

const function List(): { Types.Fields }
	const Listed: { Types.Fields } = {}
	for _, State: Types.Fields in (Active) do table.insert(Listed, State) end

	return Listed
end

const function Abandon(State: Types.Fields, Dying: boolean?): ()
	if State.Destroyed then return end
	State.Destroyed = true
	State.Generation.Refresh += 1

	if Active[State.Label] == State then
		Active[State.Label] = nil
		Awake[State.Label] = nil
		Pending[State.Label] = nil
	end

	State.Troves.Main:Clean()
	Elements.Destroy(State)
	Pool.Clear(State, Dying)

	table.clear(State.Instances.Order)
	table.clear(State.Animation.Animated)
	table.clear(State.Animation.Moving)

	Lifetime.Forget(State)
end

const function Frame(DeltaTime: number): ()
	const Stepper: Stepper = Step :: Stepper
	const Profiling: boolean = Profiler.Enabled
	const Depth: number = if Profiling then Profiler.Depth() + 1 else 0

	if Profiling then Profiler.Begin("RTP:Frame") end

	Stepping = true

	for Label: TextLabel in (Awake) do
		const Ok: boolean, Busy: boolean = pcall(Stepper, Label, DeltaTime)

		if not Ok then
			Awake[Label] = nil
			task.spawn(error, Busy, 0)

			if Profiling then Profiler.Unwind(Depth) end
		elseif not Busy then
			Awake[Label] = nil
		end
	end

	Stepping = false

	if Profiling then Profiler.Unwind(Depth - 1) end

	for Label: TextLabel in (Pending) do
		Pending[Label] = nil
		Awake[Label] = true
	end

	if next(Awake) == nil and Connection then
		(Connection :: RBXScriptConnection):Disconnect()
		Connection = nil
	end
end

const function Wake(State: Types.Fields): ()
	if State.Destroyed or not Step then return end

	if Stepping then Pending[State.Label] = true else Awake[State.Label] = true end
	if Connection then return end

	const Signal: RBXScriptSignal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat
	Connection = Signal:Connect(Frame)
end

const function Bind(Stepper: Stepper): ()
	Step = Stepper
end

return {
	Get = Get;
	Add = Add;
	List = List;
	Abandon = Abandon;
	Wake = Wake;
	Bind = Bind;
}
