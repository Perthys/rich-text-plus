--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Segment = require("../Packages/RichTextPlus/Render/Segment")
const Layout = require("../Packages/RichTextPlus/Core/Layout")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
const Pixel = require("../Packages/RichTextPlus/Utility/Pixel")
const Reflow = require("../Packages/RichTextPlus/Utility/Reflow")
const CodeBlock = require("../Packages/RichTextPlus/Classes/CodeBlock")
const XML = require("../Packages/XML")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
local Screen: ScreenGui

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

const function Create(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):Flush()
end

const function Spy(Real: Instance): (any, { [string]: number })
	const Writes: { [string]: number } = {}

	return setmetatable({}, {
		__index = function(_Proxy: any, Key: string): any
			const Value: any = (Real :: any)[Key]
			if type(Value) == "function" then return function(_Self: any, ...: any): any return Value(Real, ...) end end

			return Value
		end,
		__newindex = function(_Proxy: any, Key: string, Value: any): ()
			Writes[Key] = (Writes[Key] or 0) + 1;
			(Real :: any)[Key] = Value
		end,
	}), Writes
end

const function Find(Renderer: any, Raw: string): any
	for _, Record: any in Renderer.Instances.Segments do
		if Record.Content.Raw == Raw then return Record end
	end

	return nil
end

const function Shown(Renderer: any): number
	local Count: number = 0

	for _, Record: any in Renderer.Instances.Segments do
		if Record.Instance.Visible then Count += 1 end
	end

	return Count
end

