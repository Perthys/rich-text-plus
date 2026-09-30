--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const XMLModule = require("../Packages/XML")
const MarkdownModule = require("../Packages/RichTextPlus/Markdown")
const EmitModule = require("../Packages/RichTextPlus/Markdown/Emit")
const HighlighterModule = require("../Packages/RichTextPlus/Text/Highlighter")
const CodeBlockModule = require("../Packages/RichTextPlus/Classes/CodeBlock")
const RuleModule = require("../Packages/RichTextPlus/Classes/Rule")
const CodeModule = require("../Packages/RichTextPlus/Classes/Code")
const IntentsModule = require("../Packages/RichTextPlus/Policy/Intents")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const XML: any = XMLModule
const Markdown: any = MarkdownModule
const Emit: any = EmitModule
const Highlighter: any = HighlighterModule
const CodeBlock: any = CodeBlockModule
const Rule: any = RuleModule
const Code: any = CodeModule
const Presets: any = IntentsModule.Presets

const AllowedTags: { [string]: boolean } = {
	b = true, i = true, s = true, font = true, br = true, a = true, code = true, codeblock = true, hr = true, img = true, indent = true,
}

const Nbsp: string = "\u{A0}"
const Indent: string = string.rep(Nbsp, 2)
const Bar: string = `<indent repeat="true"><font color="#{Color3.fromHex("808080"):ToHex()}">▍</font></indent> `
const Soft: string = `<br/><indent>{Bar}</indent>`

