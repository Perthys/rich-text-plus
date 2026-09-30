--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const DriverModule = require("../Packages/RichTextPlus/Renderer/Driver")
const WhitespaceModule = require("../Packages/RichTextPlus/Policy/Whitespace")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Driver: any = DriverModule
const Whitespace: any = WhitespaceModule
const Utilities: any = Library.Utilities

const Nested: string = "<font size=\"20\">\n\t<b>\n\t\tTitle\n\t</b>\n</font>"
const Inline: string = "<font size=\"20\"><b>Title</b></font>"

const Layouts: { { string } } = {
	{Nested, Inline},
	{"<b>Name</b>\n  <font color=\"#ff5555\">red</font>\n  text\n", "<b>Name</b><font color=\"#ff5555\">red</font>text"},
	{"<b>\n\tone\n\ttwo\n</b>\n<i>\n\tthree\n</i>", "<b>one two</b><i>three</i>"},
	{"<font size=\"24\">\n  <b>Head</b>\n  <br/>\n  body\n  text\n</font>", "<font size=\"24\"><b>Head</b><br/>body text</font>"},
}

const Collapses: { { string } } = {
	{"a\n   b", "a b"},
	{"  a  \n  b  ", "  a b  "},
	{"\n\t", ""},
	{"\n", ""},
	{"a\r\n b", "a b"},
	{"a\rb", "a\rb"},
	{"x \n\n\n y", "x y"},
	{"  ", "  "},
	{"no newline   kept", "no newline   kept"},
	{"a\n", "a"},
	{"\na", "a"},
	{"a&#10;\n b", "a&#10; b"},
	{"\t\tone\n\t\ttwo\t\t", "\t\tone two\t\t"},
	{"a\n \t \n b", "a b"},
}

const Strips: { { string } } = {
	{"a\n   b", "a b"},
	{"<b>x</b>\n\t<i>y</i>", "xy"},
	{"hello\n<b>x</b>", "hellox"},
	{"<b>x</b>&#32;\n<i>y</i>", "x y"},
	{"a&#10;\n  b", "a\nb"},
	{"a\n<br/>\n b", "a\nb"},
	{"one line   stays", "one line stays"},
	{Nested, "Title"},
}

local Screen: ScreenGui

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Build(Target: TextLabel, Mode: string?, Setup: ((any) -> ())?): any
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):SetWhitespace(Mode or "Preserve")
	if Setup then Setup(Renderer) end

	return Renderer:Flush()
end

const function StyleKey(Style: any): string
	if not Style then return "-" end

	return `{tostring(Style.Bold)},{tostring(Style.Italic)},{tostring(Style.Size)},{Style.Color:ToHex()},{tostring(Style.LinkId)}`
end

const function Stream(Renderer: any): string
	const Parts: { string } = {}

	for _, Token: any in Renderer.Document.Tokens do
		if Token.Kind == "Object" then
			table.insert(Parts, `Object|{Token.Width}x{Token.Height}`)
		else
			table.insert(Parts, `{Token.Kind}|{tostring(Token.Text)}|{tostring(Token.SpaceBefore)}|{tostring(Token.Glue)}|{StyleKey(Token.Style)}`)
		end
	end

	for _, Group: any in ElementsModule.Query(Renderer, ElementsModule.Selector.Compile("a", 1), false) do table.insert(Parts, `link {Group.Text}`) end

	return table.concat(Parts, "\n")
end

const function Render(Text: string, Mode: string?, Setup: ((any) -> ())?): string
	const Target: TextLabel = Label(Text)
	const Renderer: any = Build(Target, Mode, Setup)
	const Result: string = Stream(Renderer)

	Renderer:Destroy()
	Target:Destroy()

	return Result
end

const function Words(Text: string, Mode: string?, Setup: ((any) -> ())?): string
	const Target: TextLabel = Label(Text)
	const Renderer: any = Build(Target, Mode, Setup)

	const Parts: { string } = {}
	for _, Token: any in Renderer.Document.Tokens do
		if Token.Kind == "Break" then table.insert(Parts, "|"); continue end
		if Token.Kind ~= "Word" then table.insert(Parts, "#"); continue end

		table.insert(Parts, (if Token.SpaceBefore then "_" else "") .. Token.Text)
	end

	Renderer:Destroy()
	Target:Destroy()

	return table.concat(Parts, " ")