BeforeAll(function()
	Screen = Gui.new("Writes")
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("pixel offsets", function()
	It("offset matches fromOffset", function()
		Expect(Pixel.Offset(12, -3)).toBe(UDim2.fromOffset(12, -3))
	end)

	It("offset is reused", function()
		Expect(rawequal(Pixel.Offset(40, 7), Pixel.Offset(40, 7))).toBe(true)
	end)

	It("large offsets still exact", function()
		Expect(Pixel.Offset(3000000, 5)).toBe(UDim2.fromOffset(3000000, 5))
	end)

	It("truncate toward zero", function()
		Expect(Pixel.Truncate(-1.5)).toBe(-1)
	end)

	It("truncate positive", function()
		Expect(Pixel.Truncate(2.9)).toBe(2)
	end)

	It("truncate matches udim", function()
		Expect(Pixel.Truncate(-7.25)).toBe(UDim2.fromOffset(-7.25, 0).X.Offset)
	end)
end)

Describe("segment writes only what changed", function()
	local Target: TextLabel
	local Renderer: any
	local Record: any
	local Real: TextLabel
	local Writes: { [string]: number }
	local Base: number
	local Line: any

	BeforeAll(function()
		Target = Label("<b>first</b> second third", 400, 200)
		Renderer = Create(Target)
		Record = Find(Renderer, "first")
		if not Record then return end

		Real = Record.Label
		const Proxy: any, Spied: { [string]: number } = Spy(Real)
		Writes = Spied
		Base = math.floor(Record.X) + 0.1
		Line = {Style = Record.Style, Text = Record.Content.Raw, X = Base, Y = Record.Y, Width = Record.Width, Height = Record.Height}

		Record.Label = Proxy
		Segment.Apply(Renderer, Record, Line)
		table.clear(Writes)
	end)

	AfterAll(function()
		if Record then Record.Label = Real end
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("bold segment found", function()
		Expect(Record).never.toBeNil()
	end)

	It("sub pixel move writes nothing", function()
		Line.X = Base + 0.5
		Segment.Apply(Renderer, Record, Line)

		Expect(Writes.Position).toBeNil()
	end)

	It("unchanged text writes nothing", function()
		Expect(Writes.Text).toBeNil()
	end)

	It("unchanged style writes nothing", function()
		Expect(Writes.FontFace).toBeNil()
	end)

	It("record keeps the exact x", function()
		Expect(Record.X).toBe(Base + 0.5)
	end)

	It("whole pixel move writes once", function()
		Line.X = Base + 1
		Segment.Apply(Renderer, Record, Line)

		Expect(Writes.Position).toBe(1)
	end)

	It("position lands on the truncated offset", function()
		Expect(Real.Position.X.Offset).toBe(math.floor(Base + 1))
	end)

	It("rounded width writes nothing", function()
		Line.Width = Record.Width - 0.4
		Segment.Apply(Renderer, Record, Line)

		Expect(Writes.Size).toBeNil()
	end)

	It("text change writes once", function()
		Line.Text = "changed"
		Segment.Apply(Renderer, Record, Line)

		Expect(Writes.Text).toBe(1)
	end)

	It("text change leaves RichText alone", function()
		Expect(Writes.RichText).toBeNil()
	end)
end)

Describe("created segments skip default writes", function()
	local Target: TextLabel
	local Renderer: any
	local Record: any

	BeforeAll(function()
		Target = Label("plain words", 400, 200)
		const Limit: number = Pool.Limit()
		Library.Runtime.SetPoolLimit(0)
		Library.Runtime.SetPoolLimit(Limit)

		Renderer = Create(Target)
		Record = Renderer.Instances.Segments[1]
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("segment created", function()
		Expect(Record).never.toBeNil()
	end)

	It("outline seeded from engine defaults", function()
		Expect(Record.Decor.Outline.Transparency).toBe(Record.Label.TextStrokeTransparency)
	end)

	It("outline color seeded", function()
		Expect(Record.Decor.Outline.Color).toBe(Record.Label.TextStrokeColor3)
	end)

	It("vertical alignment default kept", function()
		Expect(Record.Label.TextYAlignment).toBe(Enum.TextYAlignment.Center)
	end)

	It("host stroke still mirrored", function()
		Target.TextStrokeTransparency = 0.5
		Target.TextStrokeColor3 = Color3.new(1, 0, 0)
		task.wait()

		Expect(Record.Label.TextStrokeTransparency).toBe(0.5)
	end)

	It("host stroke color mirrored", function()
		Expect(Record.Label.TextStrokeColor3).toBe(Color3.new(1, 0, 0))
	end)
end)

Describe("ascii uppercase skips the rich parser", function()
	local Target: TextLabel
	local Renderer: any
	local Upper: any
	local Accented: any
	local Small: any

	BeforeAll(function()
		Target = Label("<uc>shout it</uc> <uc>caf\u{E9}</uc> <font color=\"#ff8800\"><sc>small</sc></font>", 600, 200)
		Renderer = Create(Target)
		Upper = Find(Renderer, "shout it")
		Accented = Find(Renderer, "caf\u{E9}")
		Small = Find(Renderer, "small")
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("ascii uppercase plain", function()
		Expect(Upper ~= nil and not Upper.Label.RichText and Upper.Label.Text == "SHOUT IT").toBe(true)
	end)

	It("non ascii uppercase stays rich", function()
		Expect(Accented ~= nil and Accented.Label.RichText and Accented.Label.Text == "<uc>caf\u{E9}</uc>").toBe(true)
	end)

	It("small caps stays rich", function()
		Expect(Small ~= nil and Small.Label.RichText).toBe(true)
	end)

	It("plain uppercase measures like the tag", function()
		const Probe: TextLabel = Label("<uc>shout it</uc>", 600, 200)
		Probe.RichText = true
		Probe.TextWrapped = false
		Probe.TextYAlignment = Enum.TextYAlignment.Center
		Probe.Size = Upper.Label.Size

		const Difference: number = math.abs(Upper.Label.TextBounds.X - Probe.TextBounds.X)
		Probe:Destroy()

		Expect(Difference).toBeLessThan(0.01)
	end)
end)

Describe("culled labels keep segments hidden", function()
	local Scroller: ScrollingFrame
	local Renderer: any

	BeforeAll(function()
		Scroller = Instance.new("ScrollingFrame")
		Scroller.Size = UDim2.fromOffset(300, 100)
		Scroller.CanvasSize = UDim2.fromOffset(300, 1000)
		Scroller.Parent = Screen

		const Target: TextLabel = Label("<b>far</b> away words", 280, 60, Scroller)
		Target.Position = UDim2.fromOffset(0, 600)

		Renderer = Create(Target)
		const _: Vector2 = Target.AbsolutePosition
		Driver.Tick(Renderer, 1 / 60)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Scroller:Destroy()
	end)

	It("label culled", function()
		Expect(Renderer.Cull.Culled).toBe(true)
	end)

	It("culled segments hidden", function()
		Expect(Shown(Renderer)).toBe(0)
	end)

	It("update keeps culled segments hidden", function()
		Renderer.Label.Text = "<b>near</b> away words"
		Renderer:Flush()

		Expect(Shown(Renderer)).toBe(0)
	end)

	It("label back in view", function()
		Scroller.CanvasPosition = Vector2.new(0, 560)
		task.wait()
		Driver.Tick(Renderer, 1 / 60)

		Expect(not Renderer.Cull.Culled).toBe(true)
	end)

	It("in view segments shown", function()
		Expect(Shown(Renderer)).toBe(#Renderer.Instances.Segments)
	end)
end)

Describe("restyle keeps decoration copies", function()
	local Target: TextLabel
	local Stroke: UIStroke
	local Renderer: any
	local Before: any
	local After: any
	local Copy: Instance?

	BeforeAll(function()
		Target = Label([[<font color="#ff0000">tint</font> words]], 400, 200)
		Stroke = Instance.new("UIStroke")
		Stroke.Thickness = 2
		Stroke.Parent = Target

		Renderer = Create(Target)
		Before = Find(Renderer, "tint")
		Copy = if Before then Before.Decoration.List[1] else nil
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("decoration copied", function()
		Expect(Copy ~= nil and (Copy :: Instance).Parent == Before.Instance).toBe(true)
	end)

	It("same record restyled", function()
		Renderer.Label.Text = [[<font color="#00ff00">tint</font> words]]
		Renderer:Flush()
		After = Find(Renderer, "tint")

		Expect(After ~= nil and After == Before).toBe(true)
	end)

	It("copy kept across restyle", function()
		Expect(After ~= nil and After.Decoration.List[1] == Copy and Copy ~= nil and (Copy :: Instance).Parent == After.Instance).toBe(true)
	end)

	It("copy still follows the source", function()
		Stroke.Thickness = 3
		task.wait()

		Expect(Copy ~= nil and (Copy :: UIStroke).Thickness == 3).toBe(true)
	end)
end)

Describe("backdrops repaint only on change", function()
	local Target: TextLabel
	local Renderer: any
	local Layer: any
	local Real: Frame
	local Writes: { [string]: number }

	BeforeAll(function()
		Target = Label([[<mark color="#FFD000">marked</mark> text]], 400, 200)
		Renderer = Create(Target)
		Layer = Renderer.Backdrop.Layers[1]
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("mark layer exists", function()
		Expect(Layer).never.toBeNil()
	end)

	It("same paint writes no color", function()
		Real = Layer.Frame
		const Proxy: any, Spied: { [string]: number } = Spy(Real)
		Writes = Spied

		Layer.Frame = Proxy
		Layer.Paint.Target = Proxy
		Segment.ApplyTransparency(Renderer)

		Expect(Writes.BackgroundColor3).toBeNil()
	end)

	It("same paint writes no transparency", function()
		Expect(Writes.BackgroundTransparency).toBeNil()
	end)

	It("relayout keeps the paint", function()
		Layout.Run(Renderer)
		Layer.Frame = Real
		Layer.Paint.Target = Real

		Expect(Writes.BackgroundColor3).toBeNil()
	end)

	It("transparency change repaints", function()
		Target.TextTransparency = 0.5
		task.wait()

		Expect(math.abs(Real.BackgroundTransparency - 0.5)).toBeLessThan(0.001)
	end)
end)

Describe("code block writes only changed parts", function()
	const Source: string = "local x = 1\nprint(x)"
	const Changes: { [string]: number } = {}
	const Connections: { RBXScriptConnection } = {}
	local Built: Frame

	BeforeAll(function()
		const Node: any = XML.GenerateTreeFromXML(`<codeblock lang="lua">{XML.Escape(Source)}</codeblock>`).Children[1]
		const Style: any = {
			Bold = false, Italic = false, Underline = false, Strike = false, Color = Color3.new(1, 1, 1), Size = 16,
			Family = "rbxasset://fonts/families/BuilderSans.json", Transparency = 0,
		}
		Built = CodeBlock.Build(Node, Style, 1, nil)
		const Panel: Frame = Built:FindFirstChild("Panel") :: Frame
		const Body: TextLabel = Panel:FindFirstChild("Code") :: TextLabel
		const Inset: UIPadding = Panel:FindFirstChildOfClass("UIPadding") :: UIPadding

		Reflow.Apply(Built, 500)
		task.wait()

		for _, Watched: Instance in {Body, Panel, Inset} do
			table.insert(Connections, Watched.Changed:Connect(function(Property: string)
				Changes[Property] = (Changes[Property] or 0) + 1
			end))
		end

		Reflow.Apply(Built, 480)
		task.wait()
	end)

	AfterAll(function()
		for _, Connection: RBXScriptConnection in Connections do Connection:Disconnect() end
		Built:Destroy()
	end)

	It("wide code keeps its text", function()
		Expect(Changes.Text).toBeNil()
	end)

	It("padding untouched", function()
		Expect(Changes.PaddingLeft).toBeNil()
	end)

	It("text size untouched", function()
		Expect(Changes.TextSize).toBeNil()
	end)

	It("narrow code rewraps", function()
		Reflow.Apply(Built, 60)
		task.wait()

		Expect(Changes.Text or 0).toBeGreaterThanOrEqual(1)
	end)
end)
