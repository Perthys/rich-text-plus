--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Measure = require("../Text/Measure")
const Profiler = require("../Utility/Profiler")
const Lifetime = require("../Utility/Lifetime")

type Region = Types.Region

type Token = Types.Token
type Line = Types.Line
type Mark = Types.MarkData

type Paragraph = Types.Paragraph
type Sheet = Types.Sheet
type Input = Types.PassData
type Totals = Types.TotalData
type Breaks = Types.BreakData

const Sheets = Lifetime.Own("Lines.Sheets", {} :: { [Types.Fields]: Sheet })
const Anchors: { [Types.IndentData]: number } = {}
const Unused: { Paragraph } = {}
const Fresh: { Line } = {}
const Rows: { number } = {}
const Added: { Paragraph } = {}
const Spill: { Line } = {}
const Region: Region = {First = 0, Last = 0, Resume = 0, Previous = 0}
const Progress = {Guard = 0, Delta = 0, Resynced = 0, Placed = 0, Opened = 0}

const function NewBreaks(): Breaks
	return {Need = 0, Limit = math.huge, Longest = 0, Exact = false}
end

const function Bound(Target: Breaks, Need: number, Limit: number, Longest: number, Exact: boolean): ()
	Target.Need = Need
	Target.Limit = Limit
	Target.Longest = Longest
	Target.Exact = Exact
end

const function SpaceStyle(Tokens: { Types.Token }, Index: number): Types.Style?
	for Back = Index, 1, -1 do
		const Found: Types.Style? = Tokens[Back].Style
		if Found then return Found end
		if Tokens[Back].Kind == "Break" then return nil end
	end

	return nil
end
const function Obtain(State: Types.Fields): Sheet
	const Existing: Sheet? = Sheets[State]; if Existing then return Existing :: Sheet end

	const Created: Sheet = {
		Lines = {};
		Heights = {};
		Spare = {};
		Paragraphs = {};
		Pass = {Source = nil, Spaces = nil, Width = 0, Ratio = 1, Factor = 1, Spacing = 1, Minimum = 0, Measure = 0};
		Totals = {Count = 0, Total = 0, Widest = 0, Serial = 0};
		Breaks = NewBreaks();
		Retain = {Retained = false, Leveled = false, Snapshot = {}, Size = 0};
	}

	Sheets[State] = Created

	return Created
end

const function Closes(Tokens: { Token }, Index: number, Span: Mark?): boolean
	if not Span then return true end

	for Ahead = Index + 1, #Tokens do
		const Next: Token = Tokens[Ahead]
		if Next.Kind == "Break" then continue end

		const Style: Types.Style? = Next.Style

		return not (Style and (Style :: Types.Style).Mark == Span)
	end

	return true
end

const function Tail(Tokens: { Token }, Index: number, Ratio: number): number
	local Last: Token = Tokens[Index]
	local Extra: number = 0

	if not Last.Glue then
		for Ahead = Index + 1, #Tokens do
			const Next: Token = Tokens[Ahead]
			if not Next.Glue then break end

			Extra += Next.Width
			Last = Next
		end
	end

	return (Extra + (Last.Hyphen or 0)) * Ratio
end

const function Column(Indent: Types.IndentData?, Scale: number): number
	if not Indent then return 0 end

	const Size: number? = (Indent :: Types.IndentData).Size
	if Size then return (Size :: number) * Scale end

	return Anchors[Indent :: Types.IndentData] or 0
end

const function Place(Lines: { Line }, Heights: { number }, Count: number, Filled: { Token }, Lead: { Token }?, Tallest: number, Width: number, Row: number): { Token }
	const Existing: Line? = Lines[Count]

	Heights[Count] = Row

	if not Existing then
		Lines[Count] = {Items = Filled, Leads = Lead, Height = Tallest, Width = Width}

		return {}
	end

	const Line: Line = Existing :: Line
	const Freed: { Token } = Line.Items

	Line.Items = Filled
	Line.Leads = Lead
	Line.Height = Tallest
	Line.Width = Width

	table.clear(Freed)

	return Freed
end

