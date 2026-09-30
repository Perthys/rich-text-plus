--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const AttributesModule = require("../Packages/RichTextPlus/Utility/Attributes")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const API: any = RichTextPlus
const Attributes: any = AttributesModule
const Ellipsis: string = "\u{2026}"

local Screen: ScreenGui
const Renderers: { any } = {}

const function Label(Text: string, Width: number?, Height: number?, Parent: Instance?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width or 400, Height or 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Text = Text
	Created.Parent = Parent or Screen

	return Created
end

const function Keep(Renderer: any): any
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Segments(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	table.sort(Found, function(Left: TextLabel, Right: TextLabel): boolean
		if Left.Position.Y.Offset ~= Right.Position.Y.Offset then return Left.Position.Y.Offset < Right.Position.Y.Offset end

		return Left.Position.X.Offset < Right.Position.X.Offset
	end)

	return Found
end

const function Joined(Target: TextLabel): string
	const Parts: { string } = {}
	for _, Segment: TextLabel in Segments(Target) do table.insert(Parts, Segment.Text) end

	return table.concat(Parts, "|")
end

const function Bottom(Target: TextLabel): number
	local Lowest: number = 0

	for _, Segment: TextLabel in Segments(Target) do
		Lowest = math.max(Lowest, Segment.Position.Y.Offset + Segment.Size.Y.Offset)
	end

	return Lowest
end

const function Right(Target: TextLabel): number
	local Widest: number = 0

	for _, Segment: TextLabel in Segments(Target) do
		Widest = math.max(Widest, Segment.Position.X.Offset + Segment.Size.X.Offset)
	end

	return Widest
end

const function Dump(Renderer: any): string
	const Parts: { string } = {}

	for _, Token: any in Renderer.Document.Tokens do
		const Style: any = Token.Style
		const Styled: string = if Style then `{tostring(Style.Bold)}{tostring(Style.Italic)}{Style.Size}{Style.Color:ToHex()}` else "-"
		table.insert(Parts, `{Token.Kind}:{tostring(Token.Text)}:{tostring(Token.SpaceBefore)}:{tostring(Token.Glue)}:{Styled}`)
	end

	return table.concat(Parts, " ")
end

const function Settle(): ()
	task.wait()
	API.Runtime.Flush()
end

const function EndsWithEllipsis(Text: string): boolean
	return string.sub(Text, -#Ellipsis) == Ellipsis
end

BeforeAll(function()
	Screen = Gui.new("FixNative")
end)

AfterAll(function()
	for _, Renderer: any in Renderers do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("incremental scanner mirrors the 2.1.0 parser", function()
	const Cases: { { any } } = {
		{"stray tail", "x <y", "x <yz", true},
		{"stray lt digit", "1<2 <b>3</b>", "1<22 <b>3</b>", true},
		{"stray lt space", "a < b <i>c</i>", "a < bb <i>c</i>", true},
		{"stray becomes tag", "a <b c", "a <b c>", false},
		{"quote reach", `x <b a="<i>y</i>" <u>z</u>`, `x <b a="<i>yy</i>" <u>z</u>`, false},
		{"quote closes into tag", `x <b a="<i>y</i> z`, `x <b a="<i>y">"</i> z`, false},
		{"cdata inner edit", "a <![CDATA[<b>x</b>]]> b", "a <![CDATA[<b>y</b>]]> b", false},
		{"text after cdata", "a <![CDATA[<b>x</b> &amp;]]> b1", "a <![CDATA[<b>x</b> &amp;]]> b2", true},
		{"unterminated cdata", "a <![CDATA[x", "a <![CDATA[xy", true},
		{"unquoted attribute", "<font color=#f55>a</font> 1", "<font color=#f55>a</font> 2", true},
		{"boolean attribute", "<b bold>x</b> 1", "<b bold>x</b> 2", true},
		{"case mismatched close", "<B>x</b> tail 1", "<B>x</b> tail 2", true},
		{"lone close lt", "a </ b <i>c</i>", "a </ b <i>cc</i>", true},
	}

	for _, Case: { any } in Cases do
		Describe(Case[1], function()
			local Fast: TextLabel
			local Full: TextLabel
			local FastRenderer: any
			local FullRenderer: any
			local Patched: boolean = false

			BeforeAll(function()
				Fast = Label(Case[2], 300, 200)
				Full = Label(Case[3], 300, 200)
				FastRenderer = Keep(API.new(Fast):SetRendering("Passthrough", false):Flush())
				FullRenderer = Keep(API.new(Full):SetRendering("Passthrough", false):Flush())

				const Tree: any = FastRenderer.Document.Tree
				FastRenderer.Label.Text = Case[3]
				FastRenderer:Flush()
				Patched = FastRenderer.Document.Tree == Tree
			end)

			It(`{Case[1]} patch path`, function()
				Expect(Patched).toBe(Case[4])
			end)

			It(`{Case[1]} matches a full parse`, function()
				Expect(Dump(FastRenderer)).toBe(Dump(FullRenderer))
			end)

			It(`{Case[1]} segments match`, function()
				Expect(Joined(Fast)).toBe(Joined(Full))
			end)
		end)
	end

	It("cdata renders literally", function()
		const Target: TextLabel = Label("keep <![CDATA[<b>raw</b>]]> text", 300, 100)
		Keep(API.new(Target):SetRendering("Passthrough", false):Flush())

		Expect(Joined(Target)).toContain("<b>raw</b>")
	end)
end)

Describe("native appends rebase on the source", function()
	local Target: TextLabel
	local Renderer: any
	local First: string = ""
	local Markup: string = ""
	local Scaled: TextLabel
	local ScaledRenderer: any

	BeforeAll(function()
		Target = Label("bold &gt; text")
		Renderer = API.new(Target):Flush()
		First = Target.Text
	end)

	It("escaped label native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("markup decodes the source", function()
		Expect(First).toBe("bold > text")
	end)

	It("append rebased on source", function()
		Target.Text ..= " more"
		Settle()
		Expect(Renderer.Document.Source).toBe("bold &gt; text more")
	end)

	It("append regenerates the markup", function()
		Expect(Target.Text).toBe("bold > text more")
	end)

	It("prepend rebased on source", function()
		Target.Text = "start " .. Target.Text
		Settle()
		Expect(Renderer.Document.Source).toBe("start bold &gt; text more")
	end)

	It("SetText read back rebased", function()
		Renderer.Label.Text = Target.Text .. "!"
		Renderer:Flush()
		Expect(Renderer.Document.Source).toBe("start bold &gt; text more!")
	end)

	It("SetText round trip keeps the source", function()
		Markup = Target.Text
		Renderer.Label.Text = Target.Text
		Renderer:Flush()
		Expect(Renderer.Document.Source).toBe("start bold &gt; text more!")
	end)

	It("SetText round trip keeps the markup", function()
		Expect(Target.Text).toBe(Markup)
	end)

	It("destroy restores rebased source", function()
		Renderer:Destroy()
		Expect(Target.Text).toBe("start bold &gt; text more!")
	end)

	It("scaled label uses segments", function()
		Scaled = Label("bold &gt; text")
		ScaledRenderer = Keep(API.new(Scaled):SetScale(2):Flush())
		Expect(ScaledRenderer.Native.Active).toBeFalsy()
	end)

	It("scaled label keeps the source", function()
		Expect(Scaled.Text).toBe("bold &gt; text")
	end)
end)

Describe("native escapes survive read back", function()
	local Target: TextLabel
	local Renderer: any
	local Plain: TextLabel
	local PlainRenderer: any

	BeforeAll(function()
		Target = Label("a &lt;b&gt; c")
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("escaped markup characters use segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("host keeps the escaped source", function()
		Expect(Target.Text).toBe("a &lt;b&gt; c")
	end)

	It("host never parses", function()
		Expect(Target.RichText).toBe(false)
	end)

	It("segments render literally", function()
		Expect(Joined(Target)).toBe("a <b> c")
	end)

	It("append keeps escapes", function()
		Target.Text ..= " d"
		Settle()
		Expect(Renderer.Document.Source).toBe("a &lt;b&gt; c d")
	end)

	It("append renders literally", function()
		Expect(Joined(Target)).toBe("a <b> c d")
	end)

	It("rewritten source renders literally", function()
		Target.Text = (string.gsub(Target.Text, "c d", "e"))
		Settle()
		Expect(Joined(Target)).toBe("a <b> e")
	end)

	It("literal markup characters use segments", function()
		Plain = Label("Tom & Jerry <3")
		PlainRenderer = API.new(Plain):Flush()
		Expect(PlainRenderer.Native.Active).toBeFalsy()
	end)

	It("literal source kept", function()
		Expect(Plain.Text).toBe("Tom & Jerry <3")
	end)

	It("literal text renders", function()
		Expect(Joined(Plain)).toBe("Tom & Jerry <3")
	end)

	It("destroy restores literal source", function()
		PlainRenderer:Destroy()
		Expect(Plain.Text).toBe("Tom & Jerry <3")
	end)

	It("destroy restores RichText", function()
		Expect(Plain.RichText).toBe(false)
	end)
end)

Describe("source that starts with its own markup", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("Hi<b></b>")
		Renderer = Keep(API.new(Target):Flush())
	end)

	It("empty tag source native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("markup drops the empty tag", function()
		Expect(Target.Text).toBe("Hi")
	end)

	It("reassigned source is not rebased twice", function()
		Target.Text = "Hi<b></b>"
		task.wait()
		Expect(Renderer.Document.Source).toBe("Hi<b></b>")
	end)

	It("reassigned source restores markup", function()
		Expect(Target.Text).toBe("Hi")
	end)

	It("append after reassign", function()
		Target.Text ..= "!"
		Settle()
		Expect(Renderer.Document.Source).toBe("Hi<b></b>!")
	end)
end)

Describe("native release keeps a pending append", function()
	local Target: TextLabel
	local Renderer: any
	local Markup: string = ""

	BeforeAll(function()
		Target = Label("typed &gt; words")
		Renderer = Keep(API.new(Target):Flush())
		Markup = Target.Text
	end)

	It("starts native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("segment mode leaves passthrough", function()
		Target.Text = Markup .. " later"
		Renderer:SetRendering("Passthrough", false):Flush()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("release writes the rebased source", function()
		Expect(Target.Text).toBe("typed &gt; words later")
	end)

	It("refresh parses the rebased source", function()
		Settle()
		Expect(Renderer.Document.Source).toBe("typed &gt; words later")
	end)

	It("host keeps the single append", function()
		Expect(Target.Text).toBe("typed &gt; words later")
	end)
end)

Describe("native label hides raw writes until refresh", function()
	local Holder: Frame
	local Target: TextLabel
	local Renderer: any
	local Pending: string = ""

	BeforeAll(function()
		Holder = Instance.new("Frame")
		Holder.Size = UDim2.fromOffset(400, 200)
		Holder.BackgroundTransparency = 1
		Holder.Parent = Screen

		Target = Label("safe text", 400, 200, Holder)
		Renderer = Keep(API.new(Target):SetPreset("Chat"):Flush())
	end)

	It("chat label native", function()
		Expect(Renderer.Native.Active).toBeTruthy()
	end)

	It("visible at rest", function()
		Expect(math.abs(Target.TextTransparency - 0)).toBeLessThanOrEqual(0.001)
	end)

	It("raw write hidden while the refresh is parked", function()
		Holder.Visible = false
		Target.Text = [[<font size="100">huge</font>]]
		task.wait()
		Pending = Target.Text
		Expect(math.abs(Target.TextTransparency - 1)).toBeLessThanOrEqual(0.001)
	end)

	It("raw write still pending", function()
		Expect(Pending).toBe([[<font size="100">huge</font>]])
	end)

	It("refresh sanitizes", function()
		Holder.Visible = true
		Settle()
		Expect(Target.Text).never.toContain("size=")
	end)

	It("refresh shows the label again", function()
		Expect(math.abs(Target.TextTransparency - 0)).toBeLessThanOrEqual(0.001)
	end)
end)

Describe("segment mode owns automatic size", function()
	const Text: string = [[<font color="#ff5555">Automatic</font> sizing follows <b>rendered</b> content, <font size="12">not</font> the <i>hidden</i> markup that lives in Label.Text right now]]
	local Target: TextLabel
	local Renderer: any
	local Wide: TextLabel
	local WideRenderer: any

	BeforeAll(function()
		Target = Label(Text, 300, 10)
		Target.AutomaticSize = Enum.AutomaticSize.Y
		Renderer = API.new(Target):SetRendering("Passthrough", false):Flush()
	end)

	It("automatic size taken over", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.None)
	end)

	It("developer automatic size stored", function()
		Expect(Renderer.Developer.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	It("developer size stored", function()
		Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBe(UDim2.fromOffset(300, 10))
	end)

	It("width kept", function()
		Expect(Target.Size.X).toBe(UDim.new(0, 300))
	end)

	It("height matches rendered content", function()
		Expect(math.abs(Target.Size.Y.Offset - Bottom(Target))).toBeLessThanOrEqual(1)
	end)

	It("height grew past the minimum", function()
		Expect(Target.Size.Y.Offset).toBeGreaterThan(40)
	end)

	It("developer size write becomes the minimum", function()
		Target.Size = UDim2.fromOffset(300, 400)
		Settle()
		Expect(Target.Size).toBe(UDim2.fromOffset(300, 400))
	end)

	It("content centred in the taller box", function()
		Target.TextYAlignment = Enum.TextYAlignment.Center
		Settle()
		const Content: number = Bottom(Target) - Segments(Target)[1].Position.Y.Offset
		Expect(math.abs(Segments(Target)[1].Position.Y.Offset - (400 - Content) / 2)).toBeLessThanOrEqual(2)
	end)

	It("shrinks back to content", function()
		Target.Size = UDim2.fromOffset(300, 10)
		Settle()
		Expect(math.abs(Target.Size.Y.Offset - Bottom(Target))).toBeLessThanOrEqual(1)
	end)

	It("destroy restores automatic size", function()
		Renderer:Destroy()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	It("destroy restores size", function()
		Expect(Target.Size).toBe(UDim2.fromOffset(300, 10))
	end)

	It("width follows content plus padding", function()
		Wide = Label("short line of text", 20, 30)
		Wide.TextWrapped = false
		Wide.AutomaticSize = Enum.AutomaticSize.X

		const Padding: UIPadding = Instance.new("UIPadding")
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 6)
		Padding.Parent = Wide

		WideRenderer = Keep(API.new(Wide):SetRendering("Passthrough", false):Flush())
		Expect(math.abs(Wide.Size.X.Offset - (Right(Wide) + 16))).toBeLessThanOrEqual(1)
	end)

	It("height kept", function()
		Expect(Wide.Size.Y).toBe(UDim.new(0, 30))
	end)

	It("native again", function()
		WideRenderer:SetRendering("Passthrough", true):Flush()
		Expect(WideRenderer.Native.Active).toBeTruthy()
	end)

	It("native restores automatic size", function()
		Expect(Wide.AutomaticSize).toBe(Enum.AutomaticSize.X)
	end)

	It("native restores size", function()
		Expect(Wide.Size).toBe(UDim2.fromOffset(20, 30))
	end)
end)

Describe("segments mirror the host text stroke", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("<b>outlined</b> words here", 300, 60)
		Target.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
		Target.TextStrokeTransparency = 0.25
		Renderer = Keep(API.new(Target):SetRendering("Passthrough", false):Flush())
	end)

	It("segments exist", function()
		Expect(#Segments(Target)).toBeGreaterThan(0)
	end)

	It("stroke color and transparency for every segment", function()
		for Index: number, Segment: TextLabel in Segments(Target) do
			Expect(`{Index} {Segment.TextStrokeColor3 == Color3.fromRGB(255, 0, 0)}`).toBe(`{Index} true`)
			Expect(`{Index} {math.abs(Segment.TextStrokeTransparency - 0.25) <= 0.001}`).toBe(`{Index} true`)
		end
	end)

	It("stroke follows the host for every segment", function()
		Target.TextStrokeColor3 = Color3.fromRGB(0, 0, 255)
		Target.TextStrokeTransparency = 0
		task.wait()

		for Index: number, Segment: TextLabel in Segments(Target) do
			Expect(`{Index} {Segment.TextStrokeColor3 == Color3.fromRGB(0, 0, 255)}`).toBe(`{Index} true`)
			Expect(`{Index} {math.abs(Segment.TextStrokeTransparency - 0) <= 0.001}`).toBe(`{Index} true`)
		end
	end)

	It("restyled stroke for every segment", function()
		Renderer.Label.Text = "<i>new</i> text keeps the outline"
		Renderer:Flush()

		for Index: number, Segment: TextLabel in Segments(Target) do
			Expect(`{Index} {Segment.TextStrokeColor3 == Color3.fromRGB(0, 0, 255)}`).toBe(`{Index} true`)
		end
	end)
end)

Describe("text truncate adds an ellipsis", function()
	const Long: string = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron"
	local Target: TextLabel
	local Last: TextLabel
	local Found: { TextLabel } = {}
	local Line: TextLabel
	local Cut: { TextLabel } = {}
	local Whole: string = ""
	local Parted: string = ""

	BeforeAll(function()
		Target = Label(Long, 200, 40)
		Target.TextTruncate = Enum.TextTruncate.AtEnd
		Keep(API.new(Target):SetRendering("Passthrough", false):Flush())
		Found = Segments(Target)
		Last = Found[#Found]
	end)

	It("clipped lines dropped", function()
		Expect(Bottom(Target)).toBeLessThanOrEqual(40)
	end)

	It("last visible line ends with an ellipsis", function()
		Expect(EndsWithEllipsis(Last.Text)).toBe(true)
	end)

	It("ellipsis line fits the box", function()
		Expect(Last.Position.X.Offset + Last.TextBounds.X).toBeLessThanOrEqual(201)
	end)

	It("no ellipsis mid text", function()
		Expect(Found[1].Text).never.toContain(Ellipsis .. " ")
	end)

	It("none has no ellipsis", function()
		Target.TextTruncate = Enum.TextTruncate.None
		Settle()
		Expect(Joined(Target)).never.toContain(Ellipsis)
	end)

	It("fitting text has no ellipsis", function()
		Target.TextTruncate = Enum.TextTruncate.AtEnd
		Target.Size = UDim2.fromOffset(200, 400)
		Settle()
		Expect(Joined(Target)).never.toContain(Ellipsis)
	end)

	It("overflowing line is the cut point", function()
		Line = Label("ab supercalifragilistic word\nnext line", 120, 200)
		Line.TextWrapped = false
		Line.TextTruncate = Enum.TextTruncate.AtEnd
		Keep(API.new(Line):SetRendering("Passthrough", false):Flush())

		Cut = Segments(Line)
		Whole = if Cut[1] then Cut[1].Text else ""
		Expect(#Cut).toBe(1)
	end)

	It("overflow ends with an ellipsis", function()
		Expect(EndsWithEllipsis(Whole)).toBe(true)
	end)

	It("overflow fits", function()
		Expect(Cut[1].Position.X.Offset + Cut[1].TextBounds.X).toBeLessThanOrEqual(121)
	end)

	It("split word fills more of the line", function()
		Line.TextTruncate = Enum.TextTruncate.SplitWord
		Settle()
		const Split: { TextLabel } = Segments(Line)
		Parted = if Split[1] then Split[1].Text else ""
		Expect(#Parted).toBeGreaterThan(#Whole)
	end)

	It("split word ends with an ellipsis", function()
		Expect(EndsWithEllipsis(Parted)).toBe(true)
	end)

	It("single word chopped by characters", function()
		const Word: TextLabel = Label("supercalifragilisticexpialidocious", 120, 30)
		Word.TextWrapped = false
		Word.TextTruncate = Enum.TextTruncate.AtEnd
		Keep(API.new(Word):SetRendering("Passthrough", false):Flush())

		const Chopped: TextLabel? = Segments(Word)[1]
		const Text: string = if Chopped then Chopped.Text else ""
		Expect(EndsWithEllipsis(Text) and #Text > #Ellipsis).toBe(true)
	end)
end)

Describe("host MaxVisibleGraphemes maps to the reveal", function()
	local Target: TextLabel
	local Renderer: any
	local Found: { TextLabel } = {}

	BeforeAll(function()
		Target = Label("<b>abc</b> <i>defg</i> hij", 400, 60)
		Renderer = Keep(API.new(Target):SetRendering("Passthrough", false):Flush())
		Found = Segments(Target)
	end)

	It("three runs", function()
		Expect(#Found).toBe(3)
	end)

	It("first run fully shown", function()
		Target.MaxVisibleGraphemes = 5
		task.wait()
		Expect(Found[1].MaxVisibleGraphemes).toBe(-1)
	end)

	It("second run partly shown", function()
		Expect(Found[2].MaxVisibleGraphemes).toBe(2)
	end)

	It("third run hidden", function()
		Expect(Found[3].MaxVisibleGraphemes).toBe(0)
	end)

	It("zero hides everything", function()
		Target.MaxVisibleGraphemes = 0
		task.wait()
		Expect(Found[1].MaxVisibleGraphemes).toBe(0)
	end)

	It("developer reveal loop reveals everything", function()
		for Step = 1, 10 do Target.MaxVisibleGraphemes = Step end
		task.wait()
		Expect(Found[3].MaxVisibleGraphemes).toBe(-1)
	end)

	It("grapheme count skips run gaps", function()
		Expect(Renderer:GetGraphemeCount()).toBe(10)
	end)

	It("host cap partly shows the second run", function()
		Target.MaxVisibleGraphemes = 4
		task.wait()
		Expect(Found[2].MaxVisibleGraphemes).toBe(1)
	end)

	It("host cap hides the third run", function()
		Expect(Found[3].MaxVisibleGraphemes).toBe(0)
	end)

	It("minus one reveals everything", function()
		Target.MaxVisibleGraphemes = -1
		task.wait()
		Expect(Found[3].MaxVisibleGraphemes).toBe(-1)
	end)
end)
