--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Layout = require("../Packages/RichTextPlus/Core/Layout")
const Lines = require("../Packages/RichTextPlus/Core/Lines")
const Scale = require("../Packages/RichTextPlus/Core/Scale")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Styles = require("../Packages/RichTextPlus/Utility/Styles")
const Culling = require("../Packages/RichTextPlus/Render/Culling")
const Gradient = require("../Packages/RichTextPlus/Classes/Gradient")
const Effect = require("../Packages/RichTextPlus/Classes/Effect")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Totals = { New: number, Reference: number, Mismatch: number, RunMismatch: number, Messages: { string } }

const Vocabulary: { string } = {
	"the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog", "arena", "traveler", "welcome", "to",
	"scaled", "label", "extraordinarily", "a", "I", "rich", "text", "plus", "wrapping", "numbers", "12345",
	"supercalifragilistic", "ok", "go", "Play", "Settings", "inventory", "legendary", "sword", "of", "fire",
}

const Uniform: { { string } } = {
	{"<b>", "</b>"},
	{"<i>", "</i>"},
	{"<u>", "</u>"},
	{"<s>", "</s>"},
	{"<code>", "</code>"},
	{"<mark color=\"#ff0\">", "</mark>"},
	{"<stroke color=\"#000\" thickness=\"2\">", "</stroke>"},
	{"<sc>", "</sc>"},
	{"<wave>", "</wave>"},
}

const Mixed: { { string } } = {
	{"<font size=\"30\">", "</font>"},
	{"<font size=\"11\">", "</font>"},
	{"<font size=\"48\">", "</font>"},
	{"<b>", "</b>"},
	{"<sc>", "</sc>"},
}

const Library: any = RichTextPlus
const LineModule: any = Lines
const MeasureModule: any = Measure
const RawCompute: any = LineModule.Compute
const RawRun: any = MeasureModule.Run
const Counts = {Compute = 0, Run = 0}
local Screen: ScreenGui

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

const function Create(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):Flush()
end

const function Counting(Body: () -> ()): ()
	LineModule.Compute = function(...: any): ...any
		Counts.Compute += 1
		return RawCompute(...)
	end
	MeasureModule.Run = function(...: any): boolean
		Counts.Run += 1
		return RawRun(...)
	end

	const Ok: boolean, Error: any = pcall(Body)

	LineModule.Compute = RawCompute
	MeasureModule.Run = RawRun

	if not Ok then error(Error, 0) end
end

const function Reference(State: any): ()
	const Target: TextLabel = State.Label
	const Size: Vector2 = Styles.ContentSize(Target)
	const BoxWidth: number = math.max(Size.X, Styles.MinimumBoxWidth)
	const BoxHeight: number = math.max(Size.Y, 8)
	const BaseSize: number = Styles.BaseSize(State)
	const MaxWidth: number = if Target.TextWrapped then BoxWidth else math.huge
	const High: number = math.max(math.min(BoxHeight, Styles.MaximumTextSize) / BaseSize, 0.05)
	const Floor: number = math.max((State.Limits.TextSize.Min or 0) / BaseSize, 0.05)

	const function Fits(Ratio: number): boolean
		const _Lines: any, _Heights: any, Total: number, Widest: number = LineModule.Compute(State, MaxWidth, Ratio)
		return Total <= BoxHeight and Widest <= BoxWidth
	end

	const function Search(): number
		const Current: number = State.Scale.Measured
		local Low: number = 0.05
		local Top: number = High

		for _ = 1, 14 do
			const Middle: number = (Low + Top) / 2
			if Fits(Middle / Current) then Low = Middle else Top = Middle end
		end

		return math.max(Low, Floor)
	end

	local Factor: number = Search()

	for Step = 1, 3 do
		if State.Scale.Measured ~= Factor then MeasureModule.Run(State, Factor) end
		if Step == 3 then break end

		const Next: number = Search()
		if Measure.Scaled(BaseSize, Next) == Measure.Scaled(BaseSize, Factor) then break end

		Factor = Next
	end

	for _ = 1, 8 do
		if Factor <= Floor or Fits(1) then break end

		Factor = math.max((Measure.Scaled(BaseSize, Factor) - 1) / BaseSize, Floor)
		MeasureModule.Run(State, Factor)
	end

	State.Scale.Factor = Factor
end