const function Seal(Input: Input, Totals: Totals, Lines: { Line }, Heights: { number }, Count: number, Items: { Token }, Lead: { Token }?, Tallest: number, X: number): { Token }
	const Last: Token? = Items[#Items]
	const Width: number = X + (if Last and Last.Hyphen then (Last.Hyphen :: number) * Input.Ratio else 0)
	const Row: number = math.floor(math.max(Tallest, Input.Minimum) * Input.Spacing + 0.5)

	Totals.Total += Row
	if Width > Totals.Widest then Totals.Widest = Width end

	return Place(Lines, Heights, Count, Items, Lead, Tallest, Width, Row)
end

const function Claim(Records: { Paragraph }, Slot: number, Start: number, Before: number, Open: Mark?, After: boolean): Paragraph
	const Record: Paragraph = table.remove(Unused) or {Start = 0, Before = 0, Open = nil, After = false, Breaks = NewBreaks()}

	Record.Start = Start
	Record.Before = Before
	Record.Open = Open
	Record.After = After
	Bound(Record.Breaks, 0, math.huge, 0, false)

	Records[Slot] = Record

	return Record
end

const function Locate(Records: { Paragraph }, Count: number, Start: number): number
	local Low: number = 1
	local High: number = Count

	while Low < High do
		const Middle: number = (Low + High + 1) // 2

		if Records[Middle].Start <= Start then Low = Middle else High = Middle - 1 end
	end

	return Low
end

const function Match(Sheet: Sheet, Start: number, Open: Mark?, After: boolean): number
	const Records: { Paragraph } = Sheet.Paragraphs
	const Count: number = #Records
	const Target: number = Start - Progress.Delta
	if Count == 0 or Records[Count].Start < Target then return 0 end

	const Found: number = Locate(Records, Count, Target)
	const Record: Paragraph = Records[Found]

	return if Record.Start == Target and Record.Open == Open and Record.After == After then Found else 0
end

const function Pass(Sheet: Sheet, From: number, Lines: { Line }, Heights: { number }, Records: { Paragraph }, Before: number, Entry: Mark?, Following: boolean, Watch: boolean): ()
	const Input: Input = Sheet.Pass
	const Totals: Totals = Sheet.Totals
	const Tokens: { Token } = Input.Source :: { Token }
	const MaxWidth: number = Input.Width
	const Ratio: number = Input.Ratio
	const Factor: number = Input.Factor
	const Scale: number = Factor * Ratio
	const SpaceWidths: { [Types.Style]: number } = Input.Spaces :: { [Types.Style]: number }
	const Size: number = #Tokens

	table.clear(Anchors)

	local Count: number = 0
	local Opened: number = 1
	local Items: { Token } = Sheet.Spare
	local X: number = 0
	local Height: number = 0
	local Open: Mark? = Entry
	local AfterBlock: boolean = Following
	local Wrapped: boolean = false
	local Leads: { Token }? = nil
	local LeadEnd: number = 0
	local LeadHeight: number = 0
	local Leveled: boolean = false
	local Need: number = 0
	local Limit: number = math.huge
	local Longest: number = 0
	local Exact: boolean = false
	local Current: Paragraph = Claim(Records, 1, From, Before, Open, AfterBlock)

	Progress.Resynced = 0

	for Index = From, Size do
		const Token: Token = Tokens[Index]
		const Kind: string = Token.Kind

		if Kind == "Break" or Token.Block then
			if Kind == "Break" then
				if AfterBlock then
					AfterBlock = false
				else
					Count += 1
					Items = Seal(Input, Totals, Lines, Heights, Count, Items, if Wrapped then Leads else nil, Height, X)
					X = 0
					Height = 0
				end
			else
				if #Items > 0 then
					Count += 1
					Items = Seal(Input, Totals, Lines, Heights, Count, Items, if Wrapped then Leads else nil, Height, X)
					X = 0
					Height = 0
				end

				const BlockHeight: number = math.floor(Token.Height * Ratio + 0.5)
				const Holder: { Token } = Items

				Token.X = 0
				table.insert(Holder, Token)
				Count += 1
				Totals.Total += BlockHeight
				Items = Place(Lines, Heights, Count, Holder, nil, BlockHeight, Token.Width * Ratio, BlockHeight)
				AfterBlock = true
				Exact = true
			end

			table.clear(Anchors)
			Wrapped = false
			Leads = nil
			LeadEnd = 0
			LeadHeight = 0

			Bound(Current.Breaks, Need, Limit, Longest, Exact)

			if Watch and Index >= Progress.Guard then
				const Found: number = Match(Sheet, Index + 1, Open, AfterBlock)
				if Found > 0 then Progress.Resynced = Found; break end
			end

			Need = 0
			Limit = math.huge
			Longest = 0
			Exact = false
			Opened += 1
			Current = Claim(Records, Opened, Index + 1, Before + Count, Open, AfterBlock)

			continue
		end

		AfterBlock = false

		const Style: Types.Style? = Token.Style
		const Width: number = Token.Width * Ratio
		const TokenHeight: number = Token.Height * Ratio
		const Indent: Types.IndentData? = if Style then (Style :: Types.Style).Indent else nil
		const Pad: number = if Style and (Style :: Types.Style).Code then Measure.Pad(Style :: Types.Style, Factor) * Ratio else 0
		const Span: Mark? = if Pad > 0 then (Style :: Types.Style).Mark else nil
		const Opening: number = if Pad > 0 and (Span == nil or Span ~= Open) then Pad else 0
		const Closing: number = if Pad > 0 and Closes(Tokens, Index, Span) then Pad else 0
		const Spacer: Types.Style? = if Token.SpaceBefore and X > 0 then Style or SpaceStyle(Tokens, Index - 1) else nil
		const Space: number = if Spacer then (SpaceWidths[Spacer :: Types.Style] or 0) * Ratio else 0
		const Next: Token? = Tokens[Index + 1]
		const Trail: number = if Token.Glue or not (Next and Next.Glue) then (Token.Hyphen or 0) * Ratio else Tail(Tokens, Index, Ratio)
		const Rest: number = Opening + Width + Closing + Trail
		const Reach: number = X + Space + Rest

		if Style and Token.Text and Width + Pad * 2 > Longest then Longest = Width + Pad * 2 end
		if Token.Level then Leveled = true end

		if X > 0 and Reach > MaxWidth then
			if Reach < Limit then Limit = Reach end

			Count += 1
			Items = Seal(Input, Totals, Lines, Heights, Count, Items, if Wrapped then Leads else nil, Height, X)
			X = 0
			Height = 0

			const Start: number = math.max(Column(Indent, Scale), if Leads then LeadEnd else 0)

			if Start > 0 then
				if MaxWidth - Rest >= Start then
					if Start + Rest > Need then Need = Start + Rest end
				else
					Exact = true
				end
			end

			Wrapped = true
			Height = LeadHeight
			X = math.max(math.min(Start, MaxWidth - Rest), 0)
			Token.X = X + Opening
		else
			if X > 0 and Reach > Need then Need = Reach end

			Token.X = X + Space + Opening
		end

		X = Token.X + Width + Closing
		Open = if Closing > 0 then nil else Span

		if Indent then
			const Data: Types.IndentData = Indent :: Types.IndentData

			if not Data.Size and Anchors[Data] == nil then Anchors[Data] = Token.X end

			if Data.Repeat and not Wrapped then
				const List: { Token } = Leads or {}
				Leads = List
				table.insert(List, Token)

				LeadEnd = X + (SpaceWidths[Style :: Types.Style] or 0) * Ratio
				if TokenHeight > LeadHeight then LeadHeight = TokenHeight end
			end
		end

		table.insert(Items, Token)

		if TokenHeight > Height then Height = TokenHeight end
	end

	if Progress.Resynced == 0 then
		if #Items > 0 then
			Count += 1
			Items = Seal(Input, Totals, Lines, Heights, Count, Items, if Wrapped then Leads else nil, Height, X)
		end

		Bound(Current.Breaks, Need, Limit, Longest, Exact)
	end

	Sheet.Spare = Items
	Progress.Placed = Count
	Progress.Opened = Opened
	if Leveled then Sheet.Retain.Leveled = true end
end

const function Tally(Sheet: Sheet): ()
	const Heights: { number } = Sheet.Heights

	local Total: number = 0
	local Widest: number = 0

	for Index: number, Line: Line in (Sheet.Lines) do
		Total += Heights[Index]

		const First: Token? = Line.Items[1]
		if not (First and First.Block) and Line.Width > Widest then Widest = Line.Width end
	end

	Sheet.Totals.Total = Total
	Sheet.Totals.Widest = Widest
end

const function Summarize(Sheet: Sheet): ()
	local Need: number = 0
	local Limit: number = math.huge
	local Longest: number = 0
	local Exact: boolean = false

	for _, Record: Paragraph in (Sheet.Paragraphs) do
		const Breaks: Breaks = Record.Breaks

		if Breaks.Need > Need then Need = Breaks.Need end
		if Breaks.Limit < Limit then Limit = Breaks.Limit end
		if Breaks.Longest > Longest then Longest = Breaks.Longest end
		if Breaks.Exact then Exact = true end
	end

	Sheet.Totals.Count = #Sheet.Lines
	Bound(Sheet.Breaks, Need, Limit, Longest, Exact)
end

const function Configure(Sheet: Sheet, State: Types.Fields, MaxWidth: number, Ratio: number, Spacing: number?, Minimum: number?): ()
	const Input: Input = Sheet.Pass
	const Factor: number = State.Scale.Measured

	Input.Source = State.Document.Tokens
	Input.Spaces = State.Document.SpaceWidths
	Input.Width = MaxWidth
	Input.Ratio = Ratio
	Input.Factor = Factor
	Input.Spacing = Spacing or State.Label.LineHeight
	Input.Minimum = (Minimum or Measure.Scaled(Styles.BaseSize(State), Factor)) * Ratio
	Input.Measure = State.Generation.Measure
end

const function Recycle(Records: { Paragraph }, From: number, To: number): ()
	for Index = From, To do
		Unused[#Unused + 1] = Records[Index]
		Records[Index] = nil
	end
end

const function Keep(Sheet: Sheet): ()
	const Retain: Types.RetainData = Sheet.Retain
	const Tokens: { Token } = Sheet.Pass.Source :: { Token }
	const Snapshot: { Token } = Retain.Snapshot
	const Size: number = #Tokens

	table.move(Tokens, 1, Size, 1, Snapshot)
	for Index = Size + 1, Retain.Size do Snapshot[Index] = nil end

	Retain.Size = Size
end

const function Compute(State: Types.Fields, MaxWidth: number, Ratio: number, Keeping: boolean?, Spacing: number?, Minimum: number?): ({ Line }, { number }, number, number)
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Lines") end

	const Sheet: Sheet = Obtain(State)
	const Lines: { Line } = Sheet.Lines
	const Heights: { number } = Sheet.Heights

	const Totals: Totals = Sheet.Totals
	const Retain: Types.RetainData = Sheet.Retain

	Configure(Sheet, State, MaxWidth, Ratio, Spacing, Minimum)
	Recycle(Sheet.Paragraphs, 1, #Sheet.Paragraphs)
	table.clear(Sheet.Spare)

	Retain.Leveled = false
	Totals.Total = 0
	Totals.Widest = 0

	Pass(Sheet, 1, Lines, Heights, Sheet.Paragraphs, 0, nil, false, false)

	for Index = #Lines, Progress.Placed + 1, -1 do
		Lines[Index] = nil
		Heights[Index] = nil
	end

	Summarize(Sheet)

	Retain.Retained = Keeping == true and #Sheet.Paragraphs > 1
	Totals.Serial += 1

	if Retain.Retained then Keep(Sheet) end
	if Profiling then Profiler.End() end

	return Lines, Heights, Totals.Total, Totals.Widest
end

const function Holds(Sheet: Sheet, MaxWidth: number): boolean
	const Breaks: Breaks = Sheet.Breaks
	if Breaks.Exact then return MaxWidth == Sheet.Pass.Width end

	return MaxWidth >= Breaks.Need and (MaxWidth < Breaks.Limit or Breaks.Limit == math.huge)
end

const function Usable(Sheet: Sheet?, State: Types.Fields, MaxWidth: number, Spacing: number, Minimum: number): boolean
	if not Sheet then return false end

	const Retain: Types.RetainData = (Sheet :: Sheet).Retain
	if not Retain.Retained or Retain.Leveled then return false end

	const Input: Input = (Sheet :: Sheet).Pass

	return Input.Source == State.Document.Tokens
		and Input.Ratio == 1
		and Input.Factor == State.Scale.Measured
		and Input.Measure == State.Generation.Measure
		and Input.Spacing == Spacing
		and Input.Minimum == Minimum
		and Holds(Sheet :: Sheet, MaxWidth)
end

const function Swap(Sheet: Sheet, First: number, Removed: number, Placed: number): ()
	const Lines: { Line } = Sheet.Lines
	const Heights: { number } = Sheet.Heights
	const Count: number = Sheet.Totals.Count
	const Shift: number = Placed - Removed
	const Resume: number = First + Removed

	for Index = First, Resume - 1 do Spill[#Spill + 1] = Lines[Index] end

	if Shift ~= 0 then
		table.move(Lines, Resume, Count, Resume + Shift)
		table.move(Heights, Resume, Count, Resume + Shift)

		for Index = Count + Shift + 1, Count do
			Lines[Index] = nil
			Heights[Index] = nil
		end
	end

	for Offset = 1, Placed do
		Lines[First + Offset - 1] = Fresh[Offset]
		Heights[First + Offset - 1] = Rows[Offset]
		Fresh[Offset] = table.remove(Spill) :: Line
	end
end

const function Graft(Sheet: Sheet, Paragraph: number, Resynced: number): ()
	const Records: { Paragraph } = Sheet.Paragraphs
	const Opened: number = Progress.Opened
	const Count: number = #Records
	const Stop: number = if Resynced > 0 then Resynced - 1 else Count
	const Removed: number = Stop - Paragraph + 1
	const Shift: number = Opened - Removed
	const Delta: number = Progress.Delta
	const Moved: number = Region.Last - Region.Resume + 1

	Recycle(Records, Paragraph, Stop)

	if Resynced > 0 then
		for Index = Resynced, Count do
			const Record: Paragraph = Records[Index]

			Record.Start += Delta
			Record.Before += Moved
		end

		if Shift ~= 0 then
			table.move(Records, Resynced, Count, Resynced + Shift)
			for Index = Count + Shift + 1, Count do Records[Index] = nil end
		end
	end

	for Offset = 1, Opened do
		Records[Paragraph + Offset - 1] = Added[Offset]
		Added[Offset] = nil
	end
end

const function Rebreak(State: Types.Fields, MaxWidth: number, Spacing: number, Minimum: number): Region?
	const Sheet: Sheet? = Sheets[State]
	if not Usable(Sheet, State, MaxWidth, Spacing, Minimum) then return nil end

	const Active: Sheet = Sheet :: Sheet
	const Input: Input = Active.Pass
	const Totals: Totals = Active.Totals
	const Tokens: { Token } = Input.Source :: { Token }
	const Snapshot: { Token } = Active.Retain.Snapshot
	const Old: number = Active.Retain.Size
	const New: number = #Tokens
	const Shared: number = math.min(Old, New)
	const Count: number = Totals.Count

	local Head: number = 0
	while Head < Shared and Snapshot[Head + 1] == Tokens[Head + 1] do Head += 1 end

	Totals.Serial += 1
	Input.Width = MaxWidth
	Input.Spaces = State.Document.SpaceWidths

	if Head == Old and Old == New then
		Region.First = Count + 1
		Region.Last = Count
		Region.Resume = Count + 1
		Region.Previous = Count

		return Region
	end

	local Tail: number = 0
	while Tail < Shared - Head and Snapshot[Old - Tail] == Tokens[New - Tail] do Tail += 1 end

	local Anchor: number = Head
	while Anchor > 0 and Tokens[Anchor].Kind == "Break" do Anchor -= 1 end

	const Records: { Paragraph } = Active.Paragraphs
	const Paragraph: number = Locate(Records, #Records, math.max(Anchor, 1))
	const Record: Paragraph = Records[Paragraph]

	Progress.Guard = New - Tail
	Progress.Delta = New - Old

	table.clear(Active.Spare)

	Pass(Active, Record.Start, Fresh, Rows, Added, Record.Before, Record.Open, Record.After, true)

	const Resynced: number = Progress.Resynced
	const First: number = Record.Before + 1
	const Resume: number = if Resynced > 0 then Records[Resynced].Before + 1 else Count + 1

	Region.First = First
	Region.Last = Record.Before + Progress.Placed
	Region.Resume = Resume
	Region.Previous = Count

	Swap(Active, First, Resume - First, Progress.Placed)
	Graft(Active, Paragraph, Resynced)
	Tally(Active)
	Summarize(Active)
	Keep(Active)

	return Region
end

const function Resume(State: Types.Fields, MaxWidth: number, Spacing: number, Minimum: number): Region?
	if not Profiler.Enabled then return Rebreak(State, MaxWidth, Spacing, Minimum) end

	Profiler.Begin("RTP:Reflow")
	const Region: Region? = Rebreak(State, MaxWidth, Spacing, Minimum)
	Profiler.End()

	return Region
end

const function Resumable(State: Types.Fields): boolean
	const Sheet: Sheet? = Sheets[State]

	return Sheet ~= nil and (Sheet :: Sheet).Retain.Retained and (Sheet :: Sheet).Pass.Source == State.Document.Tokens
end

const function Current(State: Types.Fields): ({ Line }, { number }, number, number, number)
	const Sheet: Sheet = Obtain(State)
	const Totals: Totals = Sheet.Totals

	return Sheet.Lines, Sheet.Heights, Totals.Total, Totals.Widest, Totals.Serial
end

const function Bounds(State: Types.Fields): (number, number, number, boolean, number)
	const Sheet: Sheet = Sheets[State] :: Sheet
	const Breaks: Breaks = Sheet.Breaks

	return Breaks.Need, Breaks.Limit, Breaks.Longest, Breaks.Exact, Sheet.Totals.Serial
end

return {
	Compute = Compute;
	Resume = Resume;
	Resumable = Resumable;
	Current = Current;
	Bounds = Bounds;
}
