--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const DriverModule = require("../Packages/RichTextPlus/Renderer/Driver")
const AttributesModule = require("../Packages/RichTextPlus/Utility/Attributes")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Case = {
	Text: string;
	Width: number;
	Wrapped: boolean;
}

const API: any = RichTextPlus
const Driver: any = DriverModule
const Attributes: any = AttributesModule
const Linked: string = [[Read the <a href="https://example.com">docs here</a> first]]

local Screen: ScreenGui
const Renderers: { any } = {}

const function Label(Text: string, Width: number?, Height: number?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width or 400, Height or 200)
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

const function Keep(Renderer: any): any
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Segments(Target: TextLabel): number
	local Count: number = 0

	for _, Child: Instance in Target:GetChildren() do
		if Child:GetAttribute(Attributes.Marker) and (Child :: GuiObject).Visible then Count += 1 end
	end

	return Count
end

const function Extent(Target: TextLabel): Vector2
	local MinX: number, MinY: number = math.huge, math.huge
	local MaxX: number, MaxY: number = -math.huge, -math.huge

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name ~= "Segment" or not (Child :: GuiObject).Visible then continue end

		const Segment: TextLabel = Child :: TextLabel
		const Position: UDim2 = Segment.Position

		MinX = math.min(MinX, Position.X.Offset)
		MinY = math.min(MinY, Position.Y.Offset)
		MaxX = math.max(MaxX, Position.X.Offset + Segment.TextBounds.X)
		MaxY = math.max(MaxY, Position.Y.Offset + Segment.Size.Y.Offset)
	end

	return Vector2.new(MaxX - MinX, MaxY - MinY)
end

const function Await(Condition: () -> boolean): boolean
	const Deadline: number = os.clock() + 3

	while not Condition() and os.clock() < Deadline do task.wait() end

	return Condition()
end

const function Quiet(Renderer: any): ()
	Renderer.Native.Clock = -math.huge
end

const function Near(Actual: number, Expected: number): number
	return math.abs(Actual - Expected)
end

BeforeAll(function()
	Screen = Gui.new("Native")
end)

