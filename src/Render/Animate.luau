--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Effect = require("../Classes/Effect")
const Gradient = require("../Classes/Gradient")
const Culling = require("./Culling")
const Pixel = require("../Utility/Pixel")
const Lifetime = require("../Utility/Lifetime")

type Motion = Types.MotionData
type Updates = { Types.EffectUpdate | false }
type Offset = Types.EffectOffset

type Pace = {
	Scale: number;
	Due: number;
}

const FullRateHeight: number = Config.Animate.FULL_RATE_HEIGHT
const VisibleShift: number = Config.Animate.VISIBLE_SHIFT
const RatePerPixel: number = Config.Animate.RATE_PER_PIXEL
const LongestInterval: number = Config.Animate.LONGEST_INTERVAL
const PaceInterval: number = Config.Animate.PACE_INTERVAL
const PhaseSpread: number = Config.Animate.PHASE_SPREAD

const Frames: number = Gradient.Frames
const Loop: (Data: Types.Gradient, Frame: number) -> ColorSequence = Gradient.Loop
const Internal: { [Types.EffectUpdate]: Offset } = Effect.Internal
const CombineTransparency: (Developer: number, Extra: number) -> number = Styles.CombineTransparency

const Paces = Lifetime.Own("Animate.Paces", {} :: { [Types.Fields]: Pace })
const Broken = setmetatable({} :: { [Types.EffectUpdate]: boolean }, {__mode = "k"})

const Frame: Types.EffectFrame = {
	Time = 0;
	Seed = 0;
	Amplitude = 0;
	Frequency = 0;
	Name = "";
	Node = (nil :: any);
	Offset = nil;
	Rotation = nil;
	Color = nil;
	Transparency = nil;
	StrokeColor = nil;
	StrokeTransparency = nil;
}

const function Interval(Height: number): number
	if Height >= FullRateHeight then return 0 end
	if Height <= 0 then return math.huge end

	return math.min(1 / (RatePerPixel * Height), LongestInterval)
end

const function Pacing(State: Types.Fields, Clock: number): number
	local Pace: Pace? = Paces[State]

	if not Pace then
		Pace = {Scale = 1, Due = -math.huge}
		Paces[State] = Pace
	end

	const Current: Pace = Pace :: Pace
	if Clock < Current.Due then return Current.Scale end

	Current.Scale = Culling.Apparent(State)
	Current.Due = Clock + PaceInterval

	return Current.Scale
end

const function Track(Record: Types.Record): Motion
	const Created: Motion = {
		Style = nil;
		Size = -1;
		Decorated = -1;
		X = -math.huge;
		Y = -math.huge;
		Left = 0;
		Top = 0;
		Phase = (Record.X * PhaseSpread) % 1;
		Tick = -1;
		Rotation = 0;
		Tinted = false;
		Alpha = nil;
		StrokeColor = nil;
		StrokeAlpha = nil;
	}

	Record.Motion = Created

	return Created
end

const function Placed(Motion: Motion, Record: Types.Record): boolean
	return Motion.X == Record.X
		and Motion.Y == Record.Y
		and Motion.Style == Record.Style
		and Motion.Size == Record.Look.Size
		and Motion.Decorated == Record.Decoration.Version
end

const function Shade(Record: Types.Record, Clock: number, Scale: number): ()
	const Decor: Types.DecorData = Record.Decor
	const Data: Types.Gradient = (Record.Style :: Types.Style).Gradient :: Types.Gradient
	const Wait: number = Interval(Record.Height * Scale)
	const Moment: number = if Wait == 0 then Clock else math.floor(Clock / Wait) * Wait
	const Index: number = math.floor(((Moment * Data.Speed) % 1) * Frames)
	if Index == Decor.Frame then return end

	(Decor.Gradient :: UIGradient).Color = Loop(Data, Index)
	Decor.Frame = Index
end

const function Finite(Value: any): boolean
	return type(Value) == "number" and Value == Value and Value ~= math.huge and Value ~= -math.huge
end

const function Clear(): ()
	Frame.Offset = nil
	Frame.Rotation = nil
	Frame.Color = nil
	Frame.Transparency = nil
	Frame.StrokeColor = nil
	Frame.StrokeTransparency = nil
end

const function Fail(Update: Types.EffectUpdate, Problem: any): ()
	Clear()
	Broken[Update] = true
	task.spawn(error, Problem, 0)
end

const function Wrong(Name: string, Field: string, Value: any, Expected: string): string
	return `RichTextPlus effect "{Name}" set Frame.{Field} to {typeof(Value)}, expected {Expected}`
end

