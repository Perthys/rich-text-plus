--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Measure = require("../../Text/Measure")
const Unicode = require("../../Text/Unicode")
const Backdrop = require("../../Render/Backdrop")
const Lines = require("../Lines")
const Build = require("./Build")

type Run = Types.Run
type Shape = Types.Shape
type Memory = Types.Memory
type Token = Types.Token
type Line = Types.Line


const Block: number = 1
const Facing: number = 2
const Leveled: number = 4

const Ellipsis: string = Config.Shape.ELLIPSIS
const OverflowTolerance: number = Config.Shape.OVERFLOW_TOLERANCE

const Tail: Shape = Build.Tail
const Begin = Build.Begin
const Reset = Build.Reset
const Gather = Build.Gather

const function Align(Alignment: Enum.TextXAlignment, BoxWidth: number, Width: number): number
	if Alignment == Enum.TextXAlignment.Center then return math.floor((BoxWidth - Width) / 2 + 0.5) end
	if Alignment == Enum.TextXAlignment.Right then return BoxWidth - Width end

	return 0
end

const function Start(Alignment: Enum.TextYAlignment, AutomaticY: boolean, TotalHeight: number, BoxHeight: number): number
	if AutomaticY then return 0 end

	if Alignment == Enum.TextYAlignment.Center then return math.floor((BoxHeight - TotalHeight) / 2 + 0.5) end
	if Alignment == Enum.TextYAlignment.Bottom then return math.max(BoxHeight - TotalHeight, 0) end

	return 0
end

const function Span(Style: Types.Style, Size: number, Text: string): number
	return Measure.WidthOf(Style, Size, Text).X
end

const function Chop(Token: Token, Style: Types.Style, Size: number, Limit: number): Token?
	const Text: string = Token.Text :: string
	const Starts: { number } = Unicode.Starts(Text)

	local Low: number = 0
	local High: number = #Starts - 1
	local Width: number = 0

	while Low < High do
		const Middle: number = (Low + High + 1) // 2
		const Measured: number = Span(Style, Size, string.sub(Text, 1, Starts[Middle + 1] - 1))

		if Measured <= Limit then Low = Middle; Width = Measured else High = Middle - 1 end
	end

	if Low == 0 then return nil end

	return {Kind = "Word", Text = string.sub(Text, 1, Starts[Low + 1] - 1), Style = Style, Width = Width, Height = Token.Height, SpaceBefore = Token.SpaceBefore, X = Token.X}
end