AfterAll(function()
	for _, Renderer: any in Renderers do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("eligibility", function()
	const Cases: { { any } } = {
		{"plain", "just plain words", true},
		{"bold italic", "<b>bold</b> <i>italic</i>", false},
		{"underline strike", "<u>under</u> <s>struck</s>", false},
		{"font attributes", [[<font color="#FF7800" size="24" face="Arcade" weight="light" transparency="0.3">f</font> <FONT COLOR="red">upper</FONT>]], false},
		{"font family", [[<font family="rbxasset://fonts/families/RobotoMono.json">mono</font>]], false},
		{"stroke mark", [[<stroke color="#FF0000" thickness="2" joins="miter">s</stroke> <mark color="#FFD000" transparency="0.25">m</mark>]], false},
		{"case tags", "<uppercase>a</uppercase> <uc>b</uc> <smallcaps>c</smallcaps> <sc>d</sc>", false},
		{"breaks and comments", "one<br/>two<!-- hidden -->\nthree", true},
		{"closing angle", "a &gt; b", true},
		{"entities", "a &lt;b&gt; &amp; c", false},
		{"ampersand", "Tom &amp; Jerry", false},
		{"emoji and accents", "caf\u{E9} \u{1F600} na\u{EF}ve", true},
		{"scaled base size", "just plain words", false, function(Built: any) Built:SetScale(2) end},
		{"unknown tags", "<bogus>kept</bogus> text", true},
		{"class tag is unknown", [[<customclass><class name="hot" bold="true" color="#FF0000"/><hot>x</hot></customclass>]], true},
		{"link", Linked, false},
		{"gradient", [[<gradient colors="#ff0000,#0000ff">g</gradient>]], false},
		{"wave", "<wave>w</wave> text", false},
		{"shake", "<shake>s</shake> text", false},
		{"image", [[pic <img src="rbxassetid://1" size="16"/>]], false},
		{"inline code", "<code>x = 1</code>", false},
		{"markdown", "<md>**bold** and `code`</md>", false},
		{"indent", [[<indent by="20">indented</indent>]], false},
		{"dir", [[<dir value="rtl">abc</dir>]], false},
		{"rtl text", "\u{5E9}\u{5DC}\u{5D5}\u{5DD} world", false},
		{"cjk text", "\u{4E2D}\u{6587}\u{6587}\u{672C}", false},
		{"soft hyphen", "hyphen\u{AD}ated", false},
		{"zero width space", "zero\u{200B}width", false},
		{"passthrough off", "just plain words", false, function(Built: any) Built:SetRendering("Passthrough", false) end},
		{"links off", Linked, true, function(Built: any) Built:SetIntents(API.Intents.Presets.Default:Remove("Links")) end},
		{"effects off", "<wave>w</wave> <gradient colors=\"#ff0000,#0000ff\">g</gradient>", true, function(Built: any) Built:SetIntents(API.Intents.Presets.Default:Remove("Effects", "Gradients")) end},
		{"chat escapes image", [[hi <img src="rbxassetid://1"/>]], false, function(Built: any) Built:SetPreset("Chat") end},
		{"chat plain words", "hi there", true, function(Built: any) Built:SetPreset("Chat") end},
		{"style class", "<customclass><hot>x</hot></customclass> y", false, function(Built: any) Built:AddCustomClasses({hot = {Kind = "Style"; Apply = function(Style: any) Style.Bold = true end}}) end},
		{"container class", "<customclass><boxed>x</boxed></customclass> y", false, function(Built: any) Built:AddCustomClasses({boxed = {Kind = "Container"; Wrap = function(): GuiObject? return nil end}}) end},
		{"object class", "<customclass><dot/></customclass> y", false, function(Built: any) Built:AddCustomClasses({dot = {Kind = "Object"; Build = function(): GuiObject
			const Frame: Frame = Instance.new("Frame")
			Frame.Size = UDim2.fromOffset(8, 8)
			return Frame
		end}}) end},
	}

	for _, Case: { any } in Cases do
		const Name: string = Case[1]
		const Expected: boolean = Case[3]

		Describe(Name, function()
			local Target: TextLabel
			local Renderer: any

			BeforeAll(function()
				Target = Label(Case[2])
				Renderer = Keep(API.new(Target))
				if Case[4] then Case[4](Renderer) end
				Renderer:Flush()
			end)

			It(`eligibility {Name}`, function()
				Expect(Renderer.Native.Active).toBe(Expected)
			end)

			if Expected then
				It(`eligibility {Name} creates no segments`, function()
					Expect(#Target:GetChildren()).toBe(0)
				end)
			else
				It(`eligibility {Name} renders segments`, function()
					Expect(Segments(Target)).toBeGreaterThan(0)
				end)
			end
		end)
	end
end)

Describe("markup", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("plain words here")
		Renderer = API.new(Target):Flush()
	end)

	const function Set(Text: string): ()
		Quiet(Renderer)
		Renderer.Label.Text = Text
		Renderer:Flush()
	end

	It("plain text is left untouched", function()
		Expect(Target.Text).toBe("plain words here")
	end)

	It("plain text keeps RichText", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("plain markup recorded", function()
		Expect(Renderer.Native.Markup).toBe("plain words here")
	end)

	It("label text visible", function()
		Expect(Target.TextTransparency).toBe(0)
	end)

	It("whitespace collapses like segments", function()
		Set("spaced    out\t\ttext  ")
		Expect(Target.Text).toBe("spaced out text")
	end)

	It("source keeps raw text", function()
		Expect(Renderer.Document.Source).toBe("spaced    out\t\ttext  ")
	end)

	It("styled text uses segments", function()
		Set("<b>bold</b> <font color=\"red\">named</font> a &lt;b&gt; &amp;")
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("styled text keeps the source", function()
		Expect(Target.Text).toBe("<b>bold</b> <font color=\"red\">named</font> a &lt;b&gt; &amp;")
	end)

	It("styled text never enables RichText", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("breaks return to native", function()
		Set("one<br/>two")
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("breaks become newlines", function()
		Expect(Target.Text).toBe("one\ntwo")
	end)

	It("class tag adds no styling", function()
		Set([[<customclass><class name="hot" bold="true"/><hot>x</hot></customclass> y]])
		Expect(Target.Text).toBe("x y")
	end)

	It("marks use segments", function()
		Set([[<mark color="#FFD000">a <b>b</b></mark>]])
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("sizes use segments", function()
		Set([[<font size="30">big</font> small]])
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("destroy restores source", function()
		Renderer:Destroy()
		Expect(Target.Text).toBe([[<font size="30">big</font> small]])
	end)

	It("destroy restores RichText", function()
		Expect(Target.RichText).toBe(false)
	end)
end)

Describe("parity", function()
	const Cases: { Case } = {
		{Text = "The quick brown fox jumps over the lazy dog", Width = 600, Wrapped = false};
		{Text = "The quick brown fox jumps over the lazy dog while the arena crowd cheers for every brave challenger", Width = 300, Wrapped = true};
		{Text = "one<br/>two lines<br/><br/>four", Width = 600, Wrapped = false};
		{Text = "caf\u{E9} na\u{EF}ve a &gt; b <!-- hidden --> tail", Width = 600, Wrapped = false};
	}

	for Index: number, Case: Case in Cases do
		Describe(`parity {Index}`, function()
			local First: any
			local Second: any
			local Bounds: Vector2
			local Expected: Vector2

			BeforeAll(function()
				const Native: TextLabel = Label(Case.Text, Case.Width, 300)
				const Classic: TextLabel = Label(Case.Text, Case.Width, 300)
				Native.TextWrapped = Case.Wrapped
				Classic.TextWrapped = Case.Wrapped

				First = Keep(API.new(Native):Flush())
				Second = Keep(API.new(Classic):SetRendering("Passthrough", false):Flush())
				Bounds = Native.TextBounds
				Expected = Extent(Classic)
			end)

			It(`parity {Index} native`, function()
				Expect(First.Native.Active and not Second.Native.Active).toBe(true)
			end)

			It(`parity {Index} width`, function()
				Expect(Near(Bounds.X, Expected.X)).toBeLessThanOrEqual(2)
			end)

			It(`parity {Index} height`, function()
				Expect(Near(Bounds.Y, Expected.Y)).toBeLessThanOrEqual(3)
			end)
		end)
	end
end)

Describe("switching", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("plain start")
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("starts native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("link leaves passthrough", function()
		Renderer.Label.Text = Linked
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("segment mode restores source text", function()
		Expect(Target.Text).toBe(Linked)
	end)

	It("segment mode hides label text", function()
		Expect(Near(Target.TextTransparency, 1)).toBeLessThanOrEqual(0.001)
	end)

	It("segment mode renders segments", function()
		Expect(Segments(Target)).toBeGreaterThan(0)
	end)

	It("returns to passthrough", function()
		Renderer.Label.Text = "back to native"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("passthrough clears segments", function()
		Expect(#Target:GetChildren()).toBe(0)
	end)

	It("passthrough shows label text", function()
		Expect(Target.TextTransparency).toBe(0)
	end)

	It("direct text assignment leaves passthrough", function()
		Target.Text = Linked
		Expect(Await(function(): boolean return not Renderer.Native.Active end)).toBe(true)
	end)

	It("direct text assignment enters passthrough", function()
		Target.Text = "direct plain"
		Expect(Await(function(): boolean return Renderer.Native.Active end)).toBe(true)
	end)

	It("direct text rendered", function()
		Expect(Target.Text).toBe("direct plain")
	end)

	It("feature off forces segments", function()
		Renderer:SetRendering("Passthrough", false):Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("feature off keeps source", function()
		Expect(Target.Text).toBe("direct plain")
	end)

	It("feature off one segment", function()
		Expect(Segments(Target)).toBe(1)
	end)

	It("feature on restores passthrough", function()
		Renderer:SetRendering("Passthrough", true):Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("get feature", function()
		Expect(Renderer:GetRendering("Passthrough")).toBe(true)
	end)
end)

Describe("source stability", function()
	local Target: TextLabel
	local Renderer: any
	local First: string = ""
	local Scaled: TextLabel
	local ScaledRenderer: any

	BeforeAll(function()
		Target = Label("one<br/>two   words")
		Renderer = API.new(Target):Flush()
		First = Target.Text
	end)

	It("markup collapses the source", function()
		Expect(First).toBe("one\ntwo words")
	end)

	It("rebuild does not reparse markup", function()
		Renderer:Rebuild()
		Expect(Target.Text).toBe(First)
	end)

	It("reflatten does not reparse markup", function()
		Renderer:AddCustomClass("hot", {Kind = "Style", Apply = function(Style: any) Style.Italic = true end}):Flush()
		Expect(Target.Text).toBe(First)
	end)

	It("text size change stays native", function()
		Target.TextSize = 20
		task.wait()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("text size change keeps the markup", function()
		Expect(Target.Text).toBe(First)
	end)

	It("source restored after rebuilds", function()
		Renderer:Destroy()
		Expect(Target.Text).toBe("one<br/>two   words")
	end)

	It("scaled base size uses segments", function()
		Scaled = Label("plain words")
		ScaledRenderer = Keep(API.new(Scaled):SetScale(2):Flush())
		Expect(ScaledRenderer.Native.Active).toBeFalsy()
	end)

	It("scaled base size keeps the source", function()
		Expect(Scaled.Text).toBe("plain words")
	end)
end)

Describe("plain feature", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("<b>x</b>  y")
		Renderer = Keep(API.new(Target):SetPreset("Plain"):Flush())
	end)

	It("rich text off with tags uses segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("rich text off keeps the source", function()
		Expect(Target.Text).toBe("<b>x</b>  y")
	end)

	It("rich text off never parses", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("rich text off renders tags literally", function()
		Expect(Segments(Target)).toBeGreaterThan(0)
	end)

	It("rich text off plain text native", function()
		Renderer.Label.Text = "plain  words"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("rich text off plain markup", function()
		Expect(Target.Text).toBe("plain words")
	end)
end)

Describe("raw text", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("Tom &amp; Jerry &lt;3")
		Renderer = API.new(Target):Flush()
	end)

	It("escaped text uses segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("escaped text keeps its source", function()
		Expect(Target.Text).toBe("Tom &amp; Jerry &lt;3")
	end)

	It("escaped text never parses on the host", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("developer RichText on is suppressed", function()
		Target.RichText = true
		task.wait()
		Expect(Target.RichText).toBe(false)
	end)

	It("tagged text keeps RichText off", function()
		Renderer.Label.Text = "<b>Tom</b> &amp; Jerry"
		Renderer:Flush()
		Expect(Target.RichText).toBe(false)
	end)

	It("plain text native", function()
		Renderer.Label.Text = "plain words"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("plain text keeps RichText off", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("destroy restores developer RichText", function()
		Renderer.Label.Text = "a &amp; b"
		Renderer:Flush()
		Renderer:Destroy()
		Expect(Target.RichText).toBe(true)
	end)

	It("destroy restores source", function()
		Expect(Target.Text).toBe("a &amp; b")
	end)
end)

Describe("permissions", function()
	const Hostile: string = [[<font size="90" color="#FF0000" face="Arcade">big</font> <img src="rbxassetid://1"/> <b>ok</b>]]
	local Target: TextLabel
	local Renderer: any

	const function Largest(): number
		local Size: number = 0

		for _, Child: Instance in Target:GetChildren() do
			if Child.Name == "Segment" and (Child :: GuiObject).Visible then Size = math.max(Size, (Child :: TextLabel).TextSize) end
		end

		return Size
	end

	BeforeAll(function()
		Target = Label(Hostile)
		Renderer = Keep(API.new(Target):SetPreset("Chat"):Flush())
	end)

	It("chat content uses segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("chat keeps the source", function()
		Expect(Target.Text).toBe(Hostile)
	end)

	It("chat strips size", function()
		Expect(Largest()).toBeLessThan(90)
	end)

	It("chat escapes image literally", function()
		Expect(Target:FindFirstChild("InlineImage", true)).toBeNil()
	end)

	It("plain preset with tags uses segments", function()
		Renderer:SetPreset("Plain"):Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("plain preset keeps the source", function()
		Expect(Target.Text).toBe(Hostile)
	end)

	It("plain preset never parses", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("default preset with image leaves passthrough", function()
		Renderer:SetPreset("Default"):Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("default preset restores source", function()
		Expect(Target.Text).toBe(Hostile)
	end)

	It("default preset clamps size", function()
		Renderer.Label.Text = [[<font size="200">huge</font>]]
		Renderer:Flush()
		Expect(Largest()).toBe(100)
	end)

	It("strip mode plain text native", function()
		Renderer:SetIntents({"Formatting"}):SetDenied("Strip"):Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("strip mode drops tags", function()
		Expect(Target.Text).toBe("huge")
	end)
end)

Describe("transparency", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label([[plain <font transparency="0.5">half</font> <mark color="#00FF00">mk</mark> <stroke color="#FF0000">st</stroke>]])
		Renderer = API.new(Target):Flush()
	end)

	It("faded content uses segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("faded content hides the host", function()
		Expect(Near(Target.TextTransparency, 1)).toBeLessThanOrEqual(0.001)
	end)

	It("plain content native", function()
		Renderer.Label.Text = "plain words"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("label keeps developer transparency", function()
		Target.TextTransparency = 0.5
		task.wait()
		Expect(Near(Target.TextTransparency, 0.5)).toBeLessThanOrEqual(0.001)
	end)

	It("developer transparency stored", function()
		Expect(Target:GetAttribute(Attributes.DeveloperTransparency)).toBe(0.5)
	end)

	It("fully hidden label", function()
		Target.TextTransparency = 1
		task.wait()
		Expect(Near(Target.TextTransparency, 1)).toBeLessThanOrEqual(0.001)
	end)

	It("segment mode hides label", function()
		Renderer.Label.Text = Linked
		Renderer:Flush()
		Expect(Near(Target.TextTransparency, 1)).toBeLessThanOrEqual(0.001)
	end)

	It("passthrough restores developer transparency", function()
		Renderer.Label.Text = "plain again"
		Renderer:Flush()
		Expect(Near(Target.TextTransparency, 1)).toBeLessThanOrEqual(0.001)
	end)

	It("developer change applies directly", function()
		Target.TextTransparency = 0.25
		task.wait()
		Expect(Near(Target.TextTransparency, 0.25)).toBeLessThanOrEqual(0.001)
	end)

	It("destroy keeps developer transparency", function()
		Renderer:Destroy()
		Expect(Near(Target.TextTransparency, 0.25)).toBeLessThanOrEqual(0.001)
	end)

	It("destroy clears attribute", function()
		Expect(Target:GetAttribute(Attributes.DeveloperTransparency)).toBeNil()
	end)
end)

Describe("rich text suppression", function()
	local Target: TextLabel
	local Renderer: any
	local Taken: any
	local Successor: any

	BeforeAll(function()
		Target = Label("<b>x</b> y")
		Target.RichText = true
		Renderer = API.new(Target):Flush()
	end)

	It("owned label never parses", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("developer value stored", function()
		Expect(Renderer.Native.RichText).toBe(true)
	end)

	It("updates keep RichText off", function()
		Renderer.Label.Text = "<i>many</i> updates"
		Renderer:Flush()
		Expect(Target.RichText).toBe(false)
	end)

	It("plain native", function()
		Renderer.Label.Text = "plain now"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("native keeps RichText off", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("destroy restores developer RichText", function()
		Renderer:Destroy()
		Expect(Target.RichText).toBe(true)
	end)

	It("destroy restores source", function()
		Expect(Target.Text).toBe("plain now")
	end)

	It("takeover suppresses again", function()
		Taken = API.new(Target):Flush()
		Expect(Target.RichText).toBe(false)
	end)

	It("first renderer torn down", function()
		Successor = API.new(Target):Flush()
		Expect(Taken.Destroyed).toBeTruthy()
	end)

	It("successor inherits the developer value", function()
		Expect(Successor.Native.RichText).toBe(true)
	end)

	It("takeover keeps RichText off", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("successor destroy restores developer RichText", function()
		Successor:Destroy()
		Expect(Target.RichText).toBe(true)
	end)

	It("dying label releases", function()
		const Dying: any = API.new(Target):Flush()
		Target:Destroy()
		Expect(Await(function(): boolean return Dying.Destroyed end)).toBe(true)
	end)
end)

Describe("reveal", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("hello there world")
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("idle label native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("native count is the rendered text", function()
		Expect(Renderer:GetGraphemeCount()).toBe(17)
	end)

	It("reveal keeps passthrough", function()
		Target.MaxVisibleGraphemes = 3
		task.wait()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("engine owns the reveal", function()
		Expect(Target.MaxVisibleGraphemes).toBe(3)
	end)

	It("reveal adds no segments", function()
		Expect(Segments(Target)).toBe(0)
	end)

	It("text change keeps passthrough", function()
		Renderer.Label.Text = "after reveal"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("count follows the new text", function()
		Expect(Renderer:GetGraphemeCount()).toBe(12)
	end)

	It("full reveal keeps passthrough", function()
		Target.MaxVisibleGraphemes = -1
		task.wait()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("typewriter feature removed", function()
		Expect(function() Renderer:GetFeature("Typewriter") end).toThrow()
	end)
end)

Describe("churn", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("<b>0</b> points")
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("rich label starts in segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("rapid rich updates stay in segments", function()
		for Index = 1, 5 do Renderer.Label.Text = `<b>{Index}</b> points`; Renderer:Flush() end
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("segments show source", function()
		Expect(Target.Text).toBe("<b>5</b> points")
	end)

	It("segments render", function()
		Expect(Segments(Target)).toBeGreaterThan(0)
	end)

	It("quiet rich update stays in segments", function()
		Quiet(Renderer)
		Renderer.Label.Text = "<b>6</b> points"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("rapid plain updates stay native", function()
		for Index = 1, 8 do Renderer.Label.Text = `{Index} plain points`; Renderer:Flush() end
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("plain updates render", function()
		Expect(Target.Text).toBe("8 plain points")
	end)

	It("direct rich assignments use segments", function()
		for Index = 1, 5 do
			Renderer.Native.Clock = os.clock()
			Target.Text = `<i>{Index}</i> direct`
			task.wait()
		end

		Expect(Await(function(): boolean return not Renderer.Native.Active end)).toBe(true)
	end)

	It("direct assignments show source", function()
		Expect(Target.Text).toBe("<i>5</i> direct")
	end)

	It("same source starts native", function()
		Quiet(Renderer)
		Renderer.Label.Text = "same source &gt; here"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("same source markup", function()
		Expect(Target.Text).toBe("same source > here")
	end)

	for Index = 1, 3 do
		It(`same source rewritten {Index}`, function()
			Renderer.Native.Clock = os.clock()
			Target.Text = "same source &gt; here"
			task.wait()

			Expect(Await(function(): boolean return Target.Text == "same source > here" end)).toBe(true)
		end)
	end

	It("repeated same source assignments stay native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("repeated assignments keep the source", function()
		Expect(Renderer.Document.Source).toBe("same source &gt; here")
	end)
end)

Describe("text scaled", function()
	const Original: UDim2 = UDim2.new(0, 200, 0, 40)
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("scaled big words", 200, 40)
		Target.AutomaticSize = Enum.AutomaticSize.Y
		Target.TextScaled = true
		Renderer = Keep(API.new(Target):Flush())
		task.wait()
	end)

	It("scaled content native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("automatic size untouched", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	It("size untouched", function()
		Expect(Target.Size).toBe(Original)
	end)

	It("no frozen size attribute", function()
		Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBeNil()
	end)

	It("scaled stroke uses segments", function()
		Renderer.Label.Text = [[<stroke color="#FF0000">stroked</stroke> scaled]]
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("segments freeze automatic size", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.None)
	end)

	It("scaled plain native again", function()
		Renderer.Label.Text = "plain scaled"
		Renderer:Flush()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("passthrough thaws automatic size", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	It("passthrough thaws size", function()
		Expect(Target.Size).toBe(Original)
	end)
end)

Describe("ownership", function()
	local Target: TextLabel
	local First: any
	local Second: any
	local Markup: string = ""

	BeforeAll(function()
		Target = Label("owned &gt; text")
		First = API.new(Target):Flush()
		Markup = Target.Text
		Second = API.new(Target):Flush()
	end)

	It("native markup differs from the source", function()
		Expect(Markup).toBe("owned > text")
	end)

	It("first destroyed on takeover", function()
		Expect(First.Destroyed).toBeTruthy()
	end)

	It("takeover parses the source", function()
		Expect(Second.Document.Source).toBe("owned &gt; text")
	end)

	It("takeover renders same markup", function()
		Expect(Target.Text).toBe(Markup)
	end)

	It("foreign owner abandons", function()
		Target:SetAttribute(Attributes.Owner, "foreign")
		task.wait()
		Expect(Second.Destroyed).toBeTruthy()
	end)

	It("abandon restores source", function()
		Expect(Target.Text).toBe("owned &gt; text")
	end)

	It("renderer after abandon native", function()
		const Third: any = API.new(Target):Flush()
		const Active: boolean = Third.Native.Active
		Third:Destroy()
		Expect(Active).toBeTruthy()
	end)

	It("explicit destroy restores source", function()
		Expect(Target.Text).toBe("owned &gt; text")
	end)
end)

Describe("idle", function()
	local Scroller: ScrollingFrame
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Scroller = Instance.new("ScrollingFrame")
		Scroller.Size = UDim2.fromOffset(300, 100)
		Scroller.CanvasSize = UDim2.fromOffset(300, 1000)
		Scroller.Parent = Screen

		Target = Label("line one<br/>line two<br/>line three", 300, 600)
		Target.Parent = Scroller
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("native renderer sleeps", function()
		Expect(Driver.Tick(Renderer, 0.016)).toBe(false)
	end)

	It("native renderer skips culling", function()
		Scroller.CanvasPosition = Vector2.new(0, 200)
		task.wait()
		Expect(#Renderer.Cull.Clippers).toBe(0)
	end)

	It("layout calls are no-ops", function()
		Renderer:Flush()
		Renderer:Flush()
		Expect(#Target:GetChildren()).toBe(0)
	end)
end)
