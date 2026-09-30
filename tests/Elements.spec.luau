--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Selector = require("../Packages/RichTextPlus/Elements/Selector")
const Segment = require("../Packages/RichTextPlus/Render/Segment")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Red: Color3 = Color3.fromRGB(255, 0, 0)
const Green: Color3 = Color3.fromRGB(0, 255, 0)
const Blue: Color3 = Color3.fromRGB(0, 0, 255)
const Kept: { any } = {}
local Screen: ScreenGui

const function Wait(Count: number): ()
	for _ = 1, Count do task.wait() end
end

const function Errors(Body: () -> ()): string
	const Ok: boolean, Problem: any = pcall(Body)

	return if Ok then "" else tostring(Problem)
end

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(480, 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Render(Text: string, Setup: ((Renderer: any) -> ())?): any
	const Renderer: any = Library.new(Label(Text)):SetRendering("Passthrough", false)
	if Setup then Setup(Renderer) end
	Renderer:Flush()
	table.insert(Kept, Renderer)

	return Renderer
end

const function Describe_(Elements: { any }): string
	const Parts: { string } = {}

	for _, Element: any in Elements do
		const Label: string = Element.Id or Element:GetAttribute("href") or Element.Text
		table.insert(Parts, `{Element.Tag}:{Label}`)
	end

	return table.concat(Parts, ",")
end

const function First(Element: any): any
	return Element.Records and Element.Records[1]
end

const function RecordOf(Renderer: any, Text: string): any
	for _, Record: any in Renderer.Instances.Segments do
		if string.match(Record.Content.Raw, "^%s*(.-)%s*$") == Text then return Record end
	end

	return nil
end

BeforeAll(function()
	Screen = Gui.new("Elements")
end)

AfterAll(function()
	for _, Renderer: any in Kept do
		if not Renderer.Destroyed then Renderer:Destroy() end
	end

	Gui.Cleanup()
end)

Describe("selector parser accepts the Roblox grammar", function()
	const Accepted: { string } = {
		"a", "A", ".nav", "#buy", "a.nav#buy", "[$href]", "[$href = x]", "[$href=x]", '[$href = "a b"]', "[$size = 4]", "[$on = true]",
		"[Text = Docs]", "[ Tag = a ]", "b > a", "b>a", "b >> a", "b>>a", "> a", ">> a", "a, b", "a,b", " a ", "a\t>\nb",
		":not(a)", ":not(a, b)", ":not(b > a)", ":not(:not(a))", ":has(a)", ":has(> a)", ":has(>> a)", "b:has(> i > a)",
		":Hover", ":Press", ":Focus", ":Idle", ":NonInteractable", "a:Hover:not(.muted)", "#1abc", "a-b_c", "b a",
	}

	for _, Source: string in Accepted do
		It(`accepts {Source}`, function()
			Expect(Errors(function() Selector.Compile(Source, 1) end)).toBe("")
		end)
	end

	It("empty selector compiles to no match", function()
		Expect(#Selector.Compile("", 1).List).toBe(0)
	end)

	It("compiled selectors are cached", function()
		Expect(Selector.Compile("b >> a.cached", 1)).toBe(Selector.Compile("b >> a.cached", 1))
	end)

	It("state filters mark the selector dynamic", function()
		Expect(Selector.Compile("a:Hover", 1).Dynamic).toBe(true)
		Expect(Selector.Compile("b:has(a:Press)", 1).Dynamic).toBe(true)
		Expect(Selector.Compile("b > a", 1).Dynamic).toBe(false)
	end)
end)

Describe("selector parser errors match the engine", function()
	const Cases: { { string } } = {
		{"*", "Expected at least one filter"},
		{",a", "Expected at least one filter"},
		{"a,", "Expected at least one combinator or a filter"},
		{"a >", "Expected at least one filter"},
		{"a > > b", "Expected at least one filter"},
		{"a >> > b", "Expected at least one filter"},
		{":not()", "Expected at least one filter"},
		{":has()", "Expected at least one filter"},
		{". nav", "Expected identifier for a class name"},
		{"#", "Expected identifier for an id"},
		{"[href]", "'=' expected after property name"},
		{"[$href = 'x']", "Expected identifier for an attribute value"},
		{"[Text = 'x']", "Expected identifier for a property value"},
		{"[$href = x", "Expected ']' to complete an attribute filter"},
		{"[Text = a b]", "Expected ']' to complete a property filter"},
		{"[$size = 4.5]", "Expected ']' to complete an attribute filter"},
		{"[$size ~= 4]", "'=' or ']' expected after attribute name"},
		{'[$x = "abc', "Expected '\"' to close the attribute value"},
		{"a ~ b", "Unexpected trailing character: '~'"},
		{"a + b", "Unexpected trailing character: '+'"},
		{"a < b", "Unexpected trailing character: '<'"},
		{":not(> a)", "Selector cannot start with a combinator here"},
		{":not(a", "Expected ')' to close the pseudo-class"},
		{":NOT(a)", "Pseudo-class 'NOT' filter is not supported"},
		{":hover", "Pseudo-class 'hover' filter is not supported"},
		{"a:first-child", "Pseudo-class 'first-child' filter is not supported"},
		{"a::UICorner", "Pseudo-instance selectors are not allowed"},
		{"@Small a", "StyleQuery filters are not allowed"},
	}

	for _, Case: { string } in Cases do
		It(`rejects {Case[1]}`, function()
			const Message: string = Errors(function() Selector.Compile(Case[1], 1) end)

			Expect(Message).toContain(`RichTextPlus selector "{Case[1]}": `)
			Expect(Message).toContain(Case[2])
		end)
	end

	It("rejects a non-string selector", function()
		Expect(Errors(function() Selector.Compile(5, 1) end)).toContain("selectors are strings")
	end)

	It("renderer methods raise the parse error at the caller", function()
		const Renderer: any = Render("x")

		Expect(Errors(function() Renderer:QueryDescendants("a >") end)).toContain("Expected at least one filter")
		Expect(Errors(function() Renderer:QueryFirst("*") end)).toContain("Expected at least one filter")
		Expect(Errors(function() Renderer:Bind("a,", {}) end)).toContain("Expected at least one combinator or a filter")
	end)
end)

Describe("selector matching on markup", function()
	const Markup: string = [[<b id="top" class="nav main"><a href="one">One</a> <i><a href="two" class="muted">Two</a></i></b> <a href="three">Three</a> <font color="#FF0000" data="4">red</font>]]
	local Renderer: any

	BeforeAll(function()
		Renderer = Render(Markup)
	end)

	const Cases: { { string } } = {
		{"a", "a:one,a:two,a:three"},
		{"A", "a:one,a:two,a:three"},
		{"b > a", "a:one"},
		{"b >> a", "a:one,a:two"},
		{"b a", ""},
		{"> a", "a:three"},
		{">> a", "a:one,a:two,a:three"},
		{"a, i", "a:one,i:Two,a:two,a:three"},
		{"a, a", "a:one,a:two,a:three"},
		{".nav", "b:top"},
		{".main.nav", "b:top"},
		{".nav.x", ""},
		{".Nav", ""},
		{"#top", "b:top"},
		{"#Top", ""},
		{"[$href]", "a:one,a:two,a:three"},
		{"[$href = two]", "a:two"},
		{'[$href = "three"]', "a:three"},
		{"[$HREF = one]", "a:one"},
		{"[$href = One]", ""},
		{"[$data = 4]", "font:red"},
		{'[$data = "4"]', "font:red"},
		{"[Tag = a][Text = One]", "a:one"},
		{'[Text = "Two"]', "i:Two,a:two"},
		{"[Id = top]", "b:top"},
		{"[Interactive = true]", "a:one,a:two,a:three"},
		{"[Nothing = 1]", ""},
		{":not(a)", "b:top,i:Two,font:red"},
		{"a:not(.muted)", "a:one,a:three"},
		{":not(b > a, font)", "b:top,i:Two,a:two,a:three"},
		{":has(> a)", "b:top,i:Two"},
		{":has(a)", "b:top,i:Two"},
		{"b:has(i > a)", "b:top"},
		{"b:has(> i > a)", "b:top"},
		{"i:has(i)", ""},
		{"#top > i > a", "a:two"},
		{"#top >> i >> a", "a:two"},
		{"a:Idle", "a:one,a:two,a:three"},
		{"i:NonInteractable", "i:Two"},
		{"a:NonInteractable", ""},
		{"a:Hover", ""},
		{"", ""},
	}

	for _, Case: { string } in Cases do
		It(`{Case[1]} matches {Case[2]}`, function()
			Expect(Describe_(Renderer:QueryDescendants(Case[1]))).toBe(Case[2])
		end)
	end

	It("QueryFirst returns the first in document order", function()
		Expect(Renderer:QueryFirst("a").Text).toBe("One")
	end)

	It("QueryFirst returns nil without a match", function()
		Expect(Renderer:QueryFirst("img")).toBeNil()
	end)

	It("Element:QueryDescendants scopes to the element", function()
		const Top: any = Renderer:QueryFirst("#top")

		Expect(Describe_(Top:QueryDescendants("a"))).toBe("a:one,a:two")
		Expect(Describe_(Top:QueryDescendants("> a"))).toBe("a:one")
		Expect(Describe_(Top:QueryDescendants("b a"))).toBe("")
	end)

	It("elements expose the tag tree", function()
		const Two: any = Renderer:QueryFirst("[$href = two]")

		Expect(Two.Parent.Tag).toBe("i")
		Expect(Two.Parent.Parent.Id).toBe("top")
		Expect(#Renderer:QueryFirst("#top").Children).toBe(2)
	end)

	It("GetAttribute is case-insensitive and unescaped", function()
		const Other: any = Render([[<a HREF="a&amp;b">x</a>]])

		Expect(Other:QueryFirst("a"):GetAttribute("href")).toBe("a&b")
		Expect(Other:QueryFirst("a"):GetAttribute("missing")).toBeNil()
	end)

	It("GetAttribute validates the name", function()
		Expect(Errors(function() Renderer:QueryFirst("a"):GetAttribute(5) end)).toContain("attribute name")
	end)

	It("tostring names the tag and id", function()
		Expect(tostring(Renderer:QueryFirst("#top"))).toBe("Element<b#top>")
		Expect(tostring(Renderer:QueryFirst("i"))).toBe("Element<i>")
	end)

	It("text joins words with single spaces", function()
		Expect(Render([[<b>a<br/>b   c</b>]]):QueryFirst("b").Text).toBe("a b c")
	end)

	It("queries settle pending text first", function()
		const Other: any = Render("<b>x</b>")
		Other.Label.Text = "<i>y</i>"

		Expect(Describe_(Other:QueryDescendants("i"))).toBe("i:y")
	end)
end)

Describe("zero cost for plain and passive markup", function()
	It("plain text builds no elements", function()
		const Renderer: any = Render("just some plain words")

		Expect(#Renderer.Elements.All).toBe(0)
	end)

	It("passive tags build elements but no buttons", function()
		const Renderer: any = Render("<b>bold</b> and <i>italic</i>")

		Expect(#Renderer.Elements.All).toBe(2)
		Expect(#Renderer.Elements.Interactive).toBe(0)

		for _, Record: any in Renderer.Instances.Segments do
			Expect(Record.Button).toBe(false)
		end
	end)

	It("passive elements report Visible without state tracking", function()
		const Renderer: any = Render("<b>bold</b>")

		Expect(Renderer:QueryFirst("b").State.Visible).toBe(true)
		Expect(Renderer:QueryFirst("b").Interactive).toBe(false)
	end)
end)

Describe("elements persist across re-renders", function()
	local Renderer: any
	local One: any
	local Two: any
	local Named: any

	BeforeAll(function()
		Renderer = Render([[<a href="x">first</a> <a href="y">second</a> <b id="keep">kept</b>]])
		One = Renderer:QueryFirst("[$href = x]")
		Two = Renderer:QueryFirst("[$href = y]")
		Named = Renderer:QueryFirst("#keep")
	end)

	It("text edits keep identity", function()
		Renderer.Label.Text = [[<a href="x">first edited</a> <a href="y">second</a> <b id="keep">kept</b>]]
		Renderer:Flush()

		Expect(Renderer:QueryFirst("a")).toBe(One)
		Expect(One.Text).toBe("first edited")
	end)

	It("attribute edits keep identity", function()
		Renderer.Label.Text = [[<a href="z">first edited</a> <a href="y">second</a> <b id="keep">kept</b>]]
		Renderer:Flush()

		Expect(Renderer:QueryFirst("a")).toBe(One)
		Expect(One:GetAttribute("href")).toBe("z")
	end)

	It("ids keep identity when siblings move", function()
		Renderer.Label.Text = [[<b id="keep">kept</b> <a href="z">first edited</a> <a href="y">second</a>]]
		Renderer:Flush()

		Expect(Renderer:QueryFirst("#keep")).toBe(Named)
	end)

	It("positions match elements without an id", function()
		Expect(Renderer:QueryDescendants("a")[1]).toBe(One)
		Expect(Renderer:QueryDescendants("a")[2]).toBe(Two)
	end)

	It("an inserted sibling of another tag keeps the match", function()
		Renderer.Label.Text = [[<b id="keep">kept</b> <i>new</i> <a href="z">first edited</a> <a href="y">second</a>]]
		Renderer:Flush()

		Expect(Renderer:QueryDescendants("a")[1]).toBe(One)
		Expect(Renderer:QueryDescendants("a")[2]).toBe(Two)
	end)

	It("a removed tag retires its element", function()
		Renderer.Label.Text = [[<b id="keep">kept</b> <i>new</i> <a href="y">second</a>]]
		Renderer:Flush()

		Expect(Renderer:QueryFirst("a")).toBe(One)

		Renderer.Label.Text = [[<b id="keep">kept</b> <i>new</i> <i>second</i>]]
		Renderer:Flush()

		Expect(Renderer:QueryFirst("a")).toBeNil()
	end)

	It("dropped elements are retired", function()
		Expect(One.Text).toBe("")
		Expect(One.Parent).toBeNil()
		Expect(One.State.Visible).toBe(false)
		Expect(One.Interactive).toBe(false)
	end)

	It("dropped elements drop their signals", function()
		const Connection: any = One.Activated:Connect(function() end)

		Expect(Connection.Connected).toBe(false)
	end)

	It("incremental text patches update element text", function()
		const Hud: any = Render([[<b>Coins 1</b> then <a href="h">tail words</a>]])
		const Link: any = Hud:QueryFirst("a")
		const Bold: any = Hud:QueryFirst("b")

		Hud.Label.Text = [[<b>Coins 1 2 3 4</b> then <a href="h">tail words</a>]]
		Hud:Flush()

		Expect(Hud:QueryFirst("a")).toBe(Link)
		Expect(Bold.Text).toBe("Coins 1 2 3 4")
		Expect(Link.Text).toBe("tail words")

		Hud.Label.Text = [[<b>Coins 1 2 3 4</b> then <a href="h">tail changed</a>]]
		Hud:Flush()

		Expect(Link.Text).toBe("tail changed")
	end)
end)

Describe("Bind", function()
	local Renderer: any
	local Binding: any
	const Seen: { string } = {}

	BeforeAll(function()
		Renderer = Render([[<b>bold</b> plain <i class="go">tap</i>]])
		Binding = Renderer:Bind("b, .go", {
			Activated = function(Element: any) table.insert(Seen, `activated {Element.Tag}`) end,
			HoverChanged = function(Element: any, Hovering: boolean) table.insert(Seen, `hover {Element.Tag} {Hovering}`) end,
			PressChanged = function(Element: any, Pressing: boolean) table.insert(Seen, `press {Element.Tag} {Pressing}`) end,
		})
		Renderer:Flush()
	end)

	It("returns a connection", function()
		Expect(Binding.Connected).toBe(true)
	end)

	It("matched elements become interactive", function()
		Expect(Renderer:QueryFirst("b").Interactive).toBe(true)
		Expect(Renderer:QueryFirst("i").Interactive).toBe(true)
	end)

	It("matched text renders as buttons, the rest stays labels", function()
		Expect(RecordOf(Renderer, "bold").Button).toBe(true)
		Expect(RecordOf(Renderer, "plain").Button).toBe(false)
	end)

	It("activation reaches the handler deferred", function()
		table.clear(Seen)
		Segment.Activate(RecordOf(Renderer, "bold"))

		Expect(#Seen).toBe(0)

		Wait(1)

		Expect(table.concat(Seen, ",")).toBe("activated b")
	end)

	It("hover and press reach the handlers", function()
		table.clear(Seen)
		const Record: any = RecordOf(Renderer, "tap")

		Segment.Enter(Record)
		Segment.Press(Record, true)
		Segment.Press(Record, false)
		Segment.Leave(Record)
		Wait(2)

		Expect(table.concat(Seen, ",")).toBe("hover i true,press i true,press i false,hover i false")
	end)

	It("handlers survive re-renders", function()
		table.clear(Seen)
		Renderer.Label.Text = [[<b>bolder</b> plain <i class="go">tap</i>]]
		Renderer:Flush()
		Segment.Activate(RecordOf(Renderer, "bolder"))
		Wait(1)

		Expect(table.concat(Seen, ",")).toBe("activated b")
	end)

	It("bindings apply to elements that appear later", function()
		table.clear(Seen)
		Renderer.Label.Text = [[<b>bolder</b> plain <i class="go">tap</i> <b>late</b>]]
		Renderer:Flush()
		Segment.Activate(RecordOf(Renderer, "late"))
		Wait(1)

		Expect(table.concat(Seen, ",")).toBe("activated b")
	end)

	It("disconnect stops handlers and drops interactivity", function()
		table.clear(Seen)
		Binding:Disconnect()
		Renderer:Flush()

		Expect(Binding.Connected).toBe(false)
		Expect(Renderer:QueryFirst("b").Interactive).toBe(false)
		Expect(RecordOf(Renderer, "bolder").Button).toBe(false)

		Segment.Activate(RecordOf(Renderer, "bolder"))
		Wait(1)

		Expect(#Seen).toBe(0)
	end)

	It("disconnect is idempotent", function()
		Binding:Disconnect()

		Expect(#Renderer.Elements.Bindings).toBe(0)
	end)

	It("validates its arguments", function()
		Expect(Errors(function() Renderer:Bind("b", nil) end)).toContain("table of handlers")
		Expect(Errors(function() Renderer:Bind("b", {Clicked = function() end}) end)).toContain('no event "Clicked"')
		Expect(Errors(function() Renderer:Bind("b", {Activated = 5}) end)).toContain("must be a function")
		Expect(Errors(function() Renderer:Bind(5, {}) end)).toContain("selectors are strings")
	end)
end)

Describe("Bind bubbles and filters by state", function()
	local Renderer: any
	const Seen: { string } = {}

	BeforeAll(function()
		Renderer = Render([[<b class="card">title <a href="inner">link</a></b>]])
		Renderer:Bind(".card", {Activated = function(Element: any) table.insert(Seen, `card {Element.Tag}`) end})
		Renderer:Bind("a", {Activated = function(Element: any) table.insert(Seen, `link {Element:GetAttribute("href")}`) end})
		Renderer:Bind("a:Hover", {Activated = function() table.insert(Seen, "hovered link") end})
		Renderer:Flush()
	end)

	It("activating an inner element bubbles to the outer binding", function()
		table.clear(Seen)
		Segment.Activate(RecordOf(Renderer, "link"))
		Wait(1)

		table.sort(Seen)

		Expect(table.concat(Seen, ",")).toBe("card b,link inner")
	end)

	It("activating the outer text only fires the outer binding", function()
		table.clear(Seen)
		Segment.Activate(RecordOf(Renderer, "title"))
		Wait(1)

		Expect(table.concat(Seen, ",")).toBe("card b")
	end)

	It("state selectors are checked when the event fires", function()
		table.clear(Seen)
		const Record: any = RecordOf(Renderer, "link")

		Segment.Enter(Record)
		Segment.Activate(Record)
		Wait(1)
		Segment.Leave(Record)
		Wait(1)

		table.sort(Seen)

		Expect(table.concat(Seen, ",")).toBe("card b,hovered link,link inner")
	end)

	It("hovering an inner element hovers its interactive ancestors", function()
		const Record: any = RecordOf(Renderer, "link")

		Segment.Enter(Record)

		Expect(Renderer:QueryFirst("a").State.Hovered).toBe(true)
		Expect(Renderer:QueryFirst("b").State.Hovered).toBe(true)
		Expect(Describe_(Renderer:QueryDescendants(":Hover"))).toBe("b:title link,a:inner")

		Segment.Leave(Record)
		Wait(1)

		Expect(Renderer:QueryFirst("b").State.Hovered).toBe(false)
	end)

	It("moving from the inner to the outer text keeps the outer hovered", function()
		const Seen2: { string } = {}
		const Outer: any = Renderer:QueryFirst("b")
		const Connection: any = Outer.HoverChanged:Connect(function(Hovering: boolean) table.insert(Seen2, tostring(Hovering)) end)

		Segment.Enter(RecordOf(Renderer, "link"))
		Segment.Enter(RecordOf(Renderer, "title"))
		Segment.Leave(RecordOf(Renderer, "link"))
		Wait(2)

		Expect(table.concat(Seen2, ",")).toBe("true")
		Expect(Renderer:QueryFirst("a").State.Hovered).toBe(false)

		Segment.Leave(RecordOf(Renderer, "title"))
		Wait(2)
		Connection:Disconnect()

		Expect(table.concat(Seen2, ",")).toBe("true,false")
	end)
end)

Describe("element signals and state", function()
	local Renderer: any
	local Link: any
	local Record: any
	const Seen: { string } = {}

	BeforeAll(function()
		Renderer = Render([[<a href="x">go there</a>]])
		Link = Renderer:QueryFirst("a")
		Record = First(Link)

		Link.Activated:Connect(function() table.insert(Seen, "activated") end)
		Link.HoverChanged:Connect(function(Hovering: boolean) table.insert(Seen, `hover {Hovering}`) end)
		Link.PressChanged:Connect(function(Pressing: boolean) table.insert(Seen, `press {Pressing}`) end)
	end)

	It("links are interactive without a binding", function()
		Expect(Link.Interactive).toBe(true)
		Expect(Record.Button).toBe(true)
	end)

	It("signals are cached per element", function()
		Expect(Link.Activated).toBe(Link.Activated)
	end)

	It("state follows input", function()
		Segment.Enter(Record)
		Expect(Link.State.Hovered).toBe(true)

		Segment.Press(Record, true)
		Expect(Link.State.Pressed).toBe(true)

		Segment.Activate(Record)
		Segment.Press(Record, false)
		Expect(Link.State.Pressed).toBe(false)

		Segment.Focus(Record, true)
		Expect(Link.State.Focused).toBe(true)
		Segment.Focus(Record, false)
		Expect(Link.State.Focused).toBe(false)

		Segment.Leave(Record)
		Wait(2)

		Expect(Link.State.Hovered).toBe(false)
	end)

	It("signals fire in order", function()
		Expect(table.concat(Seen, ",")).toBe("hover true,press true,activated,press false,hover false")
	end)

	It("pressing then leaving releases the press", function()
		table.clear(Seen)
		Segment.Enter(Record)
		Segment.Press(Record, true)
		Segment.Leave(Record)
		Wait(2)

		Expect(Link.State.Pressed).toBe(false)
		Expect(table.concat(Seen, ",")).toBe("hover true,press true,press false,hover false")
	end)

	It("state selectors see live state", function()
		Segment.Enter(Record)

		Expect(Renderer:QueryFirst("a:Hover")).toBe(Link)
		Expect(Renderer:QueryFirst("a:Idle")).toBeNil()
		Expect(Renderer:QueryFirst("[Hovered = true]")).toBe(Link)

		Segment.Leave(Record)
		Wait(2)

		Expect(Renderer:QueryFirst("a:Idle")).toBe(Link)
	end)
end)

Describe("state driven styling", function()
	It("hovercolor recolors the text while hovered", function()
		const Renderer: any = Render([[<font hovercolor="#00FF00">hot</font> cold]])
		const Record: any = RecordOf(Renderer, "hot")
		const Resting: Color3 = Record.Instance.TextColor3

		Expect(Renderer:QueryFirst("font").Interactive).toBe(true)

		Segment.Enter(Record)
		Expect(Record.Instance.TextColor3).toBe(Green)

		Segment.Leave(Record)
		Wait(2)
		Expect(Record.Instance.TextColor3).toBe(Resting)
	end)

	It("presscolor wins while pressed", function()
		const Renderer: any = Render([[<font hovercolor="#00FF00" presscolor="#0000FF">hot</font>]])
		const Record: any = RecordOf(Renderer, "hot")

		Segment.Enter(Record)
		Segment.Press(Record, true)
		Expect(Record.Instance.TextColor3).toBe(Blue)

		Segment.Press(Record, false)
		Expect(Record.Instance.TextColor3).toBe(Green)

		Segment.Leave(Record)
		Wait(2)
	end)

	It("an outer hovercolor reaches inner text", function()
		const Renderer: any = Render([[<font hovercolor="#00FF00">outer <b>inner</b></font>]])
		const Inner: any = RecordOf(Renderer, "inner")

		Segment.Enter(RecordOf(Renderer, "outer"))
		Expect(Inner.Instance.TextColor3).toBe(Green)

		Segment.Leave(RecordOf(Renderer, "outer"))
		Wait(2)
	end)

	It("hovercolor needs the Color intent", function()
		const Renderer: any = Render([[<font hovercolor="#00FF00">hot</font>]], function(Target: any)
			Target:SetIntents(Library.Intents.Presets.Default:Remove("Color"))
		end)

		Expect(Renderer:QueryFirst("font").Interactive).toBe(false)
	end)

	It("links take the theme colors", function()
		const Renderer: any = Render([[<a href="x">link</a>]], function(Target: any)
			Target:SetTheme({LinkColor = Red, LinkHoverColor = Blue})
		end)
		const Record: any = RecordOf(Renderer, "link")

		Expect(Record.Instance.TextColor3).toBe(Red)

		Segment.Enter(Record)
		Expect(Record.Instance.TextColor3).toBe(Blue)
		Expect(Record.Instance.Text).toContain("<u>")

		Segment.Leave(Record)
		Wait(2)
		Expect(Record.Instance.TextColor3).toBe(Red)
		Expect(Record.Instance.Text).toBe("link")
	end)

	It("links without a hover color tint lighter", function()
		const Renderer: any = Render([[<a href="x">link</a>]], function(Target: any)
			Target:SetTheme({LinkColor = Red})
		end)
		const Record: any = RecordOf(Renderer, "link")

		Segment.Enter(Record)
		Expect(Record.Instance.TextColor3 ~= Red).toBe(true)

		Segment.Leave(Record)
		Wait(2)
	end)

	It("interactive style classes restyle from Element.State", function()
		const Seen: { any } = {}
		const Renderer: any = Render([[<customclass><glow>shine</glow></customclass>]], function(Target: any)
			Target:AddCustomClass("glow", {
				Kind = "Style";
				Interactive = true;
				Apply = function(Style: any, _Node: any, Element: any)
					table.insert(Seen, Element)
					if Element.State.Hovered then Style.Color = Green end
				end;
			})
		end)
		const Glow: any = Renderer:QueryFirst("glow")

		Expect(Seen[1]).toBe(Glow)
		Expect(Glow.Interactive).toBe(true)

		Segment.Enter(RecordOf(Renderer, "shine"))
		Renderer:Flush()

		Expect(RecordOf(Renderer, "shine").Instance.TextColor3).toBe(Green)
		Expect(Renderer:QueryFirst("glow")).toBe(Glow)

		Segment.Leave(RecordOf(Renderer, "shine"))
		Wait(2)
		Renderer:Flush()

		Expect(RecordOf(Renderer, "shine").Instance.TextColor3 ~= Green).toBe(true)
	end)

	It("interactive custom classes need the CustomClasses intent", function()
		const Renderer: any = Render([[<customclass><glow>shine</glow></customclass>]], function(Target: any)
			Target:SetIntents(Library.Intents.Presets.Default:Remove("CustomClasses"))
			Target:AddCustomClass("glow", {Kind = "Style", Interactive = true, Apply = function() end})
		end)

		Expect(Renderer:QueryFirst("glow")).toBeNil()
	end)

	It("links need the Links intent", function()
		const Renderer: any = Render([[<a href="x">link</a>]], function(Target: any)
			Target:SetIntents(Library.Intents.Presets.Default:Remove("Links")):SetDenied("Strip")
		end)

		Expect(Renderer:QueryFirst("a")).toBeNil()
		Expect(RecordOf(Renderer, "link").Button).toBe(false)
	end)
end)

Describe("reveal drives Visible", function()
	It("hidden interactive text is not visible and cannot be hovered", function()
		const Renderer: any = Render([[<a href="x">link</a>]])
		const Link: any = Renderer:QueryFirst("a")

		Renderer.Label.MaxVisibleGraphemes = 0
		Renderer:Flush()
		Wait(2)

		Expect(Link.State.Visible).toBe(false)

		Segment.Enter(First(Link))
		Expect(Link.State.Hovered).toBe(false)

		Renderer.Label.MaxVisibleGraphemes = -1
		Renderer:Flush()
		Wait(2)

		Expect(Link.State.Visible).toBe(true)
	end)
end)

Describe("removed link API names its replacement", function()
	local Renderer: any

	BeforeAll(function()
		Renderer = Render("x")
	end)

	It("Links", function()
		Expect(Errors(function() return Renderer.Links end)).toContain("Renderer:Bind")
	end)

	It("SetLinkColor", function()
		Expect(Errors(function() Renderer:SetLinkColor(Red) end)).toContain("SetTheme")
	end)

	It("GetLinkColor", function()
		Expect(Errors(function() Renderer:GetLinkColor() end)).toContain("GetTheme")
	end)

	It("LinkClicked", function()
		Expect(Errors(function() return Renderer.LinkClicked end)).toContain("Renderer:Bind")
	end)
end)

Describe("cleanup on Destroy", function()
	local Renderer: any
	local Link: any
	local Binding: any
	local Signal: any
	local Count: number = 0

	BeforeAll(function()
		Renderer = Render([[<a href="x">link</a> <b>bold</b>]])
		Link = Renderer:QueryFirst("a")
		Binding = Renderer:Bind("b", {Activated = function() Count += 1 end})
		Signal = Link.Activated:Connect(function() Count += 1 end)
		Renderer:Flush()

		Segment.Activate(First(Link))
		Renderer:Destroy()
		Wait(1)
	end)

	It("pending events are dropped", function()
		Expect(Count).toBe(0)
	end)

	It("bindings disconnect", function()
		Expect(Binding.Connected).toBe(false)
	end)

	It("element signals disconnect", function()
		Expect(Signal.Connected).toBe(false)
	end)

	It("elements are retired", function()
		Expect(Link.Text).toBe("")
		Expect(#Renderer.Elements.All).toBe(0)
	end)

	It("queries return nothing", function()
		Expect(#Renderer:QueryDescendants("a")).toBe(0)
	end)

	It("binding after destroy returns a dead connection", function()
		Expect(Renderer:Bind("a", {}).Connected).toBe(false)
	end)
end)

Describe("readme example", function()
	It("binds the buy button through the class", function()
		const Renderer: any = Render(`<b class="shop"><font id="buy" hovercolor="#FFD000">Buy</font> or <a href="info">read more</a> <a href="x">other</a></b>`)
		local Bought: number = 0

		Renderer:Bind(".shop >> #buy", {Activated = function() Bought += 1 end})
		Renderer:Flush()
		Segment.Activate(RecordOf(Renderer, "Buy"))
		Wait(1)

		Expect(Bought).toBe(1)
		Expect(Describe_(Renderer:QueryDescendants("a:not([$href = info])"))).toBe("a:x")
	end)
end)

Describe("nested interactive elements inside a link", function()
	It("inner text belongs to the inner element and bubbles to the link", function()
		const Renderer: any = Render([[<a href="x">out <font hovercolor="#00FF00">in</font></a>]])
		const Inner: any = RecordOf(Renderer, "in")
		const Outer: any = RecordOf(Renderer, "out")
		local Activated: number = 0

		Renderer:QueryFirst("a").Activated:Connect(function() Activated += 1 end)

		Expect(Inner.Element.Tag).toBe("font")
		Expect(Outer.Element.Tag).toBe("a")
		Expect(Inner.Element.Parent).toBe(Outer.Element)

		Segment.Enter(Inner)
		Expect(Inner.Instance.TextColor3).toBe(Green)
		Expect(Outer.Element.State.Hovered).toBe(true)

		Segment.Activate(Inner)
		Segment.Leave(Inner)
		Wait(2)

		Expect(Activated).toBe(1)
	end)
end)
