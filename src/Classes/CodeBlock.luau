--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Measure = require("../Text/Measure")
const Reflow = require("../Utility/Reflow")
const Markdown = require("../Markdown")
const Highlighter = require("../Text/Highlighter")
const Intents = require("../Policy/Intents")
const Profiler = require("../Utility/Profiler")
const Characters = require("../Utility/Characters")
const Unicode = require("../Text/Unicode")

type Metrics = {
	Style: Types.Style;
	Size: number;
	Mono: number?;
	Line: number;
	Bytes: { [number]: number };
}

type Plan = Types.CodePlan

const HighlightedLanguages: { [string]: boolean } = Config.Classes.HIGHLIGHTED_LANGUAGES
const CodeBlocks: number = Intents.Flags.CodeBlocks

const UniformRanges: { { number } } = {
	{0x3041, 0x3096};
	{0x30A1, 0x30FA};
	{0x3400, 0x4DBF};
	{0x4E00, 0x9FFF};
	{0xAC00, 0xD7A3};
	{0xF900, 0xFAFF};
	{0x20000, 0x3FFFD};
}

const UniformGlyphs: { string } = {"あ", "ア", "中", "中", "가", "中", "中"}

const SpaceByte: number = Characters.SPACE
const AsciiLimit: number = Characters.ASCII_LIMIT
const TwoByteLimit: number = 0xE0
const ThreeByteLimit: number = 0xF0
const TagByte: number = 60
const EntityByte: number = 38
const WrapTolerance: number = Config.Classes.CODE_WRAP_TOLERANCE
const LayoutLimit: number = Config.Classes.CODE_LAYOUT_LIMIT
const MetricsLimit: number = Config.Classes.CODE_METRICS_LIMIT
const MarginRatio: number = Config.Classes.CODE_MARGIN_RATIO
const HeaderRatio: number = Config.Classes.CODE_HEADER_RATIO

const Extract = bit32.extract
const Lshift = bit32.lshift

const MetricsCache: { [string]: Metrics } = {}

local MetricsCount: number = 0

const function Body(Node: Types.Node): string
	local Code: string = (string.gsub(Styles.InnerText(Node), "\r\n?", "\n"))
	Code = (string.gsub(Code, "\t", "    "))
	Code = (string.gsub(Code, "^\n", ""))

	return Styles.TrimEnd(Code)
end

const function Extent(Metrics: Metrics, Text: string): number
	return Measure.Bounds(Metrics.Style, Metrics.Size, Text, false).X
end

const function MetricsFor(Style: Types.Style, Size: number): Metrics
	const Key: string = `{Style.Family}|{Size}`
	const Cached: Metrics? = MetricsCache[Key]; if Cached then return Cached :: Metrics end

	if MetricsCount >= MetricsLimit then table.clear(MetricsCache); MetricsCount = 0 end

	const Wide: Vector2 = Measure.Bounds(Style, Size, "M", false)
	const Narrow: number = Measure.Bounds(Style, Size, "i", false).X
	const Created: Metrics = {
		Style = Style;
		Size = Size;
		Mono = if Narrow > 0 and Narrow == Wide.X then Narrow else nil;
		Line = if Wide.Y > 0 then Wide.Y else Size;
		Bytes = {};
	}

	MetricsCache[Key] = Created
	MetricsCount += 1

	return Created
end

const function Decode(Line: string, Position: number, Size: number): number
	const Lead: number = string.byte(Line, Position)
	const Second: number = string.byte(Line, Position + 1) or 0
	const Third: number = string.byte(Line, Position + 2) or 0

	if Size == 3 then return Lshift(Extract(Lead, 0, 4), 12) + Lshift(Extract(Second, 0, 6), 6) + Extract(Third, 0, 6) end

	const Fourth: number = string.byte(Line, Position + 3) or 0

	return Lshift(Extract(Lead, 0, 3), 18) + Lshift(Extract(Second, 0, 6), 12) + Lshift(Extract(Third, 0, 6), 6) + Extract(Fourth, 0, 6)
