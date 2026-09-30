--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Registry = require("../Render/Registry")
const Styles = require("../Utility/Styles")
const Measure = require("../Text/Measure")
const Lines = require("./Lines")
const Scale = require("./Scale")
const Segment = require("../Render/Segment")
const Pool = require("../Render/Pool")
const Backdrop = require("../Render/Backdrop")
const Reveal = require("../Render/Reveal")
const Elements = require("../Elements")
const Reflow = require("../Utility/Reflow")
const Shape = require("./Shape")
const Profiler = require("../Utility/Profiler")

type Shape = Types.Shape

const Counters = {
	Skips = 0;
	Hits = 0;
	Resumes = 0;
	Builds = 0;
}

const Placed: { [GuiObject]: boolean } = {}

const function Hide(State: Types.Fields, Runs: { Types.Run }): ()
	for _, Run: Types.Run in (Runs) do
		const Object: GuiObject? = Run.Object
		if Object then Placed[Object :: GuiObject] = true end
	end

	for Object: GuiObject, Record: Types.Record in (State.Instances.Records) do
		if Record.Label or not Record.Shown or Placed[Object] then continue end

		Record.Shown = false
		Object.Visible = false
	end

	table.clear(Placed)
end

const function Reset(State: Types.Fields): ()
	const Cull: Types.CullData = State.Cull
	const Bounds: Types.BoundsData = Cull.Bounds

	table.clear(State.Instances.Order)
	table.clear(State.Animation.Animated)
	table.clear(State.Animation.Moving)

	Elements.ClearRecords(State.Elements)

	Cull.Padding = 0
	Bounds.MinX = 0
	Bounds.MinY = 0
	Bounds.MaxX = 0
	Bounds.MaxY = 0
end

const function Track(Cull: Types.CullData, Bounds: Types.BoundsData, Record: Types.Record): ()
	const X: number = Record.X
	const Y: number = Record.Y
	const Reach: number = Record.Reach

	if Reach > Cull.Padding then Cull.Padding = Reach end
	if X < Bounds.MinX then Bounds.MinX = X end
	if Y < Bounds.MinY then Bounds.MinY = Y end
	if X + Record.Width > Bounds.MaxX then Bounds.MaxX = X + Record.Width end
	if Y + Record.Height > Bounds.MaxY then Bounds.MaxY = Y + Record.Height end
end

const function Commit(State: Types.Fields, Runs: { Types.Run }, Coverage: Types.Coverage, Profiling: boolean): ()
	if Profiling then Profiler.Begin("RTP:Pool") end
	Hide(State, Runs)
	const Assigned: { Types.Record? } = Pool.Assign(State, Runs)
	if Profiling then Profiler.End() end

	if Profiling then Profiler.Begin("RTP:Apply") end
	Reset(State)

	if #Coverage.Pieces > 0 then Pool.Root(State) end

	const Order: { Types.Record } = State.Instances.Order
	const Cull: Types.CullData = State.Cull
	const Bounds: Types.BoundsData = Cull.Bounds

	for Index: number, Current: Types.Run in (Runs) do
		const Record: Types.Record? = Assigned[Index]
		if not Record then table.insert(Order, Segment.Place(State, Current)); continue end

		Segment.Apply(State, Record :: Types.Record, Current)
		table.insert(Order, Record :: Types.Record)
		Track(Cull, Bounds, Record :: Types.Record)
	end

	if Profiling then Profiler.End() end

	if Profiling then Profiler.Begin("RTP:Backdrop") end
	Backdrop.Assign(State, Coverage)
	if Profiling then Profiler.End() end

	if Profiling then Profiler.Begin("RTP:Reveal") end
	Reveal.Apply(State)
	if Profiling then Profiler.End() end

	const Animation: Types.AnimationData = State.Animation

	Cull.Dirty = State.Rendering.Culling

	if Cull.Dirty or #Animation.Animated > 0 or #Animation.Moving > 0 then Registry.Wake(State) end
end

const function Stale(State: Types.Fields, Generation: number, Ticket: number): boolean
	return State.Generation.Refresh ~= Generation or State.Generation.Layout ~= Ticket or State.Destroyed
end

const function Build(State: Types.Fields, Memory: Types.Memory, MaxWidth: number, Minimum: number, Generation: number, Ticket: number, Profiling: boolean): Shape?
	const Original: { Types.Token } = State.Document.Tokens
	const Factor: number = State.Scale.Measured
	const Blocked: boolean = Memory.Unblocked ~= Original

	if Blocked and not Reflow.Fit(State, MaxWidth, Factor) then return nil end

	if Profiling then Profiler.Begin("RTP:Split") end
	const Working: { Types.Token }? = if Memory.Settings.Scaled then Original else Measure.Split(State, MaxWidth)
	if Profiling then Profiler.End() end

	if not Working or Stale(State, Generation, Ticket) then return nil end

	const Chopped: boolean = Working ~= Original

	if Blocked then Reflow.Commit(State, MaxWidth, Factor) end

	State.Document.Tokens = Working :: { Types.Token }
	const Computed: { Types.Line }, Heights: { number }, Total: number, Widest: number = Lines.Compute(State, MaxWidth, 1, not Chopped, Memory.Settings.Spacing, Minimum)
	State.Document.Tokens = Original

	Counters.Builds += 1

	if Profiling then Profiler.Begin("RTP:Collect") end
	const Created: Shape = Shape.Create(State, Memory, Computed, Heights, Total, Widest, MaxWidth, Minimum, Chopped)
	if Profiling then Profiler.End() end

	Memory.Unblocked = if Shape.Blocked(Created) then nil else Original

	return Created
