--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Markdown = require("../Packages/RichTextPlus/Markdown")
const XML = require("../Packages/XML")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Utilities: any = Library.Utilities

const Names: { string } = {
	"Escape", "Unescape", "Attribute", "AttributeNumber", "AttributeBoolean", "InnerText",
	"ParseColor", "FormatColor", "ParseWeight", "Trim", "CanonicalId", "Strip", "Markdown", "ParseMarkdown", "Highlight",
}

const Texts: { string } = {
	"plain", "a & b", "<b>not bold</b>", [["quoted" and 'single']], "&amp; already", "&#8238;", "\u{E9}t\u{E9} \u{1F600}", "", "&&&<<>>",
}

const Junks: { string } = {"&#xFFFFFFFFFFFF;", "&#0;", "&bogus;", "&", "&#;", "&#xD800;", "&#99999999999999999999;"}

const Inline: { string } = {
	"<b>bold</b> <i>it</i> <u>u</u> <s>s</s>",
	[[<font color="#f00" size="30">a</font> <stroke thickness="2">b</stroke> <mark>c</mark>]],
	"<uc>up</uc> <smallcaps>Small</smallcaps> <uppercase>x</uppercase> <sc>y</sc>",
	"a<br/>b\nc",
	"  a   b  \n  c  ",
	"a &amp; b &lt;c&gt; &#65;",
	"a<!-- x -->b",
	[[a <img src="rbxassetid://1"/> b<img src="1">cap</img>]],
	[[<a href="u">click me</a> <a href="https://x"/>]],
	"<code>x = 1</code> after",
	[[<gradient colors="#f00,#00f">g</gradient> <wave>w</wave> <shake>s</shake> <customclass><glow>e</glow></customclass>]],
	[[<indent by="20">in dent</indent> <dir value="ltr">dir</dir>]],
	[[<customclass name="warn">w</customclass> <customclass><icon/>x</customclass> <foo>bar</foo>]],
	"<md>**bold** and *it* [link](u)\n- item\n1. one\n> quote\n# Head</md>",
	"CJK \u{6625}\u{7720}\u{4E0D}\u{899A}\u{6681} end",
	"emoji \u{1F469}\u{200D}\u{1F4BB} ok",
}

const Strips: { { string } } = {
	{"<b>bold</b> <i>it</i> <u>u</u> <s>s</s>", "bold it u s"},
	{[[<font color="#f00" size="30" face="Arial">a</font> <stroke thickness="2">b</stroke> <mark>c</mark>]], "a b c"},
	{"<uc>up</uc> <smallcaps>Small</smallcaps>", "up Small"},
	{"a<br/>b\nc", "a\nb\nc"},
	{"  a   b  \n  c  ", "a b\nc"},
	{"a &amp; b &lt;c&gt; &#65;", "a & b <c> A"},
	{"a<!-- <b>x</b> -->b", "ab"},
	{[[a <img src="rbxassetid://1"/> b <img src="1">cap</img>]], "a b cap"},
	{[[<a href="u">click me</a> <a href="https://x"/>]], "click me https://x"},
	{"a<hr/>b", "a\n\nb"},
	{"<code>x = 1</code>", "x = 1"},
	{"a <codeblock lang=\"lua\">\nlocal x = 1\n\tprint(x)  \n</codeblock> b", "a\nlocal x = 1\n    print(x)\nb"},
	{[[<gradient colors="#f00,#00f">g</gradient> <wave>w</wave> <shake>s</shake> <customclass><glow>e</glow></customclass>]], "g w s e"},
	{[[<indent by="20">in dent</indent> <dir value="rtl">dir</dir>]], "in dent dir"},
	{[[<customclass name="warn">w</customclass> <customclass><icon/>x</customclass> <foo>bar</foo>]], "w x bar"},
	{"<md>**bold** and *it* [link](u)</md>", "bold and it link"},
	{"<md>a &lt;b&gt; &amp;amp;</md>", "a <b> &amp;"},
	{"<md>```lua\nlocal y\n```\ntext `c`</md>", "local y\ntext c"},
	{"<md>---</md>after", "\nafter"},
	{"", ""},
	{"no tags at all", "no tags at all"},
}

local Screen: ScreenGui
const Renderers: { any } = {}

const function Mount(Width: number, Height: number): any
	const Target: TextLabel = Instance.new("TextLabel")
	Target.Size = UDim2.fromOffset(Width, Height)
	Target.TextSize = 20
	Target.Parent = Screen

	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Same(Left: Color3?, Right: Color3): boolean
	return Left ~= nil and (Left :: Color3):ToHex() == Right:ToHex()
