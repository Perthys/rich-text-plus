--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const Layout = require("../Packages/RichTextPlus/Core/Layout")
const Lines = require("../Packages/RichTextPlus/Core/Lines")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Config = {
	Width: number,
	Height: number,
	Wrapped: boolean,
	XAlignment: Enum.TextXAlignment,
	YAlignment: Enum.TextYAlignment,
	Truncate: Enum.TextTruncate,
	AutomaticSize: Enum.AutomaticSize,
	LineHeight: number,
	Padding: number,
	Scaled: boolean,
}

const Library: any = RichTextPlus
const LayoutModule: any = Layout
const LinesModule: any = Lines
const Counters: any = LayoutModule.Counters

const Filler: string = "the quick brown fox jumps over the lazy dog while the text keeps going for a while"

const Documents: { { string } } = {
	{"plain", `{Filler} {Filler}`},
	{"styled", `<b>bold start</b> then <i>italic words</i> and <font color="#ff8800">orange text</font> plus <font size="24">big</font> words <a href="https://x.test">a link that wraps across lines</a> end`},
	{"marks", `A <mark color="#806000">alpha <b>bold</b> <i>word</i> gamma delta epsilon</mark> B <code>alpha beta gamma delta</code> tail <mark color="#306090">m <code>c</code> n</mark>`},
	{"indent", `Label: <indent>{Filler}</indent><br/><indent by="40">{Filler}</indent>`},
	{"markdown", `<md>- {Filler}\n  - nested {Filler}\n1. {Filler}\n> quoted {Filler}</md>`},
	{"breaks", `one<br/><br/>two words here<br/>  <br/>three {Filler}<br/>`},
	{"code", `before <codeblock lang="lua">local function Example(Argument)\n    return Argument .. " a long string literal that keeps going"\nend</codeblock> after words`},
	{"bidi", "hello שלום עולם world مرحبا بالعالم again שלום more words here"},
	{"chop", "short supercalifragilisticexpialidocioussupercalifragilistic words and more words"},
	{"image", `start <img src="rbxassetid://1" size="20"/> middle words <img src="rbxassetid://2" width="30" height="16"/> end of the line`},
	{"decor", `<u>under line</u> and <s>struck words</s> and <uc>upper case</uc> text`},
}

const Widths: { number } = {120, 170, 230, 300, 377, 460, 640}
const Heights: { number } = {40, 90, 150, 600}
const XAlignments: { Enum.TextXAlignment } = {Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right}
const YAlignments: { Enum.TextYAlignment } = {Enum.TextYAlignment.Top, Enum.TextYAlignment.Center, Enum.TextYAlignment.Bottom}
const Truncations: { Enum.TextTruncate } = {Enum.TextTruncate.None, Enum.TextTruncate.AtEnd, Enum.TextTruncate.SplitWord}
const Automatics: { Enum.AutomaticSize } = {Enum.AutomaticSize.None, Enum.AutomaticSize.Y, Enum.AutomaticSize.X}

local Screen: ScreenGui
const Renderers: { any } = {}

const function Format(Value: number): string
	return string.format("%.3f", Value)
end

