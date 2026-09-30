--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const DriverModule = require("../Packages/RichTextPlus/Renderer/Driver")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Driver: any = DriverModule

type Piece = {
	Open: string;
	Text: string;
	Close: string;
}

type Config = {
	Name: string;
	Width: number;
	Height: number;
	Wrapped: boolean?;
	Scaled: boolean?;
	XAlignment: Enum.TextXAlignment?;
	YAlignment: Enum.TextYAlignment?;
	AutomaticSize: Enum.AutomaticSize?;
	LineHeight: number?;
	Padding: number?;
	Setup: ((any) -> ())?;
	Seed: number;
	Edits: number;
	Patched: number;
	Length: number?;
}

const Shy: string = "\u{AD}"
const Zwsp: string = "\u{200B}"
const Joiner: string = "\u{2060}"
const Nbsp: string = "\u{A0}"

const Words: { string } = {
	"alpha", "beta", "gamma", "42", "7", "1000", "hello,", "world.", "(paren)", "end!", "AT&T", "5 > 3",
	"&amp;", "&lt;tag&gt;", "&#x4E2D;", "中文", "日本語テキスト", "「括弧」", "한국어", "\u{1F44D}\u{1F3FD}",
	"\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}", `well{Shy}known`, `co{Shy}op`, `{Shy}lead`, `a{Zwsp}b`, `x{Joiner}y`,
	`{Nbsp}`, "supercalifragilisticexpialidocious", "\n", "  ",
}

const Scripts: { string } = {"alpha", "42", "שלום", "مرحبا", "world.", "中文", "(7)", "\n"}

const Plain: { string } = {"alpha", "beta", "gamma", "delta", "7", "42", "1000", "hello,", "world.", "end!"}

const Strays: { string } = {
	"alpha", "beta", "42", "<3", "1<2", "a < b", "x <", "</ z", "<!x", "<?", "\"quoted\"", "it's", "=", "a=\"b", "&amp;", "&lt;b&gt;", "5 > 3", "\n",
}

const Tags: { { string } } = {
	{"", ""},
	{"", ""},
	{"<b>", "</b>"},
	{"<i>", "</i>"},
	{"<u>", "</u>"},
	{"<s>", "</s>"},
	{"<b><i>", "</i></b>"},
	{"<font color=\"#ff5555\">", "</font>"},
	{"<font size=\"26\">", "</font>"},
	{"<a href=\"https://x.test\">", "</a>"},
	{"<mark>", "</mark>"},
	{"<mark color=\"#335\" transparency=\"0.2\">", "</mark>"},
	{"<gradient colors=\"#ff0000,#0000ff\">", "</gradient>"},
	{"<gradient colors=\"#ff0,#0ff\" speed=\"1\">", "</gradient>"},
	{"<wave>", "</wave>"},
	{"<shake amplitude=\"1\">", "</shake>"},
	{"<stroke color=\"#000\" thickness=\"2\">", "</stroke>"},
	{"<uc>", "</uc>"},
	{"<sc>", "</sc>"},
	{"<code>", "</code>"},
	{"<br/>", ""},
	{"<img src=\"rbxassetid://123\" width=\"18\" height=\"18\"/>", ""},
	{"<!-- note -->", ""},
}

const Parser: { { string } } = {
	{"", ""},
	{"", ""},
	{"<B>", "</b>"},
	{"<b>", "</B>"},
	{"<I><b>", "</B></i>"},
	{"<font color=#55f>", "</font>"},
	{"<font size=22 color='#f5f'>", "</FONT>"},
	{"<b bold>", "</b>"},
	{"<font color=\">\">", "</font>"},
	{"<![CDATA[", "]]>"},
	{"<b it's>", "</b>"},
	{"</u>", ""},
	{"<!-- a <b> -->", ""},
}

const function Format(Value: number): string
	return string.format("%.3f", Value)
end

const function StyleKey(Style: any): string
	if not Style then return "-" end

	return table.concat({
		tostring(Style.Bold), tostring(Style.Italic), tostring(Style.Underline), tostring(Style.Strike), tostring(Style.Size),
		Style.Color:ToHex(), Style.Family, tostring(Style.Element ~= nil), tostring(Style.Link), tostring(Style.Case), tostring(Style.Code),
		tostring(Style.Mark ~= nil), tostring(Style.Gradient ~= nil), if Style.Effect then Style.Effect.Name else "-",
		tostring(Style.Stroke ~= nil), tostring(Style.Transparency),
	}, ",")
end

