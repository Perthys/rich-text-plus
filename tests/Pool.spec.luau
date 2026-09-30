--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Want = { Weight: Enum.FontWeight, Style: Enum.FontStyle }

const WHITE: Color3 = Color3.new(1, 1, 1)

const Library: any = RichTextPlus
const Default: number = Pool.Limit()
local Screen: ScreenGui

const function Label(Text: string, Width: number?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width or 400, 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = WHITE
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Create(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):Flush()
end

const function Drain(): ()
	Library.Runtime.SetPoolLimit(0)
	Library.Runtime.SetPoolLimit(Default)
end

const function Instances(Renderer: any): { GuiObject }
	const Found: { GuiObject } = {}
	for _, Record: any in Renderer.Instances.Segments do table.insert(Found, Record.Instance) end

	return Found
end

const function Lookup(List: { GuiObject }): { [GuiObject]: boolean }
	const Set: { [GuiObject]: boolean } = {}
	for _, Object: GuiObject in List do Set[Object] = true end

	return Set
end

const function Spares(): number
	return (Pool.Spares())
end

const function RestoreLimit(): ()
	AfterAll(function()
		Library.Runtime.SetPoolLimit(Default)
	end)
end

BeforeAll(function()
	Screen = Gui.new("Pool")
end)

AfterAll(function()
	Library.Runtime.SetPoolLimit(Default)
	Gui.Cleanup()
end)

Describe("destroy returns segments", function()
	RestoreLimit()

	local Target: TextLabel
	local Renderer: any
	local Records: { any }
	local Labels: number = 0
	local Buttons: number = 0
	local PooledLabels: number
	local PooledButtons: number

	BeforeAll(function()
		Drain()

		Target = Label([[alpha <b>beta</b> <a href="x">gamma link</a> delta]])
		Renderer = Create(Target)
		Records = table.clone(Renderer.Instances.Segments)

		for _, Record: any in Records do
			if Record.Button then Buttons += 1 else Labels += 1 end
		end
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("has a link button", function()
		Expect(Buttons).toBeGreaterThan(0)
	end)

	It("pooled labels", function()
		Renderer:Destroy()
		PooledLabels, PooledButtons = Pool.Spares()

		Expect(PooledLabels).toBe(Labels)
	end)

	It("pooled buttons", function()
		Expect(PooledButtons).toBe(Buttons)
	end)

	It("label emptied", function()
		Expect(#Target:GetChildren()).toBe(0)
	end)

	It("renderer records cleared", function()
		Expect((next(Renderer.Instances.Records))).toBeNil()
	end)

	It("pooled records released", function()
		for Index: number, Record: any in Records do
			const Parent: Instance? = Record.Instance.Parent
			Expect(`{Index} parked away from label {tostring(Parent ~= nil and Parent ~= Target)}`).toBe(`{Index} parked away from label true`)
			Expect(`{Index} element {tostring(Record.Element)}`).toBe(`{Index} element nil`)
			Expect(`{Index} style {tostring(Record.Style)}`).toBe(`{Index} style nil`)
			Expect(`{Index} parented flag {tostring(Record.Parented)}`).toBe(`{Index} parented flag false`)
		end
	end)
end)

Describe("other renderers reuse pooled segments", function()
	RestoreLimit()

	local Second: TextLabel
	local Next: any
	local Reused: number = 0

	BeforeAll(function()
		Drain()

		const First: TextLabel = Label([[<b>one</b> two <i>three</i>]])
		const Renderer: any = Create(First)
		const Used: { [GuiObject]: boolean } = Lookup(Instances(Renderer))
		Renderer:Destroy()
		First:Destroy()

		Second = Label([[<font color="#00ff00">four</font> five <b>six</b>]])
		Next = Create(Second)

		for _, Object: GuiObject in Instances(Next) do
			if Used[Object] then Reused += 1 end
		end
	end)

	AfterAll(function()
		Next:Destroy()
		Second:Destroy()
	end)

	It("every segment reused", function()
		Expect(Reused).toBe(#Next.Instances.Segments)
	end)

	It("pool emptied by reuse", function()
		Expect(Spares()).toBe(0)
	end)

	It("reused segment parented to new label", function()
		for _, Object: GuiObject in Instances(Next) do Expect(Object.Parent).toBe(Second) end
	end)
end)

Describe("no stale state on reuse", function()
	RestoreLimit()

	const Expected: { [string]: Want } = {
		["plain"] = {Weight = Enum.FontWeight.Regular, Style = Enum.FontStyle.Normal},
		["italic"] = {Weight = Enum.FontWeight.Regular, Style = Enum.FontStyle.Italic},
		["more"] = {Weight = Enum.FontWeight.Regular, Style = Enum.FontStyle.Normal},
		["bold"] = {Weight = Enum.FontWeight.Bold, Style = Enum.FontStyle.Normal},
		["end"] = {Weight = Enum.FontWeight.Regular, Style = Enum.FontStyle.Normal},
	}

	local Second: TextLabel
	local Next: any
	local Used: { [GuiObject]: boolean }

	BeforeAll(function()
		Drain()

		const First: TextLabel = Label([[<font size="30" color="#ff0000"><b>BIG</b></font> <u>under</u> <stroke color="#00ff00" thickness="2">stroked</stroke> <gradient colors="#ff0000,#0000ff" speed="1">shiny</gradient> <wave>wavy</wave> <s>gone</s>]])
		First.TextTransparency = 0.5

		const Renderer: any = Create(First)
		First.MaxVisibleGraphemes = 3
		task.wait()
		Driver.Tick(Renderer, 0.35)
		Driver.Tick(Renderer, 0.1)

		Used = Lookup(Instances(Renderer))
		Renderer:Destroy()
		First:Destroy()

		Second = Label([[plain <i>italic</i> more <b>bold</b> end]])
		Next = Create(Second)
	end)

	AfterAll(function()
		Next:Destroy()
		Second:Destroy()
	end)

	It("five segments", function()
		Expect(#Next.Instances.Segments).toBe(5)
	end)

	It("reused segments are reset", function()
		for _, Record: any in Next.Instances.Segments do
			const Segment: TextLabel = Record.Instance
			const Text: string = Segment.Text
			const Wanted: Want? = Expected[Text]

			Expect(`{Text} was pooled {tostring(Used[Segment] == true)}`).toBe(`{Text} was pooled true`)
			Expect(`{Text} expected {tostring(Wanted ~= nil)}`).toBe(`{Text} expected true`)
			Expect(`{Text} rich text {tostring(Segment.RichText)}`).toBe(`{Text} rich text false`)
			Expect(`{Text} transparency {Segment.TextTransparency}`).toBe(`{Text} transparency 0`)
			Expect(`{Text} color {tostring(Segment.TextColor3 == WHITE)}`).toBe(`{Text} color true`)
			Expect(`{Text} size {Segment.TextSize}`).toBe(`{Text} size 18`)
			Expect(`{Text} revealed {Segment.MaxVisibleGraphemes}`).toBe(`{Text} revealed -1`)
			Expect(`{Text} visible {tostring(Segment.Visible)}`).toBe(`{Text} visible true`)
			Expect(`{Text} parented {tostring(Segment.Parent == Second)}`).toBe(`{Text} parented true`)
			Expect(`{Text} stroke {tostring(Segment:FindFirstChildOfClass("UIStroke"))}`).toBe(`{Text} stroke nil`)
			Expect(`{Text} gradient {tostring(Segment:FindFirstChildOfClass("UIGradient"))}`).toBe(`{Text} gradient nil`)
			Expect(`{Text} x {tostring(math.abs(Segment.Position.X.Offset - Record.X) < 1)}`).toBe(`{Text} x true`)
			Expect(`{Text} y {tostring(math.abs(Segment.Position.Y.Offset - Record.Y) < 1)}`).toBe(`{Text} y true`)
			Expect(`{Text} layers {Record.Layers}`).toBe(`{Text} layers 0`)

			if Wanted then
				Expect(`weight {Text} {Segment.FontFace.Weight.Name}`).toBe(`weight {Text} {Wanted.Weight.Name}`)
				Expect(`style {Text} {Segment.FontFace.Style.Name}`).toBe(`style {Text} {Wanted.Style.Name}`)
			end
		end
	end)

	It("nothing animated", function()
		Expect(#Next.Animation.Animated).toBe(0)
	end)

	It("nothing moving", function()
		Expect(#Next.Animation.Moving).toBe(0)
	end)
end)

Describe("buttons drop hover visuals and links", function()
	RestoreLimit()

	const Tint: Color3 = Color3.fromRGB(10, 20, 30)
	local Button: TextButton
	local Renderer: any
	local Second: TextLabel
	local Next: any
	local Record: any
	local Group: any

	BeforeAll(function()
		Drain()

		const First: TextLabel = Label([[<a href="one">first link</a>]])
		Renderer = Create(First)
		Button = Renderer.Instances.Segments[1].Instance

		Button.Text = "<u>first link</u>"
		Button.RichText = true
		Button.TextColor3 = Color3.new(1, 1, 0)

		Renderer:Destroy()
		First:Destroy()

		Second = Label([[<a href="two">second</a>]])
		Next = Create(Second):SetTheme({LinkColor = Tint}):Flush()
		Record = Next.Instances.Segments[1]
		Group = Next:QueryFirst("a")
	end)

	AfterAll(function()
		Next:Destroy()
		Second:Destroy()
	end)

	It("button reused", function()
		Expect(Record.Instance).toBe(Button)
	end)

	It("button text rewritten", function()
		Expect(Button.Text).toBe("second")
	end)

	It("button rich text off", function()
		Expect(Button.RichText).toBe(false)
	end)

	It("button color from new link", function()
		Expect(Button.TextColor3).toBe(Tint)
	end)

	It("button joins the new link element", function()
		Expect(Record.Element).toBe(Group)
	end)

	It("new element lists the button record", function()
		Expect(Group and table.find(Group.Records, Record) ~= nil).toBe(true)
	end)

	It("old renderer elements cleared", function()
		Expect(#Renderer.Elements.All).toBe(0)
	end)
end)

Describe("limit respected", function()
	RestoreLimit()

	local Target: TextLabel
	local Created: { GuiObject }
	local Labels: number
	local Buttons: number
	local Frames: number

	BeforeAll(function()
		Library.Runtime.SetPoolLimit(0)
		Library.Runtime.SetPoolLimit(3)

		Target = Label([[a <b>b</b> c <i>d</i> e <b>f</b> g <i>h</i>]])
		const Renderer: any = Create(Target)
		Created = Instances(Renderer)
		Renderer:Destroy()
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("more segments than the limit", function()
		Expect(#Created).toBeGreaterThan(3)
	end)

	It("pool filled to limit", function()
		Expect(Spares()).toBe(3)
	end)

	It("overflow destroyed", function()
		local Destroyed: number = 0
		for _, Object: GuiObject in Created do
			if Object.Parent == nil then Destroyed += 1 end
		end

		Expect(Destroyed).toBe(#Created - 3)
	end)

	It("lower limit trims", function()
		Library.Runtime.SetPoolLimit(1)

		Expect(Spares()).toBe(1)
	end)

	It("zero limit empties labels", function()
		Library.Runtime.SetPoolLimit(0)
		Labels, Buttons, Frames = Pool.Spares()

		Expect(Labels).toBe(0)
	end)

	It("zero limit empties buttons", function()
		Expect(Buttons).toBe(0)
	end)

	It("zero limit empties frames", function()
		Expect(Frames).toBe(0)
	end)

	It("zero limit disables pooling", function()
		Create(Target):Destroy()

		Expect(Spares()).toBe(0)
	end)

	It("negative limit errors", function()
		Expect((pcall(Library.Runtime.SetPoolLimit, -1))).toBe(false)
	end)

	It("nan limit errors", function()
		Expect((pcall(Library.Runtime.SetPoolLimit, 0 / 0))).toBe(false)
	end)

	It("string limit errors", function()
		Expect((pcall(Library.Runtime.SetPoolLimit, "many"))).toBe(false)
	end)
end)

Describe("backdrops pooled", function()
	RestoreLimit()

	const Blue: Color3 = Color3.fromRGB(0, 0, 255)
	local First: TextLabel
	local Backdrops: Frame
	local Layer: Frame
	local Count: number
	local Frames: number
	local Second: TextLabel
	local Next: any

	BeforeAll(function()
		Drain()

		First = Label([[<mark color="#ff0000">marked words</mark> tail]])
		const Renderer: any = Create(First)
		Backdrops = Renderer.Backdrop.Root
		Layer = Renderer.Backdrop.Layers[1].Frame
		Count = #Renderer.Backdrop.Layers

		Renderer:Destroy()

		const _Labels: number, _Buttons: number, Pooled: number = Pool.Spares()
		Frames = Pooled
	end)

	AfterAll(function()
		First:Destroy()
		if Next then Next:Destroy() end
		if Second then Second:Destroy() end
	end)

	It("backdrop frames pooled", function()
		Expect(Frames).toBe(1 + Count)
	end)

	It("backdrop root parked", function()
		Expect(Backdrops.Parent ~= First and Backdrops.Parent ~= nil).toBe(true)
	end)

	It("backdrop root reused", function()
		First:Destroy()
		Second = Label([[<mark color="#0000ff">other mark</mark> text]])
		Next = Create(Second)

		Expect(Next.Backdrop.Root).toBe(Backdrops)
	end)

	It("backdrop layer reused", function()
		Expect(Next.Backdrop.Layers[1].Frame).toBe(Layer)
	end)

	It("backdrop root parented", function()
		Expect(Backdrops.Parent).toBe(Second)
	end)

	It("layer repainted", function()
		Expect(Layer.BackgroundColor3).toBe(Blue)
	end)

	It("layer painted opaque", function()
		Expect(Layer.BackgroundTransparency).toBeLessThan(1)
	end)

	It("layer visible", function()
		Expect(Layer.Visible).toBe(true)
	end)

	It("backdrops ordered under segments", function()
		const Children: { Instance } = Second:GetChildren()
		const RootIndex: number? = table.find(Children, Backdrops)
		for _, Object: GuiObject in Instances(Next) do
			const Index: number? = table.find(Children, Object)
			Expect(RootIndex ~= nil and Index ~= nil and (RootIndex :: number) < (Index :: number)).toBe(true)
		end
	end)
end)

Describe("fresh backdrops ordered under segments", function()
	RestoreLimit()

	It("fresh backdrops first", function()
		Library.Runtime.SetPoolLimit(0)

		const Target: TextLabel = Label([[<mark>one</mark> two <b>three</b>]])
		const Renderer: any = Create(Target)
		const Children: { Instance } = Target:GetChildren()
		const RootIndex: number? = table.find(Children, Renderer.Backdrop.Root)
		const Ordered: { boolean } = {}

		for _, Object: GuiObject in Instances(Renderer) do
			const Index: number? = table.find(Children, Object)
			table.insert(Ordered, RootIndex ~= nil and Index ~= nil and (RootIndex :: number) < (Index :: number))
		end

		Renderer:Destroy()
		Target:Destroy()

		for _, Before: boolean in Ordered do Expect(Before).toBe(true) end
	end)
end)

Describe("dead labels never pool", function()
	RestoreLimit()

	local Other: any

	BeforeAll(function()
		Drain()
	end)

	It("destroy after label destroy is safe", function()
		const First: TextLabel = Label([[dying <b>label</b> text]])
		const Renderer: any = Create(First)
		First:Destroy()

		Expect((pcall(function() Renderer:Destroy() end))).toBe(true)
	end)

	It("destroyed segments not pooled", function()
		Expect(Spares()).toBe(0)
	end)

	It("destroying event tears down", function()
		const Second: TextLabel = Label([[another <i>dying</i> one]])
		Other = Create(Second)
		Second:Destroy()
		task.wait()

		Expect(Other.Destroyed).toBe(true)
	end)

	It("label destroy does not pool", function()
		Expect(Spares()).toBe(0)
	end)

	It("fresh renderer works", function()
		const Third: TextLabel = Label("fresh text")
		const Fresh: any = Create(Third)
		const Segment: any = Fresh.Instances.Segments[1]
		const Text: string? = if Segment then Segment.Instance.Text else nil

		Fresh:Destroy()
		Third:Destroy()

		Expect(Text).toBe("fresh text")
	end)
end)

Describe("decorations cleared", function()
	RestoreLimit()

	local Created: { GuiObject }
	local Copied: { boolean }

	BeforeAll(function()
		Drain()

		const First: TextLabel = Label([[stroked <b>label</b>]])
		const Outline: UIStroke = Instance.new("UIStroke")
		Outline.Thickness = 3
		Outline.Parent = First

		const Renderer: any = Create(First)
		Created = Instances(Renderer)
		Copied = {}
		for _, Object: GuiObject in Created do table.insert(Copied, Object:FindFirstChildOfClass("UIStroke") ~= nil) end

		Renderer:Destroy()
		First:Destroy()
	end)

	It("decoration copied", function()
		for _, Found: boolean in Copied do Expect(Found).toBe(true) end
	end)

	It("decoration removed on retire", function()
		for _, Object: GuiObject in Created do Expect((Object:FindFirstChildOfClass("UIStroke"))).toBeNil() end
	end)

	It("reused segment undecorated", function()
		const Second: TextLabel = Label([[plain <b>label</b>]])
		const Next: any = Create(Second)
		const Found: { string } = {}
		for _, Object: GuiObject in Instances(Next) do table.insert(Found, tostring(Object:FindFirstChildOfClass("UIStroke"))) end

		Next:Destroy()
		Second:Destroy()

		for _, Stroke: string in Found do Expect(Stroke).toBe("nil") end
	end)
end)

Describe("takeover reuses segments", function()
	RestoreLimit()

	local Target: TextLabel
	local First: any
	local Second: any
	local Used: { [GuiObject]: boolean }

	BeforeAll(function()
		Drain()

		Target = Label([[take <b>over</b> me]])
		First = Create(Target)
		Used = Lookup(Instances(First))
		Second = Create(Target)
	end)

	AfterAll(function()
		Second:Destroy()
		Target:Destroy()
	end)

	It("first renderer destroyed", function()
		Expect(First.Destroyed).toBe(true)
	end)

	It("takeover reuses instances", function()
		local Reused: number = 0
		for _, Object: GuiObject in Instances(Second) do
			if Used[Object] then Reused += 1 end
		end

		Expect(Reused).toBe(#Second.Instances.Segments)
	end)
end)

Describe("chat churn", function()
	RestoreLimit()

	It("churn creates instances once", function()
		Drain()

		const Unique: { [GuiObject]: boolean } = {}
		local Count: number = 0
		local Widest: number = 0

		for Index = 1, 50 do
			const Target: TextLabel = Label(`<b>[Player{Index}]</b>: message number {Index} <font color="#ffcc00">gold</font>`)
			const Renderer: any = Create(Target)

			if #Renderer.Instances.Segments > Widest then Widest = #Renderer.Instances.Segments end

			for _, Object: GuiObject in Instances(Renderer) do
				if not Unique[Object] then
					Unique[Object] = true
					Count += 1
				end
			end

			Renderer:Destroy()
			Target:Destroy()
		end

		Expect(Count).toBeLessThanOrEqual(Widest)
	end)
end)
