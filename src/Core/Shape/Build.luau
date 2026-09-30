--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Measure = require("../../Text/Measure")
const Unicode = require("../../Text/Unicode")
const Styles = require("../../Utility/Styles")
const Segment = require("../../Render/Segment")
const Bidi = require("../../Text/Bidi")
const Lines = require("../Lines")
const Cache = require("./Cache")

type Run = Types.Run
type Shape = Types.Shape
type Memory = Types.Memory
type Token = Types.Token
type Line = Types.Line
type Columns = Types.RunColumns
type Rows = Types.RowColumns
type Pending = Types.PendingData
type Staged = Types.StagedData

const Block: number = 1
const Facing: number = 2
const Leveled: number = 4


const Plain = setmetatable({} :: { [Types.Style]: Types.Style }, {__mode = "k"})

const NewShape = Cache.New
const Blocked = Cache.Blocked
const Claim = Cache.Claim

const Scratch: Shape = NewShape()
const Tail: Shape = NewShape()

const Cursor: Types.CursorData = {
	Height = 0;
	Factor = 1;
	Pending = {Words = {}, Size = 0, Style = nil, Level = nil, Spaced = false, Left = 0, Right = 0};
	Staged = {Count = 0, Styles = {}, Texts = {}, Lefts = {}, Rights = {}, Spaces = {}, Pieces = {}};
}

const function Emit(Shape: Shape, Style: Types.Style?, Object: GuiObject?, Text: string, Offset: number, Rise: number, Width: number, Height: number, Pad: number, Markup: string?, Gaps: { number }?): ()
	const Columns: Columns = Shape.Runs
	const Index: number = Columns.Size + 1
	const Runs: { Run } = Columns.Items
	const Existing: Run? = Runs[Index]

	Columns.Size = Index
	Columns.Offsets[Index] = Offset
	Columns.Rises[Index] = Rise
	Columns.Pads[Index] = Pad

	if not Existing then
		const Created: Run = {Style = Style, Object = Object, Text = Text, X = 0, Y = 0, Width = Width, Height = Height}

		if Markup then
			Created.Markup = Markup
			Created.Gaps = Gaps
		end

		Runs[Index] = Created

		return
	end

	const Reused: Run = Existing :: Run
	Reused.Style = Style
	Reused.Object = Object
	Reused.Text = Text
	Reused.Width = Width
	Reused.Height = Height

	if Markup or Reused.Markup then
		Reused.Markup = Markup
		Reused.Gaps = Gaps
	end
end

const function Joinable(Style: Types.Style): boolean
	return not (Style.Link or Style.Element or Style.Gradient or Style.Effect or Style.Container or Style.Code or Style.Mark)
end

const function Compatible(Left: Types.Style, Right: Types.Style): boolean
	if Left == Right then return true end

	return Left.Family == Right.Family
		and Left.Size == Right.Size
		and Left.Color == Right.Color
		and Left.Weight == Right.Weight
		and Left.Bold == Right.Bold
		and Left.Italic == Right.Italic
		and Left.Transparency == Right.Transparency
		and Left.Direction == Right.Direction
		and Segment.Stroked(Left.Stroke, Right.Stroke)
end

const function Stripped(Style: Types.Style): Types.Style
	const Known: Types.Style? = Plain[Style]; if Known then return Known :: Types.Style end

	const Created: Types.Style = Styles.Clone(Style)
	Created.Underline = false
	Created.Strike = false
	Created.Case = nil
	Plain[Style] = Created

	return Created
end

const function Part(Shape: Shape, Parts: Staged, Index: number): ()
	const Left: number = Parts.Lefts[Index]

	Emit(Shape, Parts.Styles[Index], nil, Parts.Texts[Index], Left, 0, Parts.Rights[Index] - Left, Cursor.Height, -1)
end

