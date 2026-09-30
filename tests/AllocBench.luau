--!strict

const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Incremental = require("../Packages/RichTextPlus/Core/Incremental")
const Backdrop = require("../Packages/RichTextPlus/Render/Backdrop")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
const Gui = require("./Support/Gui")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

type Fake = {
	Name: string,
	Label: TextLabel,
	Rendering: { [string]: boolean },
	Cull: { Culled: boolean },
	Destroyed: boolean,
}

const BATCHES: number = 12
const TOKEN_BYTES: number = 320

const function Allocated(Operation: (Index: number) -> (), Iterations: number): number
	for Index = 1, Iterations do Operation(Index) end

	const Deltas: { number } = table.create(BATCHES, 0)
	local Counter: number = Iterations

	for Batch = 1, BATCHES do
		const Before: number = collectgarbage("count")

		for _ = 1, Iterations do
			Counter += 1
			Operation(Counter)
		end

		Deltas[Batch] = (collectgarbage("count") - Before) * 1024 / Iterations
	end

	table.sort(Deltas)

	return Deltas[BATCHES]
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}
	const Screen: ScreenGui = Gui.new("AllocBench")

	const function Most(Name: string, Actual: number, Limit: number): ()
		table.insert(Outcome.Report :: { string }, string.format("%s: %.1f bytes per op (limit %.1f)", Name, Actual, Limit))

		if Actual <= Limit then
			Outcome.Passed += 1
			return
		end

		Outcome.Failed += 1
		table.insert(Outcome.Failures, string.format("%s: expected at most %.1f bytes per op, got %.1f", Name, Limit, Actual))
	end

	const function Label(Text: string, Width: number, Height: number): TextLabel
		const Created: TextLabel = Instance.new("TextLabel")
		Created.Size = UDim2.fromOffset(Width, Height)
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

	const function Create(Target: TextLabel): any
		return (RichTextPlus :: any).new(Target):SetRendering("Passthrough", false):Flush()
	end

	const function Section(Name: string, Body: () -> ()): ()
		const Ok: boolean, Problem: any = pcall(Body)
		if Ok then return end

		Outcome.Failed += 1
		table.insert(Outcome.Failures, `{Name} errored: {tostring(Problem)}`)
	end

	Section("measure run and cased lookups", function()
		const Renderer: any = Create(Label("<uc>upper words</uc> <sc>small caps</sc> <b>bold</b> plain words here", 400, 200))

		Most("measure run", Allocated(function() Measure.Run(Renderer, 1) end, 20), 0)
		Most("cased hit", Allocated(function() Measure.Cased("words", "SmallCaps") end, 50), 0)
		Most("uppercased hit", Allocated(function() Measure.Uppercased("words", "Upper") end, 50), 0)

		Renderer:Destroy()
	end)

	Section("incremental patch", function()
		const Target: TextLabel = Label("", 300, 40)
		const Renderer: any = Create(Target)
		const Texts: { string } = {}
		for Index = 1, 40 do Texts[Index] = `<b>Coins:</b> <font color="#FFD700">{1000 + Index}</font>` end
		Renderer.Label.Text = Texts[1]
		Renderer:Flush()

		Most("hud patch", Allocated(function(Index: number)
			Target.Text = Texts[Index % 40 + 1]
			Incremental.Patch(Renderer)
		end, 80), TOKEN_BYTES)

		Renderer:Destroy()
	end)

	Section("coverage reuse", function()
		const Mark: any = {Color = Color3.new(1, 1, 0), Transparency = 0}
		const Style: any = {Mark = {Color = Color3.new(1, 0, 0), Transparency = 0, Parent = Mark}}
		const Coverage: any = Backdrop.Begin()

		Most("coverage reuse", Allocated(function()
			Backdrop.Begin(Coverage)
			Backdrop.Row(Coverage, 0, 20)
			Backdrop.Cover(Coverage, Style, 0, 50, 2)
		end, 50), 0)
	end)

	Section("pool assignment", function()
		const Renderer: any = Create(Label("one <b>two</b> three <i>four</i>", 400, 200))
		Renderer:Flush()

		const Runs: { any } = {}
		for _, Record: any in Renderer.Instances.Segments do
			table.insert(Runs, {Style = Record.Style, Text = Record.Content.Raw, X = 0, Y = 0, Width = 1, Height = 1})
		end

		Most("sequential assign", Allocated(function() Pool.Assign(Renderer, Runs) end, 50), 0)

		const Reversed: { any } = {}
		for Index = #Runs, 1, -1 do
			const Entry: any = Runs[Index]
			table.insert(Reversed, {Style = table.clone(Entry.Style), Text = Entry.Text, X = 0, Y = 0, Width = 1, Height = 1})
		end

		Pool.Assign(Renderer, Reversed)
		Most("fallback assign", Allocated(function() Pool.Assign(Renderer, Reversed) end, 50), 128)

		Renderer:Destroy()
	end)

	Section("scheduler", function()
		const Render: Instance = (script.Parent :: any).Parent.Packages.RichTextPlus.Render
		const Copy: ModuleScript = (Render:FindFirstChild("Schedule") :: ModuleScript):Clone()
		Copy.Name = "AllocBenchScheduleCopy"
		Copy.Parent = Render

		const Unit: any = (require :: any)(Copy)
		Unit.Bind(function(_State: Fake): () end, math.max)
		Unit.SetBudget(1000)

		const Holder: TextLabel = Instance.new("TextLabel")
		Holder.Name = "quick"
		Holder.Parent = Screen
		const Quick: Fake = {Name = "quick", Label = Holder, Rendering = {Culling = false}, Cull = {Culled = false}, Destroyed = false}

		Unit.Queue(Quick, 1)
		Unit.Step()

		Most("queue and take", Allocated(function()
			Unit.Queue(Quick, 2)
			Unit.Take(Quick)
		end, 50), 0)

		Most("queue and execute", Allocated(function()
			Unit.Queue(Quick, 1)
			Unit.Step()
		end, 50), 0)

		Holder:Destroy()
		Copy:Destroy()
	end)

	Section("gradient frames", function()
		const Renderer: any = Create(Label([[<gradient colors="#ff0000,#0000ff" speed="1">gradient text here</gradient>]], 400, 100))

		Driver.Tick(Renderer, 1 / 60)
		Most("gradient frame", Allocated(function() Driver.Tick(Renderer, 1 / 60) end, 200), 0)

		Renderer:Destroy()
	end)

	Screen:Destroy()

	return Outcome
end

return {
	Run = Run,
}
