--!strict

const TextService = game:GetService("TextService")

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const XML = require("../Packages/XML")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Styles = require("../Packages/RichTextPlus/Utility/Styles")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Layout = require("../Packages/RichTextPlus/Core/Layout")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
const Reflow = require("../Packages/RichTextPlus/Utility/Reflow")
const CodeBlock = require("../Packages/RichTextPlus/Classes/CodeBlock")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const LayoutModule: any = Layout
const Parser: any = XML

const Filler: string = "the quick brown fox jumps over the lazy dog while the text keeps going for a while"
const Mono: string = "rbxasset://fonts/families/RobotoMono.json"
const White: Color3 = Color3.new(1, 1, 1)

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
	Created.TextColor3 = White
	Created.BackgroundTransparency = 1
	Created.Text = Text
	Created.Parent = Parent or Screen

	return Created
end

const function Holder(Scale: number, Clips: boolean?): (Frame, UIScale)
	const Frame: Frame = Instance.new("Frame")
	Frame.Size = UDim2.fromOffset(800, 800)
	Frame.BackgroundTransparency = 1
	Frame.ClipsDescendants = Clips == true
	Frame.Parent = Screen

	const Scaler: UIScale = Instance.new("UIScale")
	Scaler.Scale = Scale
	Scaler.Parent = Frame

	return Frame, Scaler
end

const function Segments(Target: Instance): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" then table.insert(Found, Child :: TextLabel) end
	end

	table.sort(Found, function(Left: TextLabel, Right: TextLabel): boolean
		if Left.Position.Y.Offset ~= Right.Position.Y.Offset then return Left.Position.Y.Offset < Right.Position.Y.Offset end

		return Left.Position.X.Offset < Right.Position.X.Offset
	end)

	return Found
end

const function Plain(Text: string): string
	return Parser.Unescape((string.gsub(Text, "<[^>]*>", "")))
end

const function Letters(Length: number, Seed: number): string
	const Rng: Random = Random.new(Seed)
	const Parts: { string } = table.create(Length)

	for Index = 1, Length do Parts[Index] = string.char(Rng:NextInteger(97, 122)) end

	return table.concat(Parts)
end

const function CodeStyle(Size: number): any
	return {Bold = false, Italic = false, Underline = false, Strike = false, Color = White, Size = Size, Family = Mono, Transparency = 0}
end

const function Node(Markup: string): any
	return Parser:GenerateTreeFromXML(Markup).Children[1]
end

const function CodeBody(Built: Frame): TextLabel
	return (Built:FindFirstChild("Panel") :: Frame):FindFirstChild("Code") :: TextLabel
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("FixLayout")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("ancestor scale", function()
	AfterAll(Release)

	It("nested ancestor scale", function()
		const Outer: Frame = Holder(0.5)
		const Inner: Frame = Instance.new("Frame")
		Inner.Parent = Outer

		const InnerScale: UIScale = Instance.new("UIScale")
		InnerScale.Scale = 3
		InnerScale.Parent = Inner

		const Target: TextLabel = Label("x", 100, 20, Inner)
		const Own: UIScale = Instance.new("UIScale")
		Own.Scale = 2
		Own.Parent = Target

		Expect(math.abs(Styles.AncestorScale(Target) - 3)).toBeLessThanOrEqual(1e-9)
	end)

	It("unscaled ancestor scale", function()
		Expect(Styles.AncestorScale(Label("y", 10, 10))).toBe(1)
	end)
end)