end

const function Node(Markup: string): any
	return XML.GenerateTreeFromXML(Markup).Children[1]
end

BeforeAll(function()
	Screen = Gui.new("Utilities")
end)

AfterAll(function()
	for _, Renderer: any in Renderers do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("surface", function()
	It("Utilities frozen", function()
		Expect(table.isfrozen(Utilities)).toBe(true)
	end)

	It("exposed count", function()
		local Count: number = 0
		for _ in Utilities do Count += 1 end

		Expect(Count).toBe(#Names)
	end)

	for _, Name: string in Names do
		It(`{Name} exposed`, function()
			Expect(type(Utilities[Name])).toBe("function")
		end)
	end

	It("CanonicalId lives on Utilities", function()
		Expect(Utilities.CanonicalId("123")).toBe("rbxassetid://123")
	end)

	It("no GraphemeCount", function()
		Expect(Utilities.GraphemeCount).toBeNil()
	end)
end)

Describe("escape and unescape", function()
	for _, Text: string in Texts do
		It(`round trip {Text}`, function()
			Expect(Utilities.Unescape(Utilities.Escape(Text))).toBe(Text)
		end)
	end

	It("Escape escapes every special", function()
		Expect(Utilities.Escape([[&<>"']])).toBe("&amp;&lt;&gt;&quot;&apos;")
	end)

	It("Unescape named and numeric", function()
		Expect(Utilities.Unescape("&lt;b&gt; &amp; &quot;&apos; &#65;&#x42;")).toBe([[<b> & "' AB]])
	end)

	It("Unescape leaves plain text", function()
		Expect(Utilities.Unescape("plain")).toBe("plain")
	end)

	for _, Junk: string in Junks do
		It(`Unescape never throws on {Junk}`, function()
			Expect(function() Utilities.Unescape(Junk) end).never.toThrow()
		end)

		It(`Unescape keeps {Junk} literal`, function()
			const Ok: boolean, Value: any = pcall(Utilities.Unescape, Junk)
			Expect(if Ok then Value else nil).toBe(Junk)
		end)
	end
end)

Describe("colors", function()
	const Parsed: { { any } } = {
		{"named color", "gold", Color3.fromRGB(255, 215, 0)},
		{"named color any case", " Gray ", Color3.fromRGB(128, 128, 128)},
		{"#RGB", "#ABC", Color3.fromRGB(170, 187, 204)},
		{"#RRGGBB", "#FF7800", Color3.fromRGB(255, 120, 0)},
		{"RRGGBB without hash", "ff7800", Color3.fromRGB(255, 120, 0)},
		{"rgb()", "rgb(1, 2, 3)", Color3.fromRGB(1, 2, 3)},
		{"rgb() clamps channels", "RGB(300,0,0)", Color3.fromRGB(255, 0, 0)},
	}

	for _, Case: { any } in Parsed do
		It(Case[1], function()
			Expect(Same(Utilities.ParseColor(Case[2]), Case[3])).toBe(true)
		end)
	end

	for _, Junk: string in {"", "nope", "#12", "#GGGGGG", "rgb(1, 2)", "hsl(0, 0%, 0%)", "grey"} do
		It(`rejects {Junk}`, function()
			Expect(Utilities.ParseColor(Junk)).toBeNil()
		end)
	end

	It("FormatColor", function()
		Expect(Utilities.FormatColor(Color3.fromRGB(12, 34, 56))).toBe("rgb(12, 34, 56)")
	end)

	It("FormatColor rounds and clamps", function()
		Expect(Utilities.FormatColor(Color3.new(2, -1, 0.5))).toBe("rgb(255, 0, 128)")
	end)

	It("FormatColor of a parsed hex", function()
		Expect(Utilities.FormatColor(Utilities.ParseColor("#ABC"))).toBe("rgb(170, 187, 204)")
	end)

	for Red = 0, 255, 51 do
		for Green = 0, 255, 85 do
			It(`round trip {Red}, {Green}`, function()
				const Color: Color3 = Color3.fromRGB(Red, Green, 255 - Red)
				Expect(Same(Utilities.ParseColor(Utilities.FormatColor(Color)), Color)).toBe(true)
			end)
		end
	end

	It("markup accepts FormatColor", function()
		const Renderer: any = Mount(200, 40)
		Renderer.Label.Text = `<font color="{Utilities.FormatColor(Color3.fromRGB(10, 200, 30))}">x</font>`
		Renderer:Flush()

		Expect(Same(Renderer.Document.Tokens[1].Style.Color, Color3.fromRGB(10, 200, 30))).toBe(true)
	end)
end)

Describe("weights", function()
	const Cases: { { any } } = {
		{"bold name", "bold", Enum.FontWeight.Bold},
		{"name ignores case", "ExtraBold", Enum.FontWeight.ExtraBold},
		{"name ignores hyphens", "semi-bold", Enum.FontWeight.SemiBold},
		{"name ignores underscores", "extra_light", Enum.FontWeight.ExtraLight},
		{"numeric weight", "700", Enum.FontWeight.Bold},
		{"numeric weight rounds", "640", Enum.FontWeight.SemiBold},
		{"numeric weight clamps high", "5000", Enum.FontWeight.Heavy},
		{"numeric weight clamps low", "0", Enum.FontWeight.Thin},
	}

	for _, Case: { any } in Cases do
		It(Case[1], function()
			Expect(Utilities.ParseWeight(Case[2])).toBe(Case[3])
		end)
	end

	It("unknown weight", function()
		Expect(Utilities.ParseWeight("heavyish")).toBeNil()
	end)

	It("empty weight", function()
		Expect(Utilities.ParseWeight("")).toBeNil()
	end)

	It("missing weight", function()
		Expect(Utilities.ParseWeight(nil)).toBeNil()
	end)

	for _, Weight: Enum.FontWeight in Enum.FontWeight:GetEnumItems() :: { Enum.FontWeight } do
		It(`{Weight.Name} by name`, function()
			Expect(Utilities.ParseWeight(Weight.Name)).toBe(Weight)
		end)

		It(`{Weight.Name} by value`, function()
			Expect(Utilities.ParseWeight(tostring(Weight.Value))).toBe(Weight)
		end)
	end

	It("markup agrees with ParseWeight", function()
		const Renderer: any = Mount(200, 40)
		Renderer.Label.Text = [[<font weight="semi-bold">w</font>]]
		Renderer:Flush()

		Expect(Renderer.Document.Tokens[1].Style.Weight).toBe(Utilities.ParseWeight("semi-bold"))
	end)
end)

Describe("trim", function()
	const Cases: { { string } } = {
		{"both ends", "  a b  ", "a b"},
		{"tabs and newlines", "\t\na\r\n", "a"},
		{"nothing to trim", "ab", "ab"},
		{"only spaces", "   ", ""},
		{"empty", "", ""},
		{"inner space kept", " a  b ", "a  b"},
		{"non ascii kept", " \u{E9} ", "\u{E9}"},
	}

	for _, Case: { string } in Cases do
		It(Case[1], function()
			Expect(Utilities.Trim(Case[2])).toBe(Case[3])
		end)
	end
end)

Describe("attributes", function()
	local Tag: any

	BeforeAll(function()
		Tag = Node([[<v Size=" 12.5 " big="1e999" junk="abc" none="nan" Looped="OFF" playing="yes" empty="" zero="0">text &amp; <b>more</b><br/>end</v>]])
	end)

	It("Attribute is case-insensitive", function()
		Expect(Utilities.Attribute(Tag, "size")).toBe(" 12.5 ")
	end)

	It("AttributeNumber parses", function()
		Expect(Utilities.AttributeNumber(Tag, "SIZE")).toBe(12.5)
	end)

	It("AttributeNumber missing", function()
		Expect(Utilities.AttributeNumber(Tag, "width")).toBeNil()
	end)

	It("AttributeNumber missing default", function()
		Expect(Utilities.AttributeNumber(Tag, "width", 4)).toBe(4)
	end)

	It("AttributeNumber junk default", function()
		Expect(Utilities.AttributeNumber(Tag, "junk", 7)).toBe(7)
	end)

	It("AttributeNumber infinity default", function()
		Expect(Utilities.AttributeNumber(Tag, "big", 3)).toBe(3)
	end)

	It("AttributeNumber nan", function()
		Expect(Utilities.AttributeNumber(Tag, "none")).toBeNil()
	end)

	It("AttributeBoolean false word", function()
		Expect(Utilities.AttributeBoolean(Tag, "looped", true)).toBe(false)
	end)

	It("AttributeBoolean zero", function()
		Expect(Utilities.AttributeBoolean(Tag, "zero", true)).toBe(false)
	end)

	It("AttributeBoolean yes", function()
		Expect(Utilities.AttributeBoolean(Tag, "playing", false)).toBe(true)
	end)

	It("AttributeBoolean empty is true", function()
		Expect(Utilities.AttributeBoolean(Tag, "empty", false)).toBe(true)
	end)

	It("AttributeBoolean missing default", function()
		Expect(Utilities.AttributeBoolean(Tag, "muted", true)).toBe(true)
	end)

	It("InnerText decodes and keeps breaks", function()
		Expect(Utilities.InnerText(Tag)).toBe("text & more\nend")
	end)
end)

Describe("strip", function()
	for _, Case: { string } in Strips do
		It(`Strip {Case[1]}`, function()
			Expect(Utilities.Strip(Case[1])).toBe(Case[2])
		end)
	end

	const Deep: string = string.rep("<b>", 3000) .. "deep" .. string.rep("</b>", 3000)

	It("Strip handles deep nesting", function()
		Expect(function() Utilities.Strip(Deep) end).never.toThrow()
	end)

	It("Strip deep text", function()
		const Ok: boolean, Value: any = pcall(Utilities.Strip, Deep)
		Expect(if Ok then Value else nil).toBe("deep")
	end)

	for _, Markup: string in Inline do
		It(`Strip matches the renderer for {Markup}`, function()
			const Renderer: any = Mount(2000, 400)
			Renderer.Label.Text = Markup
			Renderer:Flush()

			const Parts: { string } = {}
			local Previous: boolean = false

			for _, Token: any in Renderer.Document.Tokens do
				if Token.Kind == "Break" then
					table.insert(Parts, "\n")
					Previous = false
				elseif Token.Kind == "Word" then
					if Previous and Token.SpaceBefore then table.insert(Parts, " ") end
					table.insert(Parts, Token.Text)
					Previous = true
				end
			end

			Expect(Utilities.Strip(Markup)).toBe(table.concat(Parts))
		end)
	end
end)

Describe("markdown", function()
	const Source: string = "# Head\n**x** `c` [l](u)\n\n```lua\nlocal y\n```"

	It("Markdown is the renderer's conversion", function()
		Expect(Utilities.Markdown(Source)).toBe((Markdown :: any).ToMarkup(Source))
	end)

	It("Markdown bold", function()
		Expect(Utilities.Markdown("**x**")).toContain("<b>x</b>")
	end)

	It("Markdown heading uses TextSize", function()
		Expect(Utilities.Markdown("# H", nil, 20)).toContain([[size="40"]])
	end)

	It("Markdown heading uses Theme", function()
		Expect(Utilities.Markdown("# H", {HeadingScale = {3}}, 10)).toContain([[size="30"]])
	end)

	It("Markdown code block", function()
		Expect(Utilities.Markdown(Source)).toContain([[<codeblock lang="lua">]])
	end)

	It("Markdown escapes markup", function()
		Expect(Utilities.Markdown("<b>")).toBe("&lt;b&gt;")
	end)

	It("Markdown of blank", function()
		Expect(Utilities.Markdown("   ")).toBe("")
	end)

	It("Strip of converted markdown matches Strip of md", function()
		Expect(Utilities.Strip(Utilities.Markdown("**x** and *y*"))).toBe(Utilities.Strip("<md>**x** and *y*</md>"))
	end)
end)

Describe("highlight", function()
	const Code: string = "local x = 1 < 2 -- hi & bye\nprint(`{x}`)"
	local Highlighted: string = ""

	BeforeAll(function()
		Highlighted = Utilities.Highlight(Code)
	end)

	It("Highlight colors keywords", function()
		Expect(Highlighted).toContain(`<font color="#{Color3.fromHex("569CD6"):ToHex()}">local`)
	end)

	It("Highlight escapes", function()
		Expect(string.find(Highlighted, "&lt; ", 1, true) ~= nil and string.find(Highlighted, "&amp;", 1, true) ~= nil).toBe(true)
	end)

	It("Highlight syntax override", function()
		Expect(Utilities.Highlight("local x", {Storage = Color3.new(1, 0, 0)})).toContain([[<font color="#ff0000">local]])
	end)

	It("Highlight renders on a plain TextLabel", function()
		const Label: TextLabel = Instance.new("TextLabel")
		Label.RichText = true
		Label.Text = Highlighted
		const Content: string = Label.ContentText
		Label:Destroy()

		Expect(Content).toBe(Code)
	end)
end)