const function Snapshot(Target: TextLabel, Renderer: any): string
	const Rows: { string } = {`Host {Target.AbsoluteSize.X}x{Target.AbsoluteSize.Y}`}

	for _, Child: Instance in Target:GetChildren() do
		if not Child:IsA("GuiObject") or not (Child :: GuiObject).Visible then continue end

		const Object: GuiObject = Child :: GuiObject
		const Frame: string = `{Object.ClassName}:{Object.Name}@{Format(Object.Position.X.Offset)},{Format(Object.Position.Y.Offset)}/{Object.Size.X.Offset}x{Object.Size.Y.Offset}`

		if Object:IsA("TextLabel") or Object:IsA("TextButton") then
			const Text: TextLabel = Object :: any
			table.insert(Rows, `{Frame}|{Text.Text}|{Text.TextSize}|{Text.TextColor3:ToHex()}|{Text.FontFace.Weight.Name}|{Text.FontFace.Style.Name}|{tostring(Text.RichText)}|{Text.MaxVisibleGraphemes}`)
		elseif Object.Name == "Backdrops" then
			for _, Layer: Instance in Object:GetChildren() do
				if not (Layer :: GuiObject).Visible then continue end

				const Backdrop: Frame = Layer :: Frame
				const Fill: Frame? = Backdrop:FindFirstChild("Fill") :: Frame?
				const Painted: Frame = if Backdrop.ClipsDescendants and Fill and Fill.Visible then Fill :: Frame else Backdrop
				const Color: string = if Painted.BackgroundTransparency >= 1 then "-" else Painted.BackgroundColor3:ToHex()

				table.insert(Rows, `Backdrop@{Backdrop.Position.X.Offset},{Backdrop.Position.Y.Offset}/{Backdrop.Size.X.Offset}x{Backdrop.Size.Y.Offset}|{Color}|{tostring(Backdrop.ClipsDescendants)}`)
			end
		elseif Object.Name == "CodeBlock" then
			const Body: TextLabel? = Object:FindFirstChild("Code", true) :: TextLabel?
			table.insert(Rows, `{Frame}|{if Body then Body.Text else "-"}|{if Body then Body.Size.Y.Offset else 0}`)
		else
			table.insert(Rows, Frame)
		end
	end

	table.sort(Rows)

	const Groups: { string } = {}
	for _, Group: any in ElementsModule.Query(Renderer, ElementsModule.Selector.Compile("a", 1), false) do
		table.insert(Groups, `{Group:GetAttribute("href")}={Group.Text}={#(Group.Records or {})}`)
	end

	return `{table.concat(Rows, "\n")}\n#links {table.concat(Groups, ";")}`
end

const function Structure(Renderer: any): string
	const Computed: { any }, Heights: { number }, Total: number, Widest: number = LinesModule.Current(Renderer)
	const Parts: { string } = {`total {Total} widest {Format(Widest)} lines {#Computed}`}

	for Index: number, Line: any in Computed do
		const Items: { string } = {}
		for _, Token: any in Line.Items do table.insert(Items, `{tostring(Token.Text or Token.Kind)}@{Format(Token.X)}`) end

		const Leads: { string } = {}
		for _, Token: any in Line.Leads or {} do table.insert(Leads, `{tostring(Token.Text)}@{Format(Token.X)}`) end

		table.insert(Parts, `{Index} h{Heights[Index]} w{Format(Line.Width)} t{Format(Line.Height)} [{table.concat(Leads, " ")}] {table.concat(Items, " ")}`)
	end

	return table.concat(Parts, "\n")
end

const function Diff(Name: string, Actual: string, Expected: string): string?
	if Actual == Expected then return nil end

	const Left: { string } = string.split(Actual, "\n")
	const Right: { string } = string.split(Expected, "\n")

	for Index = 1, math.max(#Left, #Right) do
		if Left[Index] == Right[Index] then continue end

		return `{Name}: row {Index}\n  cached {tostring(Left[Index])}\n  fresh  {tostring(Right[Index])}`
	end

	return `{Name}: differs`
end

const function Match(Name: string, Actual: string, Expected: string): ()
	Expect(Diff(Name, Actual, Expected)).toBeNil()
end

const function Build(Target: TextLabel): any
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):SetRendering("Culling", false):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Configure(Target: TextLabel, Config: Config): ()
	Target.Size = UDim2.fromOffset(Config.Width, Config.Height)
	Target.TextWrapped = Config.Wrapped
	Target.TextScaled = Config.Scaled
	Target.TextXAlignment = Config.XAlignment
	Target.TextYAlignment = Config.YAlignment
	Target.TextTruncate = Config.Truncate
	Target.AutomaticSize = Config.AutomaticSize
	Target.LineHeight = Config.LineHeight

	local Padding: UIPadding? = Target:FindFirstChildOfClass("UIPadding")

	if Config.Padding == 0 then
		if Padding then (Padding :: UIPadding):Destroy() end

		return
	end

	if not Padding then
		const Created: UIPadding = Instance.new("UIPadding")
		Created.Parent = Target
		Padding = Created
	end

	const Inset: UDim = UDim.new(0, Config.Padding)
	if (Padding :: UIPadding).PaddingLeft ~= Inset then (Padding :: UIPadding).PaddingLeft = Inset end
	if (Padding :: UIPadding).PaddingTop ~= Inset then (Padding :: UIPadding).PaddingTop = Inset end
end

const function Label(Text: string, Config: Config): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.TextSize = 18
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Text = Text
	Configure(Created, Config)
	Created.Parent = Screen

	return Created