end

const function Resume(State: Types.Fields, Memory: Types.Memory, MaxWidth: number, Minimum: number, Profiling: boolean): Shape?
	if not Lines.Resumable(State) then return nil end

	const _Computed: { Types.Line }, _Heights: { number }, _Total: number, _Widest: number, Serial: number = Lines.Current(State)
	const Base: Shape? = Shape.Base(State, Memory, Serial)
	if not Base then return nil end

	Shape.Restore(Base :: Shape)

	const Region: Types.Region? = Lines.Resume(State, MaxWidth, Memory.Settings.Spacing, Minimum)
	if not Region then return nil end

	const Computed: { Types.Line }, Heights: { number }, Total: number, Widest: number = Lines.Current(State)
	const _Need: number, _Limit: number, Longest: number = Lines.Bounds(State)

	if not Memory.Settings.Scaled and Longest > MaxWidth then return nil end
	if MaxWidth == math.huge and Shape.Blocked(Base :: Shape) and Widest ~= (Base :: Shape).Metrics.Widest then return nil end

	if Profiling then Profiler.Begin("RTP:Collect") end
	Shape.Splice(State, Memory, Base :: Shape, Region :: Types.Region, Computed, Heights, Total, Widest, MaxWidth, Minimum)
	Shape.Prune(Memory, State, Base)
	if Profiling then Profiler.End() end

	Counters.Resumes += 1

	return Base
end

const function Arrange(State: Types.Fields, Profiling: boolean): ()
	const Label: TextLabel = State.Label
	const Ratio: number = Styles.AncestorScale(Label)
	const Size: Vector2 = Styles.LocalSize(Label, Ratio)
	const Scaled: boolean = Label.TextScaled
	const Owned: Enum.AutomaticSize? = if Scaled then nil else State.Developer.AutomaticSize
	const AutomaticSize: Enum.AutomaticSize = Owned or Label.AutomaticSize
	const AutomaticX: boolean = AutomaticSize == Enum.AutomaticSize.X or AutomaticSize == Enum.AutomaticSize.XY
	const AutomaticY: boolean = AutomaticSize == Enum.AutomaticSize.Y or AutomaticSize == Enum.AutomaticSize.XY
	const Content: Vector2 = Styles.ContentSize(Label, Ratio)
	const MaxWidth: number = if (not Label.TextWrapped) or AutomaticX then math.huge else math.max(Content.X, Styles.MinimumBoxWidth)

	State.Scale.Ancestor = Ratio
	State.Host.Width = Size.X
	State.Host.Height = Size.Y

	if State.Decoration.Dirty then Segment.Collect(State) end

	const Generation: number = State.Generation.Refresh
	const Factor: number = State.Scale.Measured
	const Ticket: number = State.Generation.Layout + 1
	const Memory: Types.Memory = Shape.Obtain(State)
	const Minimum: number = Measure.Scaled(Styles.BaseSize(State), Factor)

	State.Generation.Layout = Ticket

	Shape.Read(State, Memory, Scaled)

	local Found: Shape? = Shape.Find(State, Memory, MaxWidth, Minimum)

	if Found then
		Counters.Hits += 1
	else
		Found = Resume(State, Memory, MaxWidth, Minimum, Profiling) or Build(State, Memory, MaxWidth, Minimum, Generation, Ticket, Profiling)
		if not Found or Stale(State, Generation, Ticket) then return end
	end

	local Box: Vector2 = Content
	local Free: boolean = AutomaticY

	if Owned then
		Box = Scale.Fit(State, AutomaticX, AutomaticY, (Found :: Shape).Metrics.Extent, (Found :: Shape).Metrics.Total, Content)
		Free = false
	end

	if Shape.Current(State, Memory, Found :: Shape, MaxWidth, Box, Free) then Counters.Skips += 1; return end

	if Profiling then Profiler.Begin("RTP:Place") end
	local Runs: { Types.Run }?, Coverage: Types.Coverage? = Shape.Finalize(State, Memory, Found :: Shape, MaxWidth, Box, Free)
	if Profiling then Profiler.End() end

	if not Runs then
		Shape.Drop(Memory, Found :: Shape)

		Found = Build(State, Memory, MaxWidth, Minimum, Generation, Ticket, Profiling)
		if not Found or Stale(State, Generation, Ticket) then return end

		Runs, Coverage = Shape.Finalize(State, Memory, Found :: Shape, MaxWidth, Box, Free)
		if not Runs then return end
	end

	if Stale(State, Generation, Ticket) then return end

	Shape.Apply(Found :: Shape, MaxWidth, Factor)
	Commit(State, Runs :: { Types.Run }, Coverage :: Types.Coverage, Profiling)
	Shape.Remember(State, Memory, Found :: Shape, MaxWidth, Box, Free)
end

const function Run(State: Types.Fields): ()
	if State.Destroyed then return end
	if not Profiler.Enabled then Arrange(State, false); return end

	Profiler.Begin("RTP:Layout")
	Arrange(State, true)
	Profiler.End()
end

return {
	Run = Run;
	Counters = Counters;
}