const function Run(Update: Types.EffectUpdate, Name: string): boolean
	const Ok: boolean, Result: any = pcall(Update, Frame)

	if not Ok then Fail(Update, Result); return false end
	if Result == nil then return true end

	Fail(Update, `RichTextPlus effect "{Name}" Update returned a value: effects write Frame fields (Frame.Offset, Frame.Color, ...) and return nothing`)

	return false
end

const function Living(Record: Types.Record): boolean
	const List: Updates? = Record.Updates; if not List then return false end

	for Index = 1, Record.Layers do
		const Update: Types.EffectUpdate | false = (List :: Updates)[Index]
		if Update and not Broken[Update] then return true end
	end

	return false
end

const function Settle(Record: Types.Record, Motion: Motion, Left: number, Top: number): ()
	if Left == Motion.Left and Top == Motion.Top and Placed(Motion, Record) then return end

	if Left ~= Record.Left or Top ~= Record.Top then
		Record.Instance.Position = Pixel.Offset(Left, Top)
		Record.Left = Left
		Record.Top = Top
	end

	Motion.Style = Record.Style
	Motion.Size = Record.Look.Size
	Motion.Decorated = Record.Decoration.Version
	Motion.X = Record.X
	Motion.Y = Record.Y
	Motion.Left = Left
	Motion.Top = Top
end

const function Shift(Record: Types.Record, Motion: Motion, Clock: number): boolean
	const List: Updates = Record.Updates :: Updates
	const Seed: number = Record.Seed
	local Layer: Types.EffectData? = (Record.Style :: Types.Style).Effect
	local X: number, Y: number = 0, 0

	for Index = 1, Record.Layers do
		const Current: Types.EffectData = Layer :: Types.EffectData
		const Update: Types.EffectUpdate | false = List[Index]
		Layer = Current.Parent

		if not Update then continue end

		const Across: number, Down: number = Internal[Update](Clock, Current, Seed)
		X += Across
		Y += Down
	end

	Settle(Record, Motion, Pixel.Truncate(Record.X + X), Pixel.Truncate(Record.Y + Y))

	return true
end

