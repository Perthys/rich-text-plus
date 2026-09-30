--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Pixel = require("../Packages/RichTextPlus/Utility/Pixel")
const Effect = require("../Packages/RichTextPlus/Classes/Effect")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const WHITE: Color3 = Color3.new(1, 1, 1)
const RED: Color3 = Color3.new(1, 0, 0)
const BLUE: Color3 = Color3.new(0, 0, 1)
const GREEN: Color3 = Color3.new(0, 1, 0)

const Library: any = RichTextPlus
local Screen: ScreenGui

const function Label(Content: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 80)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = WHITE
	Created.Text = Content
	Created.Parent = Screen

	return Created
end

const function Create(Content: string, Classes: { [string]: any }?, Setup: ((any) -> ())?): (TextLabel, any)
	const Target: TextLabel = Label(Content)
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false)
	if Classes then Renderer:AddCustomClasses(Classes) end
	if Setup then Setup(Renderer) end

	return Target, Renderer:Flush()
end

const function Tick(Renderer: any, Count: number?): ()
	for _ = 1, Count or 1 do Driver.Tick(Renderer, 1 / 60) end
end

const function Moving(Renderer: any, Index: number?): any
	return Renderer.Animation.Moving[Index or 1]
end

const function Near(Actual: number, Expected: number, Tolerance: number): number
	return if math.abs(Actual - Expected) <= Tolerance then Expected else Actual
end