const function Markup(Rng: Random, Varied: boolean): string
	const Openers: { { string } } = if Varied then Mixed else Uniform
	const Parts: { string } = {}

	for _ = 1, Rng:NextInteger(1, 26) do
		local Word: string = Vocabulary[Rng:NextInteger(1, #Vocabulary)]
		const Roll: number = Rng:NextNumber()

		if Roll < 0.3 then
			const Pair: { string } = Openers[Rng:NextInteger(1, #Openers)]
			Word = Pair[1] .. Word .. Pair[2]
		elseif Roll < 0.36 then
			Word ..= "<br/>"
		elseif Varied and Roll < 0.42 then
			Word = `<img src="rbxassetid://1" size="{Rng:NextInteger(8, 40)}"/>`
		end

		table.insert(Parts, Word)
	end

	return table.concat(Parts, " ")
end

const function Equivalence(Name: string, Seed: number, Cases: number, Sizes: number, Varied: boolean): Totals
	const Rng: Random = Random.new(Seed)
	const Result: Totals = {Reference = 0, New = 0, Mismatch = 0, RunMismatch = 0, Messages = {}}

	for Case = 1, Cases do
		const Text: string = if Case == 1 then "Play" elseif Case == 2 then "Single line unwrapped label with several words" else Markup(Rng, Varied)
		const Target: TextLabel = Label(Text, 200, 60)
		Target.TextWrapped = Case > 2 and Rng:NextNumber() < 0.75
		Target.TextSize = ({14, 18, 24})[Rng:NextInteger(1, 3)]
		Target.LineHeight = ({1, 1.15, 0.9})[Rng:NextInteger(1, 3)]
		Target.TextScaled = true

		if Rng:NextNumber() < 0.25 then
			const Padding: UIPadding = Instance.new("UIPadding")
			Padding.PaddingLeft = UDim.new(0, Rng:NextInteger(0, 12))
			Padding.PaddingTop = UDim.new(0, Rng:NextInteger(0, 8))
			Padding.Parent = Target
		end

		const Renderer: any = Create(Target):SetScale(if Rng:NextNumber() < 0.2 then 1.25 else 1):Flush()
		local Start: number = Renderer.Scale.Factor

		for _ = 1, Sizes do
			Renderer.Host.Echoes.AbsoluteSize = (Renderer.Host.Echoes.AbsoluteSize or 0) + 1
			Renderer.Host.Echoes.Size = (Renderer.Host.Echoes.Size or 0) + 1
			Target.Size = UDim2.fromOffset(Rng:NextInteger(40, 520), Rng:NextInteger(12, 300))
			const _Absolute: Vector2 = Target.AbsoluteSize

			RawRun(Renderer, Start)
			Renderer.Scale.Factor = Start
			Counts.Compute = 0
			Counts.Run = 0
			Counting(function() Reference(Renderer) end)

			const Expected: number = Renderer.Scale.Factor
			const ExpectedRuns: number = Counts.Run
			Result.Reference += Counts.Compute

			RawRun(Renderer, Start)
			Renderer.Scale.Factor = Start
			Counts.Compute = 0
			Counts.Run = 0
			Counting(function() Scale.Solve(Renderer) end)

			Result.New += Counts.Compute

			if Renderer.Scale.Factor ~= Expected then
				Result.Mismatch += 1
				table.insert(Result.Messages, `{Name} factor mismatch case {Case} {Target.Size}: expected {Expected}, got {Renderer.Scale.Factor} text {Text}`)
			end

			if Counts.Run ~= ExpectedRuns then Result.RunMismatch += 1 end

			Start = Renderer.Scale.Factor
		end

		Renderer:Destroy()
		Target:Destroy()
	end

	return Result
end

const function Spy(Records: { any }): () -> number
	local Count: number = 0
	const Originals: { [any]: any } = {}

	for _, Record: any in Records do
		const Real: any = Record.Instance
		Originals[Record] = Real

		Record.Instance = setmetatable({}, {
			__index = function(_Proxy: any, Key: string): any
				return Real[Key]
			end,
			__newindex = function(_Proxy: any, Key: string, Value: any): ()
				if Key == "Position" then Count += 1 end
				Real[Key] = Value
			end,
		})
	end

	return function(): number
		for Record: any, Real: any in Originals do Record.Instance = Real end

		return Count
	end
end

BeforeAll(function()
	Screen = Gui.new("ScaleFx")
end)

AfterAll(function()
	LineModule.Compute = RawCompute
	MeasureModule.Run = RawRun
	Gui.Cleanup()
end)

Describe("scale equivalence uniform", function()
	local Result: Totals

	BeforeAll(function()
		Result = Equivalence("uniform", 20260924, 24, 10, false)
	end)

	It("uniform factor identical to reference", function()
		Expect(table.concat(Result.Messages, "\n")).toBe("")
	end)

	It("uniform measure passes identical to reference", function()
		Expect(Result.RunMismatch).toBe(0)
	end)

	It("uniform solver cuts line passes by half", function()
		Expect(Result.New * 2).toBeLessThanOrEqual(Result.Reference)
	end)
end)

Describe("scale equivalence mixed", function()
	local Result: Totals

	BeforeAll(function()
		Result = Equivalence("mixed", 424242, 12, 6, true)
	end)

	It("mixed factor identical to reference", function()
		Expect(table.concat(Result.Messages, "\n")).toBe("")
	end)

	It("mixed measure passes identical to reference", function()
		Expect(Result.RunMismatch).toBe(0)
	end)

	It("mixed solver never costs more", function()
		Expect(Result.New).toBeLessThanOrEqual(Result.Reference)
	end)
end)

Describe("scale unscaled label", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("not scaled", 200, 40)
		Renderer = Create(Target)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("unscaled factor one", function()
		Expect(Renderer.Scale.Factor).toBe(1)
	end)

	It("unscaled measured one", function()
		Expect(Renderer.Scale.Measured).toBe(1)
	end)
end)

Describe("effect offsets", function()
	const Wave: any = {Time = 1.3, Seed = 0.4, Amplitude = 2.5, Frequency = 6}
	const Shake: any = {Time = 0.7, Seed = 2.2, Amplitude = 1.2, Frequency = 11}

	BeforeAll(function()
		Effect.Definitions.Wave.Update(Wave)
		Effect.Definitions.Shake.Update(Shake)
	end)

	It("wave offset x", function()
		Expect(Wave.Offset.X).toBe(0)
	end)

	It("wave offset y", function()
		Expect(math.abs(Wave.Offset.Y - math.sin(1.3 * 6 + 0.4) * 2.5)).toBeLessThan(1e-5)
	end)

	It("shake offset x", function()
		Expect(math.abs(Shake.Offset.X - math.noise(2.2, 0.7 * 11) * 1.2 * 2)).toBeLessThan(1e-5)
	end)

	It("shake offset y", function()
		Expect(math.abs(Shake.Offset.Y - math.noise(0.7 * 11, 2.2) * 1.2 * 2)).toBeLessThan(1e-5)
	end)
end)

Describe("effect writes", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("<wave>a</wave> <wave>b</wave> <shake>c</shake> still", 400, 60)
		Renderer = Create(Target)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("three moving", function()
		Expect(#Renderer.Animation.Moving).toBe(3)
	end)

	It("moving offsets integral and within amplitude", function()
		for _ = 1, 3 do Driver.Tick(Renderer, 0.05) end

		for Index: number, Record: any in Renderer.Animation.Moving do
			const Position: UDim2 = Record.Instance.Position
			const Integral: boolean = Position.X.Offset == math.floor(Position.X.Offset) and Position.Y.Offset == math.floor(Position.Y.Offset)

			Expect(`{Index} integral {tostring(Integral)}`).toBe(`{Index} integral true`)
			Expect(`{Index} within amplitude {tostring(math.abs(Position.Y.Offset - Record.Y) <= 4)}`).toBe(`{Index} within amplitude true`)
		end
	end)

	It("no writes while clock is frozen", function()
		const Finish: () -> number = Spy(Renderer.Animation.Moving)
		for _ = 1, 10 do Driver.Tick(Renderer, 0) end

		Expect(Finish()).toBe(0)
	end)

	It("wave still moves", function()
		local Moved: boolean = false
		const Before: number = Renderer.Animation.Moving[1].Instance.Position.Y.Offset
		for _ = 1, 20 do
			Driver.Tick(Renderer, 1 / 60)
			if Renderer.Animation.Moving[1].Instance.Position.Y.Offset ~= Before then Moved = true end
		end

		Expect(Moved).toBe(true)
	end)
end)

Describe("effect truncation matches udim", function()
	local Target: TextLabel
	local Renderer: any
	local Position: UDim2
	local Legacy: UDim2

	BeforeAll(function()
		Target = Label("<customclass><drift>d</drift></customclass>", 400, 60)
		Renderer = Create(Target):AddCustomClasses({drift = {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(-1.6, 2.7) end}}):Flush()
		Driver.Tick(Renderer, 0.016)

		const Record: any = Renderer.Animation.Moving[1]
		Position = Record.Instance.Position
		Legacy = UDim2.fromOffset(Record.X - 1.6, Record.Y + 2.7)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("custom x like legacy udim", function()
		Expect(Position.X.Offset).toBe(Legacy.X.Offset)
	end)

	It("custom y like legacy udim", function()
		Expect(Position.Y.Offset).toBe(Legacy.Y.Offset)
	end)
end)

Describe("effect survives relayout", function()
	local Target: TextLabel
	local Renderer: any
	local Moved: any
	local Centered: any

	BeforeAll(function()
		Target = Label("<customclass><lift>up</lift></customclass> plain", 400, 60)
		Renderer = Create(Target):AddCustomClasses({lift = {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(0, 7) end}}):Flush()
		Driver.Tick(Renderer, 0.016)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("constant effect applied", function()
		const Record: any = Renderer.Animation.Moving[1]

		Expect(Record.Instance.Position.Y.Offset).toBe(Record.Y + 7)
	end)

	It("relayout writes base", function()
		const Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.Parent = Target
		Renderer.Decoration.Dirty = true
		Layout.Run(Renderer)
		Moved = Renderer.Animation.Moving[1]

		Expect(Moved.Instance.Position.Y.Offset).toBe(Moved.Y)
	end)

	It("constant effect restored after restyle", function()
		Driver.Tick(Renderer, 0.016)

		Expect(Moved.Instance.Position.Y.Offset).toBe(Moved.Y + 7)
	end)

	It("constant effect restored after move", function()
		Target.TextXAlignment = Enum.TextXAlignment.Center
		Renderer:Flush()
		Driver.Tick(Renderer, 0.016)
		Centered = Renderer.Animation.Moving[1]

		Expect(Centered.Instance.Position.Y.Offset).toBe(Centered.Y + 7)
	end)

	It("constant effect follows new x", function()
		Expect(Centered.Instance.Position.X.Offset).toBe(math.floor(Centered.X))
	end)
end)

Describe("hidden labels skip work", function()
	Describe("hidden ancestors", function()
		local Holder: Frame
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Holder = Instance.new("Frame")
			Holder.Size = UDim2.fromOffset(400, 100)
			Holder.Parent = Screen

			Target = Label("<wave>a</wave> <wave>b</wave>", 400, 60, Holder)
			Renderer = Create(Target)
			Driver.Tick(Renderer, 0.016)
		end)

		AfterAll(function()
			Renderer:Destroy()
			Holder:Destroy()
		end)

		It("visible label busy", function()
			Expect((Driver.Tick(Renderer, 0.016))).toBe(true)
		end)

		It("hidden parent sleeps", function()
			Holder.Visible = false
			task.wait()

			Expect((Driver.Tick(Renderer, 0.016))).toBe(false)
		end)

		It("hidden parent no writes", function()
			const Finish: () -> number = Spy(Renderer.Animation.Moving)
			for _ = 1, 5 do Driver.Tick(Renderer, 0.05) end

			Expect(Finish()).toBe(0)
		end)

		It("hidden label sleeps", function()
			Holder.Visible = true
			Target.Visible = false
			task.wait()

			Expect((Driver.Tick(Renderer, 0.016))).toBe(false)
		end)

		It("shown label wakes", function()
			Target.Visible = true
			task.wait()

			Expect((Driver.Tick(Renderer, 0.016))).toBe(true)
		end)
	end)

	It("transparent label no writes", function()
		const Faded: TextLabel = Label("<wave>a</wave> <wave>b</wave>", 400, 60)
		Faded.TextTransparency = 1
		const FadedRenderer: any = Create(Faded)
		Driver.Tick(FadedRenderer, 0.016)

		const Silent: () -> number = Spy(FadedRenderer.Animation.Moving)
		for _ = 1, 5 do Driver.Tick(FadedRenderer, 0.05) end
		const Writes: number = Silent()

		FadedRenderer:Destroy()
		Faded:Destroy()

		Expect(Writes).toBe(0)
	end)
end)

Describe("far surface throttles", function()
	local Camera: Camera
	local Part: Part
	local Renderer: any

	BeforeAll(function()
		Camera = workspace.CurrentCamera
		Part = Instance.new("Part")
		Part.Anchored = true
		Part.Size = Vector3.new(8, 5, 1)
		Part.CFrame = CFrame.lookAt((Camera.CFrame * CFrame.new(0, 0, -400)).Position, Camera.CFrame.Position)
		Part.Parent = workspace

		const Surface: SurfaceGui = Instance.new("SurfaceGui")
		Surface.Parent = Part

		Renderer = Create(Label("<wave>far</wave> <shake>away</shake>", 300, 100, Surface))
		Driver.Tick(Renderer, 0.016)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Part:Destroy()
	end)

	It("far surface apparent scale small", function()
		Expect(Culling.Apparent(Renderer)).toBeLessThan(0.2)
	end)

	It("far surface invisible motion skipped", function()
		const Finish: () -> number = Spy(Renderer.Animation.Moving)
		for _ = 1, 30 do Driver.Tick(Renderer, 1 / 60) end

		Expect(Finish()).toBe(0)
	end)

	It("near surface apparent scale large", function()
		Part.CFrame = CFrame.lookAt((Camera.CFrame * CFrame.new(0, 0, -4)).Position, Camera.CFrame.Position)
		for _ = 1, 20 do Driver.Tick(Renderer, 1 / 60) end

		Expect(Culling.Apparent(Renderer)).toBeGreaterThan(0.2)
	end)

	It("near surface moves", function()
		const Near: () -> number = Spy(Renderer.Animation.Moving)
		for _ = 1, 30 do Driver.Tick(Renderer, 1 / 60) end

		Expect(Near()).toBeGreaterThan(0)
	end)

	It("behind camera apparent zero", function()
		Part.CFrame = Camera.CFrame * CFrame.new(0, 0, 400)

		Expect(Culling.Apparent(Renderer)).toBe(0)
	end)

	It("screen gui apparent scale one", function()
		const Flat: TextLabel = Label("screen", 100, 40)
		const ScreenRenderer: any = Create(Flat)
		Driver.Tick(ScreenRenderer, 0.016)
		const Apparent: number = Culling.Apparent(ScreenRenderer)

		ScreenRenderer:Destroy()
		Flat:Destroy()

		Expect(Apparent).toBe(1)
	end)
end)

Describe("gradient loop", function()
	const Node: any = {TagType = "gradient", Attributes = {{Name = "colors", Value = "#ff0000,#00ff00,#0000ff"}, {Name = "speed", Value = "1"}}, Children = {}}
	local Data: any
	local Target: TextLabel
	local Renderer: any
	local Record: any

	BeforeAll(function()
		Data = Gradient.Parse(Node)
		Target = Label([[<gradient colors="#ff0000,#0000ff" speed="1">shiny</gradient>]], 300, 60)
		Renderer = Create(Target)
		Record = Renderer.Animation.Animated[1]
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("gradient parsed", function()
		Expect(Data).never.toBeNil()
	end)

	It("gradient frames", function()
		Expect(Gradient.Frames).toBe(60)
	end)

	It("gradient frame cached", function()
		Expect(Gradient.Loop(Data, 5) == Gradient.Loop(Data, 5)).toBe(true)
	end)

	It("gradient frames differ", function()
		Expect(Gradient.Loop(Data, 5) ~= Gradient.Loop(Data, 6)).toBe(true)
	end)

	It("gradient keypoints", function()
		Expect(#Gradient.Loop(Data, 0).Keypoints).toBe(13)
	end)

	It("gradient loop starts at first color", function()
		Expect(Gradient.Loop(Data, 0).Keypoints[1].Value == Color3.fromRGB(255, 0, 0)).toBe(true)
	end)

	It("animated gradient advances", function()
		Driver.Tick(Renderer, 0.05)
		const First: ColorSequence = Record.Decor.Gradient.Color
		Driver.Tick(Renderer, 0.05)

		Expect(Record.Decor.Gradient.Color ~= First).toBe(true)
	end)

	It("hidden gradient frozen", function()
		Target.Visible = false
		Renderer.Cull.Dirty = true
		Driver.Tick(Renderer, 0.016)
		const Frozen: ColorSequence = Record.Decor.Gradient.Color
		for _ = 1, 5 do Driver.Tick(Renderer, 0.05) end

		Expect(Record.Decor.Gradient.Color == Frozen).toBe(true)
	end)
end)
