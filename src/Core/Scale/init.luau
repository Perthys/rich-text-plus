--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Measure = require("../Text/Measure")
const Lines = require("./Lines")
const Reflow = require("../Utility/Reflow")
const Profiler = require("../Utility/Profiler")
const Lifetime = require("../Utility/Lifetime")

const MinimumFactor: number = Config.Scale.MINIMUM_FACTOR
const HeightTolerance: number = Config.Scale.HEIGHT_TOLERANCE
const MinimumBoxHeight: number = Config.Scale.MINIMUM_BOX_HEIGHT
const SearchSteps: number = Config.Scale.SEARCH_STEPS
const GuessSteps: number = Config.Scale.GUESS_STEPS
const CrawlSteps: number = Config.Scale.CRAWL_STEPS
const RefineSteps: number = Config.Scale.REFINE_STEPS
const ShrinkSteps: number = Config.Scale.SHRINK_STEPS

type Model = Types.Model
type Problem = Types.ProblemData
type Bracket = Types.Bracket
type Solution = Types.Solution
type Memo = Types.Memo

const Seeding: number = 1
const Guessing: number = 2
const Crawling: number = 3
const Searching: number = 4
const Bounding: number = 5
const SolutionLimit: number = Config.Scale.SOLUTION_LIMIT

const Brackets = Lifetime.Own("Scale.Brackets", {} :: { [Types.Fields]: Bracket })
const Memos = Lifetime.Own("Scale.Memos", {} :: { [Types.Fields]: Memo })
const Host = require("@self/Host")

const Echo = Host.Echo
const Release = Host.Release
const Fit = Host.Fit
const Enforce = Host.Enforce

const function NewModel(): Model
	return {Anchor = 0, Widest = 0, Merge = 0, Count = 0, Paragraphs = 0, Rows = {}, Content = {}, Waste = {}, Spans = {}, Units = {}}
end

const function NewProblem(): Problem
	return {MaxWidth = 0, Width = 0, Height = 0, Floor = 0, High = 0, Base = 0, Spacing = 1}
end

const function Pose(Target: Problem, MaxWidth: number, Width: number, Height: number, Floor: number, High: number, Base: number, Spacing: number): ()
	Target.MaxWidth = MaxWidth
	Target.Width = Width
	Target.Height = Height
	Target.Floor = Floor
	Target.High = High
	Target.Base = Base
	Target.Spacing = Spacing
end

const function Same(Left: Problem, Right: Problem): boolean
	return Left.Width == Right.Width
		and Left.Height == Right.Height
		and Left.MaxWidth == Right.MaxWidth
		and Left.Floor == Right.Floor
		and Left.High == Right.High
		and Left.Base == Right.Base
		and Left.Spacing == Right.Spacing
end

const function Obtain(State: Types.Fields): Bracket
	const Existing: Bracket? = Brackets[State]; if Existing then return Existing :: Bracket end

	const Below: Model = NewModel()
	const Created: Bracket = {
		State = State;
		Problem = NewProblem();
		Measured = {Current = 0, Minimum = 0, Longest = 0, Monotone = false};
		Known = {Yes = 0, No = 0};
		Goal = {Target = 0, Size = 0};
		Crawl = {Rising = false, Anchor = 0, Limit = 0, Model = Below};
		Models = {Below = Below, Above = NewModel(), Last = Below};
		Ends = {Tokens = {}, Ready = false};
	}

	Brackets[State] = Created

	return Created
end

const function Terminals(Bracket: Bracket): { [Types.Token]: boolean }
	const Ends: Types.EndData = Bracket.Ends
	const Found: { [Types.Token]: boolean } = Ends.Tokens
	if Ends.Ready then return Found end

	const Tokens: { Types.Token } = Bracket.State.Document.Tokens

	table.clear(Found)

	for Index: number, Token: Types.Token in (Tokens) do
		const Next: Types.Token? = Tokens[Index + 1]
		if not Next or Next.Kind == "Break" or Next.Block then Found[Token] = true end
	end

	Ends.Ready = true

	return Found