Describe("uiscale layout", function()
	AfterAll(Release)

	const Text: string = `{Filler} <mark color="#806000">marked words</mark> {Filler}`
	local Scaler: UIScale
	local Target: TextLabel
	local Renderer: any
	local Expected: { TextLabel }
	local Actual: { TextLabel }

	BeforeAll(function()
		const Reference: TextLabel = Label(Text, 240, 400)
		Build(Reference)

		local Frame: Frame
		Frame, Scaler = Holder(0.5)
		Target = Label(Text, 240, 400, Frame)
		Renderer = Build(Target)

		Expected = Segments(Reference)
		Actual = Segments(Target)
	end)

	It("uiscale segment count", function()
		Expect(#Actual).toBe(#Expected)
	end)

	It("uiscale local width", function()
		Expect(math.abs(Renderer.Host.Width - 240)).toBeLessThanOrEqual(0.01)
	end)

	It("uiscale state scale", function()
		Expect(Renderer.Scale.Ancestor).toBe(0.5)
	end)

	It("uiscale text and position per segment", function()
		for Index: number, Segment: TextLabel in Expected do
			const Other: TextLabel? = Actual[Index]
			if not Other then break end

			Expect(Other.Text).toBe(Segment.Text)
			Expect(Other.Position).toBe(Segment.Position)
		end
	end)

	Describe("scale change", function()
		local Layouts: number = 0

		BeforeAll(function()
			const RawRun: any = LayoutModule.Run

			LayoutModule.Run = function(...: any): ()
				Layouts += 1

				return RawRun(...)
			end

			const Ok: boolean, Error: any = pcall(function()
				Scaler.Scale = 0.8
				const _Size: Vector2 = Target.AbsoluteSize
				task.wait()
				Renderer:Flush()
			end)

			LayoutModule.Run = RawRun
			if not Ok then error(Error, 0) end
		end)

		It("uiscale change skips relayout", function()
			Expect(Layouts).toBe(0)
		end)

		It("uiscale change tracked", function()
			Expect(math.abs(Renderer.Scale.Ancestor - 0.8)).toBeLessThanOrEqual(1e-6)
		end)
	end)
end)

Describe("uiscale text scaled", function()
	AfterAll(Release)

	local Frame: Frame

	BeforeAll(function()
		Frame = Holder(0.5)
	end)

	It("uiscale scaled text size", function()
		const Reference: TextLabel = Label("Play the scaled words", 220, 70)
		Reference.TextScaled = true
		const Baseline: any = Build(Reference)

		const Target: TextLabel = Label("Play the scaled words", 220, 70, Frame)
		Target.TextScaled = true
		const Renderer: any = Build(Target)

		Expect(Measure.Scaled(18, Renderer.Scale.Factor)).toBe(Measure.Scaled(18, Baseline.Scale.Factor))
	end)

	It("uiscale frozen size local", function()
		const Frozen: TextLabel = Label("hi", 200, 60, Frame)
		Frozen.TextScaled = true
		Frozen.AutomaticSize = Enum.AutomaticSize.X
		Build(Frozen)

		Expect(Frozen.Size).toBe(UDim2.fromOffset(200, 60))
	end)
end)

Describe("uiscale culling", function()
	AfterAll(Release)

	local Target: TextLabel
	local Near: number = 0
	local Far: number = 0

	BeforeAll(function()
		const Frame: Frame = Holder(0.5, true)
		Frame.Size = UDim2.fromOffset(400, 100)

		Target = Label(string.rep(Filler .. " ", 6), 400, 1200, Frame)
		Driver.Tick(Build(Target), 1 / 60)
	end)

	It("uiscale culling keeps near rows and hides far rows", function()
		for _, Segment: TextLabel in Segments(Target) do
			const Y: number = Segment.Position.Y.Offset

			if Y + Segment.Size.Y.Offset <= 90 then
				Near += 1
				Expect(`row {Y} visible {Segment.Visible}`).toBe(`row {Y} visible true`)
			elseif Y >= 130 then
				Far += 1
				Expect(`row {Y} visible {Segment.Visible}`).toBe(`row {Y} visible false`)
			end
		end
	end)

	It("uiscale culling saw near rows", function()
		Expect(Near).toBeGreaterThan(0)
	end)

	It("uiscale culling saw far rows", function()
		Expect(Far).toBeGreaterThan(0)
	end)
end)

Describe("clippers restack", function()
	AfterAll(Release)

	local Box: Frame
	local Target: TextLabel
	local Renderer: any

	const function Hidden(): (number, number)
		local Low: number, High: number = 0, 0

		for _, Segment: TextLabel in Segments(Target) do
			if Segment.Visible then continue end

			const Y: number = Segment.Position.Y.Offset

			if Y >= 70 then High += 1 elseif Y + Segment.Size.Y.Offset <= 60 then Low += 1 end
		end

		return Low, High
	end

	BeforeAll(function()
		Box = Instance.new("Frame")
		Box.Size = UDim2.fromOffset(300, 60)
		Box.BackgroundTransparency = 1
		Box.Parent = Screen

		Target = Label(string.rep(Filler .. " ", 4), 300, 600, Box)
		Renderer = Build(Target)
		Driver.Tick(Renderer, 1 / 60)
	end)

	It("unclipped nothing hidden", function()
		const Low: number, High: number = Hidden()

		Expect(Low + High).toBe(0)
	end)

	Describe("clipped", function()
		local Low: number
		local High: number

		BeforeAll(function()
			Box.ClipsDescendants = true
			task.wait()
			Driver.Tick(Renderer, 1 / 60)
			Low, High = Hidden()
		end)

		It("clip keeps visible rows", function()
			Expect(Low).toBe(0)
		end)

		It("clip hides rows below", function()
			Expect(High).toBeGreaterThan(0)
		end)
	end)

	It("unclip shows rows again", function()
		Box.ClipsDescendants = false
		task.wait()
		Driver.Tick(Renderer, 1 / 60)
		const Low: number, High: number = Hidden()

		Expect(Low + High).toBe(0)
	end)
end)

Describe("zindex", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	const function Audit(Depth: number): number
		local Seen: number = 0

		for _, Child: Instance in Target:GetDescendants() do
			if not Child:IsA("GuiObject") then continue end

			Seen += 1
			Expect(`{Child.Name} {(Child :: GuiObject).ZIndex}`).toBe(`{Child.Name} {if Child.Name == "Dot" then Depth + 2 else Depth}`)
		end

		return Seen
	end

	BeforeAll(function()
		Target = Label(`plain <mark color="#806000">marked</mark> <a href="x">link</a> <customclass name="badge"/><br/><codeblock lang="lua">local x = 1</codeblock>`, 400, 300)
		Target.ZIndex = 5

		Renderer = Build(Target):AddCustomClasses({badge = {Kind = "Object", Build = function(): GuiObject
			const Badge: Frame = Instance.new("Frame")
			Badge.Name = "Badge"
			Badge.Size = UDim2.fromOffset(12, 12)

			const Dot: Frame = Instance.new("Frame")
			Dot.Name = "Dot"
			Dot.ZIndex = 3
			Dot.Parent = Badge

			return Badge
		end}}):Flush()
	end)

	It("zindex has backdrop", function()
		Expect(Target:FindFirstChild("Backdrops")).never.toBeNil()
	end)

	It("zindex has code block", function()
		Expect(Target:FindFirstChild("CodeBlock")).never.toBeNil()
	end)

	It("zindex has badge", function()
		Expect(Target:FindFirstChild("Badge")).never.toBeNil()
	end)

	for _, Depth: number in {5, 7} do
		Describe(`depth {Depth}`, function()
			local Seen: number = 0

			BeforeAll(function()
				if Target.ZIndex ~= Depth then
					Target.ZIndex = Depth
					task.wait()
				end
			end)

			It(`zindex {Depth} per descendant`, function()
				Seen = Audit(Depth)
			end)

			It(`zindex {Depth} audited`, function()
				Expect(Seen).toBeGreaterThanOrEqual(8)
			end)
		end)
	end

	It("pooled segment restamped", function()
		Renderer:Destroy()

		const Reused: TextLabel = Label("pooled <b>again</b>", 300, 100)
		Reused.ZIndex = 2
		Build(Reused)

		for _, Segment: TextLabel in Segments(Reused) do Expect(Segment.ZIndex).toBe(2) end
	end)
end)

Describe("text size constraint", function()
	AfterAll(Release)

	Describe("capped", function()
		local Capped: TextLabel
		local Renderer: any
		local Constraint: UITextSizeConstraint

		BeforeAll(function()
			Capped = Label("Play", 300, 200)
			Capped.TextScaled = true
			Capped.TextSize = 14

			Constraint = Instance.new("UITextSizeConstraint")
			Constraint.MaxTextSize = 20
			Constraint.Parent = Capped

			Renderer = Build(Capped)
		end)

		It("constraint caps text", function()
			for _, Segment: TextLabel in Segments(Capped) do Expect(Segment.TextSize).toBeLessThanOrEqual(20) end
		end)

		It("constraint cap reached", function()
			Expect(Measure.Scaled(14, Renderer.Scale.Factor)).toBe(20)
		end)

		It("constraint change resolves", function()
			Constraint.MaxTextSize = 30
			task.wait()
			Renderer:Flush()

			for _, Segment: TextLabel in Segments(Capped) do Expect(Segment.TextSize).toBe(30) end
		end)

		It("constraint removal uncaps", function()
			Constraint:Destroy()
			task.wait()
			Renderer:Flush()

			for _, Segment: TextLabel in Segments(Capped) do Expect(Segment.TextSize).toBeGreaterThan(30) end
		end)
	end)

	Describe("floored", function()
		local Floored: TextLabel

		BeforeAll(function()
			Floored = Label(string.rep(Filler .. " ", 3), 200, 30)
			Floored.TextScaled = true
		end)

		It("constraint floors text", function()
			const Minimum: UITextSizeConstraint = Instance.new("UITextSizeConstraint")
			Minimum.MinTextSize = 14
			Minimum.Parent = Floored

			const Floor: any = Build(Floored)
			for _, Segment: TextLabel in Segments(Floored) do Expect(Segment.TextSize).toBeGreaterThanOrEqual(14) end

			Floor:Destroy()
			Minimum:Destroy()
		end)

		It("limits floor text", function()
			const Policy: any = Library.new(Floored):SetRendering("Passthrough", false):SetLimits({TextSize = {Min = 12}}):Flush()
			table.insert(Renderers, Policy)

			for _, Segment: TextLabel in Segments(Floored) do Expect(Segment.TextSize).toBeGreaterThanOrEqual(12) end

			Policy:Destroy()
		end)

		It("default policy floors at 8", function()
			Build(Floored)

			for _, Segment: TextLabel in Segments(Floored) do Expect(Segment.TextSize).toBeGreaterThanOrEqual(8) end
		end)
	end)
end)

Describe("container wrap", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	const function Wrappers(Name: string): ()
		local Boxed: number = 0

		for _, Segment: TextLabel in Segments(Target) do
			if not string.find(Segment.Text, "alpha", 1, true) then continue end

			Boxed += 1
			local Count: number = 0
			for _, Child: Instance in Segment:GetChildren() do if Child.Name == "Wrapper" then Count += 1 end end
			Expect(Count).toBe(1)
		end

		Expect(Boxed).toBeGreaterThan(0)
	end

	BeforeAll(function()
		Target = Label(`<customclass name="boxed">alpha beta</customclass> tail`, 400, 100)
		Renderer = Build(Target):AddCustomClasses({boxed = {Kind = "Container", Wrap = function(): GuiObject
			const Wrapper: Frame = Instance.new("Frame")
			Wrapper.Name = "Wrapper"

			return Wrapper
		end}}):Flush()
	end)

	It("container initial one wrapper and found boxed segment", function()
		Wrappers("container initial")
	end)

	for Round = 1, 3 do
		It(`container restyle {Round} one wrapper and found boxed segment`, function()
			const Gradient: UIGradient = Instance.new("UIGradient")
			Gradient.Parent = Target
			task.wait()
			Renderer:Flush()

			Wrappers(`container restyle {Round}`)
		end)
	end
end)

Describe("unrevealed links", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	const function Buttons(): { TextButton }
		const Found: { TextButton } = {}
		for _, Record: any in Renderer.Instances.Segments do if Record.Button then table.insert(Found, Record.Instance) end end

		return Found
	end

	BeforeAll(function()
		Target = Label(`intro words here <a href="x">click me</a> end`, 400, 100)
		Renderer = Build(Target)
	end)

	It("links present", function()
		Expect(#Buttons()).toBeGreaterThan(0)
	end)

	It("link interactable before the reveal", function()
		for _, Button: TextButton in Buttons() do Expect(Button.Interactable).toBe(true) end
	end)

	It("hidden link not interactable and not selectable", function()
		Target.MaxVisibleGraphemes = 2
		task.wait()

		for _, Button: TextButton in Buttons() do
			Expect(Button.Interactable).toBe(false)
			Expect(Button.Selectable).toBe(false)
		end
	end)

	It("revealed link interactable and selectable", function()
		Target.MaxVisibleGraphemes = -1
		task.wait()

		for _, Button: TextButton in Buttons() do
			Expect(Button.Interactable).toBe(true)
			Expect(Button.Selectable).toBe(true)
		end
	end)
end)

Describe("code block text scaled wrap", function()
	AfterAll(Release)

	local Renderer: any
	local Block: Frame?
	local Panel: Frame
	local Body: TextLabel
	local Padding: number
	local Lines: { string }

	BeforeAll(function()
		const Source: string = `local value = "{string.rep("abc ", 24)}"\nprint(value)`
		const Target: TextLabel = Label(`<codeblock lang="lua">{Parser.Escape(Source)}</codeblock>`, 240, 300)
		Target.TextScaled = true

		Renderer = Build(Target)
		Block = Target:FindFirstChild("CodeBlock") :: Frame?
		if not Block then return end

		Panel = (Block :: Frame):FindFirstChild("Panel") :: Frame
		Body = Panel:FindFirstChild("Code") :: TextLabel
		Padding = (Panel:FindFirstChildOfClass("UIPadding") :: UIPadding).PaddingLeft.Offset
		Lines = string.split(Plain(Body.Text), "\n")
	end)

	It("scaled code block present", function()
		Expect(Block).never.toBeNil()
	end)

	It("scaled code block within box", function()
		if not Block then return end
		Expect(Block.Size.X.Offset).toBeLessThanOrEqual(240)
	end)

	It("scaled code block wraps", function()
		if not Block then return end
		Expect(#Lines).toBeGreaterThan(2)
	end)

	It("scaled code text size", function()
		if not Block then return end
		Expect(Body.TextSize).toBe(Measure.Scaled(18, Renderer.Scale.Factor))
	end)

	It("scaled code block fits height", function()
		if not Block then return end
		Expect(Block.Position.Y.Offset + Block.Size.Y.Offset).toBeLessThanOrEqual(301)
	end)

	It("scaled panel matches block", function()
		if not Block then return end
		Expect(Panel.Size.Y.Offset + Panel.Position.Y.Offset * 2).toBe(Block.Size.Y.Offset)
	end)

	It("scaled code lines fit", function()
		if not Block then return end

		const Parameters: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
		Parameters.Font = Body.FontFace
		Parameters.Size = Body.TextSize
		Parameters.Width = 100000

		for _, Line: string in Lines do
			Parameters.Text = if Line == "" then " " else Line
			Expect(TextService:GetTextBoundsAsync(Parameters).X).toBeLessThanOrEqual(240 - Padding * 2 + 1)
		end
	end)
end)

Describe("code block unwraps", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Body: TextLabel

	BeforeAll(function()
		const Source: string = `local value = "{string.rep("abc ", 24)}"`
		Target = Label(`<codeblock lang="lua">{Parser.Escape(Source)}</codeblock>`, 240, 400)
		Renderer = Build(Target)
		Body = CodeBody(Target:FindFirstChild("CodeBlock") :: Frame)
	end)

	It("wrapped code has breaks", function()
		Expect(#string.split(Plain(Body.Text), "\n")).toBeGreaterThan(1)
	end)

	It("unwrapped code has no breaks", function()
		Target.TextWrapped = false
		task.wait()
		Renderer:Flush()

		Expect(#string.split(Plain(Body.Text), "\n")).toBe(1)
	end)
end)

Describe("code block measuring", function()
	AfterAll(Release)

	local Built: Frame
	local Body: TextLabel
	local Before: string
	local Size: Vector2

	BeforeAll(function()
		const Source: string = `local value = "{string.rep("abc ", 24)}"`
		Built = CodeBlock.Build(Node(`<codeblock lang="lua">{Parser.Escape(Source)}</codeblock>`), CodeStyle(16), 1, nil)
		Body = CodeBody(Built)
		Before = Body.Text
		Size = Reflow.Measure(Built, 160)
	end)

	AfterAll(function()
		Built:Destroy()
	end)

	It("measure has no side effects", function()
		Expect(Body.Text).toBe(Before)
	end)

	It("measure reports height", function()
		Expect(Size.Y).toBeGreaterThan(Built.Size.Y.Offset)
	end)

	It("apply writes wrapped text", function()
		Reflow.Apply(Built, 160)

		Expect(Body.Text).never.toBe(Before)
	end)

	It("code glyphs use shared cache", function()
		Expect(Measure.Cached(CodeStyle(16), 16, "M", false)).toBeTruthy()
	end)

	Describe("ideographs", function()
		const Ideographs: { string } = {}
		for Index = 0, 799 do table.insert(Ideographs, utf8.char(0x4E00 + Index * 7)) end

		BeforeAll(function()
			const Wide: Frame = CodeBlock.Build(Node(`<codeblock>{table.concat(Ideographs)}</codeblock>`), CodeStyle(16), 1, nil)
			Reflow.Height(Wide, 200)
			Wide:Destroy()
		end)

		It("ideographs measured once", function()
			Expect(Measure.Cached(CodeStyle(16), 16, "中", false)).toBeTruthy()
		end)

		It("ideographs not measured one by one", function()
			Expect(Measure.Cached(CodeStyle(16), 16, Ideographs[400], false)).toBeFalsy()
		end)
	end)
end)

Describe("untagged code plain", function()
	AfterAll(Release)

	const Built: { Frame } = {}

	const function Make(Markup: string, Options: any): Frame
		const Frame: Frame = CodeBlock.Build(Node(Markup), CodeStyle(16), 1, Options)
		table.insert(Built, Frame)

		return Frame
	end

	AfterAll(function()
		for _, Frame: Frame in Built do Frame:Destroy() end
	end)

	It("untagged not highlighted", function()
		Expect(CodeBody(Make("<codeblock>local x = 1</codeblock>", nil)).RichText).toBe(false)
	end)

	It("theme opts untagged in", function()
		const OptIn: Frame = Make("<codeblock>local x = 1</codeblock>", {Theme = {CodeLanguage = "luau"}, Intents = Library.Intents.Presets.Default, Rendering = {SyntaxHighlight = true}})

		Expect(CodeBody(OptIn).RichText).toBe(true)
	end)

	It("tagged language wins over theme", function()
		const Other: Frame = Make("<codeblock lang=\"json\">{}</codeblock>", {Theme = {CodeLanguage = "luau"}, Intents = Library.Intents.Presets.Default, Rendering = {SyntaxHighlight = true}})

		Expect(CodeBody(Other).RichText).toBe(false)
	end)

	It("markdown untagged fence plain", function()
		const Fence: TextLabel = Label("<md>```\nlocal x = 1\n```</md>", 300, 200)
		Build(Fence)
		const Block: Frame? = Fence:FindFirstChild("CodeBlock") :: Frame?

		Expect(Block ~= nil and not CodeBody(Block :: Frame).RichText).toBe(true)
	end)
end)

Describe("pool signature buckets", function()
	AfterAll(Release)

	const function Colored(Count: number): string
		const Parts: { string } = table.create(Count)

		for Index = 1, Count do
			Parts[Index] = `<font color="rgb({Index % 256},{(Index // 256) % 256},{(Index * 7) % 256})">w{Index}</font>`
		end

		return table.concat(Parts, " ")
	end

	const function Twins(Count: number): boolean
		const Target: TextLabel = Label(Colored(Count), 6000, 4000)
		Target.TextWrapped = false

		const Renderer: any = Build(Target):SetRendering("Culling", false):Flush()
		const Runs: { any } = {}
		const Owned: { [any]: boolean } = {}

		for Index: number, Record: any in Renderer.Instances.Segments do
			Owned[Record] = true
			Runs[#Renderer.Instances.Segments - Index + 1] = {Style = Styles.Clone(Record.Style), Text = Record.Content.Raw, X = Record.X, Y = Record.Y, Width = Record.Width, Height = Record.Height}
		end

		const Assigned: { any } = Pool.Assign(Renderer, Runs)
		local Matched: boolean = #Runs == Count

		for Index: number, Run: any in Runs do
			const Record: any = Assigned[Index]
			if not (Record and Owned[Record] and Record.Style.Color == Run.Style.Color) then Matched = false end
		end

		Renderer:Destroy()
		Target:Destroy()

		return Matched
	end

	It("assign reuses twins small", function()
		Expect(Twins(300)).toBe(true)
	end)

	It("assign reuses twins large", function()
		Expect(Twins(2400)).toBe(true)
	end)
end)

Describe("segments skip localization", function()
	AfterAll(Release)

	It("segment AutoLocalize off", function()
		const Target: TextLabel = Label("localize <b>me</b> <a href=\"x\">not</a>", 300, 100)
		Build(Target)

		for _, Segment: TextLabel in Segments(Target) do Expect(Segment.AutoLocalize).toBe(false) end
	end)
end)

Describe("measure cache generations", function()
	AfterAll(Release)

	const Style: any = {Bold = false, Italic = false, Underline = false, Strike = false, Color = White, Size = 17, Family = "rbxasset://fonts/families/Oswald.json", Transparency = 0}
	local Limit: number
	local Survived: number = 0

	BeforeAll(function()
		Limit = Measure.CacheLimit
		Measure.Bounds(Style, 17, "sentinel", false)
	end)

	It("sentinel cached", function()
		Expect(Measure.Cached(Style, 17, "sentinel", false)).toBeTruthy()
	end)

	Describe("generations", function()
		BeforeAll(function()
			for Index = 1, Limit * 2 + 2 do
				Measure.Bounds(Style, 17, `g{Index}`, false)
				if not Measure.Cached(Style, 17, "sentinel", false) then break end

				Survived = Index
			end
		end)

		It("cache survives a full generation", function()
			Expect(Survived).toBeGreaterThanOrEqual(Limit)
		end)

		It("cache stays bounded", function()
			Expect(Survived).toBeLessThan(Limit * 2 + 2)
		end)
	end)
end)

Describe("chop is bounded", function()
	AfterAll(Release)

	for _, Row: { number } in {{300, 3}, {600, 1}, {4800, 2}} do
		Describe(`{Row[1]} letters`, function()
			const Text: string = Letters(Row[1], Row[2])
			const Pieces: { TextLabel } = {}

			BeforeAll(function()
				const Target: TextLabel = Label(Text, 150, 60000)
				Build(Target):SetRendering("Culling", false):Flush()

				for _, Segment: TextLabel in Segments(Target) do table.insert(Pieces, Segment) end
			end)

			It("chopped piece fits", function()
				for _, Segment: TextLabel in Pieces do Expect(Segment.Size.X.Offset).toBeLessThanOrEqual(151) end
			end)

			It(`chop preserves {#Text} characters`, function()
				const Joined: { string } = {}
				for _, Segment: TextLabel in Pieces do table.insert(Joined, Segment.Text) end

				Expect(table.concat(Joined)).toBe(Text)
			end)
		end)
	end
end)

Describe("border strokes", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Outline: UIStroke

	const function Strokes(): { UIStroke }
		const Found: { UIStroke } = {}

		for _, Segment: TextLabel in Segments(Target) do
			for _, Child: Instance in Segment:GetChildren() do
				if Child:IsA("UIStroke") then table.insert(Found, Child :: UIStroke) end
			end
		end

		return Found
	end

	BeforeAll(function()
		Target = Label("stroked words here", 400, 100)

		const Border: UIStroke = Instance.new("UIStroke")
		Border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Border.Thickness = 2
		Border.Parent = Target

		Outline = Instance.new("UIStroke")
		Outline.Color = Color3.new(1, 0, 0)
		Outline.Thickness = 1
		Outline.Parent = Target

		Renderer = Build(Target)
	end)

	It("contextual stroke copied", function()
		Expect(#Strokes()).toBeGreaterThan(0)
	end)

	It("border stroke not copied", function()
		for _, Copy: UIStroke in Strokes() do Expect(Copy.ApplyStrokeMode).toBe(Enum.ApplyStrokeMode.Contextual) end
	end)

	It("stroke change propagates", function()
		Outline.Thickness = 3
		task.wait()

		for _, Copy: UIStroke in Strokes() do Expect(Copy.Thickness).toBe(3) end
	end)

	It("border switch removes copies", function()
		Outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		task.wait()
		Renderer:Flush()

		Expect(#Strokes()).toBe(0)
	end)
end)