end

type Pair = {
	Fast: TextLabel;
	Full: TextLabel;
	FastRenderer: any;
	FullRenderer: any;
}

const function Pair(Text: string): Pair
	const Fast: TextLabel = Label(Text)
	const Full: TextLabel = Label(Text)
	const FastRenderer: any = Build(Fast, "Markup")
	const FullRenderer: any = Build(Full, "Markup")

	FastRenderer:Flush()
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

const function Close(Target: Pair?): ()
	if not Target then return end

	Target.FastRenderer:Destroy()
	Target.FullRenderer:Destroy()
	Target.Fast:Destroy()
	Target.Full:Destroy()
end

BeforeAll(function()
	Screen = Gui.new("Whitespace")
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("collapse rule", function()
	for _, Case: { string } in Collapses do
		It(`collapse {string.format("%q", Case[1])}`, function()
			Expect(Whitespace.Collapse(Case[1])).toBe(Case[2])
		end)
	end
end)

Describe("preserve is the default and unchanged", function()
	for _, Source: string in {"a\n   b", "<b>x</b>\n\t<i>y</i>", Nested, "hello\n<b>x</b>", "plain words", "a&#10;\n b"} do
		It(`preserve explicit {string.format("%q", Source)}`, function()
			const Default: string = Render(Source, nil)
			Expect(Render(Source, "Preserve")).toBe(Default)
		end)
	end

	It("preserve keeps newline breaks", function()
		Expect(Words("a\n   b", "Preserve")).toBe("a | _b")
	end)

	It("preserve keeps whitespace text nodes", function()
		Expect(Words("<b>x</b>\n\t<i>y</i>", nil)).toBe("x | _y")
	end)

	It("default mode", function()
		const Target: TextLabel = Label("x")
		const Renderer: any = Library.new(Target):Flush()
		const Mode: string = Renderer:GetWhitespace()
		Renderer:Destroy()
		Target:Destroy()

		Expect(Mode).toBe("Preserve")
	end)
end)

Describe("markup follows the jsx rule", function()
	It("markup joins lines with a space", function()
		Expect(Words("a\n   b", "Markup")).toBe("a _b")
	end)

	It("markup single line unchanged", function()
		Expect(Words("one   line  here", "Markup")).toBe(Words("one   line  here", "Preserve"))
	end)

	It("markup drops whitespace nodes with a newline", function()
		Expect(Words("<b>x</b>\n\t<i>y</i>", "Markup")).toBe("x y")
	end)

	It("markup keeps whitespace nodes without a newline", function()
		Expect(Words("<b>x</b> <i>y</i>", "Markup")).toBe("x _y")
	end)

	It("markup trailing newline before a tag glues", function()
		Expect(Words("hello\n<b>x</b>", "Markup")).toBe("hello x")
	end)

	It("markup keeps first line leading space", function()
		Expect(Words("<b>x</b>  y\n  z", "Markup")).toBe("x _y _z")
	end)

	It("markup crlf", function()
		Expect(Words("a\r\n  b", "Markup")).toBe("a _b")
	end)

	It("markup drops blank lines", function()
		Expect(Words("a\n\n   \n\tb", "Markup")).toBe("a _b")
	end)
end)

Describe("entity escapes survive", function()
	It("escaped space between tags", function()
		Expect(Words("<b>x</b>&#32;\n<i>y</i>", "Markup")).toBe("x _y")
	end)

	It("escaped newline breaks", function()
		Expect(Words("a&#10;\n  b", "Markup")).toBe("a | _b")
	end)

	It("escaped newline alone", function()
		Expect(Words("<b>x</b>&#10;<i>y</i>", "Markup")).toBe("x | y")
	end)
end)

Describe("br breaks", function()
	It("br between indented lines", function()
		Expect(Words("a\n<br/>\n  b", "Markup")).toBe("a | b")
	end)

	It("br in nested markup", function()
		Expect(Words("<b>\n  one\n  <br/>\n  two\n</b>", "Markup")).toBe("one | two")
	end)
end)

Describe("indented markup matches the single line form", function()
	for Index: number, Case: { string } in Layouts do
		It(`layout {Index}`, function()
			Expect(Render(Case[1], "Markup")).toBe(Render(Case[2], "Markup"))
		end)

		It(`layout {Index} differs under preserve`, function()
			Expect(Render(Case[1], "Preserve")).never.toBe(Render(Case[2], "Preserve"))
		end)
	end
end)

Describe("codeblock and md stay whitespace significant", function()
	const Code: string = "<codeblock>\n  local x = 1\n\n    return x\n</codeblock>"
	const Markdown: string = "<md>\n# Title\n\n- one\n- two\n\n  indented text\nnext line\n</md>"
	const Mixed: string = "<b>head</b><md>a\n  b\n\n# c</md>"
	const Unknown: string = "<md>a\n  b</md>"

	It("codeblock tokens", function()
		Expect(Render(Code, "Markup")).toBe(Render(Code, "Preserve"))
	end)

	It("md tokens", function()
		Expect(Render(Markdown, "Markup")).toBe(Render(Markdown, "Preserve"))
	end)

	It("md after markup", function()
		Expect(Render(Mixed, "Markup")).toBe(Render(Mixed, "Preserve"))
	end)

	It("codeblock strip", function()
		Expect(Utilities.Strip(Code, {Whitespace = "Markup"})).toBe(Utilities.Strip(Code))
	end)

	It("md strip", function()
		Expect(Utilities.Strip(Markdown, {Whitespace = "Markup"})).toBe(Utilities.Strip(Markdown))
	end)

	It("disabled md keeps raw lines", function()
		const Disabled = function(Built: any) Built:SetIntents(Library.Intents.Presets.Default:Remove("Markdown", "CodeBlocks")) end
		Expect(Words("<md>a\n  b</md>", "Markup", Disabled)).toBe(Words("<md>a\n  b</md>", "Preserve", Disabled))
	end)

	It("disabled codeblock keeps raw lines", function()
		const Disabled = function(Built: any) Built:SetIntents(Library.Intents.Presets.Default:Remove("Markdown", "CodeBlocks")) end
		Expect(Render(Code, "Markup", Disabled)).toBe(Render(Code, "Preserve", Disabled))
	end)

	It("rejected md keeps raw lines", function()
		const Rejected = function(Built: any) Built:SetIntents(Library.Intents.Presets.Default:Remove("Markdown")):SetDenied("Escape") end
		Expect(Words(Unknown, "Markup", Rejected)).toBe(Words(Unknown, "Preserve", Rejected))
	end)
end)

Describe("strip takes the option", function()
	for _, Case: { string } in Strips do
		It(`strip markup {string.format("%q", Case[1])}`, function()
			Expect(Utilities.Strip(Case[1], {Whitespace = "Markup"})).toBe(Case[2])
		end)
	end

	It("strip default preserves", function()
		Expect(Utilities.Strip("a\n   b")).toBe("a\nb")
	end)

	It("strip explicit preserve", function()
		Expect(Utilities.Strip("a\n   b", {Whitespace = "Preserve"})).toBe("a\nb")
	end)

	It("strip empty options", function()
		Expect(Utilities.Strip("a\n   b", {})).toBe("a\nb")
	end)

	It("strip rejects unknown mode", function()
		Expect(function() Utilities.Strip("x", {Whitespace = "Collapse"}) end).toThrow()
	end)
end)

Describe("links text", function()
	const Source: string = "<a href=\"u\">go<b>\n  now</b></a>"

	It("markup link text glues", function()
		Expect(Render(Source, "Markup")).toContain("link gonow")
	end)

	It("preserve link text spaces", function()
		Expect(Render(Source, "Preserve")).toContain("link go now")
	end)
end)

Describe("options are validated", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("x")
	end)

	AfterAll(function()
		if Renderer then Renderer:Destroy() end
		Target:Destroy()
	end)

	It("new rejects unknown mode", function()
		Expect(function() Library.new(Target, {Whitespace = "Collapse"}) end).toThrow()
	end)

	It("new rejects non string mode", function()
		Expect(function() Library.new(Target, {Whitespace = true}) end).toThrow()
	end)

	It("get markup", function()
		Renderer = Library.new(Target):SetWhitespace("Markup"):Flush()
		Expect(Renderer:GetWhitespace()).toBe("Markup")
	end)

	It("set rejects unknown mode", function()
		Expect(function() Renderer:SetWhitespace("Collapse") end).toThrow()
	end)

	It("failed set keeps mode", function()
		Expect(Renderer:GetWhitespace()).toBe("Markup")
	end)
end)