const function Snapshot(Target: TextLabel, Renderer: any): string
	const Rows: { string } = {}

	for _, Child: Instance in Target:GetChildren() do
		if not Child:IsA("GuiObject") or not (Child :: GuiObject).Visible then continue end

		const Object: GuiObject = Child :: GuiObject
		const Frame: string = `{Object.ClassName}:{Object.Name}@{Format(Object.Position.X.Offset)},{Format(Object.Position.Y.Offset)}/{Object.Size.X.Offset}x{Object.Size.Y.Offset}`

		if Object:IsA("TextLabel") or Object:IsA("TextButton") then
			const Text: TextLabel = Object :: any
			table.insert(Rows, `{Frame}|{Text.Text}|{Text.TextSize}|{Text.TextColor3:ToHex()}|{Text.FontFace.Family}|{Text.FontFace.Weight.Name}|{Text.FontFace.Style.Name}|{tostring(Text.RichText)}|{Text.MaxVisibleGraphemes}|{Format(Text.TextTransparency)}|{tostring(Text:FindFirstChildOfClass("UIStroke") ~= nil)}|{tostring(Text:FindFirstChildOfClass("UIGradient") ~= nil)}`)
		elseif Object.Name == "Backdrops" then
			for _, Layer: Instance in Object:GetChildren() do
				if not (Layer :: GuiObject).Visible then continue end

				const Backdrop: Frame = Layer :: Frame
				const Fill: Frame? = Backdrop:FindFirstChild("Fill") :: Frame?
				const Painted: Frame = if Backdrop.ClipsDescendants and Fill and Fill.Visible then Fill :: Frame else Backdrop
				const Color: string = if Painted.BackgroundTransparency >= 1 then "-" else Painted.BackgroundColor3:ToHex()

				table.insert(Rows, `Backdrop@{Backdrop.Position.X.Offset},{Backdrop.Position.Y.Offset}/{Backdrop.Size.X.Offset}x{Backdrop.Size.Y.Offset}|{Color}|{Format(Painted.BackgroundTransparency)}|{tostring(Backdrop.ClipsDescendants)}`)
			end
		else
			table.insert(Rows, Frame)
		end
	end

	table.sort(Rows)

	const Groups: { string } = {}
	for _, Group: any in ElementsModule.Query(Renderer, ElementsModule.Selector.Compile("a", 1), false) do
		table.insert(Groups, `{Group:GetAttribute("href")}={Group.Text}`)
	end

	const Tokens: { string } = {}
	for _, Token: any in Renderer.Document.Tokens do
		table.insert(Tokens, `{Token.Kind}|{tostring(Token.Text)}|{Format(Token.Width)}|{Format(Token.Height)}|{tostring(Token.SpaceBefore)}|{tostring(Token.Glue)}|{tostring(Token.Hyphen)}|{tostring(Token.Block)}|{StyleKey(Token.Style)}`)
	end

	return `{table.concat(Rows, "\n")}\n#links {table.concat(Groups, ";")}\n#tokens {table.concat(Tokens, "\n")}`
end

const function Source(Pieces: { Piece }): string
	const Parts: { string } = {}
	for _, Entry: Piece in Pieces do table.insert(Parts, Entry.Open .. Entry.Text .. Entry.Close) end

	return table.concat(Parts)
end

const Inserts: { string } = {"", " ", "\n", "  ", Shy, Zwsp, Joiner, "7", "42", "x", " word", "word ", "中", "\u{1F44D}"}