const function Balanced(Markup: string, Allowed: { [string]: boolean }?): (boolean, string?)
	const Stack: { string } = {}
	local Position: number = 1

	while true do
		const Start: number?, Stop: number?, Slash: string?, Name: string?, Rest: string? = string.find(Markup, "<(/?)([%w]+)([^<>]*)>", Position)

		const Text: string = string.sub(Markup, Position, if Start then (Start :: number) - 1 else #Markup)
		if string.find(Text, "[<>]") then return false, `raw angle bracket near {Position}` end
		if string.find((string.gsub(Text, "&#?%w+;", "")), "&", 1, true) then return false, `raw ampersand near {Position}` end

		if not Start then break end

		const Tag: string = string.lower(Name :: string)
		if Allowed and not (Allowed :: { [string]: boolean })[Tag] then return false, `unexpected tag {Tag}` end

		if Slash == "/" then
			if Stack[#Stack] ~= Tag then return false, `mismatched </{Tag}> expected </{tostring(Stack[#Stack])}>` end
			table.remove(Stack)
		elseif string.sub(Rest :: string, -1) ~= "/" then
			table.insert(Stack, Tag)
		end

		Position = (Stop :: number) + 1
	end

	if #Stack > 0 then return false, `unclosed <{Stack[#Stack]}>` end

	return true, nil
end

const function Hex(Class: string): string
	return (Highlighter.Defaults[Class] :: Color3):ToHex()
end

const function ToMarkup(Source: string): string
	return Markdown.ToMarkup(Source, nil, 14)
end

const function Plain(Markup: string): string
	return XML.Unescape((string.gsub(Markup, "</?font[^>]*>", "")))
end

const function Problem(Markup: string): string?
	const Ok: boolean, Reason: string? = Balanced(Markup, AllowedTags)

	return if Ok then nil else `{tostring(Reason)} in {Markup}`
end

const function Cases(List: { { any } }): ()
	for _, Case: { any } in List do
		It(Case[1], function()
			Expect(Case[2]()).toBe(Case[3])
		end)
	end
end

const function WellFormed(Name: string, Source: () -> string): ()
	It(`{Name} balanced`, function()
		Expect(Problem(Source())).toBeNil()
	end)

	It(`{Name} round trip`, function()
		const Markup: string = Source()
		Expect(XML:GenerateXMLFromTree(XML:GenerateTreeFromXML(Markup))).toBe(Markup)
	end)
end

AfterAll(function()
	Gui.Cleanup()
end)

Describe("preprocess", function()
	Cases({
		{"preprocess identity", function() return Markdown.Preprocess("plain <b>text</b>") end, "plain <b>text</b>"},
		{"preprocess escapes body", function() return Markdown.Preprocess("<md>**a** <b> & 'q'</md>") end, "<md>**a** &lt;b&gt; &amp; &apos;q&apos;</md>"},
		{"preprocess case", function() return Markdown.Preprocess("<MD>x</Md>") end, "<md>x</md>"},
		{"preprocess many", function() return Markdown.Preprocess("<md>a<</md> mid <md>b></md>") end, "<md>a&lt;</md> mid <md>b&gt;</md>"},
		{"preprocess unclosed", function() return Markdown.Preprocess("x <md>**y** <b>z</b>") end, "x &lt;md&gt;**y** <b>z</b>"},
		{"preprocess attributes", function() return Markdown.Preprocess("<md theme=\"a\">*x*</md >") end, "<md theme=\"a\">*x*</md>"},
		{"preprocess ignores mdx", function() return Markdown.Preprocess("<mdx>a</mdx>") end, "<mdx>a</mdx>"},
		{"preprocess prose md", function() return Markdown.Preprocess("I love <md and <b>x</b></md>") end, "I love <md and <b>x</b></md>"},
		{"preprocess self closing", function() return Markdown.Preprocess("<md/> <md />") end, "<md/> <md />"},
	})

	const Raw: string = "# Hi\n```lua\nif a < b then\n```\n<b>&amp;"

	const function Block(): any
		return XML:GenerateTreeFromXML(Markdown.Preprocess(`<md>{Raw}</md>`)).Children[1]
	end

	It("preprocess single child", function()
		Expect(#Block().Children).toBe(1)
	end)

	It("preprocess raw survives", function()
		Expect(Block().Children[1]:GetText()).toBe(Raw)
	end)
end)

Describe("inline and block conversion", function()
	const Pairs: { { string } } = {
		{"heading 1", "# Title", "<b><font size=\"28\">Title</font></b>"},
		{"heading 2", "## Title ##", "<b><font size=\"22\">Title</font></b>"},
		{"heading 6", "###### x", "<b><font size=\"13\">x</font></b>"},
		{"heading needs space", "#tag", "#tag"},
		{"heading 7 is text", "####### x", "####### x"},
	}

	for _, Case: { string } in Pairs do
		It(Case[1], function()
			Expect(ToMarkup(Case[2])).toBe(Case[3])
		end)
	end

	It("heading theme scale", function()
		Expect(Markdown.ToMarkup("# a", {HeadingScale = {3}}, 10)).toBe("<b><font size=\"30\">a</font></b>")
	end)

	const Rest: { { string } } = {
		{"setext", "A\n===\nB\n---", "<b><font size=\"28\">A</font></b><br/><b><font size=\"22\">B</font></b>"},
		{"bold", "**b** __u__", "<b>b</b> <b>u</b>"},
		{"italic", "*i* _j_", "<i>i</i> <i>j</i>"},
		{"both", "***x***", "<i><b>x</b></i>"},
		{"nested", "*a **b** c*", "<i>a <b>b</b> c</i>"},
		{"strike", "~~s~~ ~t~", "<s>s</s> ~t~"},
		{"snake case", "snake_case_name _ok_", "snake_case_name <i>ok</i>"},
		{"intraword star", "a*b*c", "a<i>b</i>c"},
		{"unmatched", "**a *b", "**a *b"},
		{"spaced star", "a * b * c", "a * b * c"},
		{"rule of three", "*a**b*", "<i>a**b</i>"},
		{"code span", "`x < y`", "<code>x &lt; y</code>"},
		{"double code span", "``a ` b``", "<code>a ` b</code>"},
		{"code span beats emphasis", "`*a*`", "<code>*a*</code>"},
		{"unmatched backtick", "`a", "`a"},
		{"escapes", "\\*a\\* \\_ \\\\ \\q", "*a* _ \\ \\q"},
		{"html is literal", "<b>x</b> & y", "&lt;b&gt;x&lt;/b&gt; &amp; y"},
		{"quotes escaped", "say \"hi\" it's", "say &quot;hi&quot; it&apos;s"},
		{"link", "[t *e*](http://u.v/a_(b) \"title\")", "<a href=\"http://u.v/a_(b)\">t <i>e</i></a>"},
		{"link angle", "[t](<a b>)", "<a href=\"a b\">t</a>"},
		{"link no dest", "[t] (x)", "[t] (x)"},
		{"no nested links", "[a [b](c) d](e)", "[a <a href=\"c\">b</a> d](e)"},
		{"image", "![alt *x*](rbxassetid://5)", "<img src=\"rbxassetid://5\"/>"},
		{"autolink", "<https://roblox.com/a?b=1&c>", "<a href=\"https://roblox.com/a?b=1&amp;c\">https://roblox.com/a?b=1&amp;c</a>"},
		{"emphasis across link", "*[a*](b)", "*<a href=\"b\">a*</a>"},
		{"line break", "a\nb", "a<br/>b"},
		{"paragraphs", "a\n\n\nb", "a<br/><br/>b"},
		{"boundary whitespace kept", "\n\na\n\n", " a "},
		{"boundary inline", " *a* ", " <i>a</i> "},
		{"blank source", " \n\t ", ""},
		{"dedent", "    # T\n    x", " <b><font size=\"28\">T</font></b><br/>x"},
		{"crlf", "a\r\nb", "a<br/>b"},
		{"fence", "```lua\nlocal a = \"<x>\"\n```", "<codeblock lang=\"lua\">local a = &quot;&lt;x&gt;&quot;</codeblock>"},
		{"fence tilde", "~~~\n~~\n```\n~~~", "<codeblock>~~\n```</codeblock>"},
		{"fence unclosed", "```\na\n\nb", "<codeblock>a\n\nb</codeblock>"},
		{"fence indent", "x\n  ```\n  a\n    b\n  ```", "x<br/><codeblock>a\n  b</codeblock>"},
		{"fence then text", "```\n```\nafter", "<codeblock></codeblock>after"},
		{"rule", "---", "<hr/>"},
		{"rule spaced", "* * *", "<hr/>"},
		{"rule underscores", "___", "<hr/>"},
		{"rule between", "a\n\n***\n\nb", "a<br/><hr/>b"},
	}

	for _, Case: { string } in Rest do
		It(Case[1], function()
			Expect(ToMarkup(Case[2])).toBe(Case[3])
		end)
	end
end)

Describe("lists", function()
	const Before: { { string } } = {
		{"bullets", "- a\n* b\n+ c", `{Indent}• <indent>a</indent><br/>{Indent}• <indent>b</indent><br/>{Indent}• <indent>c</indent>`},
		{"ordered", "3. a\n4. b", `{Indent}3. <indent>a</indent><br/>{Indent}4. <indent>b</indent>`},
		{"ordered paren", "1) a", `{Indent}1) <indent>a</indent>`},
		{"tasks", "- [ ] a\n- [x] b\n- [X]", `{Indent}☐ <indent>a</indent><br/>{Indent}☑ <indent>b</indent><br/>{Indent}☑ `},
		{"empty item", "-", `{Indent}• `},
	}

	for _, Case: { string } in Before do
		It(Case[1], function()
			Expect(ToMarkup(Case[2])).toBe(Case[3])
		end)
	end

	It("nested level 2", function()
		Expect(ToMarkup("- a\n  - b\n    - c\n- d")).toContain("◦ <indent>b</indent>")
	end)

	It("nested level 3", function()
		Expect(ToMarkup("- a\n  - b\n    - c\n- d")).toContain("▪ <indent>c</indent>")
	end)

	It("nested indents", function()
		Expect(select(2, string.gsub(ToMarkup("- a\n  - b\n    - c\n- d"), Nbsp, ""))).toBeGreaterThan(8)
	end)

	It("item continuation", function()
		Expect(ToMarkup("- a\n  more\n\n  second\n- b")).toContain("a<br/>")
	end)

	It("item paragraphs", function()
		Expect(select(2, string.gsub(ToMarkup("- a\n  more\n\n  second\n- b"), "<br/>", ""))).toBe(4)
	end)

	const After: { { string } } = {
		{"lazy continuation", "- a\nb", `{Indent}• <indent>a<br/><indent>{Indent}{string.rep(Nbsp, 2)} </indent>b</indent>`},
		{"list code block", "- a\n\n  ```\n  x\n  ```", `{Indent}• <indent>a</indent><br/><codeblock>x</codeblock>`},
		{"list starts with fence", "- ```\n  x\n  ```", `{Indent}• <br/><codeblock>x</codeblock>`},
		{"list interrupts paragraph", "p\n- a", `p<br/>{Indent}• <indent>a</indent>`},
	}

	for _, Case: { string } in After do
		It(Case[1], function()
			Expect(ToMarkup(Case[2])).toBe(Case[3])
		end)
	end
end)

Describe("quotes", function()
	const Quotes: { { string } } = {
		{"quote", "> a\n> b", `{Bar}<indent>a{Soft}b</indent>`},
		{"quote nested", "> a\n> > b", `{Bar}<indent>a</indent><br/>{Bar}{Bar}<indent>b</indent>`},
		{"quote lazy", "> a\nb", `{Bar}<indent>a{Soft}b</indent>`},
		{"quote gap", "> a\n>\n> b", `{Bar}<indent>a</indent><br/>{Bar}<br/>{Bar}<indent>b</indent>`},
		{"quote heading", "> # h", `{Bar}<indent><b><font size="28">h</font></b></indent>`},
	}

	for _, Case: { string } in Quotes do
		It(Case[1], function()
			Expect(ToMarkup(Case[2])).toBe(Case[3])
		end)
	end

	It("quote color", function()
		Expect(Markdown.ToMarkup("> a", {QuoteColor = Color3.new(1, 0, 0)})).toBe("<indent repeat=\"true\"><font color=\"#ff0000\">▍</font></indent> <indent>a</indent>")
	end)

	It("quote emphasis across lines", function()
		Expect(ToMarkup("> **a\n> b**")).toBe(`{Bar}<indent><b>a{Soft}b</b></indent>`)
	end)
end)

Describe("tree", function()
	local Tree: any

	BeforeAll(function()
		Tree = Markdown.ToTree("**a** `b`\n\n---", nil)
	end)

	It("tree root", function()
		Expect(Tree.Type).toBe("ROOT")
	end)

	It("tree bold", function()
		Expect(Tree.Children[1].TagType).toBe("b")
	end)

	It("tree code", function()
		Expect(Tree.Children[3].TagType).toBe("code")
	end)

	It("tree rule", function()
		Expect(Tree.Children[5].TagType).toBe("hr")
	end)

	It("tree rule single", function()
		Expect(Tree.Children[5].Type).toBe("SINGLE")
	end)
end)

Describe("showcase and fuzz", function()
	const Showcase: string = table.concat({
		"# Patch Notes", "Some **bold**, *italic*, ***both***, ~~gone~~ and `inline < code`.", "",
		"## Lists", "- one", "  - nested *emph*", "    - deeper", "- [ ] todo", "- [x] done", "1. first", "2. second", "",
		"> A quote with **bold**", "> > nested quote", "", "---", "", "```luau", "local x: number = 1 -- <comment>",
		"print(`v{x}`)", "```", "[Docs](https://create.roblox.com) and <https://roblox.com> \\*literal\\*",
		"Setext", "======", "![icon](rbxassetid://1)", "trailing **unclosed *emphasis _here",
	}, "\n")

	WellFormed("showcase", function(): string return ToMarkup(Showcase) end)

	It("fuzz well formed", function()
		const Alphabet: { string } = {
			"*", "**", "_", "__", "~~", "~", "`", "``", "[", "]", "(", ")", "![", "\\", "<", ">", "&", "#", "# ", "- ", "1. ", "> ",
			"```", "---", " ", " ", "\n", "\n\n", "a", "b", "x_y", "http://", "\"", "'", "[ ] ", "  ", ":", "<a:b>",
		}
		const Generator: Random = Random.new(42)
		local Failures: number = 0
		local First: string? = nil

		for Iteration = 1, 3000 do
			const Pieces: { string } = {}
			for _ = 1, Generator:NextInteger(1, 40) do table.insert(Pieces, Alphabet[Generator:NextInteger(1, #Alphabet)]) end

			const Source: string = table.concat(Pieces)
			const Ok: boolean, Markup: any = pcall(ToMarkup, Source)
			const Good: boolean = Ok and Balanced(Markup, AllowedTags) and XML:GenerateXMLFromTree(XML:GenerateTreeFromXML(Markup)) == Markup

			if not Good then
				Failures += 1
				if not First then First = `fuzz {Iteration}: {(string.gsub(Source, "\n", "\\n"))} -> {tostring(Markup)}` end
			end
		end

		Expect(if Failures == 0 then nil else `{Failures} failing inputs, first {First}`).toBeNil()
	end)
end)

Describe("highlighter", function()
	const Sample: string = "local function Foo(A: number, B)\n\treturn `v{A + {1}}` .. \"s\\\"x\" -- c\nend\n"
		.. "print(0xFF, 0b1010, 1_000, 1.5e-3, .5) --[==[ long ]] ]==] x = [[s]] game:GetService('Players')\n"
		.. "type Foo = {Name: string}\nfor i, v in pairs(t) do if not v then continue end end\nconst Y = nil\n"

	local Colored: string = ""

	BeforeAll(function()
		Colored = Highlighter.Highlight(Sample)
	end)

	It("highlight lossless", function()
		Expect(Plain(Colored)).toBe(Sample)
	end)

	WellFormed("highlight", function(): string return Colored end)

	const Contains: { { any } } = {
		{"highlight storage", function(): string return `<font color="#{Hex("Storage")}">local function </font>` end},
		{"highlight function def", function(): string return `<font color="#{Hex("Function")}">Foo</font>` end},
		{"highlight parameter", function(): string return `<font color="#{Hex("Local")}">A</font>` end},
		{"highlight type", function(): string return `<font color="#{Hex("Type")}">number</font>` end},
		{"highlight keyword", function(): string return `<font color="#{Hex("Keyword")}">return </font>` end},
		{"highlight interpolation", function(): string return `<font color="#{Hex("Interpolation")}">{"{"}</font>` end},
		{"highlight escaped string", function(): string return "&quot;s\\&quot;x&quot;" end},
		{"highlight comment", function(): string return `<font color="#{Hex("Comment")}">-- c` end},
		{"highlight long comment", function(): string return "--[==[ long ]] ]==]" end},
		{"highlight hex", function(): string return ">0xFF<" end},
		{"highlight binary", function(): string return ">0b1010<" end},
		{"highlight underscore number", function(): string return ">1_000<" end},
		{"highlight exponent", function(): string return ">1.5e-3<" end},
		{"highlight leading dot number", function(): string return ">.5<" end},
		{"highlight builtin", function(): string return `<font color="#{Hex("Builtin")}">game</font>` end},
		{"highlight method", function(): string return `<font color="#{Hex("Function")}">GetService</font>` end},
		{"highlight loop locals", function(): string return `<font color="#{Hex("Local")}">i</font>` end},
		{"highlight literal", function(): string return `<font color="#{Hex("Literal")}">nil` end},
		{"highlight const name", function(): string return `<font color="#{Hex("Local")}">Y </font>` end},
		{"highlight keyword run", function(): string return `<font color="#{Hex("Keyword")}">do if not </font>` end},
	}

	for _, Case: { any } in Contains do
		It(Case[1], function()
			Expect(Colored).toContain(Case[2]())
		end)
	end

	It("highlight simple", function()
		Expect(Highlighter.Highlight("local x = 1")).toBe(`<font color="#{Hex("Storage")}">local </font><font color="#{Hex("Local")}">x </font>= <font color="#{Hex("Number")}">1</font>`)
	end)

	It("highlight override", function()
		Expect(Highlighter.Highlight("local x", {Storage = Color3.new(1, 0, 0)})).toContain("<font color=\"#ff0000\">local ")
	end)

	It("highlight text override untagged", function()
		Expect(Highlighter.Highlight("x", {Text = Color3.new(1, 0, 0), Local = Color3.new(1, 0, 0)})).toBe("x")
	end)

	for _, Broken: string in {"\"abc", "'a\\", "[[abc", "--[[abc", "`a{b", "`a{b}", "`a{ {1} ", "0x", "a.", "::", "\\", "\"a\nb\""} do
		It(`highlight unterminated {Broken}`, function()
			const Ok: boolean, Output: any = pcall(Highlighter.Highlight, Broken)
			Expect(Ok and Plain(Output) == Broken and Balanced(Output)).toBe(true)
		end)
	end

	It("highlight fuzz lossless", function()
		const Generator: Random = Random.new(7)
		const Alphabet: string = "abc01xX_.:-[]=\"'`{}()<>&\\\n \t#+*/%^~|,;"
		local Mismatches: number = 0

		for _ = 1, 2000 do
			const Bytes: { string } = {}
			for _ = 1, Generator:NextInteger(1, 60) do
				const Index: number = Generator:NextInteger(1, #Alphabet)
				table.insert(Bytes, string.sub(Alphabet, Index, Index))
			end

			const Source: string = table.concat(Bytes)
			const Ok: boolean, Output: any = pcall(Highlighter.Highlight, Source)
			if not (Ok and Plain(Output) == Source and Balanced(Output)) then Mismatches += 1 end
		end

		Expect(Mismatches).toBe(0)
	end)
end)

Describe("classes", function()
	const Style = {
		Bold = false, Italic = false, Underline = false, Strike = false, Color = Color3.new(1, 1, 1), Size = 16,
		Family = "rbxasset://fonts/families/BuilderSans.json", Transparency = 0,
	}

	const function Node(Markup: string): any
		return XML:GenerateTreeFromXML(Markup).Children[1]
	end

	const Built: { Instance } = {}

	const function Make(Class: any, Markup: string, Scale: number, State: any?): Frame
		const Frame: Frame = Class.Build(Node(Markup), table.clone(Style), Scale, State)
		table.insert(Built, Frame)

		return Frame
	end

	local Block: Frame
	local Panel: Frame
	local Body: TextLabel

	BeforeAll(function()
		Block = Make(CodeBlock, "<codeblock lang=\"Luau\">\n\tlocal x = 1\nprint(x)  \n\n</codeblock>", 1)
		Panel = Block:FindFirstChild("Panel") :: Frame
		Body = Panel:FindFirstChild("Code") :: TextLabel
	end)

	AfterAll(function()
		for _, Item: Instance in Built do Item:Destroy() end
	end)

	It("codeblock name", function()
		Expect(Block.Name).toBe("CodeBlock")
	end)

	It("codeblock block flag", function()
		Expect(CodeBlock.Block).toBe(true)
	end)

	It("codeblock kind", function()
		Expect(CodeBlock.Kind).toBe("Object")
	end)

	It("codeblock has size", function()
		Expect(Block.Size.X.Offset > 0 and Block.Size.Y.Offset > 0).toBe(true)
	end)

	It("codeblock rich", function()
		Expect(Body.RichText).toBe(true)
	end)

	It("codeblock source normalized", function()
		Expect(Plain(Body.Text)).toBe("    local x = 1\nprint(x)")
	end)

	It("codeblock corner", function()
		Expect(Panel:FindFirstChildOfClass("UICorner")).never.toBeNil()
	end)

	It("codeblock padding", function()
		Expect(Panel:FindFirstChildOfClass("UIPadding")).never.toBeNil()
	end)

	It("codeblock language", function()
		Expect((Panel:FindFirstChild("Language") :: TextLabel).Text).toBe("Luau")
	end)

	It("codeblock background", function()
		Expect(Panel.BackgroundColor3).toBe(Markdown.Defaults.CodeBackground)
	end)

	It("codeblock family", function()
		Expect(Body.FontFace.Family).toBe("rbxasset://fonts/families/RobotoMono.json")
	end)

	It("codeblock clips", function()
		Expect(Panel.ClipsDescendants).toBe(true)
	end)

	It("codeblock width relative", function()
		Expect(Panel.Size.X.Scale == 1 and Body.Size.X.Scale == 1).toBe(true)
	end)

	It("codeblock two lines tall", function()
		Expect(Body.Size.Y.Offset >= 32 and Body.Size.Y.Offset < 48).toBe(true)
	end)

	It("codeblock other language plain", function()
		const Other: Frame = Make(CodeBlock, "<codeblock lang=\"python\">x = 1</codeblock>", 1)
		Expect(((Other:FindFirstChild("Panel") :: Frame):FindFirstChild("Code") :: TextLabel).RichText).toBe(false)
	end)

	It("codeblock language attribute is not a lang alias", function()
		const AliasedPanel: Frame = Make(CodeBlock, "<codeblock language=\"lua\">local x</codeblock>", 1):FindFirstChild("Panel") :: Frame
		Expect(AliasedPanel:FindFirstChild("Language") == nil and not (AliasedPanel:FindFirstChild("Code") :: TextLabel).RichText).toBe(true)
	end)

	local ThemedPanel: Frame

	It("codeblock theme background", function()
		ThemedPanel = Make(CodeBlock, "<codeblock>x</codeblock>", 2, {
			Theme = {CodeBackground = Color3.new(1, 0, 0), CodePadding = 4, CodeFamily = "Arial"},
			Intents = Presets.Default,
			Rendering = {SyntaxHighlight = true},
		}):FindFirstChild("Panel") :: Frame
		Expect(ThemedPanel.BackgroundColor3).toBe(Color3.new(1, 0, 0))
	end)

	It("codeblock theme padding scaled", function()
		Expect((ThemedPanel:FindFirstChildOfClass("UIPadding") :: UIPadding).PaddingLeft.Offset).toBe(8)
	end)

	It("codeblock no language label", function()
		Expect(ThemedPanel:FindFirstChild("Language")).toBeNil()
	end)

	It("codeblock highlight off", function()
		const Unhighlighted: Frame = Make(CodeBlock, "<codeblock>local x</codeblock>", 1, {Theme = {}, Intents = Presets.Default, Rendering = {SyntaxHighlight = false}})
		const UnhighlightedBody: TextLabel = (Unhighlighted:FindFirstChild("Panel") :: Frame):FindFirstChild("Code") :: TextLabel
		Expect(not UnhighlightedBody.RichText and UnhighlightedBody.Text == "local x").toBe(true)
	end)

	local FlatPanel: Frame

	It("codeblock off transparent", function()
		FlatPanel = Make(CodeBlock, "<codeblock lang=\"lua\">local x</codeblock>", 1, {Theme = {}, Intents = Presets.Default:Remove("CodeBlocks"), Rendering = {SyntaxHighlight = true}}):FindFirstChild("Panel") :: Frame
		Expect(FlatPanel.BackgroundTransparency).toBe(1)
	end)

	It("codeblock off plain", function()
		Expect(FlatPanel:FindFirstChildOfClass("UICorner") == nil and not (FlatPanel:FindFirstChild("Code") :: TextLabel).RichText).toBe(true)
	end)

	It("codeblock off color", function()
		Expect((FlatPanel:FindFirstChild("Code") :: TextLabel).TextColor3).toBe(Style.Color)
	end)

	It("codeblock empty has height", function()
		Expect(Make(CodeBlock, "<codeblock></codeblock>", 1).Size.Y.Offset).toBeGreaterThan(0)
	end)

	local Divider: Frame
	local Line: Frame

	It("rule name", function()
		Divider = Make(Rule, "<hr color=\"#00ff00\" THICKNESS=\"3\"/>", 1)
		Line = Divider:FindFirstChild("Line") :: Frame
		Expect(Divider.Name).toBe("Rule")
	end)

	It("rule block", function()
		Expect(Rule.Block).toBe(true)
	end)

	It("rule color", function()
		Expect(Line.BackgroundColor3).toBe(Color3.fromRGB(0, 255, 0))
	end)

	It("rule thickness", function()
		Expect(Line.Size.Y.Offset).toBe(3)
	end)

	It("rule full width", function()
		Expect(Line.Size.X.Scale).toBe(1)
	end)

	It("rule default color", function()
		Expect((Make(Rule, "<hr/>", 1):FindFirstChild("Line") :: Frame).BackgroundColor3).toBe(Markdown.Defaults.RuleColor)
	end)

	local Inline: any

	It("code kind", function()
		Inline = table.clone(Style)
		Code.Apply(Inline, Node("<code>x</code>"), nil)
		Expect(Code.Kind).toBe("Style")
	end)

	It("code flag", function()
		Expect(Inline.Code).toBe(true)
	end)

	It("code family", function()
		Expect(Inline.Family).toBe("rbxasset://fonts/families/RobotoMono.json")
	end)

	It("code color", function()
		Expect(Inline.Color).toBe(Markdown.Defaults.CodeTextColor)
	end)
end)

Describe("render", function()
	type Seen = {
		HasBlock: boolean,
		BlockWidth: number?,
		HasDivider: boolean,
		HasPanel: boolean,
		PanelTransparency: number?,
		HasBody: boolean,
		BodyRich: boolean,
		Texts: string,
	}

	local Holder: ScreenGui

	const function Render(Setup: ((any) -> ())?): Seen
		const Label: TextLabel = Instance.new("TextLabel")
		Label.Size = UDim2.fromOffset(400, 300)
		Label.TextSize = 16
		Label.TextWrapped = true
		Label.Text = "<md>**b** & <x>\n\n---\n```lua\nlocal x = 1\n```</md>"
		Label.Parent = Holder

		const Renderer: any = Library.new(Label)
		if Setup then Setup(Renderer) end
		Renderer:Flush()

		const Texts: { string } = {}

		for _, Child: Instance in Label:GetChildren() do
			if Child:IsA("TextLabel") or Child:IsA("TextButton") then table.insert(Texts, XML.Unescape((Child :: TextLabel).Text)) end
		end

		const Block: Frame? = Label:FindFirstChild("CodeBlock") :: Frame?
		const Panel: Frame? = if Block then Block:FindFirstChild("Panel") :: Frame? else nil
		const Body: TextLabel? = if Panel then Panel:FindFirstChild("Code") :: TextLabel? else nil

		const Result: Seen = {
			HasBlock = Block ~= nil,
			BlockWidth = if Block then Block.Size.X.Offset else nil,
			HasDivider = Label:FindFirstChild("Rule") ~= nil,
			HasPanel = Panel ~= nil,
			PanelTransparency = if Panel then Panel.BackgroundTransparency else nil,
			HasBody = Body ~= nil,
			BodyRich = if Body then Body.RichText else false,
			Texts = table.concat(Texts, "|"),
		}

		Renderer:Destroy()
		Label:Destroy()

		return Result
	end

	local Default: Seen
	local Off: Seen
	local CodeOff: Seen
	local HighlightOff: Seen

	BeforeAll(function()
		Holder = Gui.new("Markdown")
		Default = Render(nil)
		Off = Render(function(Built: any) Built:SetIntents(Presets.Default:Remove("Markdown")):SetRendering("Passthrough", false) end)
		CodeOff = Render(function(Built: any) Built:SetIntents(Presets.Default:Remove("CodeBlocks")) end)
		HighlightOff = Render(function(Built: any) Built:SetRendering("SyntaxHighlight", false) end)
	end)

	It("render codeblock", function()
		Expect(Default.HasPanel and Default.PanelTransparency == 0).toBe(true)
	end)

	It("render rule", function()
		Expect(Default.HasDivider).toBe(true)
	end)

	It("render literal symbols", function()
		Expect(Default.Texts).toContain("& <x>")
	end)

	It("render bold stripped", function()
		Expect(Default.Texts).never.toContain("**")
	end)

	It("render codeblock full width", function()
		Expect(Default.BlockWidth).toBe(400)
	end)

	It("render codeblock highlighted", function()
		Expect(Default.HasBody and Default.BodyRich).toBe(true)
	end)

	It("markdown off no objects", function()
		Expect(not Off.HasBlock and not Off.HasDivider).toBe(true)
	end)

	It("markdown off literal", function()
		Expect(Off.Texts).toContain("**b** & <x>")
	end)

	It("codeblocks off plain", function()
		Expect(CodeOff.HasPanel and CodeOff.PanelTransparency == 1 and CodeOff.HasBody and not CodeOff.BodyRich).toBe(true)
	end)

	It("highlight off", function()
		Expect(HighlightOff.HasPanel and HighlightOff.PanelTransparency == 0 and HighlightOff.HasBody and not HighlightOff.BodyRich).toBe(true)
	end)
end)

Describe("ast", function()
	local Children: { any }
	local Inlines: { any }
	local Document: any

	BeforeAll(function()
		Document = Markdown.Parse("# Title\n\nSome *soft* and **strong** `code` [link](http://x.y) ![pic](7)\n\n> quoted\n> > nested\n\n- one\n  - inner\n- [x] done\n\n3) three\n4) four\n\n```lua\nprint(1)\n```\n\n---")
		Children = Document.Children
		Inlines = Children[2].Children
	end)

	Cases({
		{"ast document type", function() return Document.Type end, "Document"},
		{"ast block count", function() return #Children end, 7},
		{"ast heading", function() return Children[1].Type end, "Heading"},
		{"ast heading level", function() return Children[1].Level end, 1},
		{"ast heading inline", function() return Children[1].Children[1].Value end, "Title"},
		{"ast paragraph spaced", function() return Children[2].Spaced end, true},
		{"ast first block not spaced", function() return Children[1].Spaced end, false},
		{"ast inline text", function() return Inlines[1].Value end, "Some "},
		{"ast emphasis", function() return Inlines[2].Type end, "Emphasis"},
		{"ast emphasis child", function() return Inlines[2].Children[1].Value end, "soft"},
		{"ast strong", function() return Inlines[4].Type end, "Strong"},
		{"ast code span", function() return Inlines[6].Type end, "Code"},
		{"ast code value", function() return Inlines[6].Value end, "code"},
		{"ast link", function() return Inlines[8].Type end, "Link"},
		{"ast link destination", function() return Inlines[8].Destination end, "http://x.y"},
		{"ast link text", function() return Inlines[8].Children[1].Value end, "link"},
		{"ast image", function() return Inlines[10].Type end, "Image"},
		{"ast image source", function() return Inlines[10].Source end, "7"},
		{"ast quote", function() return Children[3].Type end, "BlockQuote"},
		{"ast quote paragraph", function() return Children[3].Children[1].Type end, "Paragraph"},
		{"ast nested quote", function() return Children[3].Children[2].Type end, "BlockQuote"},
		{"ast bullet list", function() return Children[4].Type end, "List"},
		{"ast bullet unordered", function() return Children[4].Ordered end, false},
		{"ast bullet items", function() return #Children[4].Items end, 2},
		{"ast nested list", function() return Children[4].Items[1].Children[2].Type end, "List"},
		{"ast task checked", function() return Children[4].Items[2].Checked end, true},
		{"ast plain item unchecked", function() return Children[4].Items[1].Checked end, nil},
		{"ast ordered", function() return Children[5].Ordered end, true},
		{"ast ordered start", function() return Children[5].Start end, 3},
		{"ast ordered delimiter", function() return Children[5].Delimiter end, ")"},
		{"ast fence", function() return Children[6].Type end, "CodeBlock"},
		{"ast fence language", function() return Children[6].Language end, "lua"},
		{"ast fence body", function() return Children[6].Body end, "print(1)"},
		{"ast rule", function() return Children[7].Type end, "ThematicBreak"},
	})
end)

Describe("ast details", function()
	local Tail: any
	local Nested: any
	local Escaped: any

	BeforeAll(function()
		Tail = Markdown.Parse("Setext\n---\n\n")
		Nested = Markdown.Parse("***x***")
		Escaped = Markdown.Parse("a\\*b &amp; <http://u.v>")
	end)

	Cases({
		{"ast setext heading", function() return Tail.Children[1].Type end, "Heading"},
		{"ast setext level", function() return Tail.Children[1].Level end, 2},
		{"ast trailing blank", function() return Tail.EndsBlank end, true},
		{"ast trailing space", function() return Tail.TrailingSpace end, true},
		{"ast leading space", function() return Tail.LeadingSpace end, false},
		{"ast triple emphasis outer", function() return Nested.Children[1].Children[1].Type end, "Emphasis"},
		{"ast triple emphasis inner", function() return Nested.Children[1].Children[1].Children[1].Type end, "Strong"},
		{"ast escape keeps literal", function() return Escaped.Children[1].Children[2].Value end, "*"},
		{"ast entity decoded", function() return Escaped.Children[1].Children[3].Value end, "b & "},
		{"ast autolink", function() return Escaped.Children[1].Children[4].Type end, "Link"},
		{"ast break", function() return Markdown.Parse("a\nb").Children[1].Children[2].Type end, "Break"},
		{"ast depth limit keeps one block", function() return #Markdown.Parse(string.rep("> ", 20) .. "deep").Children end, 1},
		{"ast parse matches render", function() return Markdown.ToMarkup("*a*") end, "<i>a</i>"},
	})
end)

Describe("dialects", function()
	local Dialect: any

	BeforeAll(function()
		const Notes: any = {
			Name = "Note";
			Leads = "!";
			Interrupts = true;
			Nested = false;
			Test = function(Line: string): boolean return string.find(Line, "^!!! ") ~= nil end;
			Parse = function(_: any, Lines: { string }, Index: number): (any, number)
				const Body: string? = string.match(Lines[Index], "^!!! (.*)$")
				if not Body then return nil, Index end

				return {Type = "Note", Source = Body}, Index + 1
			end;
		}

		Dialect = Markdown.Extend(Markdown.Standard, {
			Blocks = {Notes};
			Emitters = {
				Note = function(Out: any, Node: any, Context: any): ()
					Emit.WriteText(Out, Context, Node.Source, "<i>", "</i>")
				end;
			};
			Inlines = {
				[string.byte("^")] = function(State: any, _: string, Start: number): number
					State.Count += 1
					State.Pieces[State.Count] = {Type = "Text", Value = "caret"}

					return Start + 1
				end;
			};
		})
	end)

	Cases({
		{"extension block parses", function() return Markdown.Parse("text\n!!! heads up", Dialect).Children[2].Type end, "Note"},
		{"extension block interrupts paragraphs", function() return #Markdown.Parse("text\n!!! heads up", Dialect).Children end, 2},
		{"extension emitter renders", function() return Markdown.ToMarkup("!!! a^b", nil, 14, Dialect) end, "<i>acaretb</i>"},
		{"standard dialect unchanged", function() return Markdown.ToMarkup("!!! a^b", nil, 14) end, "!!! a^b"},
		{"extension keeps paragraph last", function() return Dialect.Blocks[#Dialect.Blocks].Name end, "Paragraph"},
		{"dialect frozen", function() return table.isfrozen(Dialect) end, true},
	})
end)