const function Move(State: Types.Fields, Record: Types.Record, Clock: number, Scale: number): boolean
	const Motion: Motion = Record.Motion or Track(Record)
	const Wait: number = Interval(Record.Height * Scale)

	if Record.Internal and Record.Reach * Scale < VisibleShift and Placed(Motion, Record) then return true end

	if Wait > 0 then
		const Tick: number = math.floor(Clock / Wait + Motion.Phase)
		if Tick == Motion.Tick and Placed(Motion, Record) then return true end

		Motion.Tick = Tick
	end

	const Single: Offset? = Record.Shift

	if Single then
		const Across: number, Down: number = (Single :: Offset)(Clock, (Record.Style :: Types.Style).Effect :: Types.EffectData, Record.Seed)
		const Left: number = Pixel.Truncate(Record.X + Across)
		const Top: number = Pixel.Truncate(Record.Y + Down)

		if Left ~= Motion.Left or Top ~= Motion.Top or not Placed(Motion, Record) then Settle(Record, Motion, Left, Top) end

		return true
	end

	if Record.Internal then return Shift(Record, Motion, Clock) end

	const Style: Types.Style = Record.Style :: Types.Style
	const List: Updates = Record.Updates :: Updates
	const Seed: number = Record.Seed

	local X: number, Y: number, Turn: number = 0, 0, 0
	local Tint: Color3? = nil
	local Alpha: number? = nil
	local Edge: Color3? = nil
	local EdgeAlpha: number? = nil
	local Alive: boolean = false
	local Layer: Types.EffectData? = Style.Effect

	for Index = 1, Record.Layers do
		const Current: Types.EffectData = Layer :: Types.EffectData
		const Update: Types.EffectUpdate | false = List[Index]
		Layer = Current.Parent

		if not Update or Broken[Update] then continue end

		const Fast: Offset? = Internal[Update]

		if Fast then
			const Across: number, Down: number = (Fast :: Offset)(Clock, Current, Seed)
			X += Across
			Y += Down
			Alive = true

			continue
		end

		Frame.Time = Clock
		Frame.Seed = Seed
		Frame.Amplitude = Current.Amplitude
		Frame.Frequency = Current.Frequency
		Frame.Name = Current.Name
		Frame.Node = Current.Node

		const Name: string = Current.Name
		if not Run(Update, Name) then continue end

		const Offset: any = Frame.Offset
		const Rotation: any = Frame.Rotation
		const Color: any = Frame.Color
		const Transparency: any = Frame.Transparency
		const StrokeColor: any = Frame.StrokeColor
		const StrokeTransparency: any = Frame.StrokeTransparency
		local Across: number, Down: number = 0, 0

		if Offset ~= nil then
			if typeof(Offset) ~= "Vector2" then Fail(Update, Wrong(Name, "Offset", Offset, "a finite Vector2")); continue end

			Across, Down = Offset.X, Offset.Y
			if not (Finite(Across) and Finite(Down)) then Fail(Update, Wrong(Name, "Offset", Offset, "a finite Vector2")); continue end

			Frame.Offset = nil
		end

		if Rotation ~= nil then
			if not Finite(Rotation) then Fail(Update, Wrong(Name, "Rotation", Rotation, "a finite number")); continue end

			Frame.Rotation = nil
		end

		if Color ~= nil then
			if typeof(Color) ~= "Color3" then Fail(Update, Wrong(Name, "Color", Color, "a Color3")); continue end

			Frame.Color = nil
		end

		if Transparency ~= nil then
			if not Finite(Transparency) then Fail(Update, Wrong(Name, "Transparency", Transparency, "a finite number")); continue end

			Frame.Transparency = nil
		end

		if StrokeColor ~= nil then
			if typeof(StrokeColor) ~= "Color3" then Fail(Update, Wrong(Name, "StrokeColor", StrokeColor, "a Color3")); continue end

			Frame.StrokeColor = nil
		end

		if StrokeTransparency ~= nil then
			if not Finite(StrokeTransparency) then Fail(Update, Wrong(Name, "StrokeTransparency", StrokeTransparency, "a finite number")); continue end

			Frame.StrokeTransparency = nil
		end

		Alive = true
		X += Across
		Y += Down
		if Rotation ~= nil then Turn += Rotation end
		if Tint == nil then Tint = Color end
		if Alpha == nil and Transparency ~= nil then Alpha = math.clamp(Transparency, 0, 1) end
		if Edge == nil then Edge = StrokeColor end
		if EdgeAlpha == nil and StrokeTransparency ~= nil then EdgeAlpha = math.clamp(StrokeTransparency, 0, 1) end
	end

	const Label: TextLabel = Record.Label :: TextLabel
	const Look: Types.LookData = Record.Look

	Settle(Record, Motion, Pixel.Truncate(Record.X + X), Pixel.Truncate(Record.Y + Y))

	if Turn ~= Motion.Rotation then Label.Rotation = Turn; Motion.Rotation = Turn end

	if Tint then
		if Look.Color ~= Tint then Label.TextColor3 = Tint; Look.Color = Tint end
		Motion.Tinted = true
	elseif Motion.Tinted then
		Motion.Tinted = false
		if Look.Color ~= Style.Color then Label.TextColor3 = Style.Color; Look.Color = Style.Color end
	end

	if Alpha ~= Motion.Alpha then
		Motion.Alpha = Alpha

		const Transparency: number = CombineTransparency(State.Developer.Transparency, Alpha or Style.Transparency)
		if Look.Transparency ~= Transparency then Label.TextTransparency = Transparency; Look.Transparency = Transparency end
	end

	const Stroke: UIStroke? = Record.Decor.Stroke
	const Data: Types.StrokeData? = Style.Stroke

	if Stroke and Data then
		if Edge ~= Motion.StrokeColor then Motion.StrokeColor = Edge; Stroke.Color = Edge or Data.Color end
		if EdgeAlpha ~= Motion.StrokeAlpha then Motion.StrokeAlpha = EdgeAlpha; Stroke.Transparency = CombineTransparency(State.Developer.Transparency, EdgeAlpha or Data.Transparency) end
	end

	return Alive
end

const function Drop(Moving: { Types.Record }): ()
	local Count: number = 0

	for _, Record: Types.Record in (Moving) do
		if not Living(Record) then continue end

		Count += 1
		Moving[Count] = Record
	end

	for Index = #Moving, Count + 1, -1 do Moving[Index] = nil end
end

const function Step(State: Types.Fields, Clock: number): ()
	if State.Developer.Transparency >= 1 then return end

	const Scale: number = Pacing(State, Clock)
	if Scale <= 0 then return end

	const Animation: Types.AnimationData = State.Animation

	for _, Record: Types.Record in (Animation.Animated) do
		if Record.Shown then Shade(Record, Clock, Scale) end
	end

	local Dropped: boolean = false

	for _, Record: Types.Record in (Animation.Moving) do
		if Record.Shown and not Move(State, Record, Clock, Scale) then Dropped = true end
	end

	if Dropped then Drop(Animation.Moving) end
end

return {
	Step = Step;
}