Describe("switching at runtime re-renders", function()
	local Target: TextLabel
	local Renderer: any
	local Before: string = ""

	BeforeAll(function()
		Target = Label("<b>x</b>\n\t<i>y</i>\nz")
		Renderer = Build(Target, "Preserve")
		Renderer:Flush()
		Before = Stream(Renderer)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("set returns renderer", function()
		Expect(Renderer:SetWhitespace("Markup")).toBe(Renderer)
	end)

	It("switch to markup", function()
		Renderer:Flush()
		Expect(Stream(Renderer)).toBe(Render(Target.Text, "Markup"))
	end)

	It("mode stored", function()
		Expect(Renderer:GetWhitespace()).toBe("Markup")
	end)

	It("switch back to preserve", function()
		Renderer:SetWhitespace("Preserve"):Flush()
		Renderer:Flush()
		Expect(Stream(Renderer)).toBe(Before)
	end)
end)

Describe("native path agrees", function()
	const Source: string = "alpha\n   beta\n\tgamma delta"
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(Source)
		Renderer = Library.new(Target):SetWhitespace("Markup"):Flush()
		Renderer:Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("markup plain text stays native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("native text collapsed", function()
		Expect(Renderer.Native.Markup).toBe("alpha beta gamma delta")
	end)

	It("native tokens match segments", function()
		Expect(Words(Source, "Markup")).toBe("alpha _beta _gamma _delta")
	end)

	It("native preserve keeps newlines", function()
		Renderer:SetWhitespace("Preserve"):Flush()
		Renderer:Flush()
		Expect(Renderer.Native.Markup).toBe("alpha\nbeta\ngamma delta")
	end)
end)

Describe("incremental edits agree with the full path", function()
	const Steps: { string } = {
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points\n  more",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points\n  more words",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points\n  more words\n",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points\n  more words\n  and&#32;\n",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points\n  more words\n  and&#32;\n  x",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>  points",
		"<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n\npoints",
	}

	local Target: Pair?

	BeforeAll(function()
		Target = Pair("<b>Score</b>\n  <font color=\"#ff5555\">1</font>\n  points")
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("single line edit patches", function()
		Expect(Apply(Target :: Pair, "<b>Score</b>\n  <font color=\"#ff5555\">12</font>\n  points")).toBe(true)
	end)

	It("single line edit", function()
		Expect(Stream((Target :: Pair).FastRenderer)).toBe(Stream((Target :: Pair).FullRenderer))
	end)

	for Index: number, Step: string in Steps do
		It(`append step {Index}`, function()
			Apply(Target :: Pair, Step)
			Expect(Stream((Target :: Pair).FastRenderer)).toBe(Stream((Target :: Pair).FullRenderer))
		end)

		It(`append step {Index} matches fresh`, function()
			Expect(Stream((Target :: Pair).FastRenderer)).toBe(Render(Step, "Markup"))
		end)
	end
end)

Describe("incremental link edits agree", function()
	local Target: Pair?

	BeforeAll(function()
		Target = Pair("<a href=\"u\">go<b>\n  now</b></a> tail")
	end)

	AfterAll(function()
		Close(Target)
	end)

	It("link edit", function()
		Apply(Target :: Pair, "<a href=\"u\">go<b>\n  nowhere</b></a> tail")
		Expect(Stream((Target :: Pair).FastRenderer)).toBe(Stream((Target :: Pair).FullRenderer))
	end)

	It("link text collapsed", function()
		Expect(Stream((Target :: Pair).FastRenderer)).toContain("link gonowhere")
	end)

	It("link multi line edit", function()
		Apply(Target :: Pair, "<a href=\"u\">go<b>\n  nowhere\n  fast</b></a> tail")
		Expect(Stream((Target :: Pair).FastRenderer)).toBe(Stream((Target :: Pair).FullRenderer))
	end)

	It("link multi line text", function()
		Expect(Stream((Target :: Pair).FastRenderer)).toContain("link gonowhere fast")
	end)
end)
