--!strict

const RichTextPlus = require("../Packages/RichTextPlus")
const XML = require("../Packages/XML")
const Styles = require("../Packages/RichTextPlus/Utility/Styles")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
const Reflow = require("../Packages/RichTextPlus/Utility/Reflow")
const CodeBlock = require("../Packages/RichTextPlus/Classes/CodeBlock")
const Gui = require("./Support/Gui")

export type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const Library: any = RichTextPlus
const Parser: any = XML

const White: Color3 = Color3.new(1, 1, 1)
const Mono: string = "rbxasset://fonts/families/RobotoMono.json"

const function Label(Screen: ScreenGui, Text: string, Width: number, Height: number): TextLabel
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
	Created.Parent = Screen

	return Created
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

const function Colored(Count: number): string
	const Parts: { string } = table.create(Count)

	for Index = 1, Count do
		Parts[Index] = `<font color="rgb({Index % 256},{(Index // 256) % 256},{(Index * 7) % 256})">w{Index}</font>`
	end

	return table.concat(Parts, " ")
end

const function Ideographs(): number
	const Glyphs: { string } = {}
	for Index = 0, 799 do table.insert(Glyphs, utf8.char(0x4E00 + Index * 7)) end

	const Node: any = Parser:GenerateTreeFromXML(`<codeblock>{table.concat(Glyphs)}</codeblock>`).Children[1]
	const Started: number = os.clock()
	const Wide: Frame = CodeBlock.Build(Node, CodeStyle(16), 1, nil)
	Reflow.Height(Wide, 200)
	const Elapsed: number = os.clock() - Started

	Wide:Destroy()

	return Elapsed
end

const function Assign(Screen: ScreenGui, Count: number): number
	const Target: TextLabel = Label(Screen, Colored(Count), 6000, 4000)
	Target.TextWrapped = false

	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):SetRendering("Culling", false):Flush()
	const Runs: { any } = {}

	for Index: number, Record: any in Renderer.Instances.Segments do
		Runs[#Renderer.Instances.Segments - Index + 1] = {Style = Styles.Clone(Record.Style), Text = Record.Content.Raw, X = Record.X, Y = Record.Y, Width = Record.Width, Height = Record.Height}
	end

	const Started: number = os.clock()
	Pool.Assign(Renderer, Runs)
	const Elapsed: number = os.clock() - Started

	Renderer:Destroy()
	Target:Destroy()

	return Elapsed
end

const function BestAssign(Screen: ScreenGui, Count: number): number
	local Fastest: number = math.huge
	for _ = 1, 3 do Fastest = math.min(Fastest, Assign(Screen, Count)) end

	return Fastest
end

const function Chop(Screen: ScreenGui, Text: string): number
	const Target: TextLabel = Label(Screen, Text, 150, 60000)
	const Started: number = os.clock()
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):SetRendering("Culling", false):Flush()
	const Elapsed: number = os.clock() - Started

	Renderer:Destroy()
	Target:Destroy()

	return Elapsed
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}
	const Screen: ScreenGui = Gui.new("FixLayoutBench")

	const function Check(Name: string, Condition: boolean, Detail: string): ()
		table.insert(Outcome.Report :: { string }, `{Name}: {Detail}`)

		if Condition then
			Outcome.Passed += 1
		else
			Outcome.Failed += 1
			table.insert(Outcome.Failures, `{Name}: {Detail}`)
		end
	end

	const Ok: boolean, Problem: any = pcall(function()
		const Wide: number = Ideographs()
		Check("ideograph block bounded", Wide < 0.25, `{Wide}`)

		Assign(Screen, 100)
		const Small: number = BestAssign(Screen, 300)
		const Large: number = BestAssign(Screen, 2400)
		Check("assign scales linearly", Large < math.max(Small, 0.0005) * 24, `{Small} -> {Large}`)

		Chop(Screen, Letters(300, 3))
		const Short: number = Chop(Screen, Letters(600, 1))
		const Long: number = Chop(Screen, Letters(4800, 2))
		Check("chop scales linearly", Long < math.max(Short, 0.001) * 24, `{Short} -> {Long}`)
	end)

	if not Ok then
		Outcome.Failed += 1
		table.insert(Outcome.Failures, `errored: {tostring(Problem)}`)
	end

	Screen:Destroy()

	return Outcome
end

return {
	Run = Run,
}