const function Truncate(Items: { Token }, Limit: number, Factor: number, Split: boolean): ({ Token }, number)
	const Kept: { Token } = {}
	const Widths: { [Types.Style]: number } = {}

	local Right: number = 0
	local Last: Types.Style? = nil

	const function Reserve(Style: Types.Style): number
		const Known: number? = Widths[Style]; if Known then return Known end

		const Measured: number = Span(Style, Measure.Scaled(Style.Size, Factor), Ellipsis)
		Widths[Style] = Measured

		return Measured
	end

	for _, Token: Token in (Items) do
		const Style: Types.Style? = Token.Style or Last
		const Room: number = if Style then Reserve(Style :: Types.Style) else 0

		if Token.X + Token.Width + Room <= Limit then
			table.insert(Kept, Token)
			Right = Token.X + Token.Width
			Last = Style

			continue
		end

		const Own: Types.Style? = Token.Style

		if Own and Token.Text and (Split or #Kept == 0) then
			const Size: number = Measure.Scaled((Own :: Types.Style).Size, Factor)
			const Piece: Token? = Chop(Token, Own :: Types.Style, Size, Limit - Token.X - Room)

			if Piece then
				table.insert(Kept, Piece :: Token)
				Right = Token.X + (Piece :: Token).Width
				Last = Own
			end
		end

		break
	end

	if not Last then return Kept, Right end

	const Style: Types.Style = Last :: Types.Style
	const Width: number = Reserve(Style)

	table.insert(Kept, {Kind = "Word", Text = Ellipsis, Style = Style, Width = Width, Height = 0, SpaceBefore = false, X = Right})

	return Kept, Right + Width
end

const function Direction(Alignment: Enum.TextXAlignment, Mode: number): Enum.TextXAlignment
	if bit32.btest(Mode, Facing) and Alignment == Enum.TextXAlignment.Left then return Enum.TextXAlignment.Right end

	return Alignment
end

const function Place(Shape: Shape, Output: { Run }, Count: number, Coverage: Types.Coverage, From: number, To: number, Shift: number, Y: number): number
	const Columns: Types.RunColumns = Shape.Runs
	const Runs: { Run } = Columns.Items
	const Offsets: { number } = Columns.Offsets
	const Rises: { number } = Columns.Rises
	const Pads: { number } = Columns.Pads

	local Placed: number = Count

	for Index = From, To do
		const Current: Run = Runs[Index]
		const Pad: number = Pads[Index]

		Current.X = Shift + Offsets[Index]
		Current.Y = Y + Rises[Index]

		if Pad >= 0 then Backdrop.Cover(Coverage, Current.Style :: Types.Style, Current.X, Current.Width, Pad) end

		Placed += 1
		Output[Placed] = Current
	end

	return Placed
end

const function Shorten(State: Types.Fields, Shape: Shape, Index: number, BoxWidth: number, Truncation: Enum.TextTruncate): number?
	const Computed: { Line }, _Heights: { number }, _Total: number, _Widest: number, Serial: number = Lines.Current(State)
	if Serial ~= Shape.Key.Serial then return nil end

	const Line: Line = Computed[Index]
	const Items: { Token }, Width: number = Truncate(Line.Items, BoxWidth, State.Scale.Measured, Truncation == Enum.TextTruncate.SplitWord)

	Reset(Tail)
	Begin(State.Scale.Measured)
	Gather(Tail, Items, Line.Leads, Shape.Rows.Heights[Index])

	return Width
end

const function Finalize(State: Types.Fields, Memory: Memory, Shape: Shape, MaxWidth: number, Box: Vector2, Free: boolean): (({ Run })?, Types.Coverage?)
	const Settings: Types.SettingData = Memory.Settings
	const Rows: Types.RowColumns = Shape.Rows
	const Alignment: Enum.TextXAlignment = Settings.Horizontal
	const Truncation: Enum.TextTruncate = Settings.Cut
	const BoxWidth: number = math.min(MaxWidth, Box.X)
	const Floor: number = if State.Rendering.Clipping and not Free then Box.Y + 0.5 else math.huge
	const Heights: { number } = Rows.Heights
	const Spans: { number } = Rows.Spans
	const Flags: { number } = Rows.Flags
	const Firsts: { number } = Rows.Firsts
	const Output: { Run } = Memory.Output
	const Coverage: Types.Coverage = Backdrop.Begin(Memory.Coverage)

	local Y: number = Start(Settings.Vertical, Free, Shape.Metrics.Total, Box.Y)
	local Count: number = 0

	Memory.Coverage = Coverage

	if Floor < math.huge and Y < 0 then Y = 0 end

	for Index = 1, Rows.Count do
		const LineHeight: number = Heights[Index]
		if Y + LineHeight > Floor then break end

		const Mode: number = Flags[Index]
		const From: number = Firsts[Index]
		const To: number = Firsts[Index + 1] - 1

		if Mode == Block then
			Count = Place(Shape, Output, Count, Coverage, From, To, Align(Alignment, BoxWidth, Spans[Index]), Y)
			Y = Y + LineHeight

			continue
		end

		if Truncation ~= Enum.TextTruncate.None and not bit32.btest(Mode, Leveled) then
			const Following: number? = Heights[Index + 1]

			if (Following and Y + LineHeight + Following > Floor) or Spans[Index] > BoxWidth + OverflowTolerance then
				const Width: number? = Shorten(State, Shape, Index, BoxWidth, Truncation)
				if not Width then return nil, nil end

				Backdrop.Row(Coverage, Y, LineHeight)
				Count = Place(Tail, Output, Count, Coverage, 1, Tail.Runs.Size, Align(Direction(Alignment, Mode), BoxWidth, Width :: number), Y)

				break
			end
		end

		Backdrop.Row(Coverage, Y, LineHeight)
		Count = Place(Shape, Output, Count, Coverage, From, To, Align(Direction(Alignment, Mode), BoxWidth, Spans[Index]), Y)
		Y = Y + LineHeight
	end

	for Index = #Output, Count + 1, -1 do Output[Index] = nil end

	return Output, Coverage
end

const function Signature(State: Types.Fields, Memory: Memory, Shape: Shape, MaxWidth: number, Box: Vector2, Free: boolean): (Enum.TextXAlignment, Enum.TextTruncate, number, number, number)
	const Settings: Types.SettingData = Memory.Settings
	const Alignment: Enum.TextXAlignment = Settings.Horizontal
	const Truncation: Enum.TextTruncate = Settings.Cut
	const Floor: number = if State.Rendering.Clipping and not Free then Box.Y + 0.5 else math.huge
	const Fixed: boolean = Alignment == Enum.TextXAlignment.Left and not Shape.Metrics.Rtl and Truncation == Enum.TextTruncate.None

	local Y: number = Start(Settings.Vertical, Free, Shape.Metrics.Total, Box.Y)
	if Floor < math.huge and Y < 0 then Y = 0 end

	return Alignment, Truncation, if Fixed then 0 else math.min(MaxWidth, Box.X), Y, Floor
end

const function Current(State: Types.Fields, Memory: Memory, Shape: Shape, MaxWidth: number, Box: Vector2, Free: boolean): boolean
	const Commit: Types.CommitData = Memory.Commit
	if Commit.Shape ~= Shape or Commit.Version ~= Shape.Version then return false end

	const Instances: Types.InstanceData = State.Instances

	if Commit.Factor ~= State.Scale.Factor or Commit.Decoration ~= State.Decoration.Version or State.Decoration.Dirty then return false end
	if Commit.Placed ~= #Instances.Segments or Commit.Ordered ~= #Instances.Order then return false end

	const Alignment: Enum.TextXAlignment, Truncation: Enum.TextTruncate, BoxWidth: number, Y: number, Floor: number = Signature(State, Memory, Shape, MaxWidth, Box, Free)

	return Commit.Alignment == Alignment and Commit.Truncation == Truncation and Commit.BoxWidth == BoxWidth and Commit.Start == Y and Commit.Floor == Floor
end

const function Remember(State: Types.Fields, Memory: Memory, Shape: Shape, MaxWidth: number, Box: Vector2, Free: boolean): ()
	const Instances: Types.InstanceData = State.Instances
	const Alignment: Enum.TextXAlignment, Truncation: Enum.TextTruncate, BoxWidth: number, Y: number, Floor: number = Signature(State, Memory, Shape, MaxWidth, Box, Free)

	const Commit: Types.CommitData = Memory.Commit

	Commit.Shape = Shape
	Commit.Version = Shape.Version
	Commit.Alignment = Alignment
	Commit.Truncation = Truncation
	Commit.BoxWidth = BoxWidth
	Commit.Start = Y
	Commit.Floor = Floor
	Commit.Factor = State.Scale.Factor
	Commit.Decoration = State.Decoration.Version
	Commit.Placed = #Instances.Segments
	Commit.Ordered = #Instances.Order
end

return {
	Finalize = Finalize;
	Current = Current;
	Remember = Remember;
}
