--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Lines = require("../Packages/RichTextPlus/Core/Lines")
const Rendering = require("../Packages/RichTextPlus/Policy/Rendering")
const Attributes = require("../Packages/RichTextPlus/Utility/Attributes")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus

const Mixed: string = [[<b>Welcome</b> to the <font color="#FF7800">arena</font>, traveler! Today we test <i>italic words</i>, <u>underlined phrases</u> and a <a href="https://example.com">clickable link here</a>. The quick brown fox jumps over the lazy dog while text keeps going for a while.]]

local Screen: ScreenGui
const Renderers: { any } = {}

const function Build(Target: TextLabel): any
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Label(Text: string, Width: number, Height: number, Parent: Instance?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width, Height)
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

const function Segments(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	return Found
end

const function HasLiteral(Target: TextLabel): boolean
	for _, Segment: TextLabel in Segments(Target) do
		if string.find(Segment.Text, "<b>", 1, true) then return true end
	end

	return false
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("Core")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("render", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Found: { TextLabel }

	BeforeAll(function()
		Target = Label(Mixed, 400, 300)
		Renderer = Build(Target)
		Found = Segments(Target)
	end)

	It("render creates segments", function()
		Expect(#Found).toBeGreaterThanOrEqual(8)
	end)

	It("label text hidden", function()
		Expect(Target.TextTransparency).toBeCloseTo(1, 3)
	end)

	It("owner attribute", function()
		Expect(Target:GetAttribute(Attributes.Owner)).toBe(Renderer.Token)
	end)

	It("renderer alive", function()
		Expect(Renderer.Destroyed).toBeFalsy()
	end)

	Describe("bold", function()
		local Bold: TextLabel?

		BeforeAll(function()
			for _, Segment: TextLabel in Found do if Segment.Text == "Welcome" then Bold = Segment end end
		end)

		It("bold segment exists", function()
			Expect(Bold).never.toBeNil()
		end)

		It("bold weight", function()
			if not Bold then return end
			Expect(Bold.FontFace.Weight).toBe(Enum.FontWeight.Bold)
		end)
	end)

	It("segment within width", function()
		for _, Segment: TextLabel in Found do
			Expect(Segment.Position.X.Offset + Segment.Size.X.Offset).toBeLessThanOrEqual(402)
		end
	end)

	It("wraps onto several lines", function()
		const Rows: { [number]: boolean } = {}
		local RowCount: number = 0
		for _, Segment: TextLabel in Found do
			const Y: number = Segment.Position.Y.Offset
			if not Rows[Y] then Rows[Y] = true; RowCount += 1 end
		end

		Expect(RowCount).toBeGreaterThanOrEqual(3)
	end)

	It("link renders as TextButton", function()
		local Button: Instance? = nil
		for _, Record: any in Renderer.Instances.Segments do if Record.Button then Button = Record.Instance end end

		Expect(Button ~= nil and (Button :: Instance):IsA("TextButton")).toBe(true)
	end)

	Describe("destroy", function()
		BeforeAll(function()
			Renderer:Destroy()
		end)

		It("destroy restores transparency", function()
			Expect(Target.TextTransparency).toBe(0)
		end)

		It("destroy removes segments", function()
			Expect(#Segments(Target)).toBe(0)
		end)

		It("destroy clears owner", function()
			Expect(Target:GetAttribute(Attributes.Owner)).toBeNil()
		end)
	end)
end)

Describe("pooling", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Count: number

	BeforeAll(function()
		Target = Label(Mixed, 400, 300)
		Renderer = Build(Target)
	end)

	It("relayout reuses segment instances", function()
		const Before: { [Instance]: boolean } = {}
		for _, Segment: TextLabel in Segments(Target) do Before[Segment] = true end

		for Step = 1, 6 do
			Target.Size = UDim2.fromOffset(if Step % 2 == 0 then 400 else 360, 300)
			const _Size: Vector2 = Target.AbsoluteSize
			Renderer:Flush()
		end

		local Reused: number = 0
		local Total: number = 0
		for _, Segment: TextLabel in Segments(Target) do
			Total += 1
			if Before[Segment] then Reused += 1 end
		end

		Expect(Reused).toBeGreaterThanOrEqual(Total - 2)
	end)

	Describe("short text", function()
		BeforeAll(function()
			Count = #Target:GetChildren()
			Renderer.Label.Text = "short text"
			Renderer:Flush()
		end)

		It("shorter text reuses or hides pooled segments", function()
			Expect(#Target:GetChildren()).toBeLessThanOrEqual(Count)
		end)

		It("short text visible segments", function()
			Expect(#Segments(Target)).toBe(1)
		end)

		It("short text content", function()
			Expect(Segments(Target)[1].Text).toBe("short text")
		end)
	end)

	It("longer text again renders", function()
		Renderer.Label.Text = Mixed
		Renderer:Flush()

		Expect(#Segments(Target)).toBeGreaterThanOrEqual(8)
	end)
end)

Describe("measure", function()
	AfterAll(Release)

	local Renderer: any
	local Style: any
	local First: Vector2

	BeforeAll(function()
		Renderer = Build(Label("alpha beta", 400, 60))
		Style = Renderer.Document.Tokens[1].Style
		First = Measure.Bounds(Style, 18, "alpha", false)
	end)

	It("measure cache returns same bounds", function()
		Expect(Measure.Bounds(Style, 18, "alpha", false)).toBe(First)
	end)

	It("measure positive width", function()
		Expect(First.X).toBeGreaterThan(0)
	end)

	for _, Row: { any } in {
		{"scaled identity", 18, 1, 18},
		{"scaled rounds", 18, 0.5, 9},
		{"scaled clamps to max", 80, 3, 100},
		{"scaled clamps to min", 18, 0.001, 1},
	} do
		It(Row[1], function()
			Expect(Measure.Scaled(Row[2], Row[3])).toBe(Row[4])
		end)
	end

	It("cased escapes", function()
		Expect(Measure.Cased("a<b", nil)).toBe("a&lt;b")
	end)

	It("cased upper", function()
		Expect(Measure.Cased("ab", "Upper")).toBe("<uc>ab</uc>")
	end)

	It("space width cached per style", function()
		Expect(Renderer.Document.SpaceWidths[Style]).toBeGreaterThan(0)
	end)

	It("second word placed after space", function()
		const Space: number = Renderer.Document.SpaceWidths[Style]
		Expect(math.abs(Renderer.Document.Tokens[2].X - (Renderer.Document.Tokens[1].Width + Space))).toBeLessThanOrEqual(0.01)
	end)
end)

Describe("lines", function()
	AfterAll(Release)

	local Computed: { any }
	local Heights: { number }
	local Total: number

	BeforeAll(function()
		const Renderer: any = Build(Label("one<br/>two<br/><br/>four", 400, 200))
		Computed, Heights, Total = Lines.Compute(Renderer, math.huge, 1)
	end)

	It("break lines", function()
		Expect(#Computed).toBe(4)
	end)

	It("empty line kept", function()
		Expect(#Computed[3].Items).toBe(0)
	end)

	It("empty line has height", function()
		Expect(Heights[3]).toBeGreaterThan(0)
	end)

	It("total height sums", function()
		Expect(math.abs(Total - (Heights[1] + Heights[2] + Heights[3] + Heights[4]))).toBeLessThanOrEqual(0.001)
	end)
end)

Describe("block tokens", function()
	AfterAll(Release)

	local Target: TextLabel
	local Block: GuiObject?
	local Before: TextLabel?
	local After: TextLabel?

	BeforeAll(function()
		Target = Label("before <blockstub/><br/>after", 300, 200)
		const Renderer: any = Build(Target):AddCustomClasses({
			blockstub = {
				Kind = "Object";
				Block = true;
				Build = function(): GuiObject
					const Frame: Frame = Instance.new("Frame")
					Frame.Name = "BlockStub"
					Frame.Size = UDim2.fromOffset(50, 40)

					return Frame
				end;
			};
		}):Flush()

		Renderer.Label.Text = "before <customclass><blockstub/></customclass><br/>after"
		Renderer:Flush()

		Block = Target:FindFirstChild("BlockStub") :: GuiObject?
		for _, Segment: TextLabel in Segments(Target) do
			if Segment.Text == "before" then Before = Segment end
			if Segment.Text == "after" then After = Segment end
		end
	end)

	It("block object rendered", function()
		Expect(Block).never.toBeNil()
	end)

	It("block at x 0", function()
		if not Block then return end
		Expect(Block.Position.X.Offset).toBe(0)
	end)

	It("block full width", function()
		if not Block then return end
		Expect(Block.Size.X.Offset).toBe(300)
	end)

	It("block keeps height", function()
		if not Block then return end
		Expect(Block.Size.Y.Offset).toBe(40)
	end)

	It("text before block", function()
		if not Block then return end
		Expect(Before ~= nil and (Before :: TextLabel).Position.Y.Offset < Block.Position.Y.Offset).toBe(true)
	end)

	It("br after block absorbed", function()
		if not Block then return end
		Expect(if After then After.Position.Y.Offset else nil).toBe(Block.Position.Y.Offset + 40)
	end)
end)

Describe("styles", function()
	AfterAll(Release)

	local Target: TextLabel
	const ByText: { [string]: TextLabel } = {}

	const function Painted(Color: Color3): Frame?
		for _, Child: Instance in Target:GetDescendants() do
			if not (Child:IsA("Frame") and (Child.Name == "Backdrop" or Child.Name == "Fill")) then continue end
			if Child.Visible and Child.BackgroundTransparency < 1 and Child.BackgroundColor3 == Color then return Child end
		end

		return nil
	end

	BeforeAll(function()
		Target = Label([[<mark color="#FFD000" transparency="0.25">marked</mark> <stroke color="#FF0000" thickness="2">stroked</stroke> <uppercase>upper</uppercase> <code>code</code>]], 400, 80)
		Build(Target):SetTheme({CodeBackground = Color3.fromRGB(10, 20, 30)}):Flush()

		for _, Segment: TextLabel in Segments(Target) do ByText[Segment.Text] = Segment end
	end)

	It("mark segment", function()
		Expect(ByText["marked"]).never.toBeNil()
	end)

	It("mark background layer", function()
		Expect(Painted(Color3.fromRGB(255, 208, 0))).never.toBeNil()
	end)

	It("mark segment has no own background", function()
		const Marked: TextLabel? = ByText["marked"]
		if not Marked then return end
		Expect(Marked.BackgroundTransparency).toBe(1)
	end)

	It("mark background transparency", function()
		const MarkLayer: Frame? = Painted(Color3.fromRGB(255, 208, 0))
		if not MarkLayer then return end
		Expect(MarkLayer.BackgroundTransparency).toBeCloseTo(0.25, 3)
	end)

	It("stroke segment", function()
		Expect(ByText["stroked"]).never.toBeNil()
	end)

	It("stroke uses UIStroke", function()
		const Stroked: TextLabel? = ByText["stroked"]
		if not Stroked then return end
		Expect(Stroked:FindFirstChildOfClass("UIStroke")).never.toBeNil()
	end)

	It("stroke color", function()
		const Stroked: TextLabel? = ByText["stroked"]
		const Stroke: UIStroke? = if Stroked then Stroked:FindFirstChildOfClass("UIStroke") else nil
		if not Stroke then return end
		Expect(Stroke.Color).toBe(Color3.fromRGB(255, 0, 0))
	end)

	It("ascii uppercase renders plain", function()
		const Upper: TextLabel? = ByText["UPPER"]
		Expect(Upper ~= nil and not Upper.RichText).toBe(true)
	end)

	It("code segment", function()
		Expect(ByText["code"]).never.toBeNil()
	end)

	It("code background from theme", function()
		Expect(Painted(Color3.fromRGB(10, 20, 30))).never.toBeNil()
	end)

	Describe("code layer", function()
		local Code: TextLabel?
		local CodeLayer: Frame?

		BeforeAll(function()
			Code = ByText["code"]
			CodeLayer = Painted(Color3.fromRGB(10, 20, 30))
		end)

		It("code has corner", function()
			if not (Code and CodeLayer) then return end
			Expect(CodeLayer:FindFirstChildOfClass("UICorner")).never.toBeNil()
		end)

		It("code padded wider than text", function()
			if not (Code and CodeLayer) then return end
			Expect(CodeLayer.Size.X.Offset).toBeGreaterThan(Code.TextBounds.X)
		end)

		It("code text inside padding", function()
			if not (Code and CodeLayer) then return end
			Expect(Code.Position.X.Offset).toBeGreaterThan(CodeLayer.Position.X.Offset)
		end)
	end)
end)

Describe("text scaled", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Image: Instance?
	local FirstFactor: number

	BeforeAll(function()
		Target = Label([[<b>Scaled</b> text with an <img src="rbxassetid://1" size="20"/> image]], 300, 60)
		Target.TextScaled = true

		Renderer = Build(Target)
		Image = Target:FindFirstChild("InlineImage", true)
		FirstFactor = Renderer.Scale.Factor
	end)

	It("scaled factor solved", function()
		Expect(FirstFactor > 0 and FirstFactor ~= 1).toBe(true)
	end)

	It("scaled content fits height", function()
		local Bottom: number = 0
		for _, Segment: TextLabel in Segments(Target) do Bottom = math.max(Bottom, Segment.Position.Y.Offset + Segment.Size.Y.Offset) end

		Expect(Bottom).toBeLessThanOrEqual(60)
	end)

	Describe("smaller box", function()
		BeforeAll(function()
			Target.Size = UDim2.fromOffset(150, 30)
			const _Size: Vector2 = Target.AbsoluteSize
			Renderer:Flush()
			Renderer:Flush()
		end)

		It("smaller box shrinks factor", function()
			Expect(Renderer.Scale.Factor).toBeLessThan(FirstFactor)
		end)

		It("image object built", function()
			Expect(Image).never.toBeNil()
		end)

		It("image object survives rescale", function()
			Expect(Image ~= nil and Target:FindFirstChild("InlineImage", true) == Image).toBe(true)
		end)

		It("image scaled with text", function()
			if not Image then return end
			Expect((Image :: ImageLabel).Size.X.Offset).toBeLessThan(20 * FirstFactor + 1)
		end)
	end)
end)

Describe("features", function()
	AfterAll(Release)

	It("rendering resolves defaults", function()
		Expect(Rendering.Resolve(nil).Culling).toBe(true)
	end)

	It("rendering override", function()
		Expect(Rendering.Resolve({Culling = false}).Culling).toBe(false)
	end)

	It("unknown rendering switch errors", function()
		Expect(function() Rendering.Resolve({Bogus = true}) end).toThrow()
	end)

	It("Plain grants no intents", function()
		Expect(Library.Intents.Presets.Plain.Bitfield).toBe(0)
	end)

	Describe("renderer", function()
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Target = Label("<b>bold</b> text", 400, 60)
			Renderer = Build(Target):SetPreset("Plain"):Flush()
		end)

		It("get intents", function()
			Expect(Renderer:GetIntents():Has("Formatting")).toBe(false)
		end)

		It("rich text off renders tags literally", function()
			Expect(HasLiteral(Target)).toBe(true)
		end)

		It("set preset rebuilds", function()
			Renderer:SetPreset("Default"):Flush()

			Expect(HasLiteral(Target)).toBe(false)
		end)

		It("has of an unknown flag errors", function()
			Expect(function() Renderer:GetIntents():Has("Nope") end).toThrow()
		end)

		It("set feature removed", function()
			Expect(function() Renderer:SetFeature("RichText", true) end).toThrow()
		end)

		It("removed get feature errors", function()
			Expect(function() Renderer:GetFeature("Typewriter") end).toThrow()
		end)

		It("plain preset shows tags literally", function()
			Renderer:SetPreset("Plain"):Flush()

			Expect(HasLiteral(Target)).toBe(true)
		end)
	end)
end)

Describe("reveal", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Segment: TextLabel

	BeforeAll(function()
		Target = Label("hello there world", 400, 60)
		Renderer = Build(Target)
	end)

	It("grapheme count", function()
		Expect(Renderer:GetGraphemeCount()).toBe(17)
	end)

	It("no typewriter api", function()
		Expect(Renderer.Play).toBeNil()
	end)

	It("reveal starts hidden", function()
		Target.MaxVisibleGraphemes = 0
		task.wait()
		Segment = Segments(Target)[1]

		Expect(Segment.MaxVisibleGraphemes).toBe(0)
	end)

	It("reveal follows the host", function()
		Target.MaxVisibleGraphemes = 3
		task.wait()

		Expect(Segment.MaxVisibleGraphemes).toBe(3)
	end)

	It("relayout keeps the reveal", function()
		Target.Size = UDim2.fromOffset(60, 200)
		const _Size: Vector2 = Target.AbsoluteSize
		Renderer:Flush()

		local Visible: number = 0
		for _, Record: any in Renderer.Instances.Order do
			if Record.Content.Revealed == -1 then Visible += Record.Content.Graphemes elseif Record.Content.Revealed > 0 then Visible += Record.Content.Revealed end
		end

		Expect(Visible).toBe(3)
	end)

	It("wrapped count skips break spaces", function()
		Expect(Renderer:GetGraphemeCount()).toBe(15)
	end)

	It("count reveals everything", function()
		Target.MaxVisibleGraphemes = Renderer:GetGraphemeCount()
		task.wait()

		for _, Record: any in Renderer.Instances.Order do Expect(Record.Content.Revealed).toBe(-1) end
	end)

	It("minus one reveals everything", function()
		Target.MaxVisibleGraphemes = -1
		task.wait()

		for _, Record: any in Renderer.Instances.Order do Expect(Record.Content.Revealed).toBe(-1) end
	end)
end)

Describe("animation", function()
	AfterAll(Release)

	local Renderer: any

	BeforeAll(function()
		Renderer = Build(Label([[<gradient colors="#ff0000,#0000ff" speed="1">shiny</gradient> <wave>wavy</wave> still]], 400, 60))
	end)

	It("one animated gradient", function()
		Expect(#Renderer.Animation.Animated).toBe(1)
	end)

	It("one moving effect", function()
		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("gradient advances", function()
		const Gradient: UIGradient = Renderer.Animation.Animated[1].Decor.Gradient
		Driver.Tick(Renderer, 0.05)
		const First: ColorSequence = Gradient.Color
		Driver.Tick(Renderer, 0.05)

		Expect(Gradient.Color).never.toBe(First)
	end)

	It("effect moves segment", function()
		const Wave: GuiObject = Renderer.Animation.Moving[1].Instance
		const Start: number = Wave.Position.Y.Offset
		Driver.Tick(Renderer, 0.05)
		Driver.Tick(Renderer, 0.05)

		Expect(Wave.Position.Y.Offset ~= Start or Renderer.Animation.Moving[1].Y ~= Start).toBe(true)
	end)

	It("animated renderer stays busy", function()
		Expect(Driver.Tick(Renderer, 0.016)).toBeTruthy()
	end)
end)

Describe("idle", function()
	AfterAll(Release)

	local Renderer: any

	BeforeAll(function()
		Renderer = Build(Label("static text only", 400, 60))
		Driver.Tick(Renderer, 0.016)
	end)

	It("idle renderer sleeps after culling pass", function()
		Expect(Driver.Tick(Renderer, 0.016)).toBe(false)
	end)

	It("idle renderer without culling sleeps", function()
		Renderer:SetRendering("Culling", false):Flush()

		Expect(Driver.Tick(Renderer, 0.016)).toBe(false)
	end)

	It("no clip chain without culling", function()
		Expect(#Renderer.Cull.Clippers).toBe(0)
	end)
end)

Describe("culling", function()
	AfterAll(Release)

	local Scroller: ScrollingFrame
	local Renderer: any

	BeforeAll(function()
		Scroller = Instance.new("ScrollingFrame")
		Scroller.Size = UDim2.fromOffset(300, 100)
		Scroller.CanvasSize = UDim2.fromOffset(300, 1000)
		Scroller.Parent = Screen

		Renderer = Build(Label("line one<br/>line two<br/>line three<br/>line four<br/>line five<br/>line six<br/>line seven<br/>line eight", 300, 600, Scroller))
		Driver.Tick(Renderer, 0.016)
	end)

	It("offscreen segments culled", function()
		local Hidden: number = 0
		for _, Record: any in Renderer.Instances.Segments do if not Record.Shown then Hidden += 1 end end

		Expect(Hidden).toBeGreaterThan(0)
	end)

	It("scrolled away segment hidden", function()
		Scroller.CanvasPosition = Vector2.new(0, 200)
		const _Position: Vector2 = Renderer.Label.AbsolutePosition
		task.wait()
		Driver.Tick(Renderer, 0.016)

		Expect(Renderer.Instances.Segments[1].Shown).toBe(false)
	end)

	It("culling off shows all", function()
		Renderer:SetRendering("Culling", false):Flush()

		local Shown: number = 0
		for _, Record: any in Renderer.Instances.Segments do if Record.Shown then Shown += 1 end end

		Expect(Shown).toBe(#Renderer.Instances.Segments)
	end)
end)

Describe("transparency", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label([[plain <font transparency="0.5">half</font>]], 400, 60)
		Renderer = Build(Target)

		Target.TextTransparency = 0.5
		task.wait()
	end)

	It("transparency per segment", function()
		for _, Segment: TextLabel in Segments(Target) do
			const Expected: number = if Segment.Text == "half" then 0.75 else 0.5
			Expect(Segment.TextTransparency).toBeCloseTo(Expected, 3)
		end
	end)

	It("developer transparency stored", function()
		Expect(Target:GetAttribute(Attributes.DeveloperTransparency)).toBe(0.5)
	end)

	It("restores developer transparency", function()
		Renderer:Destroy()

		Expect(Target.TextTransparency).toBeCloseTo(0.5, 3)
	end)
end)

Describe("text scaled automatic size", function()
	AfterAll(Release)

	const Original: UDim2 = UDim2.new(0.5, 0, 0, 40)
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("scaled automatic", 200, 40)
		Target.Size = Original
		Target.AutomaticSize = Enum.AutomaticSize.Y
		Target.TextScaled = true

		Renderer = Build(Target)
		task.wait()
	end)

	It("scaled freezes automatic size", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.None)
	end)

	It("stored developer size survives echoes", function()
		Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBe(Original)
	end)

	It("stored developer automatic size", function()
		Expect(Renderer.Developer.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	Describe("destroyed", function()
		BeforeAll(function()
			Renderer:Destroy()
		end)

		It("destroy restores automatic size", function()
			Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
		end)

		It("destroy restores size", function()
			Expect(Target.Size).toBe(Original)
		end)
	end)
end)

Describe("set text", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("first", 400, 60)
		Renderer = Build(Target)

		Renderer.Label.Text = "second <b>value</b>"
		Renderer:Flush()
	end)

	It("set text renders synchronously", function()
		Expect(#Segments(Target)).toBe(2)
	end)

	It("set text updates source", function()
		Expect(Renderer.Document.Source).toBe("second <b>value</b>")
	end)

	It("text property change rebuilds", function()
		Target.Text = "third"
		task.wait()

		Expect(Segments(Target)[1].Text).toBe("third")
	end)
end)

Describe("takeover", function()
	AfterAll(Release)

	local Target: TextLabel
	local First: any
	local Second: any

	BeforeAll(function()
		Target = Label("owned", 400, 60)
		First = Build(Target)
		Second = Build(Target)
	end)

	It("first renderer destroyed", function()
		Expect(First.Destroyed).toBeTruthy()
	end)

	It("second renderer alive", function()
		Expect(Second.Destroyed).toBeFalsy()
	end)

	It("single set of segments", function()
		Expect(#Segments(Target)).toBe(1)
	end)

	It("foreign owner abandons", function()
		Target:SetAttribute(Attributes.Owner, "someone else")
		task.wait()

		Expect(Second.Destroyed).toBeTruthy()
	end)
end)

Describe("effect class", function()
	AfterAll(Release)

	const Bounce = {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(0, 7) end}
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label([[<customclass><bounce>hop</bounce></customclass>]], 400, 60)
		Renderer = Build(Target):AddCustomClasses({bounce = Bounce}):Flush()
	end)

	It("effect class animates its content", function()
		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("effect class offset applied", function()
		const Moving: any = Renderer.Animation.Moving[1]
		Driver.Tick(Renderer, 0.016)
		if not Moving then return end

		Expect(Moving.Instance.Position.Y.Offset).toBe(Moving.Y + 7)
	end)

	It("effect data carries the class name", function()
		const Moving: any = Renderer.Animation.Moving[1]
		if not Moving then return end

		Expect(Moving.Style.Effect.Name).toBe("bounce")
	end)

	It("removed effect class stops animating", function()
		Renderer:RemoveCustomClass("bounce"):Flush()

		Expect(#Renderer.Animation.Moving).toBe(0)
	end)

	It("re-registered effect class animates", function()
		Renderer:AddCustomClass("BOUNCE", Bounce):Flush()

		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("effect class outside a region is an unknown tag", function()
		Target.Text = [[<bounce>outside</bounce>]]
		Renderer:Flush()

		Expect(#Renderer.Animation.Moving).toBe(0)
	end)

	It("effect class shorthand animates", function()
		Target.Text = [[<customclass name="bounce" amplitude="3">short</customclass>]]
		Renderer:Flush()

		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("effect class reads amplitude", function()
		const Moving: any = Renderer.Animation.Moving[1]
		if not Moving then return end

		Expect(Moving.Style.Effect.Amplitude).toBe(3)
	end)

	Describe("gated", function()
		BeforeAll(function()
			Target.Text = [[<customclass><bounce>hop</bounce></customclass>]]
			Renderer:SetIntents(Library.Intents.Presets.Default:Remove("Effects")):Flush()
		end)

		It("effect class gated by the Effects feature", function()
			Expect(#Renderer.Animation.Moving).toBe(0)
		end)

		It("gated effect class keeps its content", function()
			Expect(Segments(Target)[1] and Segments(Target)[1].Text).toBe("hop")
		end)
	end)

	It("effect class allowed with Effects", function()
		Renderer:SetIntents("Default"):Flush()

		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("effect class needs custom class regions", function()
		Renderer:SetIntents(Library.Intents.Presets.Default:Remove("CustomClasses")):Flush()

		Expect(#Renderer.Animation.Moving).toBe(0)
	end)

	It("effect class needs Update", function()
		Renderer:SetPreset("Default"):Flush()

		Expect(function() Renderer:AddCustomClass("broken", {Kind = "Effect"}) end).toThrow()
	end)

	It("effect class Update must be a function", function()
		Expect(function() Renderer:AddCustomClass("broken", {Kind = "Effect", Update = 1}) end).toThrow()
	end)

	Describe("override", function()
		BeforeAll(function()
			Renderer:AddCustomClass("wave", {Kind = "Effect", Override = true, Update = Bounce.Update}):Flush()
			Target.Text = [[<customclass><wave>w</wave></customclass> <wave>builtin</wave>]]
			Renderer:Flush()
		end)

		It("override effect class replaces wave inside regions only", function()
			local Overridden: number = 0
			for _, Record: any in Renderer.Animation.Moving do if Record.Updates[1] == Bounce.Update then Overridden += 1 end end

			Expect(Overridden).toBe(1)
		end)

		It("builtin wave still animates outside", function()
			Expect(#Renderer.Animation.Moving).toBe(2)
		end)
	end)

	It("the effect tag is gone", function()
		Target.Text = [[<effect name="bounce">old</effect>]]
		Renderer:Flush()

		Expect(#Renderer.Animation.Moving).toBe(0)
	end)
end)

Describe("api shape", function()
	AfterAll(Release)

	const Moved: { string } = {"Preload", "SetFrameBudget", "SetPoolLimit", "SetProfiling", "Flush"}
	const Replacements: { { string } } = {
		{"SetText", "Label.Text"},
		{"Render", "Flush"},
		{"Layout", "Flush"},
		{"SolveScale", "Flush"},
		{"ApplyTransparency", "Flush"},
		{"Flatten", "Label.Text"},
		{"Abandon", "Destroy"},
		{"Owns", "Destroy"},
		{"AddEffect", "AddCustomClass"},
		{"GetEffectNames", "AddCustomClass"},
	}

	local Renderer: any

	BeforeAll(function()
		Renderer = Build(Label("shape", 200, 40))
	end)

	for _, Name: string in Moved do
		It(`Runtime.{Name} is a function`, function()
			Expect(type(Library.Runtime[Name])).toBe("function")
		end)

		It(`module {Name} names its new home`, function()
			Expect(function() return Library[Name] end).toThrow()
		end)
	end

	It("module method access errors", function()
		Expect(function() return Library.SetText end).toThrow()
	end)

	It("unknown module member reads nil", function()
		Expect(Library.NoSuchMember).toBeNil()
	end)

	It("renderer has no constructor", function()
		Expect(Renderer.new).toBeNil()
	end)

	It("renderer has no runtime statics", function()
		Expect(Renderer.SetFrameBudget).toBeNil()
	end)

	It("renderer has no runtime table", function()
		Expect(Renderer.Runtime).toBeNil()
	end)

	It("instance flush settles", function()
		Expect(function() Renderer:Flush() end).never.toThrow()
	end)

	It("runtime flush settles", function()
		Expect(Library.Runtime.Flush).never.toThrow()
	end)

	It("SetFeature still names its replacement", function()
		Expect(function() Renderer:SetFeature("Images", false) end).toThrow()
	end)

	for _, Row: { string } in Replacements do
		const Name: string, Replacement: string = Row[1], Row[2]

		It(`Renderer:{Name} errors`, function()
			Expect(function() return Renderer[Name] end).toThrow()
		end)

		It(`Renderer:{Name} names {Replacement}`, function()
			const _Ok: boolean, Problem: any = pcall(function() return Renderer[Name] end)
			Expect((string.find(tostring(Problem), Replacement, 1, true))).never.toBeNil()
		end)

		It(`module {Name} errors`, function()
			Expect(function() return Library[Name] end).toThrow()
		end)

		It(`module {Name} names {Replacement}`, function()
			const _Ok: boolean, Problem: any = pcall(function() return Library[Name] end)
			Expect((string.find(tostring(Problem), Replacement, 1, true))).never.toBeNil()
		end)
	end

	It("unknown renderer member reads nil", function()
		Expect(Renderer.NoSuchMember).toBeNil()
	end)

	It("RenderingNames frozen", function()
		Expect(table.isfrozen(Library.Runtime.RenderingNames)).toBe(true)
	end)

	It("RenderingNames count", function()
		Expect(#Library.Runtime.RenderingNames).toBe(4)
	end)

	for _, Name: string in Library.Runtime.RenderingNames do
		It(`{Name} is a readable switch`, function()
			Expect(type(Renderer:GetRendering(Name))).toBe("boolean")
		end)

		It(`{Name} is in Renderer.Rendering`, function()
			Expect(type(Renderer.Rendering[Name])).toBe("boolean")
		end)
	end

	It("RenderingNames covers Renderer.Rendering", function()
		local Switches: number = 0
		for _ in Renderer.Rendering do Switches += 1 end

		Expect(Switches).toBe(#Library.Runtime.RenderingNames)
	end)

	It("module RenderingNames names its new home", function()
		Expect(function() return Library.RenderingNames end).toThrow()
	end)
end)