end

const function Uniform(Code: number): string?
	const Index: number? = Unicode.Locate(Code, UniformRanges)

	return if Index then UniformGlyphs[Index :: number] else nil
end

const function Glyph(Metrics: Metrics, Line: string, Position: number, Size: number): number
	const Character: string = string.sub(Line, Position, Position + Size - 1)
	if Size < 3 then return Extent(Metrics, Character) end

	return Extent(Metrics, Uniform(Decode(Line, Position, Size)) or Character)
end

const function Ascii(Metrics: Metrics, Byte: number): number
	const Mono: number? = Metrics.Mono; if Mono then return Mono :: number end
	const Known: number? = Metrics.Bytes[Byte]; if Known then return Known :: number end

	const Measured: number = Extent(Metrics, string.char(Byte))
	Metrics.Bytes[Byte] = Measured

	return Measured
end

const function Breaks(Rows: { string }, Metrics: Metrics, Limit: number, Into: { number }, Hangs: { number }): (number, number)
	const Space: number = Ascii(Metrics, SpaceByte)

	local Lines: number = 0
	local Widest: number = 0
	local Offset: number = 0

	for _, Line: string in (Rows) do
		Lines += 1

		const Length: number = #Line
		const Lead: number = #(string.match(Line, "^ *") :: string)
		const Hang: number = if Lead * Space <= Limit / 2 then Lead else 0
		const HangWidth: number = Hang * Space

		local X: number = 0
		local Position: number = 1
		local Opportunity: number? = nil
		local Reached: number = 0

		while Position <= Length do
			const Byte: number = string.byte(Line, Position)
			const Size: number = if Byte < AsciiLimit then 1 elseif Byte < TwoByteLimit then 2 elseif Byte < ThreeByteLimit then 3 else 4
			const Advance: number = if Size == 1 then Ascii(Metrics, Byte) else Glyph(Metrics, Line, Position, Size)

			if Position > 1 and X + Advance > Limit + WrapTolerance then
				const At: number = Opportunity or Position

				Widest = math.max(Widest, if Opportunity then Reached else X)
				X = HangWidth + (if Opportunity then X - Reached else 0)
				Opportunity = nil
				Lines += 1

				table.insert(Into, Offset + At)
				table.insert(Hangs, Hang)
			end

			X += Advance

			if Byte == SpaceByte and Position > Lead then
				Opportunity = Position + 1
				Reached = X
			end

			Position += Size
		end

		Widest = math.max(Widest, X)
		Offset += Length + 1
	end

	return Lines, Widest
end

const function Insert(Text: string, Rich: boolean, Into: { number }, Hangs: { number }): string
	if #Into == 0 then return Text end

	const Parts: { string } = {}
	const Length: number = #Text

	local Plain: number = 1
	local Position: number = 1
	local Cursor: number = 1
	local Next: number = 1

	while Position <= Length and Next <= #Into do
		const Byte: number = string.byte(Text, Position)

		if Rich and Byte == TagByte then
			Position = (string.find(Text, ">", Position, true) or Length) + 1

			continue
		end

		if Plain == Into[Next] then
			table.insert(Parts, string.sub(Text, Cursor, Position - 1))
			table.insert(Parts, "\n" .. string.rep(" ", Hangs[Next]))

			Cursor = Position
			Next += 1

			continue
		end

		Position = if Rich and Byte == EntityByte then (string.find(Text, ";", Position, true) or Position) + 1 else Position + 1
		Plain += 1
	end

	table.insert(Parts, string.sub(Text, Cursor))

	return table.concat(Parts)
end

const function Label(Name: string, Text: string, Face: Font, Size: number, Color: Color3): TextLabel
	const Result: TextLabel = Instance.new("TextLabel")
	Result.Name = Name
	Result.AutoLocalize = false
	Result.BackgroundTransparency = 1
	Result.BorderSizePixel = 0
	Result.FontFace = Face
	Result.TextSize = Size
	Result.TextColor3 = Color
	Result.TextXAlignment = Enum.TextXAlignment.Left
	Result.TextYAlignment = Enum.TextYAlignment.Top
	Result.TextWrapped = false
	Result.Text = Text

	return Result