BeforeAll(function()
	Screen = Gui.new("Effects")
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("frame fields read", function()
	const Seen: { any } = {}
	const Frames: { [any]: boolean } = {}
	local Target: TextLabel
	local Renderer: any
	local Moved: number
	local First: any

	BeforeAll(function()
		const Probe: any = {Kind = "Effect", Update = function(Frame: any): ()
			Frames[Frame] = true
			table.insert(Seen, {Time = Frame.Time, Seed = Frame.Seed, Amplitude = Frame.Amplitude, Frequency = Frame.Frequency, Name = Frame.Name, Node = Frame.Node, Offset = Frame.Offset, Color = Frame.Color})
		end}
		Target, Renderer = Create([[<customclass><probe amplitude="3" frequency="4" tint="red">one two</probe></customclass>]], {probe = Probe})

		Moved = #Renderer.Animation.Moving
		Tick(Renderer, 3)
		First = Seen[1]
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("two segments move", function()
		Expect(Moved).toBe(2)
	end)

	It("update ran", function()
		Expect(First).never.toBeNil()
	end)

	It("time is the animation clock", function()
		Expect(Seen[#Seen].Time).toBe(Renderer.Animation.Clock)
	end)

	It("seed is the segment seed", function()
		Expect(First.Seed).toBe(Moving(Renderer).Seed)
	end)

	It("amplitude read", function()
		Expect(First.Amplitude).toBe(3)
	end)

	It("frequency read", function()
		Expect(First.Frequency).toBe(4)
	end)

	It("name read", function()
		Expect(First.Name).toBe("probe")
	end)

	It("node is the tag", function()
		Expect(First.Node and First.Node.TagType).toBe("probe")
	end)

	It("node attributes readable", function()
		Expect(Library.Utilities.Attribute(First.Node, "tint")).toBe("red")
	end)

	It("offset starts unset", function()
		Expect(First.Offset).toBeNil()
	end)

	It("color starts unset", function()
		Expect(First.Color).toBeNil()
	end)

	It("one reused frame table", function()
		local Count: number = 0
		for _ in Frames do Count += 1 end

		Expect(Count).toBe(1)
	end)

	It("seeds differ per segment", function()
		Expect(Seen[1] and Seen[2] and Seen[1].Seed ~= Seen[2].Seed).toBe(true)
	end)
end)

Describe("writable fields applied and restored", function()
	local On: boolean = true
	local Target: TextLabel
	local Renderer: any
	local Record: any
	local Segment: TextLabel
	local Stroke: UIStroke
	local Before: Color3

	BeforeAll(function()
		const Full: any = {Kind = "Effect", Update = function(Frame: any): ()
			if not On then return end

			Frame.Offset = Vector2.new(3, -4)
			Frame.Rotation = 15
			Frame.Color = RED
			Frame.Transparency = 0.4
			Frame.StrokeColor = BLUE
			Frame.StrokeTransparency = 0.6
		end}
		Target, Renderer = Create([[<customclass><full><stroke color="#00ff00" transparency="0.2">word</stroke></full></customclass>]], {full = Full})
		Record = Moving(Renderer)
		Segment = Record.Label
		Stroke = Record.Decor.Stroke
		Before = Segment.TextColor3
		Tick(Renderer)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("segment has a stroke", function()
		Expect(Stroke).never.toBeNil()
	end)

	It("base color before", function()
		Expect(Before).toBe(WHITE)
	end)

	It("offset x applied", function()
		Expect(Segment.Position.X.Offset).toBe(Pixel.Truncate(Record.X + 3))
	end)

	It("offset y applied", function()
		Expect(Segment.Position.Y.Offset).toBe(Pixel.Truncate(Record.Y - 4))
	end)

	It("rotation applied", function()
		Expect(Segment.Rotation).toBe(15)
	end)

	It("color applied", function()
		Expect(Segment.TextColor3).toBe(RED)
	end)

	It("transparency applied", function()
		Expect(Near(Segment.TextTransparency, 0.4, 1e-3)).toBe(0.4)
	end)

	It("stroke color applied", function()
		Expect(Stroke.Color).toBe(BLUE)
	end)

	It("stroke transparency applied", function()
		Expect(Near(Stroke.Transparency, 0.6, 1e-3)).toBe(0.6)
	end)

	It("offset x restored", function()
		On = false
		Tick(Renderer)

		Expect(Segment.Position.X.Offset).toBe(Pixel.Truncate(Record.X))
	end)

	It("offset y restored", function()
		Expect(Segment.Position.Y.Offset).toBe(Pixel.Truncate(Record.Y))
	end)

	It("rotation restored", function()
		Expect(Segment.Rotation).toBe(0)
	end)

	It("color restored", function()
		Expect(Segment.TextColor3).toBe(WHITE)
	end)

	It("transparency restored", function()
		Expect(Near(Segment.TextTransparency, 0, 1e-3)).toBe(0)
	end)

	It("stroke color restored", function()
		Expect(Stroke.Color).toBe(GREEN)
	end)

	It("stroke transparency restored", function()
		Expect(Near(Stroke.Transparency, 0.2, 1e-3)).toBe(0.2)
	end)

	It("color reapplied", function()
		On = true
		Tick(Renderer)

		Expect(Segment.TextColor3).toBe(RED)
	end)

	It("effect transparency combines with the label", function()
		Target.TextTransparency = 0.5
		task.wait()
		Renderer:Flush()
		Tick(Renderer)

		Expect(Near(Segment.TextTransparency, 1 - 0.5 * 0.6, 1e-3)).toBe(1 - 0.5 * 0.6)
	end)

	It("pooled segments return to base", function()
		Target.TextTransparency = 0
		Target.Text = "plain word"
		Renderer:Flush()

		for _, Child: Instance in Target:GetChildren() do
			if Child.Name ~= "Segment" or not (Child :: GuiObject).Visible then continue end

			const Text: string = (Child :: TextLabel).Text
			Expect(`pooled {Text} color base {tostring((Child :: TextLabel).TextColor3 == WHITE)}`).toBe(`pooled {Text} color base true`)
			Expect(`pooled {Text} rotation base {(Child :: TextLabel).Rotation}`).toBe(`pooled {Text} rotation base 0`)
			Expect(`pooled {Text} transparency base {math.abs((Child :: TextLabel).TextTransparency) <= 1e-3}`).toBe(`pooled {Text} transparency base true`)
		end
	end)
end)

Describe("only changed values are written", function()
	It("steady values write nothing", function()
		const Fixed: any = {Kind = "Effect", Update = function(Frame: any): ()
			Frame.Color = RED
			Frame.Rotation = 5
		end}
		const Target: TextLabel, Renderer: any = Create([[<customclass><fixed>word</fixed></customclass>]], {fixed = Fixed})
		const Segment: TextLabel = Moving(Renderer).Label

		Tick(Renderer)

		local Writes: number = 0
		const Connections: { RBXScriptConnection } = {
			Segment:GetPropertyChangedSignal("TextColor3"):Connect(function() Writes += 1 end),
			Segment:GetPropertyChangedSignal("Rotation"):Connect(function() Writes += 1 end),
			Segment:GetPropertyChangedSignal("TextTransparency"):Connect(function() Writes += 1 end),
			Segment:GetPropertyChangedSignal("Position"):Connect(function() Writes += 1 end),
		}

		Tick(Renderer, 10)
		task.wait()

		for _, Connection: RBXScriptConnection in Connections do Connection:Disconnect() end
		Renderer:Destroy()
		Target:Destroy()

		Expect(Writes).toBe(0)
	end)
end)

Describe("nesting composes", function()
	local Target: TextLabel
	local Renderer: any
	local Both: any = nil
	local Solo: any = nil
	local Mixed: any

	BeforeAll(function()
		const Outer: any = {Kind = "Effect", Update = function(Frame: any): ()
			Frame.Offset = Vector2.new(2, 0)
			Frame.Rotation = 10
			Frame.Color = BLUE
			Frame.Transparency = 0.5
		end}
		const Inner: any = {Kind = "Effect", Update = function(Frame: any): ()
			Frame.Offset = Vector2.new(0, 3)
			Frame.Rotation = 5
			Frame.Color = RED
		end}
		Target, Renderer = Create([[<customclass><outer><inner>both</inner> solo</outer></customclass>]], {outer = Outer, inner = Inner})

		Tick(Renderer)

		for _, Record: any in Renderer.Animation.Moving do
			if Record.Content.Raw == "both" then Both = Record elseif Record.Content.Raw == "solo" then Solo = Record end
		end
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("nested segment found", function()
		Expect(Both).never.toBeNil()
	end)

	It("outer segment found", function()
		Expect(Solo).never.toBeNil()
	end)

	It("nested layers", function()
		Expect(Both.Layers).toBe(2)
	end)

	It("offsets add x", function()
		Expect(Both.Label.Position.X.Offset).toBe(Pixel.Truncate(Both.X + 2))
	end)

	It("offsets add y", function()
		Expect(Both.Label.Position.Y.Offset).toBe(Pixel.Truncate(Both.Y + 3))
	end)

	It("rotations add", function()
		Expect(Both.Label.Rotation).toBe(15)
	end)

	It("innermost color wins", function()
		Expect(Both.Label.TextColor3).toBe(RED)
	end)

	It("outer transparency applies when inner sets none", function()
		Expect(Near(Both.Label.TextTransparency, 0.5, 1e-3)).toBe(0.5)
	end)

	It("outer only layer", function()
		Expect(Solo.Layers).toBe(1)
	end)

	It("outer color", function()
		Expect(Solo.Label.TextColor3).toBe(BLUE)
	end)

	It("wave adds to a custom offset", function()
		Target.Text = [[<wave amplitude="4"><customclass><inner>w</inner></customclass></wave>]]
		Renderer:Flush()
		Tick(Renderer)
		Mixed = Moving(Renderer)

		const Expected: number = Pixel.Truncate(Mixed.Y + 3 + math.sin(Renderer.Animation.Clock * 6 + Mixed.Seed) * 4)

		Expect(math.abs(Mixed.Label.Position.Y.Offset - Expected)).toBeLessThanOrEqual(1)
	end)

	It("custom color inside wave", function()
		Expect(Mixed.Label.TextColor3).toBe(RED)
	end)
end)

Describe("effects feature gate", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		const Tint: any = {Kind = "Effect", Update = function(Frame: any): () Frame.Color = RED end}
		const Muted: any = Library.Intents.Presets.Default:Remove("Effects")
		Target, Renderer = Create([[<customclass><tint>word</tint></customclass> <wave>w</wave>]], {tint = Tint}, function(Built: any) Built:SetIntents(Muted) end)

		Tick(Renderer, 2)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("nothing animates without Effects", function()
		Expect(#Renderer.Animation.Moving).toBe(0)
	end)

	It("gated color stays base", function()
		for _, Child: Instance in Target:GetChildren() do
			if Child.Name == "Segment" then
				Expect(`{(Child :: TextLabel).Text} {tostring((Child :: TextLabel).TextColor3 == WHITE)}`).toBe(`{(Child :: TextLabel).Text} true`)
			end
		end
	end)

	It("effects animate once allowed", function()
		Renderer:SetPreset("Default"):Flush()
		Tick(Renderer)

		Expect(#Renderer.Animation.Moving).toBe(2)
	end)
end)

Describe("bad effects dropped", function()
	const Cases: { [string]: any } = {
		throws = {Kind = "Effect", Update = function(Frame: any): ()
			Frame.Color = RED
			error("effect spec expected failure")
		end},
		returns = {Kind = "Effect", Update = function(): any return Vector2.new(0, 3) end},
		badcolor = {Kind = "Effect", Update = function(Frame: any): () Frame.Color = "red" end},
		nanturn = {Kind = "Effect", Update = function(Frame: any): () Frame.Rotation = 0 / 0 end},
		hugealpha = {Kind = "Effect", Update = function(Frame: any): () Frame.Transparency = math.huge end},
	}

	for Name: string, Definition: any in Cases do
		Describe(Name, function()
			local Target: TextLabel
			local Renderer: any
			local Segment: TextLabel

			BeforeAll(function()
				Target, Renderer = Create(`<customclass><{Name}>bad</{Name}></customclass>`, {[Name] = Definition})
				Segment = Moving(Renderer).Label

				Tick(Renderer, 2)
			end)

			AfterAll(function()
				Renderer:Destroy()
				Target:Destroy()
			end)

			It(`{Name} dropped`, function()
				Expect(#Renderer.Animation.Moving).toBe(0)
			end)

			It(`{Name} color left base`, function()
				Expect(Segment.TextColor3).toBe(WHITE)
			end)

			It(`{Name} rotation left base`, function()
				Expect(Segment.Rotation).toBe(0)
			end)
		end)
	end

	It("transparency clamped to 1", function()
		const Clamp: any = {Kind = "Effect", Update = function(Frame: any): () Frame.Transparency = 3 end}
		const Target: TextLabel, Renderer: any = Create([[<customclass><clamp>x</clamp></customclass>]], {clamp = Clamp})
		Tick(Renderer)

		const Transparency: number = Moving(Renderer).Label.TextTransparency
		Renderer:Destroy()
		Target:Destroy()

		Expect(Transparency).toBe(1)
	end)

	Describe("stacked", function()
		local Nested: TextLabel
		local Stacked: any

		BeforeAll(function()
			const Boom: any = {Kind = "Effect", Update = function(): () error("effect spec expected failure") end}
			const Lift: any = {Kind = "Effect", Update = function(Frame: any): () Frame.Rotation = 7 end}
			Nested, Stacked = Create([[<customclass><lift><boom>x</boom></lift></customclass>]], {boom = Boom, lift = Lift})
			Tick(Stacked, 2)
		end)

		AfterAll(function()
			Stacked:Destroy()
			Nested:Destroy()
		end)

		It("healthy outer layer keeps animating", function()
			Expect(#Stacked.Animation.Moving).toBe(1)
		end)

		It("outer layer still applies", function()
			Expect(Moving(Stacked) and Moving(Stacked).Label.Rotation).toBe(7)
		end)
	end)
end)

Describe("per-frame animation", function()
	It("all words animate", function()
		const Numeric: any = {Kind = "Effect", Update = function(Frame: any): ()
			Frame.Rotation = math.sin(Frame.Time + Frame.Seed)
			Frame.Transparency = 0.5 + 0.5 * math.sin(Frame.Time * Frame.Frequency)
		end}
		const Words: { string } = {}
		for Index = 1, 40 do Words[Index] = `w{Index}` end

		const Target: TextLabel, Renderer: any = Create(`<customclass><numeric>{table.concat(Words, " ")}</numeric></customclass>`, {numeric = Numeric})
		Target.Size = UDim2.fromOffset(900, 400)
		Renderer:Flush()
		Tick(Renderer, 30)

		const Count: number = #Renderer.Animation.Moving
		Renderer:Destroy()
		Target:Destroy()

		Expect(Count).toBe(40)
	end)
end)

Describe("wave and shake parity", function()
	local Target: TextLabel
	local Renderer: any
	local Both: any
	local Now: number

	BeforeAll(function()
		Target, Renderer = Create([[<wave amplitude="4" frequency="3">wave</wave> <shake amplitude="2" frequency="9">shake</shake>]])
		Tick(Renderer, 7)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("wave and shake offsets", function()
		const Clock: number = Renderer.Animation.Clock

		for _, Record: any in Renderer.Animation.Moving do
			const Raw: string = Record.Content.Raw
			const X: number = Record.Label.Position.X.Offset + 0
			const Y: number = Record.Label.Position.Y.Offset + 0

			if Raw == "wave" then
				Expect(`wave x {X}`).toBe(`wave x {Pixel.Truncate(Record.X) + 0}`)
				Expect(`wave y {Y}`).toBe(`wave y {Pixel.Truncate(Record.Y + math.sin(Clock * 3 + Record.Seed) * 4) + 0}`)
			else
				Expect(`shake x {X}`).toBe(`shake x {Pixel.Truncate(Record.X + math.noise(Record.Seed, Clock * 9) * 2 * 2) + 0}`)
				Expect(`shake y {Y}`).toBe(`shake y {Pixel.Truncate(Record.Y + math.noise(Clock * 9, Record.Seed) * 2 * 2) + 0}`)
			end

			Expect(`{Raw} internal {tostring(Record.Internal)}`).toBe(`{Raw} internal true`)
			Expect(`{Raw} rotation untouched {Record.Label.Rotation}`).toBe(`{Raw} rotation untouched 0`)
			Expect(`{Raw} color untouched {tostring(Record.Label.TextColor3 == WHITE)}`).toBe(`{Raw} color untouched true`)
		end
	end)

	It("built-in stack layers", function()
		Target.Text = [[<wave amplitude="3" frequency="2"><shake amplitude="1" frequency="5">both</shake></wave>]]
		Renderer:Flush()
		Tick(Renderer, 4)

		Both = Moving(Renderer)
		Now = Renderer.Animation.Clock

		Expect(Both.Layers).toBe(2)
	end)

	It("built-in stack stays internal", function()
		Expect(Both.Internal).toBe(true)
	end)

	It("built-in stack x adds", function()
		Expect(Both.Label.Position.X.Offset + 0).toBe(Pixel.Truncate(Both.X + math.noise(Both.Seed, Now * 5) * 1 * 2) + 0)
	end)

	It("built-in stack y adds", function()
		Expect(Both.Label.Position.Y.Offset + 0).toBe(Pixel.Truncate(Both.Y + (math.noise(Now * 5, Both.Seed) * 1 * 2 + math.sin(Now * 2 + Both.Seed) * 3)) + 0)
	end)

	It("built-in wave definition", function()
		Expect(Effect.Definitions.Wave.Kind).toBe("Effect")
	end)

	It("built-in shake definition", function()
		Expect(Effect.Definitions.Shake.Kind).toBe("Effect")
	end)
end)
