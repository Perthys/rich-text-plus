--!strict

const Gui = require("./Support/Gui")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

type Fake = {
	Name: string,
	Label: TextLabel,
	Rendering: { [string]: boolean },
	Cull: { Culled: boolean },
	Destroyed: boolean,
}

const LAYOUT: number = 1

const function Fresh(): (any, ModuleScript)
	const Render: Instance = (script.Parent :: any).Parent.Packages.RichTextPlus.Render
	const Copy: ModuleScript = (Render:FindFirstChild("Schedule") :: ModuleScript):Clone()
	Copy.Name = "BudgetBenchScheduleCopy"
	Copy.Parent = Render

	return (require :: any)(Copy), Copy
end

const function Fake(Name: string, Parent: Instance, Culled: boolean): Fake
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Name = Name
	Created.Parent = Parent

	return {Name = Name, Label = Created, Rendering = {Culling = true}, Cull = {Culled = Culled}, Destroyed = false}
end

const function Burn(Milliseconds: number): ()
	const Stop: number = os.clock() + Milliseconds / 1000
	while os.clock() < Stop do end
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}
	const Screen: ScreenGui = Gui.new("BudgetBench")

	const function Check(Name: string, Condition: boolean, Detail: any): ()
		table.insert(Outcome.Report :: { string }, `{Name}: {tostring(Detail)}`)

		if Condition then
			Outcome.Passed += 1
			return
		end

		Outcome.Failed += 1
		table.insert(Outcome.Failures, `{Name}: {tostring(Detail)}`)
	end

	const function Section(Name: string, Body: () -> ()): ()
		const Ok: boolean, Problem: any = pcall(Body)
		if Ok then return end

		Outcome.Failed += 1
		table.insert(Outcome.Failures, `{Name} errored: {tostring(Problem)}`)
	end

	Section("budget adherence", function()
		const Unit: any, Copy: ModuleScript = Fresh()
		local Ran: number = 0
		Unit.Bind(function(): () Burn(0.4); Ran += 1 end, math.max)
		Unit.SetBudget(2)

		for Index = 1, 20 do Unit.Queue(Fake(`item{Index}`, Screen, false), LAYOUT) end

		local Steps: number = 0
		local Most: number = 0
		local Fewest: number = math.huge
		const Durations: { number } = {}

		while Ran < 20 and Steps < 100 do
			const Before: number = Ran
			const Start: number = os.clock()
			Unit.Step()
			table.insert(Durations, os.clock() - Start)
			Most = math.max(Most, Ran - Before)
			Fewest = math.min(Fewest, Ran - Before)
			Steps += 1
		end

		table.sort(Durations)
		const Median: number = Durations[math.ceil(#Durations / 2)] * 1000

		Check("budgeted work completes", Ran == 20, Ran)
		Check("work spread across frames", Steps >= 4, Steps)
		Check("every frame makes progress", Fewest >= 1, Fewest)
		Check("frame never runs more than budget plus one item", Most <= 6, Most)
		Check("frame fills its budget", Most >= 3, Most)
		Check("typical frame stays within budget plus one item", Median <= 2 + 0.4 + 0.5, string.format("%.3f ms", Median))

		Copy:Destroy()
	end)

	Section("starvation", function()
		const Unit: any, Copy: ModuleScript = Fresh()
		const Offscreen: Fake = Fake("offscreen", Screen, true)
		const Busy: Fake = Fake("busy", Screen, false)
		local RanAt: number? = nil
		local Steps: number = 0

		Unit.Bind(function(State: Fake): ()
			if State == Offscreen then
				RanAt = Steps
				return
			end

			Burn(1.5)
		end, math.max)
		Unit.SetBudget(1)
		Unit.Queue(Offscreen, LAYOUT)

		while not RanAt and Steps < 60 do
			Steps += 1
			Unit.Queue(Busy, LAYOUT)
			Unit.Step()
		end

		Check("offscreen waits behind visible work", RanAt ~= nil and (RanAt :: number) > 1, RanAt)
		Check("offscreen is not starved", RanAt ~= nil and (RanAt :: number) <= 32, RanAt)

		Unit.Take(Busy)
		Copy:Destroy()
	end)

	Screen:Destroy()

	return Outcome
end

return {
	Run = Run,
}