end

const function Relayout(Renderer: any): ()
	Renderer:Flush()
	if not Renderer.Native.Active then LayoutModule.Run(Renderer) end
end

const function Settle(Renderer: any): ()
	local _Read: Vector2 = Renderer.Label.AbsoluteSize
	task.wait()
	Relayout(Renderer)
end

const function Fresh(Name: string, Target: TextLabel, Renderer: any, Config: Config, Text: string): ()
	const Created: TextLabel = Label(Text, Config)
	const Reference: any = Build(Created)

	Settle(Reference)

	const Problem: string? = Diff(Name, Snapshot(Target, Renderer), Snapshot(Created, Reference))

	Reference:Destroy()
	Created:Destroy()

	Expect(Problem).toBeNil()
end

const function Default(Width: number, Height: number): Config
	return {
		Width = Width,
		Height = Height,
		Wrapped = true,
		XAlignment = Enum.TextXAlignment.Left,
		YAlignment = Enum.TextYAlignment.Top,
		Truncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.None,
		LineHeight = 1,
		Padding = 0,
		Scaled = false,
	}
end

const function Outline(Config: Config): string
	return `[{Config.Width}x{Config.Height} wrap={tostring(Config.Wrapped)} {Config.XAlignment.Name}/{Config.YAlignment.Name} {Config.Truncate.Name} {Config.AutomaticSize.Name} lh={Config.LineHeight} pad={Config.Padding}]`
end