end

const function Language(Node: Types.Node): string
	return Styles.Attribute(Node, "Lang") or ""
end

const function Highlights(Tagged: string, State: Types.Fields?): boolean
	const Theme: Types.Theme? = if State then State.Theme else nil
	const Fallback: string? = if Theme then (Theme :: Types.Theme).CodeLanguage else nil
	const Effective: string = if Tagged ~= "" then Tagged else Fallback or ""

	return HighlightedLanguages[string.lower(Effective)] == true
end

const function Build(Node: Types.Node, Style: Types.Style, Scale: number, State: Types.Fields?): GuiObject?
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:CodeBlock") end

	const Theme: Markdown.ResolvedTheme = Markdown.Theme(if State then State.Theme else nil)
	const Styled: boolean = not State or bit32.btest((State :: Types.Fields).Intents.Bitfield, CodeBlocks)
	const Coloring: boolean = Styled and (not State or (State :: Types.Fields).Rendering.SyntaxHighlight)

	const Tagged: string = Language(Node)
	const Highlighted: boolean = Coloring and Highlights(Tagged, State)

	const Code: string = Body(Node)
	const Text: string = if Highlighted then Highlighter.Highlight(Code, Theme.Syntax) else Code
	const Face: Font = Font.new(Styles.ResolveFamily(Theme.CodeFamily))
	const Color: Color3 = if Styled then (if Theme.Syntax then Theme.Syntax.Text else nil) or Theme.CodeTextColor else Style.Color
	const Rows: { string } = string.split(Code, "\n")

	const Metric: Types.Style = {
		Bold = false;
		Italic = false;
		Underline = false;
		Strike = false;
		Color = Color;
		Size = Style.Size;
		Family = Face.Family;
		Transparency = 0;
	}

	const Plans: { [number]: { [number]: Plan } } = {}
	local Stored: number = 0
	local Shown: Plan? = nil

	const function Compose(Size: number, Inner: number): Plan
		const Ratio: number = Scale * Size / math.max(Style.Size, 1)
		const Padding: number = if Styled then math.floor(Theme.CodePadding * Ratio + 0.5) else 0
		const Margin: number = if Styled then math.floor(Size * MarginRatio + 0.5) else 0
		const Header: number = if Styled and Tagged ~= "" then math.floor(Size * HeaderRatio + 0.5) else 0
		const Gap: number = if Header > 0 then math.floor(Padding * 0.5 + 0.5) else 0
		const Metrics: Metrics = MetricsFor(Metric, Size)
		const Into: { number } = {}
		const Hangs: { number } = {}
		const Limit: number = if Inner < math.huge then math.max(Inner - Padding * 2, 1) else math.huge
		const Lines: number, Widest: number = Breaks(Rows, Metrics, Limit, Into, Hangs)
		const Body: number = math.floor(Lines * Metrics.Line + 0.5)
		const Panel: number = Padding * 2 + Header + Gap + Body

		return {
			Text = Insert(Text, Highlighted, Into, Hangs);
			Lines = Lines;
			Size = Size;
			Outer = {Width = math.ceil(Widest) + Padding * 2, Height = Panel + Margin * 2};
			Panel = {
				Margin = Margin;
				Padding = Padding;
				Header = Header;
				Gap = Gap;
				Body = Body;
				Height = Panel;
				Radius = if Styled then math.floor(Theme.CodeCornerRadius * Ratio + 0.5) else 0;
			};
		}
	end

	const function Resolve(Width: number, Factor: number): Plan
		const Size: number = Measure.Scaled(Style.Size, Factor)
		const Inner: number = if Width < math.huge then math.max(math.floor(Width), 1) else math.huge
		const Existing: { [number]: Plan }? = Plans[Size]
		const Cached: Plan? = if Existing then (Existing :: { [number]: Plan })[Inner] else nil
		if Cached then return Cached :: Plan end

		const Created: Plan = Compose(Size, Inner)

		if Stored >= LayoutLimit then table.clear(Plans); Stored = 0 end

		const Sized: { [number]: Plan } = Plans[Size] or {}
		Plans[Size] = Sized
		Sized[Inner] = Created
		Stored += 1

		return Created
	end

	const Frame: Frame = Instance.new("Frame")
	Frame.Name = "CodeBlock"
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0

	const Panel: Frame = Instance.new("Frame")
	Panel.Name = "Panel"
	Panel.BackgroundColor3 = Theme.CodeBackground
	Panel.BackgroundTransparency = if Styled then Theme.CodeBackgroundTransparency else 1
	Panel.BorderSizePixel = 0
	Panel.ClipsDescendants = true
	Panel.Parent = Frame

	const Corner: UICorner? = if Styled then Instance.new("UICorner") else nil
	const Inset: UIPadding? = if Styled then Instance.new("UIPadding") else nil

	if Corner then Corner.Parent = Panel end
	if Inset then Inset.Parent = Panel end

	const Caption: TextLabel? = if Styled and Tagged ~= "" then Label("Language", Tagged, Face, Style.Size, Color) else nil

	if Caption then
		Caption.TextTransparency = 0.45
		Caption.Parent = Panel
	end

	const Body: TextLabel = Label("Code", Text, Face, Style.Size, Color)
	Body.RichText = Highlighted
	Body.TextTransparency = Style.Transparency
	Body.Parent = Panel

	const function Apply(Width: number, Factor: number): ()
		const Current: Plan = Resolve(Width, Factor)
		const Previous: Plan? = Shown
		if Previous == Current then return end

		Shown = Current

		const Fresh: boolean = Previous == nil
		const Last: Plan = Previous or Current
		const Was: Types.PanelData = Last.Panel
		const Now: Types.PanelData = Current.Panel

		if (if Fresh then Body.Text ~= Current.Text else Last.Text ~= Current.Text) then Body.Text = Current.Text end
		if Fresh or Last.Size ~= Current.Size then Body.TextSize = Current.Size end
		if Fresh or Was.Header + Was.Gap ~= Now.Header + Now.Gap then Body.Position = UDim2.fromOffset(0, Now.Header + Now.Gap) end
		if Fresh or Was.Body ~= Now.Body then Body.Size = UDim2.new(1, 0, 0, Now.Body) end
		if Fresh or Was.Margin ~= Now.Margin then Panel.Position = UDim2.fromOffset(0, Now.Margin) end
		if Fresh or Was.Height ~= Now.Height then Panel.Size = UDim2.new(1, 0, 0, Now.Height) end
		if Corner and (Fresh or Was.Radius ~= Now.Radius) then Corner.CornerRadius = UDim.new(0, Now.Radius) end

		if Inset and (Fresh or Was.Padding ~= Now.Padding) then
			const Padding: UDim = UDim.new(0, Now.Padding)

			Inset.PaddingTop = Padding
			Inset.PaddingBottom = Padding
			Inset.PaddingLeft = Padding
			Inset.PaddingRight = Padding
		end

		if Caption and (Fresh or Was.Header ~= Now.Header) then
			Caption.TextSize = Now.Header
			Caption.Size = UDim2.new(1, 0, 0, Now.Header)
		end
	end

	Reflow.Register(Frame, function(Width: number, Factor: number): Vector2
		const Outer: Types.SizeData = Resolve(Width, Factor).Outer

		return Vector2.new(Outer.Width, Outer.Height)
	end, Apply)

	const Natural: Types.SizeData = Resolve(math.huge, 1).Outer
	Apply(math.huge, 1)
	Frame.Size = UDim2.fromOffset(Natural.Width, Natural.Height)

	if Profiling then Profiler.End() end

	return Frame
end

return {
	Kind = "Object";
	Block = true;
	Build = Build;
	Body = Body;
}