const function Phrase(Generator: Random, Pool: { string }, Length: number?): string
	const Parts: { string } = {}

	for Index = 1, Generator:NextInteger(1, Length or 4) do
		if Index > 1 then table.insert(Parts, if Generator:NextNumber() < 0.8 then " " else "") end
		table.insert(Parts, Pool[Generator:NextInteger(1, #Pool)])
	end

	return table.concat(Parts)
end

const function NewPiece(Generator: Random, Pool: { string }, Length: number?, Markup: { { string } }?): Piece
	const List: { { string } } = Markup or Tags
	const Tag: { string } = List[Generator:NextInteger(1, #List)]
	const Text: string = if Tag[2] == "" and Tag[1] ~= "" then (if Generator:NextNumber() < 0.5 then " " .. Phrase(Generator, Pool, Length) else "") else Phrase(Generator, Pool, Length)

	return {Open = Tag[1], Text = Text, Close = Tag[2]}
end

const function Textual(Pieces: { Piece }): { number }
	const Found: { number } = {}
	for Index: number, Entry: Piece in Pieces do
		if Entry.Text ~= "" then table.insert(Found, Index) end
	end

	return Found
end

const function Splice(Generator: Random, Text: string, Pool: { string }): string
	const Characters: number = utf8.len(Text) or #Text
	const At: number = Generator:NextInteger(1, Characters + 1)
	const Cut: number = math.min(Generator:NextInteger(0, 3), Characters + 1 - At)
	const From: number = utf8.offset(Text, At) or (#Text + 1)
	const To: number = utf8.offset(Text, At + Cut) or (#Text + 1)
	const Insert: string = if Generator:NextNumber() < 0.7 then Inserts[Generator:NextInteger(1, #Inserts)] else Pool[Generator:NextInteger(1, #Pool)]

	return string.sub(Text, 1, From - 1) .. Insert .. string.sub(Text, To)
end

const function Mutate(Generator: Random, Text: string, Pool: { string }): string
	const Roll: number = Generator:NextNumber()

	if Roll < 0.35 then return Splice(Generator, Text, Pool) end

	if Roll < 0.55 then
		const Digits: { number } = {}
		for Index = 1, #Text do
			const Code: number = string.byte(Text, Index)
			if Code >= 48 and Code <= 57 then table.insert(Digits, Index) end
		end

		if #Digits > 0 then
			const At: number = Digits[Generator:NextInteger(1, #Digits)]
			return string.sub(Text, 1, At - 1) .. tostring(Generator:NextInteger(0, 9)) .. string.sub(Text, At + 1)
		end

		return Text .. tostring(Generator:NextInteger(0, 99))
	end

	if Roll < 0.65 then return Text .. (if Generator:NextNumber() < 0.7 then " " else "") .. Pool[Generator:NextInteger(1, #Pool)] end
	if Roll < 0.72 then return Pool[Generator:NextInteger(1, #Pool)] .. (if Generator:NextNumber() < 0.7 then " " else "") .. Text end
	if Roll < 0.8 then return Phrase(Generator, Pool) end

	if Roll < 0.88 then
		const Cut: number? = utf8.offset(Text, Generator:NextInteger(1, math.max(utf8.len(Text) or 1, 1)))
		if Cut and Cut > 1 then return string.sub(Text, 1, Cut - 1) end

		return Text .. "x"
	end

	if Roll < 0.94 then return Text .. (if Generator:NextNumber() < 0.5 then " " else "\n") end

	return (string.gsub(Text, "%s+", " ", 1))
end

type Pair = {
	Fast: TextLabel;
	Full: TextLabel;
	FastRenderer: any;
	FullRenderer: any;
}

local Screen: ScreenGui

const API: any = setmetatable({
	new = function(Target: TextLabel): any
		return Library.new(Target):SetRendering("Passthrough", false):Flush()
	end;
}, {__index = Library})

const function Label(Config: Config): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Config.Width, Config.Height)
	Created.TextSize = 18
	Created.TextWrapped = Config.Wrapped ~= false
	Created.TextScaled = Config.Scaled == true
	Created.TextXAlignment = Config.XAlignment or Enum.TextXAlignment.Left
	Created.TextYAlignment = Config.YAlignment or Enum.TextYAlignment.Top
	Created.AutomaticSize = Config.AutomaticSize or Enum.AutomaticSize.None
	Created.LineHeight = Config.LineHeight or 1
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Parent = Screen

	if Config.Padding then
		const Padding: UIPadding = Instance.new("UIPadding")
		Padding.PaddingLeft = UDim.new(0, Config.Padding :: number)
		Padding.PaddingTop = UDim.new(0, Config.Padding :: number)
		Padding.Parent = Created
	end

	return Created
end

const function Configure(Renderer: any, Config: Config): any
	if Config.Setup then Config.Setup(Renderer) end

	return Renderer:Flush()
end

const function MakePair(Config: Config, Text: string): Pair
	const Fast: TextLabel = Label(Config)
	const Full: TextLabel = Label(Config)
	const FastRenderer: any = Configure(API.new(Fast), Config)
	const FullRenderer: any = Configure(API.new(Full), Config)

	Fast.Text = Text
	FastRenderer:Flush()
	Full.Text = Text
	FullRenderer:Rebuild()

	return {Fast = Fast, Full = Full, FastRenderer = FastRenderer, FullRenderer = FullRenderer}
end

const function Apply(Target: Pair, Text: string): boolean
	const Tree: any = Target.FastRenderer.Document.Tree

	Target.Fast.Text = Text
	Target.FastRenderer:Flush()
	Target.Full.Text = Text
	Target.FullRenderer:Rebuild()

	Driver.Tick(Target.FastRenderer, 0)
	Driver.Tick(Target.FullRenderer, 0)

	return Target.FastRenderer.Document.Tree == Tree
end

const function Mismatch(Fast: string, Other: string, Text: string): string?
	if Fast == Other then return nil end

	const FastLines: { string } = string.split(Fast, "\n")
	const OtherLines: { string } = string.split(Other, "\n")

	for Index = 1, math.max(#FastLines, #OtherLines) do
		if FastLines[Index] == OtherLines[Index] then continue end

		return `line {Index}\n  fast {tostring(FastLines[Index])}\n  other {tostring(OtherLines[Index])}\n  source {Text}`
	end

	return "snapshots differ"
end

const function Compare(Target: Pair): string?
	return Mismatch(Snapshot(Target.Fast, Target.FastRenderer), Snapshot(Target.Full, Target.FullRenderer), Target.Full.Text)
end

const function Fresh(Config: Config, Target: Pair): string?
	const Created: TextLabel = Label(Config)
	Created.Text = Target.Full.Text

	const Renderer: any = Configure(API.new(Created), Config)
	Driver.Tick(Renderer, 0)

	const Result: string? = Mismatch(Snapshot(Target.Fast, Target.FastRenderer), Snapshot(Created, Renderer), Created.Text)

	Renderer:Destroy()
	Created:Destroy()

	return Result
end

const function Close(Target: Pair?): ()
	if not Target then return end

	Target.FastRenderer:Destroy()
	Target.FullRenderer:Destroy()
	Target.Fast:Destroy()
	Target.Full:Destroy()
end

BeforeAll(function()
	Screen = Gui.new("Incremental")
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("hud counter patches in place", function()
	const Config: Config = {Name = "hud", Width = 320, Height = 40, Seed = 0, Edits = 0, Patched = 0}
	local Target: Pair
	local Style: any
	const Before: { [Instance]: boolean } = {}

	BeforeAll(function()
		Target = MakePair(Config, `Coins: <b>41</b>  HP: <font color="#f55">100</font>`)
		Style = Target.FastRenderer.Document.Tokens[1].Style
		for _, Record: any in Target.FastRenderer.Instances.Segments do Before[Record.Instance] = true end
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("hud single value patched", function()
		Expect(Apply(Target, `Coins: <b>42</b>  HP: <font color="#f55">100</font>`)).toBe(true)
	end)

	It("hud single value", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("hud both values patched", function()
		Expect(Apply(Target, `Coins: <b>420</b>  HP: <font color="#f55">99</font>`)).toBe(true)
	end)

	It("hud both values", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("hud digit growth patched", function()
		Expect(Apply(Target, `Coins: <b>1000000</b>  HP: <font color="#f55">9</font>`)).toBe(true)
	end)

	It("hud digit growth", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("hud keeps styles", function()
		Expect(Target.FastRenderer.Document.Tokens[1].Style).toBe(Style)
	end)

	It("hud reuses every segment instance", function()
		local Reused: number = 0
		for _, Record: any in Target.FastRenderer.Instances.Segments do if Before[Record.Instance] then Reused += 1 end end

		Expect(Reused).toBe(#Target.FastRenderer.Instances.Segments)
	end)

	It("hud source tracked", function()
		Expect(Target.FastRenderer.Document.Source).toBe(`Coins: <b>1000000</b>  HP: <font color="#f55">9</font>`)
	end)

	It("tag change falls back", function()
		Expect(Apply(Target, `Coins: <i>1</i>  HP: <font color="#f55">9</font>`)).toBe(false)
	end)

	It("tag change", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("attribute change falls back", function()
		Expect(Apply(Target, `Coins: <i>1</i>  HP: <font color="#5f5">9</font>`)).toBe(false)
	end)

	It("attribute change", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("patches again after fallback", function()
		Expect(Apply(Target, `Coins: <i>2</i>  HP: <font color="#5f5">9</font>`)).toBe(true)
	end)

	It("patch after fallback", function()
		Expect(Compare(Target)).toBeNil()
	end)
end)

Describe("edge cases", function()
	const Config: Config = {Name = "edge", Width = 300, Height = 300, Seed = 0, Edits = 0, Patched = 0}

	const Cases: { { any } } = {
		{"append in tag", "a<b>1</b>", "a<b>12</b>", true},
		{"delete in tag", "a<b>12</b>", "a<b>1</b>", true},
		{"empty text falls back", "a<b>1</b>", "a<b></b>", false},
		{"new text node falls back", "a<b></b>", "a<b>1</b>", false},
		{"insert between tags falls back", "<b>x</b><i>y</i>", "<b>x</b> <i>y</i>", false},
		{"leading text", "a<b>x</b>", "ab<b>x</b>", true},
		{"tail text", "<b>x</b> tail", "<b>x</b> tails", true},
		{"stray tail patches as text", "x <y", "x <yz", true},
		{"stray becomes tag falls back", "a <b c", "a <b c>", false},
		{"stray lt space", "a < b <b>c</b>", "a < bb <b>c</b>", true},
		{"stray lt digit", "1<2 <b>3</b>", "1<22 <b>3</b>", true},
		{"stray lt at end", "a <", "a <<", true},
		{"stray lt entity", "a &lt; <b>x</b> < y", "a &lt; <b>x</b> < yy", true},
		{"stray quote reach falls back", `x <b a="<i>y</i>" <u>z</u>`, `x <b a="<i>yy</i>" <u>z</u>`, false},
		{"stray quote closes into tag", `x <b a="<i>y</i> z`, `x <b a="<i>y">"</i> z`, false},
		{"stray before tag unaffected", "x <y <b>1</b>", "x <y <b>2</b>", true},
		{"lone close lt", "a </ b <i>c</i>", "a </ b <i>cc</i>", true},
		{"text quotes", `say "hi" <b>x</b>`, `say "hey" <b>x</b>`, true},
		{"apostrophe in tag", "<b it's>x</b> y", "<b it's>x</b> yy", true},
		{"quoted gt in attribute", `<font color=">">a</font> 1`, `<font color=">">a</font> 2`, true},
		{"cdata edit falls back", "a <![CDATA[<b>x</b>]]> b", "a <![CDATA[<b>y</b>]]> b", false},
		{"text after cdata", "a <![CDATA[<x> &amp;]]> b1", "a <![CDATA[<x> &amp;]]> b2", true},
		{"text before cdata", "a1 <![CDATA[x]]>", "a2 <![CDATA[x]]>", true},
		{"empty cdata", "a<![CDATA[]]>b", "a<![CDATA[]]>bb", true},
		{"unterminated cdata", "a <![CDATA[x", "a <![CDATA[xy", true},
		{"unquoted attribute", "<font color=#f55>a</font> 1", "<font color=#f55>a</font> 2", true},
		{"unquoted value edit falls back", "<font size=20>a</font>", "<font size=24>a</font>", false},
		{"boolean attribute", "<b bold>x</b> 1", "<b bold>x</b> 22", true},
		{"case mismatched close", "<B>x</b> tail 1", "<B>x</b> tail 2", true},
		{"case mismatched close inner", "<b>x</B> y", "<b>xx</B> y", true},
		{"mixed case nesting", "<I><b>a</B> b</i> c", "<I><b>aa</B> b</i> c", true},
		{"unmatched close dropped", "a</u> b", "a</u> bb", true},
		{"text before unterminated tail", "x <y", "xx <y", true},
		{"comment kept", "a<!-- c -->b", "a<!-- c -->bb", true},
		{"comment edit falls back", "a<!-- c -->b", "a<!-- d -->b", false},
		{"entity created", "a &am b", "a &amp; b", true},
		{"entity removed", "a &amp; b", "a &am b", true},
		{"new tag falls back", "a b c", "a <b>b</b> c", false},
		{"newline added", "a<b>x</b>\nb", "a<b>x</b>\n\nb", true},
		{"newline in word", "one two", "one\ntwo", true},
		{"soft hyphen", `well{Shy}known <b>x</b>`, `well{Shy}knowns <b>x</b>`, true},
		{"soft hyphen hook", `<b>x</b>{Shy}y`, `<b>x</b>{Shy}yy`, true},
		{"soft hyphen hook removed falls back", `<b>x</b>{Shy}y`, `<b>x</b>y`, false},
		{"glued end", "<b>ab</b>cd", "<b>ab</b>ce", true},
		{"leading space added", "<b>ab</b>cd", "<b>ab</b> cd", true},
		{"cjk", "中文<b>字</b>符", "中文<b>字字</b>符", true},
		{"cjk boundary class", "<b>a</b>b", "<b>中</b>b", false},
		{"emoji", `<b>\u{1F44D}</b> ok`, `<b>\u{1F44D}\u{1F3FD}</b> ok`, true},
		{"rtl falls back", "<b>abc</b> def", "<b>שלום</b> def", false},
		{"markdown falls back", "<md>**a** 1</md>", "<md>**a** 2</md>", false},
		{"link text", `<a href="u">click 1</a> tail`, `<a href="u">click 22</a> tail`, true},
		{"code span", "<code>x = 1</code> y", "<code>x = 22</code> y", true},
		{"quoted attribute", `<font color="#f55">a</font> 1`, `<font color="#f55">a</font> 2`, true},
		{"gt in text", "a > b <b>c</b>", "a >> b <b>c</b>", true},
		{"multi span", "<b>1</b> and <i>2</i> and <u>3</u>", "<b>9</b> and <i>2</i> and <u>8</u>", true},
		{"prolog kept", "<?x y?>a 1", "<?x y?>a 2", true},
	}

	for _, Case: { any } in Cases do
		Describe(Case[1], function()
			local Target: Pair
			local Patched: boolean = false

			BeforeAll(function()
				Target = MakePair(Config, Case[2])
				Patched = Apply(Target, Case[3])
			end)

			AfterAll(function()
				Close(Target)
			end)

			It(`{Case[1]} path`, function()
				Expect(Patched).toBe(Case[4])
			end)

			It(Case[1], function()
				Expect(Compare(Target)).toBeNil()
			end)
		end)
	end
end)

Describe("custom classes", function()
	const Config: Config = {Name = "custom", Width = 300, Height = 200, Seed = 0, Edits = 0, Patched = 0}
	local Target: Pair

	BeforeAll(function()
		Target = MakePair(Config, "a <customclass><len>abc</len></customclass> b <customclass><hot>x</hot></customclass> 1")

		for _, Renderer: any in {Target.FastRenderer, Target.FullRenderer} do
			Renderer:AddCustomClass("len", {Kind = "Style", Apply = function(Style: any, Node: any): ()
				const Child: any = Node.Children[1]
				Style.Size = 12 + (if Child and Child.Text then #Child.Text else 0)
			end})
			Renderer:AddCustomClass("hot", {Kind = "Style", Apply = function(Style: any): () Style.Color = Color3.fromRGB(255, 0, 0) end}):Flush()
		end
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("custom classes initial", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("text inside custom class falls back", function()
		Expect(Apply(Target, "a <customclass><len>abcdef</len></customclass> b <customclass><hot>x</hot></customclass> 1")).toBe(false)
	end)

	It("custom inner text", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("text outside custom class patches", function()
		Expect(Apply(Target, "a <customclass><len>abcdef</len></customclass> b <customclass><hot>x</hot></customclass> 2")).toBe(true)
	end)

	It("custom outer text", function()
		Expect(Compare(Target)).toBeNil()
	end)
end)

Describe("reveal and culling", function()
	const Config: Config = {Name = "reveal", Width = 300, Height = 200, Seed = 0, Edits = 0, Patched = 0}
	local Target: Pair

	const function Reveal(Count: number): ()
		Target.Fast.MaxVisibleGraphemes = Count
		Target.Full.MaxVisibleGraphemes = Count
		task.wait()
	end

	BeforeAll(function()
		Target = MakePair(Config, "Score <b>10</b> and a longer sentence that keeps growing along")
		Reveal(8)
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("revealing text change patches", function()
		Expect(Apply(Target, "Score <b>11</b> and a longer sentence that keeps growing along")).toBe(true)
	end)

	It("mid reveal", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("reveal continues", function()
		Reveal(20)
		Expect(Compare(Target)).toBeNil()
	end)

	It("grapheme counts agree", function()
		Expect(Target.FastRenderer:GetGraphemeCount()).toBe(Target.FullRenderer:GetGraphemeCount())
	end)

	It("reveal cleared", function()
		Reveal(-1)
		Expect(Compare(Target)).toBeNil()
	end)
end)

Describe("windowed patches", function()
	const Config: Config = {Name = "window", Width = 300, Height = 600, Seed = 0, Edits = 0, Patched = 0}
	const Sentence: string = "The clock tower chimed twice as the crowd grew restless and the lanterns glowed along the path."
	local Target: Pair
	local Leading: any
	local Count: number = 0

	BeforeAll(function()
		Target = MakePair(Config, `<b>Start</b> {Sentence} Round number ends in 1.`)
		Leading = Target.FastRenderer.Document.Tokens[2]
		Count = #Target.FastRenderer.Document.Tokens
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("last digit patched", function()
		Expect(Apply(Target, `<b>Start</b> {Sentence} Round number ends in 2.`)).toBe(true)
	end)

	It("last digit", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("prefix tokens kept", function()
		Expect(Target.FastRenderer.Document.Tokens[2]).toBe(Leading)
	end)

	It("token count kept", function()
		Expect(#Target.FastRenderer.Document.Tokens).toBe(Count)
	end)

	const Cases: { { any } } = {
		{"middle word", `<b>Start</b> The clock tower chimed thrice as the crowd grew restless and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"first word", `<b>Start</b> A clock tower chimed thrice as the crowd grew restless and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"leading space removed", `<b>Start</b>A clock tower chimed thrice as the crowd grew restless and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"newline inserted", `<b>Start</b>A clock tower chimed thrice as the crowd\ngrew restless and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"double space", `<b>Start</b>A clock tower chimed thrice as the crowd\ngrew  restless and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"words merged", `<b>Start</b>A clock tower chimed thrice as the crowd\ngrew  restlessand the lanterns glowed along the path. Round number ends in 2.`, true},
		{"soft hyphen", `<b>Start</b>A clock tower chimed thrice as the crowd\ngrew  restless{Shy}and the lanterns glowed along the path. Round number ends in 2.`, true},
		{"control at word start", `<b>Start</b>A clock tower chimed thrice as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 2.`, true},
		{"cjk run", `<b>Start</b>A clock tower chimed 中文字符 as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 2.`, true},
		{"cjk run edit", `<b>Start</b>A clock tower chimed 中文字符字 as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 2.`, true},
		{"trailing spaces", `<b>Start</b>A clock tower chimed 中文字符字 as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 2.   `, false},
		{"trailing spaces edit", `<b>Start</b>A clock tower chimed 中文字符字 as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 3.   `, true},
		{"entity", `<b>Start</b>A clock tower chimed &amp; as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 3.   `, true},
		{"entity edit", `<b>Start</b>A clock tower chimed &amp; as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 4.   `, true},
		{"entity removed", `<b>Start</b>A clock tower chimed as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 4.   `, true},
		{"after entity removed", `<b>Start</b>A clock tower chimed as the crowd\ngrew  restless{Shy}and the {Zwsp}lanterns glowed along the path. Round number ends in 5.   `, true},
	}

	for _, Case: { any } in Cases do
		It(`{Case[1]} path`, function()
			Expect(Apply(Target, Case[2])).toBe(Case[3])
		end)

		It(Case[1], function()
			Expect(Compare(Target)).toBeNil()
		end)
	end
end)

Describe("limits", function()
	const Config: Config = {
		Name = "limits";
		Width = 300;
		Height = 200;
		Setup = function(Built: any) Built:SetLimits({Characters = 20}) end;
		Seed = 0;
		Edits = 0;
		Patched = 0;
	}
	local Target: Pair

	BeforeAll(function()
		Target = MakePair(Config, "abc <b>12</b> def")
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("within limit patches", function()
		Expect(Apply(Target, "abc <b>123</b> def")).toBe(true)
	end)

	It("within limit", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("crossing limit falls back", function()
		Expect(Apply(Target, "abc <b>1234567890123456</b> def")).toBe(false)
	end)

	It("crossing limit", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("truncated source falls back", function()
		Expect(Apply(Target, "abc <b>12345678901234567</b> def")).toBe(false)
	end)

	It("truncated", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("back under limit falls back once", function()
		Expect(Apply(Target, "abc <b>1</b> def")).toBe(false)
	end)

	It("then patches", function()
		Expect(Apply(Target, "abc <b>2</b> def")).toBe(true)
	end)

	It("under limit again", function()
		Expect(Compare(Target)).toBeNil()
	end)
end)

Describe("feature toggles", function()
	const Config: Config = {Name = "plain", Width = 300, Height = 200, Setup = function(Built: any) Built:SetIntents({}):SetDenied("Escape") end, Seed = 0, Edits = 0, Patched = 0}
	local Target: Pair

	BeforeAll(function()
		Target = MakePair(Config, "plain <b>1</b>")
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("rich text off falls back", function()
		Expect(Apply(Target, "plain <b>2</b>")).toBe(false)
	end)

	It("rich text off", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("enabled again patches", function()
		Target.FastRenderer:SetPreset("Default"):Flush()
		Target.FullRenderer:SetPreset("Default"):Flush()
		Expect(Apply(Target, "plain <b>3</b>")).toBe(true)
	end)

	It("rich text on", function()
		Expect(Compare(Target)).toBeNil()
	end)

	It("links off structural change falls back", function()
		const NoLinks: any = Library.Intents.Presets.Default:Remove("Links")
		Target.FastRenderer:SetIntents(NoLinks):Flush()
		Target.FullRenderer:SetIntents(NoLinks):Flush()
		Expect(Apply(Target, `plain <a href="x">link 4</a>`)).toBe(false)
	end)

	It("links off text patches", function()
		Expect(Apply(Target, `plain <a href="x">link 5</a>`)).toBe(true)
	end)

	It("links off", function()
		Expect(Compare(Target)).toBeNil()
	end)
end)

const Configs: { Config } = {
	{Name = "wrapped", Width = 320, Height = 400, Seed = 11, Edits = 80, Patched = 0};
	{Name = "scaled", Width = 180, Height = 60, Scaled = true, Seed = 12, Edits = 50, Patched = 0};
	{Name = "clipped", Width = 240, Height = 70, YAlignment = Enum.TextYAlignment.Center, Seed = 13, Edits = 60, Patched = 0};
	{Name = "automatic", Width = 300, Height = 10, AutomaticSize = Enum.AutomaticSize.Y, XAlignment = Enum.TextXAlignment.Center, Seed = 14, Edits = 50, Patched = 0};
	{Name = "unwrapped", Width = 400, Height = 40, Wrapped = false, XAlignment = Enum.TextXAlignment.Right, Seed = 15, Edits = 50, Patched = 0};
	{Name = "padded", Width = 260, Height = 300, Padding = 12, LineHeight = 1.3, YAlignment = Enum.TextYAlignment.Bottom, Seed = 16, Edits = 50, Patched = 0};
	{Name = "budget", Width = 300, Height = 300, Setup = function(Built: any) Built:SetLimits({Characters = 160}) end, Seed = 17, Edits = 50, Patched = 0};
	{Name = "toggles", Width = 300, Height = 300, Setup = function(Built: any) Built:SetIntents(Library.Intents.Presets.Default:Remove("Links", "Gradients", "Effects")) end, Seed = 18, Edits = 40, Patched = 0};
	{Name = "chat", Width = 300, Height = 300, Setup = function(Built: any) Built:SetPreset("Chat") end, Seed = 19, Edits = 40, Patched = 0};
	{Name = "plain words", Width = 280, Height = 300, Seed = 20, Edits = 60, Patched = 0};
	{Name = "scripts", Width = 260, Height = 300, Seed = 21, Edits = 40, Patched = 0};
	{Name = "long", Width = 300, Height = 900, Seed = 22, Edits = 120, Patched = 0, Length = 30};
	{Name = "long scaled", Width = 300, Height = 200, Scaled = true, Seed = 23, Edits = 60, Patched = 0, Length = 20};
	{Name = "long plain", Width = 260, Height = 900, Seed = 24, Edits = 120, Patched = 0, Length = 40};
	{Name = "parser", Width = 300, Height = 600, Seed = 25, Edits = 120, Patched = 0};
	{Name = "parser long", Width = 300, Height = 900, Seed = 26, Edits = 120, Patched = 0, Length = 12};
}

const MISMATCH_LIMIT: number = 3

for _, Config: Config in Configs do
	Describe(`random {Config.Name}`, function()
		const Parsing: boolean = string.find(Config.Name, "parser", 1, true) ~= nil
		const Pool: { string } = if Config.Name == "plain words" or Config.Name == "long plain" then Plain elseif Config.Name == "scripts" then Scripts elseif Parsing then Strays else Words
		const Markup: { { string } }? = if Parsing then Parser else nil

		local Generator: Random
		local Target: Pair
		const Pieces: { Piece } = {}
		local Mismatches: number = 0

		const function Step(): ()
			const Roll: number = Generator:NextNumber()
			const Candidates: { number } = Textual(Pieces)

			if Roll < 0.1 or #Candidates == 0 then
				if #Pieces > 2 and Generator:NextNumber() < 0.5 then
					table.remove(Pieces, Generator:NextInteger(1, #Pieces))
				else
					table.insert(Pieces, Generator:NextInteger(1, #Pieces + 1), NewPiece(Generator, Pool, Config.Length, Markup))
				end
			elseif Roll < 0.15 then
				Pieces[Candidates[Generator:NextInteger(1, #Candidates)]].Text = ""
			else
				for _ = 1, if Generator:NextNumber() < 0.25 then 2 else 1 do
					const Chosen: Piece = Pieces[Candidates[Generator:NextInteger(1, #Candidates)]]
					Chosen.Text = Mutate(Generator, Chosen.Text, Pool)
				end
			end

			if Apply(Target, Source(Pieces)) then Config.Patched += 1 end
		end

		const function Record(Problem: string?): string?
			if Problem then Mismatches += 1 end

			return Problem
		end

		BeforeAll(function()
			Generator = Random.new(Config.Seed)
			for _ = 1, Generator:NextInteger(if Config.Length then 2 else 3, if Config.Length then 5 else 9) do table.insert(Pieces, NewPiece(Generator, Pool, Config.Length, Markup)) end

			Target = MakePair(Config, Source(Pieces))
		end)

		AfterAll(function()
			Close(Target)
		end)

		It(`{Config.Name} initial`, function()
			Expect(Compare(Target)).toBeNil()
		end)

		for Index = 1, Config.Edits do
			It(`{Config.Name} step {Index}`, function()
				if Mismatches >= MISMATCH_LIMIT then
					Expect(`skipped after {MISMATCH_LIMIT} mismatches`).toBeNil()
					return
				end

				Step()
				Expect(Record(Compare(Target))).toBeNil()
			end)

			if not Config.Scaled and Index % 8 == 0 then
				It(`{Config.Name} fresh {Index}`, function()
					if Mismatches >= MISMATCH_LIMIT then
						Expect(`skipped after {MISMATCH_LIMIT} mismatches`).toBeNil()
						return
					end

					Expect(Record(Fresh(Config, Target))).toBeNil()
				end)
			end
		end

		if Config.Name ~= "scripts" then
			It(`{Config.Name} mostly patched`, function()
				Expect(Config.Patched).toBeGreaterThanOrEqual(Config.Edits * 0.3)
			end)
		end
	end)
end