const function Settle(Shape: Shape): ()
	const Parts: Staged = Cursor.Staged
	const Count: number = Parts.Count
	if Count == 0 then return end

	const Styled: { Types.Style } = Parts.Styles
	const Texts: { string } = Parts.Texts

	local First: number = 0
	local Last: number = 0
	local Parsed: number = 0

	Parts.Count = 0

	for Index = 1, Count do
		if not Segment.Rich(Styled[Index], Texts[Index]) then continue end

		if First == 0 then First = Index end
		Last = Index
		Parsed += 1
	end

	if Parsed < 2 then
		for Index = 1, Count do Part(Shape, Parts, Index) end

		return
	end

	for Index = 1, First - 1 do Part(Shape, Parts, Index) end

	const Pieces: { string } = Parts.Pieces
	const Spaces: { boolean } = Parts.Spaces

	local Size: number = 0
	local Offset: number = 0
	local Gaps: { number }? = nil

	for Index = First, Last do
		if Index > First and Spaces[Index] then
			const List: { number } = Gaps or {}
			Gaps = List
			table.insert(List, Offset)

			Size += 1
			Pieces[Size] = " "
		end

		Size += 1
		Pieces[Size] = Segment.Compose(Texts[Index], Styled[Index], false)
		Offset += Unicode.Count(Texts[Index])
	end

	const Left: number = Parts.Lefts[First]

	Emit(Shape, Stripped(Styled[First]), nil, table.concat(Texts, "", First, Last), Left, 0, Parts.Rights[Last] - Left, Cursor.Height, -1, table.concat(Pieces, "", 1, Size), Gaps)

	for Index = Last + 1, Count do Part(Shape, Parts, Index) end
end

const function Stage(Shape: Shape, Style: Types.Style, Text: string): ()
	const Current: Pending = Cursor.Pending
	const Parts: Staged = Cursor.Staged

	if Parts.Count == 0 and not (Style.Underline or Style.Strike or Style.Case) then
		Emit(Shape, Style, nil, Text, Current.Left, 0, Current.Right - Current.Left, Cursor.Height, if Style.Mark then Measure.Pad(Style, Cursor.Factor) else -1)

		return
	end

	const Joins: boolean = Current.Level == nil and Joinable(Style)

	if Parts.Count > 0 and not (Joins and Compatible(Parts.Styles[1], Style)) then Settle(Shape) end

	if not Joins or (Parts.Count == 0 and not Segment.Rich(Style, Text)) then
		Emit(Shape, Style, nil, Text, Current.Left, 0, Current.Right - Current.Left, Cursor.Height, if Style.Mark then Measure.Pad(Style, Cursor.Factor) else -1)

		return
	end

	const Index: number = Parts.Count + 1

	Parts.Count = Index
	Parts.Styles[Index] = Style
	Parts.Texts[Index] = Text
	Parts.Lefts[Index] = Current.Left
	Parts.Rights[Index] = Current.Right
	Parts.Spaces[Index] = Current.Spaced
end

const function Flush(Shape: Shape): ()
	const Current: Pending = Cursor.Pending
	const Style: Types.Style? = Current.Style; if not Style then return end

	const Size: number = Current.Size
	const Words: { string } = Current.Words

	Current.Style = nil

	Stage(Shape, Style :: Types.Style, if Size == 1 then Words[1] else table.concat(Words, "", 1, Size))
end