end

const function Begin(Bracket: Bracket): ()
	const State: Types.Fields = Bracket.State
	const Measured: Types.MeasuredData = Bracket.Measured
	const Models: Types.ModelData = Bracket.Models
	const Current: number = State.Scale.Measured

	local Longest: number = 0
	local Tallest: number? = nil
	local Monotone: boolean = true

	for _, Token: Types.Token in (State.Document.Tokens) do
		if Token.Kind == "Break" or Token.Block then continue end
		if Token.Width > Longest then Longest = Token.Width end

		if Tallest == nil then Tallest = Token.Height elseif math.abs(Token.Height - Tallest :: number) > HeightTolerance then Monotone = false end
	end

	Measured.Current = Current
	Measured.Minimum = Measure.Scaled(Bracket.Problem.Base, Current)
	Measured.Longest = Longest
	Measured.Monotone = Monotone
	Bracket.Known.Yes = Bracket.Problem.Floor
	Bracket.Known.No = Bracket.Problem.High
	Models.Below.Anchor = 0
	Models.Above.Anchor = 0
	Models.Last = Models.Below
end

const function Survey(Bracket: Bracket, Model: Model, Computed: { Types.Line }, Heights: { number }, Ratio: number): ()
	const Problem: Problem = Bracket.Problem
	const Rows: { number } = Model.Rows
	const Ends: { [Types.Token]: boolean } = Terminals(Bracket)
	const Minimum: number = Bracket.Measured.Minimum * Ratio
	const Spacing: number = Problem.Spacing
	const Width: number = Problem.Width
	const Wrapping: boolean = Problem.MaxWidth < math.huge
	const Count: number = #Computed
	const Spaces: { [Types.Style]: number } = Bracket.State.Document.SpaceWidths

	local Paragraphs: number = 0
	local Merge: number = 0
	local Sum: number = 0
	local Slack: number = 0
	local Span: number = 0

	for Index: number, Line: Types.Line in (Computed) do
		const Items: { Types.Token } = Line.Items
		const First: Types.Token? = Items[1]
		const Last: Types.Token? = Items[#Items]
		const Block: boolean = First ~= nil and (First :: Types.Token).Block == true
		const Row: number = if Block then (First :: Types.Token).Height * Ratio else math.max(Line.Height, Minimum) * Spacing

		Rows[Index] = if math.floor(Row + 0.5) == Heights[Index] then Row else Heights[Index]
		Sum += Line.Width
		Span += 1

		if not (Block or Last == nil or Ends[Last :: Types.Token] or Index == Count) then
			const Next: Types.Token = Computed[Index + 1].Items[1]
			const Style: Types.Style? = Next.Style or (Last :: Types.Token).Style
			const Space: number = if Next.SpaceBefore and Style then (Spaces[Style :: Types.Style] or 0) * Ratio else 0

			Slack += Width - Line.Width
			Merge = math.max(Merge, Width / (Line.Width + Space + Next.Width * Ratio))

			continue
		end

		Paragraphs += 1
		Model.Content[Paragraphs] = if Wrapping and not Block and Last then Sum else 0
		Model.Waste[Paragraphs] = Slack
		Model.Spans[Paragraphs] = Span
		Model.Units[Paragraphs] = Rows[Index]

		Sum = 0
		Slack = 0
		Span = 0
	end

	Model.Count = Count
	Model.Paragraphs = Paragraphs
	Model.Merge = Merge
end

const function Probe(Bracket: Bracket, Factor: number): boolean
	const Problem: Problem = Bracket.Problem
	const Models: Types.ModelData = Bracket.Models
	const Ratio: number = Factor / Bracket.Measured.Current
	const Computed: { Types.Line }, Heights: { number }, Total: number, Widest: number = Lines.Compute(Bracket.State, Problem.MaxWidth, Ratio)
	const Fits: boolean = Total <= Problem.Height and Widest <= Problem.Width
	const Model: Model = if Fits then Models.Below else Models.Above

	if Fits then Bracket.Known.Yes = Factor else Bracket.Known.No = Factor end
	if not Bracket.Measured.Monotone then return Fits end

	Survey(Bracket, Model, Computed, Heights, Ratio)

	Model.Widest = Widest
	Model.Anchor = Factor
	Models.Last = Model

	return Fits
end

const function Known(Bracket: Bracket, Factor: number): boolean
	if Factor <= Bracket.Problem.Floor then return true end

	if Bracket.Measured.Monotone then
		const Verdicts: Types.KnownData = Bracket.Known

		if Factor <= Verdicts.Yes then return true end
		if Factor >= Verdicts.No then return false end
	end

	return Probe(Bracket, Factor)
end

const function Stack(Bracket: Bracket, Model: Model, Growth: number, Rewrap: boolean): number
	const Rows: { number } = Model.Rows

	local Total: number = 0

	for Index = 1, Model.Count do Total += math.floor(Rows[Index] * Growth + 0.5) end

	if not Rewrap then return Total end

	const Width: number = Bracket.Problem.Width

	for Paragraph = 1, Model.Paragraphs do
		const Content: number = Model.Content[Paragraph]
		if Content == 0 then continue end

		const Extra: number = math.max(math.ceil((Content * Growth + Model.Waste[Paragraph]) / Width), 1) - Model.Spans[Paragraph]
		if Extra ~= 0 then Total += Extra * math.floor(Model.Units[Paragraph] * Growth + 0.5) end
	end

	return Total
end

const function Reach(Bracket: Bracket, Model: Model, Factor: number): number
	if Bracket.Problem.MaxWidth < math.huge then return Bracket.Measured.Longest * Factor / Bracket.Measured.Current end

	return Model.Widest * Factor / Model.Anchor
end

const function Predict(Bracket: Bracket, Factor: number): boolean
	const Model: Model = Bracket.Models.Last
	const Problem: Problem = Bracket.Problem

	return Reach(Bracket, Model, Factor) <= Problem.Width and Stack(Bracket, Model, Factor / Model.Anchor, true) <= Problem.Height
end

const function Test(Bracket: Bracket, Mode: number, Middle: number): boolean
	if Mode == Seeding then return Middle <= Bracket.Goal.Target end
	if Mode == Bounding then return Measure.Scaled(Bracket.Problem.Base, Middle) < Bracket.Goal.Size end
	if Mode == Searching then return Known(Bracket, Middle) end

	const Verdicts: Types.KnownData = Bracket.Known

	if Mode == Guessing then return Middle <= Verdicts.Yes or (Middle < Verdicts.No and Predict(Bracket, Middle)) end

	if Middle <= Verdicts.Yes then return true end
	if Middle >= Verdicts.No then return false end

	const Crawl: Types.CrawlData = Bracket.Crawl
	const Rising: boolean = Crawl.Rising

	if Rising and Middle >= Crawl.Limit then return false end
	if not Rising and Middle <= Crawl.Limit then return true end

	const Model: Model = Crawl.Model
	const Problem: Problem = Bracket.Problem

	return Reach(Bracket, Model, Middle) <= Problem.Width and Stack(Bracket, Model, Middle / Crawl.Anchor, false) <= Problem.Height
end

const function Walk(Bracket: Bracket, Mode: number): (number, number)
	local Low: number = MinimumFactor
	local Top: number = Bracket.Problem.High

	for _ = 1, SearchSteps do
		const Middle: number = (Low + Top) / 2

		if Test(Bracket, Mode, Middle) then Low = Middle else Top = Middle end
	end

	return Low, Top
end

const function Inside(Bracket: Bracket, Low: number, Top: number): number?
	const Verdicts: Types.KnownData = Bracket.Known

	if Low > Verdicts.Yes and Low < Verdicts.No then return Low end
	if Top > Verdicts.Yes and Top < Verdicts.No then return Top end

	return nil
end

const function Estimate(Bracket: Bracket): number
	const State: Types.Fields = Bracket.State
	const Problem: Problem = Bracket.Problem
	const Spaces: { [Types.Style]: number } = State.Document.SpaceWidths
	const Minimum: number = Bracket.Measured.Minimum
	const Spacing: number = Problem.Spacing

	local Area: number = 0
	local Widest: number = 0
	local Longest: number = 0
	local Depth: number = 0
	local Row: number = 0
	local Tall: number = 0

	local Ambient: Types.Style? = nil

	for _, Token: Types.Token in (State.Document.Tokens) do
		if Token.Kind == "Break" then
			Ambient = nil
			Depth += math.max(Tall, Minimum) * Spacing
			Longest = math.max(Longest, Row)
			Row = 0
			Tall = 0

			continue
		end

		const Style: Types.Style? = Token.Style or Ambient
		const Width: number = Token.Width + (if Token.SpaceBefore and Style then Spaces[Style :: Types.Style] or 0 else 0)

		if Token.Style then Ambient = Token.Style end

		Area += Width * math.max(Token.Height, Minimum) * Spacing
		Row += Width
		Widest = math.max(Widest, Token.Width)
		Tall = math.max(Tall, Token.Height)
	end

	Depth += math.max(Tall, Minimum) * Spacing
	Longest = math.max(Longest, Row)

	const Width: number = Problem.Width
	const Height: number = Problem.Height
	const Ratio: number = if Problem.MaxWidth < math.huge
		then math.min(Height / math.max(Depth, 1), Width / math.max(Widest, 1), math.sqrt(Width * Height / math.max(Area, 1)))
		else math.min(Height / math.max(Depth, 1), Width / math.max(Longest, 1))

	return Bracket.Measured.Current * Ratio
end

const function Seed(Bracket: Bracket): ()
	Bracket.Goal.Target = Estimate(Bracket)

	const Low: number, Top: number = Walk(Bracket, Seeding)
	const Point: number? = Inside(Bracket, Low, Top)

	if Point then Probe(Bracket, Point :: number) end
end

const function Guess(Bracket: Bracket): (number?, boolean)
	if Bracket.Models.Last.Anchor == 0 then return nil, false end

	const Low: number, Top: number = Walk(Bracket, Guessing)
	const Verdicts: Types.KnownData = Bracket.Known

	if Low > Verdicts.Yes then return if Top < Verdicts.No or Verdicts.No == Bracket.Problem.High then Low else nil, true end
	if Top < Verdicts.No then return Top, false end

	return nil, false
end

const function Crawl(Bracket: Bracket): boolean
	const Models: Types.ModelData = Bracket.Models
	const Rising: boolean = Models.Below.Anchor ~= 0
	const Model: Model = if Rising then Models.Below else Models.Above
	if Model.Anchor == 0 or Model.Widest <= 0 then return false end

	const Anchor: number = Model.Anchor
	const Crawler: Types.CrawlData = Bracket.Crawl

	Crawler.Rising = Rising
	Crawler.Model = Model
	Crawler.Anchor = Anchor
	Crawler.Limit = if Rising then Anchor * Bracket.Problem.Width / Model.Widest else Anchor * Model.Merge

	const Low: number, Top: number = Walk(Bracket, Crawling)
	const Point: number? = Inside(Bracket, Low, Top)

	return Point ~= nil and Probe(Bracket, Point :: number)
end

const function Narrow(Bracket: Bracket): ()
	if Bracket.Models.Last.Anchor == 0 then Seed(Bracket) end
	if Bracket.Models.Below.Anchor == 0 then Crawl(Bracket) end

	for _ = 1, GuessSteps do
		const Point: number?, Expected: boolean = Guess(Bracket); if not Point then break end
		if Probe(Bracket, Point :: number) ~= Expected then break end
	end

	for _ = 1, CrawlSteps do
		if not Crawl(Bracket) then break end
	end
end

const function Search(Bracket: Bracket): number
	if Bracket.Measured.Monotone then Narrow(Bracket) end

	const Low: number, _Top: number = Walk(Bracket, Searching)

	return math.max(Low, Bracket.Problem.Floor)
end

const function Boundary(Bracket: Bracket, Size: number): number
	const Base: number = Bracket.Problem.Base
	if Measure.Scaled(Base, MinimumFactor) >= Size then return MinimumFactor end

	Bracket.Goal.Size = Size

	const _Low: number, Top: number = Walk(Bracket, Bounding)

	return Top
end

const function Settled(Bracket: Bracket, Factor: number): boolean
	const Size: number = Measure.Scaled(Bracket.Problem.Base, Factor)
	const Upper: number = Boundary(Bracket, Size + 1)

	if Upper < Bracket.Problem.High and Known(Bracket, Upper) then return false end
	if Known(Bracket, Factor) then return true end

	const Lower: number = Boundary(Bracket, Size)

	return Lower <= MinimumFactor or Known(Bracket, Lower)
end

const function Advance(Bracket: Bracket, Factor: number): number?
	if Bracket.Measured.Monotone then return if Settled(Bracket, Factor) then nil else Search(Bracket) end

	const Next: number = Search(Bracket)
	const Base: number = Bracket.Problem.Base

	return if Measure.Scaled(Base, Next) == Measure.Scaled(Base, Factor) then nil else Next
end

const function Limits(State: Types.Fields, BoxHeight: number, BaseSize: number): (number, number)
	const Bounds: Types.LimitsData? = State.Limits
	const Constraint: UITextSizeConstraint? = State.Label:FindFirstChildWhichIsA("UITextSizeConstraint")

	local Smallest: number = if Bounds then (Bounds :: Types.LimitsData).TextSize.Min or 0 else 0
	local Largest: number = math.min(BoxHeight, Styles.MaximumTextSize, if Bounds then (Bounds :: Types.LimitsData).TextSize.Max or math.huge else math.huge)

	if Constraint then
		Smallest = math.max(Smallest, (Constraint :: UITextSizeConstraint).MinTextSize)
		Largest = math.min(Largest, (Constraint :: UITextSizeConstraint).MaxTextSize)
	end

	const Floor: number = math.max(Smallest / BaseSize, MinimumFactor)

	return Floor, math.max(Largest / BaseSize, Floor)
end

const function Gauge(State: Types.Fields, Factor: number): boolean
	if not Profiler.Enabled then return Measure.Run(State, Factor) end

	Profiler.Begin("RTP:Measure")
	const Measured: boolean = Measure.Run(State, Factor)
	Profiler.End()

	return Measured
end

const function Remeasure(State: Types.Fields, Factor: number, MaxWidth: number): boolean
	return Gauge(State, Factor) and Reflow.Fit(State, MaxWidth, Factor)
end

const function Recall(State: Types.Fields, Bracket: Bracket): number?
	const Memo: Memo? = Memos[State]; if not Memo then return nil end

	const Found: Memo = Memo :: Memo

	if Found.Tokens ~= State.Document.Tokens or Found.Text ~= State.Generation.Text then
		Found.Tokens = nil
		table.clear(Found.Solutions)

		return nil
	end

	for _, Solution: Solution in (Found.Solutions) do
		if not Same(Solution.Problem, Bracket.Problem) then continue end

		Found.Clock += 1
		Solution.Used = Found.Clock

		return Solution.Factor
	end

	return nil
end

const function Store(State: Types.Fields, Bracket: Bracket, Factor: number): ()
	const Memo: Memo = Memos[State] or {Tokens = nil, Text = 0, Clock = 0, Solutions = {}}
	const Solutions: { Solution } = Memo.Solutions

	Memos[State] = Memo

	if Memo.Tokens ~= State.Document.Tokens or Memo.Text ~= State.Generation.Text then
		Memo.Tokens = State.Document.Tokens
		Memo.Text = State.Generation.Text
		table.clear(Solutions)
	end

	local Slot: Solution? = nil

	if #Solutions >= SolutionLimit then
		for _, Solution: Solution in (Solutions) do
			if not Slot or Solution.Used < (Slot :: Solution).Used then Slot = Solution end
		end
	end

	const Target: Solution = Slot or {Problem = NewProblem(), Factor = 0, Used = 0}
	const Source: Problem = Bracket.Problem

	if not Slot then table.insert(Solutions, Target) end

	Memo.Clock += 1

	Pose(Target.Problem, Source.MaxWidth, Source.Width, Source.Height, Source.Floor, Source.High, Source.Base, Source.Spacing)
	Target.Factor = Factor
	Target.Used = Memo.Clock
end

const function Balance(State: Types.Fields): boolean
	const Label: TextLabel = State.Label
	const Ratio: number = Styles.AncestorScale(Label)
	const Size: Vector2 = Styles.ContentSize(Label, Ratio)
	const BoxWidth: number = math.max(Size.X, Styles.MinimumBoxWidth)
	const BoxHeight: number = math.max(Size.Y, MinimumBoxHeight)
	const MaxWidth: number = if Label.TextWrapped then BoxWidth else math.huge
	const BaseSize: number = Styles.BaseSize(State)
	const Floor: number, High: number = Limits(State, BoxHeight, BaseSize)
	const Bracket: Bracket = Obtain(State)

	State.Scale.Ancestor = Ratio

	Pose(Bracket.Problem, MaxWidth, BoxWidth, BoxHeight, Floor, High, BaseSize, Label.LineHeight)
	Bracket.Ends.Ready = false

	const Recalled: number? = Recall(State, Bracket)

	if Recalled then
		if State.Scale.Measured ~= Recalled and not Remeasure(State, Recalled :: number, MaxWidth) then return false end

		State.Scale.Factor = Recalled :: number

		return true
	end

	if State.Scale.Measured == 0 and not Gauge(State, State.Scale.Factor) then return false end
	if not Reflow.Fit(State, MaxWidth, State.Scale.Measured) then return false end

	Begin(Bracket)

	local Factor: number = Search(Bracket)

	for Step = 1, RefineSteps do
		if State.Scale.Measured ~= Factor then
			if not Remeasure(State, Factor, MaxWidth) then return false end

			Begin(Bracket)
		end

		if Step == RefineSteps then break end

		const Next: number? = Advance(Bracket, Factor); if not Next then break end

		Factor = Next :: number
	end

	for _ = 1, ShrinkSteps do
		if Factor <= Floor or Known(Bracket, Factor) then break end

		Factor = math.max((Measure.Scaled(BaseSize, Factor) - 1) / BaseSize, Floor)
		if not Remeasure(State, Factor, MaxWidth) then return false end

		Begin(Bracket)
	end

	State.Scale.Factor = Factor
	Store(State, Bracket, Factor)

	return true
end

const function Solve(State: Types.Fields): boolean
	if State.Destroyed then return false end

	if not State.Label.TextScaled then
		State.Scale.Factor = 1

		return State.Scale.Measured == 1 or Gauge(State, 1)
	end

	if not Profiler.Enabled then return Balance(State) end

	Profiler.Begin("RTP:Scale")
	const Solved: boolean = Balance(State)
	Profiler.End()

	return Solved
end

return {
	Echo = Echo;
	Release = Release;
	Enforce = Enforce;
	Fit = Fit;
	Solve = Solve;
}