const function Mutate(Generator: Random, Config: Config): string
	const Roll: number = Generator:NextInteger(1, 10)

	if Roll <= 4 then Config.Width = Widths[Generator:NextInteger(1, #Widths)]; return "width" end
	if Roll == 5 then Config.Height = Heights[Generator:NextInteger(1, #Heights)]; return "height" end
	if Roll == 6 then Config.XAlignment = XAlignments[Generator:NextInteger(1, #XAlignments)]; return "x" end
	if Roll == 7 then Config.YAlignment = YAlignments[Generator:NextInteger(1, #YAlignments)]; return "y" end
	if Roll == 8 then Config.Truncate = Truncations[Generator:NextInteger(1, #Truncations)]; return "truncate" end

	if Roll == 9 then
		const Pick: number = Generator:NextInteger(1, 3)

		if Pick == 1 then Config.Wrapped = not Config.Wrapped; return "wrapped" end
		if Pick == 2 then Config.LineHeight = if Config.LineHeight == 1 then 1.3 else 1; return "spacing" end

		Config.Padding = if Config.Padding == 0 then 6 else 0

		return "padding"
	end

	Config.Width = Widths[Generator:NextInteger(1, #Widths)]
	Config.Height = Heights[Generator:NextInteger(1, #Heights)]

	return "box"
end

const function Visible(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	table.sort(Found, function(Left: TextLabel, Right: TextLabel): boolean return Left.Position.X.Offset < Right.Position.X.Offset end)

	return Found
end

const function Parsed(Target: TextLabel): number
	local Count: number = 0

	for _, Segment: TextLabel in Visible(Target) do
		if Segment.RichText then Count += 1 end
	end

	return Count
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("LayoutCache")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("randomized relayout equivalence", function()
	AfterAll(Release)

	for Index: number, Document: { string } in Documents do
		It(`{Document[1]} initial and 9 mutation steps`, function()
			const Generator: Random = Random.new(9000 + Index)
			const Config: Config = Default(Widths[Generator:NextInteger(1, #Widths)], 600)
			Config.AutomaticSize = Automatics[Generator:NextInteger(1, #Automatics)]

			const Target: TextLabel = Label(Document[2], Config)
			const Renderer: any = Build(Target)

			Settle(Renderer)
			Fresh(`{Document[1]} initial`, Target, Renderer, Config, Document[2])

			for Step = 1, 9 do
				const Change: string = Mutate(Generator, Config)

				Configure(Target, Config)
				Settle(Renderer)
				Fresh(`{Document[1]} step {Step} {Change} {Outline(Config)}`, Target, Renderer, Config, Document[2])
			end
		end)
	end
end)

Describe("resize cycle reuses layouts", function()
	AfterAll(Release)

	const Config: Config = Default(300, 600)
	const Seen: { [number]: string } = {}
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`{Filler} <b>{Filler}</b> {Filler}`, Config)
		Renderer = Build(Target)

		for _, Width: number in {300, 420, 190} do
			Config.Width = Width
			Configure(Target, Config)
			Settle(Renderer)
			Seen[Width] = Snapshot(Target, Renderer)
		end
	end)

	for Round = 2, 3 do
		for _, Width: number in {300, 420, 190} do
			It(`cycle {Round} width {Width}`, function()
				Config.Width = Width
				Configure(Target, Config)
				Settle(Renderer)

				Match(`cycle {Round} width {Width}`, Snapshot(Target, Renderer), Seen[Width])
			end)
		end
	end

	It("revisited widths never rebuild", function()
		const Builds: number = Counters.Builds

		for _ = 1, 4 do
			for _, Width: number in {300, 420, 190} do
				Config.Width = Width
				Configure(Target, Config)
				Settle(Renderer)
			end
		end

		Expect(Counters.Builds).toBe(Builds)
	end)

	It("cycle final", function()
		Fresh("cycle final", Target, Renderer, Config, Target.Text)
	end)
end)

Describe("width tween stays on committed layout", function()
	AfterAll(Release)

	const Config: Config = Default(300, 600)
	local Target: TextLabel
	local Renderer: any
	local Skips: number
	local Builds: number

	BeforeAll(function()
		Target = Label(Filler, Config)
		Renderer = Build(Target)

		Settle(Renderer)

		Skips = Counters.Skips
		Builds = Counters.Builds
	end)

	for Width = 300, 340, 2 do
		It(`tween width {Width} tracked`, function()
			Target.Size = UDim2.fromOffset(Width, 600)
			Settle(Renderer)

			Expect(Renderer.Host.Width).toBe(Width)
		end)
	end

	It("tween rebuilds only at breaks", function()
		Expect(Counters.Builds - Builds).toBeLessThanOrEqual(6)
	end)

	It("tween reuses the committed layout", function()
		Expect(Counters.Skips - Skips).toBeGreaterThanOrEqual(21 + 21 - 2 * (Counters.Builds - Builds))
	end)

	It("tween end", function()
		Config.Width = 340
		Settle(Renderer)

		Fresh("tween end", Target, Renderer, Config, Filler)
	end)
end)

Describe("truncated layout rebuilds when its lines are gone", function()
	AfterAll(Release)

	const Config: Config = Default(300, 40)
	Config.Truncate = Enum.TextTruncate.AtEnd

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`{Filler} {Filler}`, Config)
		Renderer = Build(Target)

		Settle(Renderer)
	end)

	for Step: number, Width: number in {200, 300, 170, 300, 200} do
		It(`truncated width {Width} step {Step}`, function()
			Config.Width = Width
			Configure(Target, Config)
			Settle(Renderer)

			Fresh(`truncated width {Width}`, Target, Renderer, Config, Target.Text)
		end)
	end

	It("split word truncation", function()
		Config.Truncate = Enum.TextTruncate.SplitWord
		Configure(Target, Config)
		Settle(Renderer)

		Fresh("split word truncation", Target, Renderer, Config, Target.Text)
	end)
end)

Describe("no change relayout is skipped", function()
	AfterAll(Release)

	const Config: Config = Default(260, 600)
	local Target: TextLabel
	local Renderer: any
	local Before: string
	local Skips: number

	BeforeAll(function()
		Target = Label(`<mark color="#806000">{Filler}</mark> <a href="x">link words</a>`, Config)
		Renderer = Build(Target)

		Settle(Renderer)

		Before = Snapshot(Target, Renderer)
		Skips = Counters.Skips

		for _ = 1, 10 do Relayout(Renderer) end
	end)

	It("repeat layouts skip", function()
		Expect(Counters.Skips - Skips).toBe(10)
	end)

	It("repeat layouts unchanged", function()
		Match("repeat layouts unchanged", Snapshot(Target, Renderer), Before)
	end)

	It("alignment after skip", function()
		Target.TextXAlignment = Enum.TextXAlignment.Center
		Settle(Renderer)
		Config.XAlignment = Enum.TextXAlignment.Center

		Fresh("alignment after skip", Target, Renderer, Config, Target.Text)
	end)

	It("decoration change relayouts", function()
		const Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.Thickness = 2
		Stroke.Parent = Target
		Settle(Renderer)

		local Stroked: number = 0
		for _, Record: any in Renderer.Instances.Segments do
			if Record.Instance:FindFirstChildOfClass("UIStroke") then Stroked += 1 end
		end

		const Total: number = #Renderer.Instances.Segments
		Stroke:Destroy()
		Settle(Renderer)

		Expect(Stroked).toBe(Total)
	end)

	It("reveal kept after skip", function()
		Target.MaxVisibleGraphemes = 5
		Settle(Renderer)
		Relayout(Renderer)
		const Kept: boolean = Renderer:GetGraphemeCount() > 5 and Renderer.Instances.Order[1].Content.Revealed ~= -1
		Target.MaxVisibleGraphemes = -1
		Settle(Renderer)

		Expect(Kept).toBe(true)
	end)

	It("feature round trip", function()
		Renderer:SetRendering("Clipping", false):Flush()
		Settle(Renderer)
		Renderer:SetRendering("Clipping", true):Flush()
		Settle(Renderer)

		Fresh("feature round trip", Target, Renderer, Config, Target.Text)
	end)
end)

Describe("native round trip relayouts", function()
	AfterAll(Release)

	const Config: Config = Default(260, 600)
	const Indented: string = `<indent by="10">indented</indent> {Filler}`
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(Filler, Config)
		Renderer = Library.new(Target):SetRendering("Culling", false):Flush()
		table.insert(Renderers, Renderer)

		Settle(Renderer)
	end)

	It("plain text goes native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("segments restored after native", function()
		for _, Text: string in {Indented, Filler, Indented} do
			Renderer.Label.Text = Text
			Renderer:Flush()
			Settle(Renderer)
		end
		Relayout(Renderer)

		Expect(#Renderer.Instances.Segments).toBeGreaterThan(0)
	end)

	It("native round trip", function()
		Fresh("native round trip", Target, Renderer, Config, Indented)
	end)
end)

Describe("incremental reflow matches full line breaking", function()
	AfterAll(Release)

	const Paragraphs: { string } = {
		Filler,
		`<b>bold opening</b> {Filler}`,
		`Label: <indent>{Filler}</indent>`,
		`<indent by="30">{Filler}</indent>`,
		`x <code>alpha beta gamma delta</code> y {Filler}`,
		`<mark color="#806000">marked {Filler}</mark>`,
		`<a href="https://x.test">linked words</a> {Filler}`,
		"",
		"short",
	}
	const Edits: { string } = {"", "x", "wide", "supercalifragilistic", "a b c", "longer phrase here", "0", "!!"}
	const Generator: Random = Random.new(4242)
	const Config: Config = Default(240, 2000)

	for Case = 1, 6 do
		Describe(`case {Case}`, function()
			local Resumed: number = 0

			It(`case {Case} incremental steps match a fresh layout`, function()
				const Pieces: { string } = {}
				for Index = 1, 8 do Pieces[Index] = Paragraphs[Generator:NextInteger(1, #Paragraphs)] end

				Config.Width = Widths[Generator:NextInteger(2, #Widths)]
				Config.XAlignment = XAlignments[Generator:NextInteger(1, #XAlignments)]

				const Target: TextLabel = Label(table.concat(Pieces, "<br/>"), Config)
				const Renderer: any = Build(Target)

				for Step = 1, 14 do
					const Slot: number = Generator:NextInteger(1, #Pieces)
					const Piece: string = Pieces[Slot]
					const Words: { string } = string.split(Piece, " ")
					const Word: number = Generator:NextInteger(1, math.max(#Words, 1))
					const Plain: boolean = Words[Word] ~= nil and not string.find(Words[Word], "[<>&=\"]")

					if Plain then
						Words[Word] = Edits[Generator:NextInteger(1, #Edits)]
						Pieces[Slot] = table.concat(Words, " ")
					else
						Pieces[Slot] = Piece .. " " .. Edits[Generator:NextInteger(2, #Edits)]
					end

					const Text: string = table.concat(Pieces, "<br/>")
					const Before: number = Counters.Resumes

					Renderer.Label.Text = Text
					Renderer:Flush()

					if Counters.Resumes == Before then continue end

					Resumed += 1

					const Created: TextLabel = Label(Text, Config)
					const Reference: any = Build(Created)
					const Lined: string? = Diff(`case {Case} step {Step} lines`, Structure(Renderer), Structure(Reference))
					const Drawn: string? = Diff(`case {Case} step {Step} render`, Snapshot(Target, Renderer), Snapshot(Created, Reference))

					Reference:Destroy()
					Created:Destroy()

					Expect(Lined).toBeNil()
					Expect(Drawn).toBeNil()
				end

				Renderer:Destroy()
				Target:Destroy()
			end)

			It(`case {Case} took the incremental path`, function()
				Expect(Resumed).toBeGreaterThanOrEqual(4)
			end)
		end)
	end
end)

Describe("incremental reflow renders like a rebuild", function()
	AfterAll(Release)

	const Generator: Random = Random.new(777)
	const Config: Config = Default(300, 2000)
	const Pieces: { string } = {}
	local Target: TextLabel
	local Renderer: any
	local Resumes: number

	BeforeAll(function()
		for Index = 1, 12 do Pieces[Index] = `{Index} {string.sub(Filler, 1, Generator:NextInteger(10, #Filler))}` end

		Target = Label(table.concat(Pieces, "<br/>"), Config)
		Renderer = Build(Target)
		Resumes = Counters.Resumes
	end)

	for Round = 1, 4 do
		It(`rebuild step {Round * 5}`, function()
			for _ = 1, 5 do
				const Slot: number = Generator:NextInteger(1, #Pieces)
				const Roll: number = Generator:NextInteger(1, 3)

				if Roll == 1 then
					Pieces[Slot] ..= " appended words"
				elseif Roll == 2 then
					Pieces[Slot] = string.sub(Pieces[Slot], 1, math.max(#Pieces[Slot] - Generator:NextInteger(1, 20), 1))
				else
					Pieces[Slot] = string.gsub(Pieces[Slot], "quick", "remarkably quick", 1)
				end

				Renderer.Label.Text = table.concat(Pieces, "<br/>")
				Renderer:Flush()
			end

			Fresh(`rebuild step {Round * 5}`, Target, Renderer, Config, Target.Text)
		end)
	end

	It("paragraph edits resume", function()
		Expect(Counters.Resumes - Resumes).toBeGreaterThanOrEqual(15)
	end)
end)

Describe("text scaled caches solved factors", function()
	AfterAll(Release)

	const Config: Config = Default(300, 120)
	Config.Scaled = true
	Config.XAlignment = Enum.TextXAlignment.Center
	Config.YAlignment = Enum.TextYAlignment.Center

	const Boxes: { { number } } = {{300, 120}, {420, 90}, {200, 200}}
	const First: { [number]: string } = {}
	const Factors: { [number]: number } = {}
	local Target: TextLabel
	local Renderer: any

	const function Visit(Box: { number }): ()
		Config.Width = Box[1]
		Config.Height = Box[2]
		Configure(Target, Config)
		Settle(Renderer)
	end

	BeforeAll(function()
		Target = Label(`{Filler} <b>bold</b> end`, Config)
		Renderer = Build(Target)

		for Index: number, Box: { number } in Boxes do
			Visit(Box)
			First[Index] = Snapshot(Target, Renderer)
			Factors[Index] = Renderer.Scale.Factor
		end
	end)

	for Round = 2, 3 do
		for Index = 1, #Boxes do
			Describe(`round {Round} box {Index}`, function()
				local Shot: string
				local Factor: number

				BeforeAll(function()
					Visit(Boxes[Index])
					Shot = Snapshot(Target, Renderer)
					Factor = Renderer.Scale.Factor
				end)

				It(`scaled round {Round} box {Index}`, function()
					Match(`scaled round {Round} box {Index}`, Shot, First[Index])
				end)

				It(`scaled factor round {Round} box {Index}`, function()
					Expect(Factor).toBe(Factors[Index])
				end)
			end)
		end
	end

	Describe("revisits", function()
		local Calls: number = 0
		local Ok: boolean
		local Problem: any

		BeforeAll(function()
			const RawCompute: any = LinesModule.Compute

			LinesModule.Compute = function(...: any): ...any
				Calls += 1
				return RawCompute(...)
			end

			Ok, Problem = pcall(function()
				for _, Box: { number } in Boxes do Visit(Box) end
			end)

			LinesModule.Compute = RawCompute
		end)

		It("scaled cycle ran", function()
			Expect(if Ok then true else tostring(Problem)).toBe(true)
		end)

		It("revisited boxes skip the solve", function()
			Expect(Calls).toBeLessThanOrEqual(#Boxes)
		end)
	end)

	It("scaled after text change", function()
		Renderer.Label.Text = `changed text {Filler}`
		Renderer:Flush()
		Settle(Renderer)

		Fresh("scaled after text change", Target, Renderer, Config, Target.Text)
	end)

	It("constraint change re-solves", function()
		const Constraint: UITextSizeConstraint = Instance.new("UITextSizeConstraint")
		Constraint.MaxTextSize = 9
		Constraint.Parent = Target
		Settle(Renderer)

		Expect(Renderer.Scale.Factor * 18).toBeLessThanOrEqual(9.5)
	end)
end)

Describe("neighbouring rich runs share one segment", function()
	AfterAll(Release)

	const Config: Config = Default(900, 200)
	local Target: TextLabel
	local Renderer: any
	local Found: { TextLabel }

	const function Show(Text: string): ()
		Renderer.Label.Text = Text
		Renderer:Flush()
		Settle(Renderer)
	end

	BeforeAll(function()
		Target = Label("plain <u>under</u> mid <s>struck</s> <sc>caps</sc> tail", Config)
		Renderer = Build(Target)

		Settle(Renderer)
		Found = Visible(Target)
	end)

	It("merged segment count", function()
		Expect(#Found).toBe(3)
	end)

	It("one rich parse", function()
		Expect(Parsed(Target)).toBe(1)
	end)

	It("leading plain kept apart", function()
		if #Found ~= 3 then return end
		Expect(Found[1].Text).toBe("plain")
	end)

	It("merged markup", function()
		if #Found ~= 3 then return end
		Expect(Found[2].Text).toBe("<u>under</u> mid <s>struck</s> <sc>caps</sc>")
	end)

	It("trailing plain kept apart", function()
		if #Found ~= 3 then return end
		Expect(Found[3].Text).toBe("tail")
	end)

	It("merged segment draws at its measured width", function()
		if #Found ~= 3 then return end
		Expect(math.abs(Found[2].TextBounds.X - Found[2].Size.X.Offset)).toBeLessThanOrEqual(1)
	end)

	It("graphemes unchanged by merging", function()
		Expect(Renderer:GetGraphemeCount()).toBe(27)
	end)

	Describe("partial reveal", function()
		local Merged: any

		BeforeAll(function()
			Target.MaxVisibleGraphemes = 12
			Settle(Renderer)
			Merged = Renderer.Instances.Order[2]
		end)

		It("reveal skips the leading plain segment", function()
			Expect(Renderer.Instances.Order[1].Content.Revealed).toBe(-1)
		end)

		It("reveal shows the gap spaces it passed", function()
			Expect(Merged and Merged.Content.Revealed).toBe(8)
		end)

		It("merged segment gap offsets", function()
			Expect(Merged and table.concat(Merged.Content.Gaps or {}, ",")).toBe("5,8,14")
		end)
	end)

	Describe("single rich run", function()
		BeforeAll(function()
			Target.MaxVisibleGraphemes = -1
			Settle(Renderer)
			Show("<u>Gold:</u> 1234")
		end)

		It("single rich run leaves values plain", function()
			Expect(Parsed(Target)).toBe(1)
		end)

		It("single rich run keeps two segments", function()
			Expect(#Visible(Target)).toBe(2)
		end)
	end)

	It("links split merged runs", function()
		Show(`<u>a</u> <a href="x">link</a> <s>b</s>`)

		Expect(Parsed(Target)).toBe(2)
	end)

	It("different colors never merge", function()
		Show(`<u>a</u> <font color="#ff0000"><s>b</s></font>`)

		Expect(Parsed(Target)).toBe(2)
	end)

	It("marks split merged runs", function()
		Show(`<u>a</u> <mark color="#335">m</mark> <s>b</s> <uc>é</uc>`)

		Expect(Parsed(Target)).toBe(2)
	end)

	It("bold group and regular group merge separately", function()
		Show(`<b><u>one</u> two <s>three</s></b> <u>four</u> <uc>FIVE</uc> <s>six</s>`)

		Expect(Parsed(Target)).toBe(2)
	end)

	It("merged runs match a fresh layout", function()
		Fresh("merged runs match a fresh layout", Target, Renderer, Config, Target.Text)
	end)
end)