const function Gather(Shape: Shape, Items: { Token }, Leads: { Token }?, LineHeight: number): ()
	const Current: Pending = Cursor.Pending
	const Words: { string } = Current.Words
	const Last: Token? = Items[#Items]

	Cursor.Height = LineHeight

	if Leads then
		for _, Lead: Token in (Leads :: { Token }) do Emit(Shape, Lead.Style, nil, Lead.Text or "", Lead.X, 0, Lead.Width, LineHeight, -1) end
	end

	for _, Token: Token in (Items) do
		const Object: GuiObject? = Token.Object

		if Object then
			Flush(Shape)
			Settle(Shape)
			Emit(Shape, nil, Object, "", Token.X, math.floor((LineHeight - Token.Height) / 2 + 0.5), Token.Width, Token.Height, -1)

			continue
		end

		const Style: Types.Style? = Token.Style
		const Text: string? = Token.Text
		if not (Style and Text) then continue end

		const Hyphen: number = if Token == Last and Token.Hyphen then Token.Hyphen :: number else 0
		const Finish: number = Token.X + Token.Width + Hyphen

		if Style == Current.Style and Token.Level == Current.Level and not (Style :: Types.Style).Effect then
			local Size: number = Current.Size
			if Token.SpaceBefore then Size += 1; Words[Size] = " " end

			Size += 1
			Words[Size] = Text :: string
			Current.Size = Size
			Current.Left = math.min(Current.Left, Token.X)
			Current.Right = math.max(Current.Right, Finish)
		else
			Flush(Shape)

			Words[1] = Text :: string
			Current.Style = Style
			Current.Level = Token.Level
			Current.Spaced = Token.SpaceBefore
			Current.Size = 1
			Current.Left = Token.X
			Current.Right = Finish
		end

		if Hyphen > 0 then
			Current.Size += 1
			Words[Current.Size] = "-"
		end
	end

	Flush(Shape)
	Settle(Shape)
end

const function Begin(Factor: number): ()
	Cursor.Factor = Factor
	Cursor.Pending.Style = nil
end

const function Hold(Shape: Shape, Token: Token): ()
	const Held: Types.BlockData = Shape.Blocks
	const Blocks: { Token } = Held.Tokens or {}
	const Sizes: { number } = Held.Sizes or {}
	const Count: number = #Blocks + 1

	Held.Tokens = Blocks
	Held.Sizes = Sizes

	Blocks[Count] = Token
	Sizes[Count * 2 - 1] = Token.Width
	Sizes[Count * 2] = Token.Height
end

const function Build(State: Types.Fields, Shape: Shape, Computed: { Line }, Heights: { number }, From: number, To: number, MaxWidth: number, Widest: number): ()
	const Rows: Rows = Shape.Rows
	const Columns: Columns = Shape.Runs
	const Metrics: Types.MetricsData = Shape.Metrics
	const Firsts: { number } = Rows.Firsts
	const Spans: { number } = Rows.Spans
	const Flags: { number } = Rows.Flags
	const Tall: { number } = Rows.Heights

	local Reach: number = Widest

	Begin(State.Scale.Measured)

	for Index = From, To do
		const Line: Line = Computed[Index]
		const Items: { Token } = Line.Items
		const First: Token? = Items[1]
		const LineHeight: number = Heights[Index]
		const Slot: number = Rows.Count + 1

		if Line.Width > Reach then Reach = Line.Width end

		Rows.Count = Slot
		Firsts[Slot] = Columns.Size + 1
		Tall[Slot] = LineHeight

		if First and First.Block then
			const Wide: number = if MaxWidth < math.huge then MaxWidth else math.max(Widest, Line.Width)

			Hold(Shape, First)

			Spans[Slot] = Wide
			Flags[Slot] = Block
			Emit(Shape, nil, First.Object, "", 0, 0, math.ceil(Wide), LineHeight, -1)

			continue
		end

		local Mode: number = 0

		if First and First.Rtl then Mode += Facing; Metrics.Rtl = true end

		if First and First.Level then
			Mode += Leveled
			Bidi.Arrange(Items)
		end

		Spans[Slot] = Line.Width
		Flags[Slot] = Mode
		Gather(Shape, Items, Line.Leads, LineHeight)
	end

	Firsts[Rows.Count + 1] = Columns.Size + 1
	Metrics.Extent = Reach
end

const function Trim(Shape: Shape): ()
	const Columns: Columns = Shape.Runs
	const Rows: Rows = Shape.Rows
	const Count: number = Rows.Count
	const Size: number = Columns.Size

	for Index = #Columns.Offsets, Size + 1, -1 do
		Columns.Offsets[Index] = nil
		Columns.Rises[Index] = nil
		Columns.Pads[Index] = nil
	end

	for Index = #Rows.Heights, Count + 1, -1 do
		Rows.Heights[Index] = nil
		Rows.Spans[Index] = nil
		Rows.Flags[Index] = nil
	end

	for Index = #Rows.Firsts, Count + 2, -1 do Rows.Firsts[Index] = nil end
end

const function Reset(Shape: Shape): ()
	const Held: Types.BlockData = Shape.Blocks

	Shape.Rows.Count = 0
	Shape.Runs.Size = 0
	Shape.Metrics.Rtl = false

	const Blocks: { Token }? = Held.Tokens
	if Blocks then table.clear(Blocks :: { Token }) end

	const Sizes: { number }? = Held.Sizes
	if Sizes then table.clear(Sizes :: { number }) end
end

const function Extent(Computed: { Line }, Widest: number): number
	local Width: number = Widest

	for _, Line: Line in (Computed) do
		if Line.Width > Width then Width = Line.Width end
	end

	return Width
end

const function Stamp(State: Types.Fields, Memory: Memory, Shape: Shape, MaxWidth: number, Minimum: number, Chopped: boolean, Total: number, Widest: number): ()
	const Need: number, Limit: number, Longest: number, Exact: boolean, Serial: number = Lines.Bounds(State)
	const Settings: Types.SettingData = Memory.Settings
	const Scaled: boolean = Settings.Scaled
	const Key: Types.KeyData = Shape.Key
	const Widths: Types.WidthData = Shape.Widths

	Key.Tokens = State.Document.Tokens
	Key.Text = State.Generation.Text
	Key.Measure = State.Generation.Measure
	Key.Factor = State.Scale.Measured
	Key.Spacing = Settings.Spacing
	Key.Minimum = Minimum
	Key.Scaled = Scaled
	Key.Serial = Serial
	Widths.Width = MaxWidth
	Widths.Exact = Exact or Chopped or Blocked(Shape)
	Widths.Low = if Scaled then Need else math.max(Need, Longest)
	Widths.High = Limit
	Shape.Metrics.Total = Total
	Shape.Metrics.Widest = Widest
	Shape.Version += 1
end

const function Create(State: Types.Fields, Memory: Memory, Computed: { Line }, Heights: { number }, Total: number, Widest: number, MaxWidth: number, Minimum: number, Chopped: boolean): Shape
	const Shape: Shape = Claim(State, Memory)

	Reset(Shape)
	Build(State, Shape, Computed, Heights, 1, #Computed, MaxWidth, Widest)
	Trim(Shape)
	Stamp(State, Memory, Shape, MaxWidth, Minimum, Chopped, Total, Widest)

	return Shape
end

const function Shift<T>(List: { T }, From: number, To: number, By: number, Size: number): ()
	if By == 0 then return end
	if From <= To then table.move(List, From, To, From + By) end
	if By < 0 then
		for Index = Size + By + 1, Size do List[Index] = nil end
	end
end

const function Splice(State: Types.Fields, Memory: Memory, Shape: Shape, Region: Types.Region, Computed: { Line }, Heights: { number }, Total: number, Widest: number, MaxWidth: number, Minimum: number): ()
	const Columns: Columns = Shape.Runs
	const Rows: Rows = Shape.Rows
	const Fresh: Columns = Scratch.Runs
	const Built: Rows = Scratch.Rows
	const First: number = Region.First
	const Resume: number = Region.Resume
	const Previous: number = Rows.Count
	const Firsts: { number } = Rows.Firsts
	const RunFrom: number = Firsts[First]
	const RunStop: number = Firsts[Resume]
	const Size: number = Columns.Size

	Reset(Scratch)
	Build(State, Scratch, Computed, Heights, First, Region.Last, MaxWidth, Widest)

	const Added: number = Fresh.Size
	const Moved: number = Added - (RunStop - RunFrom)
	const Grown: number = Built.Count - (Resume - First)
	const Runs: { Run } = Columns.Items
	const Loose: { Run } = Fresh.Items

	for Index = #Runs, Size + 1, -1 do
		table.insert(Loose, Runs[Index])
		Runs[Index] = nil
	end

	for Index = RunFrom, RunStop - 1 do table.insert(Loose, Runs[Index]) end

	Shift(Runs, RunStop, Size, Moved, Size)
	Shift(Columns.Offsets, RunStop, Size, Moved, Size)
	Shift(Columns.Rises, RunStop, Size, Moved, Size)
	Shift(Columns.Pads, RunStop, Size, Moved, Size)
	table.move(Loose, 1, Added, RunFrom, Runs)
	table.move(Fresh.Offsets, 1, Added, RunFrom, Columns.Offsets)
	table.move(Fresh.Rises, 1, Added, RunFrom, Columns.Rises)
	table.move(Fresh.Pads, 1, Added, RunFrom, Columns.Pads)
	table.move(Loose, Added + 1, #Loose, 1)
	for Index = #Loose, #Loose - Added + 1, -1 do Loose[Index] = nil end

	Shift(Rows.Heights, Resume, Previous, Grown, Previous)
	Shift(Rows.Spans, Resume, Previous, Grown, Previous)
	Shift(Rows.Flags, Resume, Previous, Grown, Previous)
	Shift(Firsts, Resume, Previous + 1, Grown, Previous + 1)

	for Index = Resume + Grown, Previous + 1 + Grown do Firsts[Index] += Moved end

	for Offset = 1, Built.Count do
		const Target: number = First + Offset - 1

		Firsts[Target] = RunFrom + Built.Firsts[Offset] - 1
		Rows.Heights[Target] = Built.Heights[Offset]
		Rows.Spans[Target] = Built.Spans[Offset]
		Rows.Flags[Target] = Built.Flags[Offset]
		if bit32.btest(Built.Flags[Offset], Facing) then Shape.Metrics.Rtl = true end
	end

	Rows.Count = Previous + Grown
	Columns.Size = Size + Moved

	Trim(Shape)
	Stamp(State, Memory, Shape, MaxWidth, Minimum, false, Total, Widest)
	Shape.Metrics.Extent = Extent(Computed, Widest)
end

return {
	Scratch = Scratch;
	Tail = Tail;
	Begin = Begin;
	Reset = Reset;
	Gather = Gather;
	Create = Create;
	Splice = Splice;
}
