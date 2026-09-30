--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Schedule = require("../Packages/RichTextPlus/Render/Schedule")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Fake = {
	Name: string,
	Label: TextLabel,
	Rendering: { [string]: boolean },
	Cull: { Culled: boolean },
	Destroyed: boolean,
}

const LAYOUT: number = 1
const SCALE: number = 2
const FLATTEN: number = 3
const PARSE: number = 4
const TEXT: number = 5

const Library: any = RichTextPlus
local Screen: ScreenGui

const function Label(Content: string, Width: number, Height: number, Parent: Instance?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width, Height)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Text = Content
	Created.Parent = Parent or Screen

	return Created
end

const function Create(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):Flush()
end

const function Fresh(): (any, ModuleScript)
	const Render: Instance = (script.Parent :: any).Parent.Packages.RichTextPlus.Render
	const Copy: ModuleScript = (Render:FindFirstChild("Schedule") :: ModuleScript):Clone()
	Copy.Name = "ScheduleSpecCopy"
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

const function Wait(Count: number): ()
	for _ = 1, Count do task.wait() end
end

const function RestoreBudget(): ()
	AfterAll(function()
		Library.Runtime.SetFrameBudget(2)
	end)
end

BeforeAll(function()
	Screen = Gui.new("Budget")
end)

AfterAll(function()
	Library.Runtime.SetFrameBudget(2)
	Gui.Cleanup()
end)

Describe("ordering", function()
	local Unit: any
	local Copy: ModuleScript
	local Closed: ScreenGui
	local Hidden: Fake
	const Order: { string } = {}

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(State: Fake): () table.insert(Order, State.Name) end, math.max)
		Unit.SetBudget(1000)

		Closed = Instance.new("ScreenGui")
		Closed.Enabled = false
		Closed.Parent = Screen

		const Offscreen: Fake = Fake("offscreen", Screen, true)
		const First: Fake = Fake("first", Screen, false)
		Hidden = Fake("hidden", Closed, false)
		const Second: Fake = Fake("second", Screen, false)

		Unit.Queue(Offscreen, LAYOUT)
		Unit.Queue(First, LAYOUT)
		Unit.Queue(Hidden, LAYOUT)
		Unit.Queue(Second, LAYOUT)
		Unit.Step()
	end)

	AfterAll(function()
		Closed:Destroy()
		Copy:Destroy()
	end)

	It("visible before offscreen", function()
		Expect(table.concat(Order, ",")).toBe("first,second,offscreen")
	end)

	It("hidden deferred", function()
		Expect(Unit.Pending(Hidden)).toBe(LAYOUT)
	end)

	It("hidden stays deferred across frames", function()
		Unit.Step()

		Expect(#Order).toBe(3)
	end)

	It("hidden runs once its collector enables", function()
		Closed.Enabled = true
		Unit.Touch(Hidden)

		Expect(Order[4]).toBe("hidden")
	end)

	It("promoted entry leaves the queue", function()
		Expect(Unit.Pending(Hidden)).toBeNil()
	end)

	It("offscreen label scrolled into view runs immediately", function()
		const Late: Fake = Fake("late", Screen, true)
		Unit.Queue(Late, SCALE)
		Late.Cull.Culled = false
		Unit.Touch(Late)

		Expect(Order[5]).toBe("late")
	end)
end)

Describe("coalescing", function()
	Describe("unit", function()
		local Unit: any
		local Copy: ModuleScript
		local Target: Fake
		const Calls: { number } = {}

		BeforeAll(function()
			Unit, Copy = Fresh()
			Unit.Bind(function(_State: Fake, Stage: number): () table.insert(Calls, Stage) end, math.max)
			Unit.SetBudget(1000)
			Target = Fake("target", Screen, false)
		end)

		AfterAll(function()
			Copy:Destroy()
		end)

		It("unit merge keeps strongest", function()
			Unit.Queue(Target, LAYOUT)
			Unit.Queue(Target, FLATTEN)
			Unit.Queue(Target, SCALE)

			Expect(Unit.Pending(Target)).toBe(FLATTEN)
		end)

		It("coalesced into one run", function()
			Unit.Step()

			Expect(#Calls).toBe(1)
		end)

		It("coalesced stage", function()
			Expect(Calls[1]).toBe(FLATTEN)
		end)
	end)

	Describe("renderer", function()
		const Sequence: { { number } } = {
			{LAYOUT, SCALE, LAYOUT},
			{SCALE, TEXT},
			{TEXT, LAYOUT},
			{TEXT, FLATTEN},
			{FLATTEN, TEXT},
			{TEXT, PARSE},
			{PARSE, TEXT},
			{LAYOUT, FLATTEN, SCALE},
		}
		const Expected: { number } = {SCALE, TEXT, TEXT, PARSE, PARSE, PARSE, PARSE, FLATTEN}

		local Real: TextLabel
		local Renderer: any
		local Generation: number

		BeforeAll(function()
			Real = Label("coalesce me", 300, 60)
			Renderer = Create(Real)
		end)

		AfterAll(function()
			Renderer:Destroy()
			Real:Destroy()
		end)

		for Index: number, Stages: { number } in Sequence do
			It(`merge rule {Index}`, function()
				for _, Stage: number in Stages do Schedule.Queue(Renderer, Stage) end
				const Pending: number? = Schedule.Pending(Renderer)
				Schedule.Take(Renderer)

				Expect(Pending).toBe(Expected[Index])
			end)
		end

		It("text and size triggers run once", function()
			Generation = Renderer.Generation.Refresh
			Real.TextSize = 24
			Real.Text = "coalesced <b>text</b>"
			Wait(2)

			Expect(Renderer.Generation.Refresh).toBe(Generation + 1)
		end)

		It("merged run parsed new text", function()
			Expect(Renderer.Document.Source).toBe("coalesced <b>text</b>")
		end)

		It("merged run restyled size", function()
			Expect(Renderer.Document.Tokens[1].Style.Size).toBe(24)
		end)
	end)
end)

Describe("budget adherence", function()
	local Unit: any
	local Copy: ModuleScript
	local Ran: number = 0
	const Fakes: { Fake } = {}

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(): () Burn(0.4); Ran += 1 end, math.max)
		for Index = 1, 10 do table.insert(Fakes, Fake(`item{Index}`, Screen, false)) end
	end)

	AfterAll(function()
		Copy:Destroy()
	end)

	It("zero budget runs exactly one per frame", function()
		Unit.SetBudget(0)
		for Index = 1, 3 do Unit.Queue(Fakes[Index], LAYOUT) end
		Unit.Step()

		Expect(Ran).toBe(1)
	end)

	It("zero budget drains one at a time", function()
		Unit.Step()
		Unit.Step()

		Expect(Ran).toBe(3)
	end)

	It("large budget drains in one frame", function()
		Ran = 0
		Unit.SetBudget(1000)
		for Index = 1, 10 do Unit.Queue(Fakes[Index], LAYOUT) end
		Unit.Step()

		Expect(Ran).toBe(10)
	end)
end)

Describe("visibility gate", function()
	local Unit: any
	local Copy: ModuleScript
	local Holder: Frame
	local Inner: Frame
	local Gated: Fake
	const Order: { string } = {}

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(State: Fake): () table.insert(Order, State.Name) end, math.max)
		Unit.SetBudget(1000)

		Holder = Instance.new("Frame")
		Holder.Visible = false
		Holder.Parent = Screen

		Inner = Instance.new("Frame")
		Inner.Visible = false
		Inner.Parent = Holder

		Gated = Fake("gated", Inner, false)
	end)

	AfterAll(function()
		Holder:Destroy()
		Copy:Destroy()
	end)

	It("invisible ancestor defers work", function()
		Unit.Queue(Gated, TEXT)
		Unit.Step()

		Expect(#Order).toBe(0)
	end)

	It("inner gate opening under a hidden parent keeps it deferred", function()
		Inner.Visible = true
		Wait(1)

		Expect(#Order).toBe(0)
	end)

	It("entry still queued behind outer gate", function()
		Expect(Unit.Pending(Gated)).toBe(TEXT)
	end)

	It("last gate opening runs deferred work", function()
		Holder.Visible = true
		Wait(1)

		Expect(Order[1]).toBe("gated")
	end)

	It("gated entry cleared", function()
		Expect(Unit.Pending(Gated)).toBeNil()
	end)
end)

Describe("destroy during queue", function()
	RestoreBudget()

	Describe("unit", function()
		local Unit: any
		local Copy: ModuleScript
		local Flagged: Fake
		local Dropped: Fake
		const Order: { string } = {}

		BeforeAll(function()
			Unit, Copy = Fresh()
			Unit.Bind(function(State: Fake): () table.insert(Order, State.Name) end, math.max)
			Unit.SetBudget(1000)

			const Kept: Fake = Fake("kept", Screen, false)
			Flagged = Fake("flagged", Screen, false)
			Dropped = Fake("dropped", Screen, false)

			Unit.Queue(Flagged, LAYOUT)
			Unit.Queue(Kept, LAYOUT)
			Unit.Queue(Dropped, LAYOUT)
			Flagged.Destroyed = true
			Unit.Take(Dropped)
			Unit.Queue(Flagged, SCALE)
			Unit.Step()
		end)

		AfterAll(function()
			Copy:Destroy()
		end)

		It("only live entries run", function()
			Expect(table.concat(Order, ",")).toBe("kept")
		end)

		It("dropped entry gone", function()
			Expect(Unit.Pending(Dropped)).toBeNil()
		end)

		It("destroyed entry gone", function()
			Expect(Unit.Pending(Flagged)).toBeNil()
		end)
	end)

	Describe("renderers", function()
		const Labels: { TextLabel } = {}
		const Renderers: { any } = {}
		const Sources: { [number]: string? } = {}

		BeforeAll(function()
			Library.Runtime.SetFrameBudget(0)

			for Index = 1, 6 do
				Labels[Index] = Label(`row {Index}`, 300, 40)
				Renderers[Index] = Create(Labels[Index])
			end

			for Index, Target: TextLabel in Labels do Target.Text = `changed {Index}` end
			Wait(1)

			for Index = 4, 6 do Sources[Index] = Renderers[Index].Document.Source end
		end)

		AfterAll(function()
			for Index = 1, 3 do Renderers[Index]:Destroy() end
			for _, Target: TextLabel in Labels do Target:Destroy() end
		end)

		It("explicit destroy leaves the queue at once", function()
			Renderers[6]:Destroy()

			Expect(Schedule.Pending(Renderers[6])).toBeNil()
		end)

		for Index = 4, 5 do
			It(`destroyed label {Index} left the queue`, function()
				if Labels[Index].Parent then
					Labels[4]:Destroy()
					Labels[5]:Destroy()
					Wait(1)
				end

				Expect(Schedule.Pending(Renderers[Index])).toBeNil()
			end)
		end

		for Index = 1, 3 do
			It(`survivor {Index} settles`, function()
				if Index == 1 then Wait(8) end

				Expect(Renderers[Index].Document.Source).toBe(`changed {Index}`)
			end)
		end

		for Index = 4, 6 do
			It(`destroyed renderer {Index} untouched`, function()
				Expect(Renderers[Index].Document.Source).toBe(Sources[Index])
			end)
		end
	end)
end)

Describe("visible first", function()
	RestoreBudget()

	local Scroller: ScrollingFrame
	const Renderers: { any } = {}
	const Settled: { [number]: number } = {}

	BeforeAll(function()
		Library.Runtime.SetFrameBudget(0)

		Scroller = Instance.new("ScrollingFrame")
		Scroller.Size = UDim2.fromOffset(300, 100)
		Scroller.CanvasSize = UDim2.fromOffset(300, 1200)
		Scroller.Parent = Screen

		for Index = 1, 10 do
			const Target: TextLabel = Label(`entry {Index}`, 280, 40, Scroller)
			Target.Position = UDim2.fromOffset(0, (Index - 1) * 45)
			Renderers[Index] = Create(Target)
			Driver.Tick(Renderers[Index], 0)
		end
	end)

	AfterAll(function()
		for _, Renderer: any in Renderers do Renderer:Destroy() end
		Scroller:Destroy()
	end)

	It("first entries on screen", function()
		Expect(not Renderers[1].Cull.Culled and not Renderers[2].Cull.Culled).toBe(true)
	end)

	It("later entries culled", function()
		Expect(Renderers[5].Cull.Culled and Renderers[10].Cull.Culled).toBe(true)
	end)

	It("all entries eventually settle", function()
		for Index = 10, 1, -1 do Renderers[Index].Label.Text = `fresh {Index}` end

		local Step: number = 0
		while Step < 40 do
			Wait(1)
			Step += 1

			local Done: boolean = true
			for Index = 1, 10 do
				if not Settled[Index] and Renderers[Index].Document.Source == `fresh {Index}` then Settled[Index] = Step end
				if not Settled[Index] then Done = false end
			end

			if Done then break end
		end

		Expect(Settled[10] ~= nil and Settled[1] ~= nil).toBe(true)
	end)

	It("visible entries settle before offscreen ones", function()
		local LatestVisible: number = 0
		local EarliestOffscreen: number = math.huge
		for Index = 1, 10 do
			const At: number = Settled[Index] or math.huge
			if Renderers[Index].Cull.Culled then EarliestOffscreen = math.min(EarliestOffscreen, At) else LatestVisible = math.max(LatestVisible, At) end
		end

		Expect(LatestVisible).toBeLessThanOrEqual(EarliestOffscreen)
	end)
end)

Describe("collector promotion", function()
	local Holder: ScreenGui
	local Renderer: any

	BeforeAll(function()
		Holder = Gui.new("BudgetGate")
		Renderer = Create(Label("before", 300, 40, Holder))
		Driver.Tick(Renderer, 0)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Holder:Destroy()
	end)

	It("disabled collector culls", function()
		Holder.Enabled = false
		Wait(1)
		Driver.Tick(Renderer, 0)

		Expect(Renderer.Cull.Culled).toBe(true)
	end)

	It("disabled collector defers relayout", function()
		Renderer.Label.Text = "after"
		Wait(4)

		Expect(Renderer.Document.Source).toBe("before")
	end)

	It("deferred work stays queued", function()
		Expect(Schedule.Pending(Renderer)).toBe(TEXT)
	end)

	It("enabling runs pending work before render", function()
		Holder.Enabled = true
		Wait(1)
		Driver.Tick(Renderer, 0)

		Expect(Renderer.Document.Source).toBe("after")
	end)

	It("promoted work left the queue", function()
		Expect(Schedule.Pending(Renderer)).toBeNil()
	end)
end)

Describe("explicit calls stay synchronous", function()
	RestoreBudget()

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Library.Runtime.SetFrameBudget(0)
		Target = Label("start", 300, 40)
		Renderer = Create(Target)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("text change queued", function()
		Target.Text = "via layout"
		Schedule.Queue(Renderer, TEXT)

		Expect(Schedule.Pending(Renderer)).toBe(TEXT)
	end)

	It("layout settles pending text", function()
		Renderer:Flush()

		Expect(Renderer.Document.Source).toBe("via layout")
	end)

	It("layout clears pending", function()
		Expect(Schedule.Pending(Renderer)).toBeNil()
	end)

	It("set text is synchronous", function()
		Schedule.Queue(Renderer, FLATTEN)
		Target.TextSize = 26
		Renderer.Label.Text = "set text"
		Renderer:Flush()

		Expect(Renderer.Document.Source).toBe("set text")
	end)

	It("set text consumes pending work", function()
		Expect(Schedule.Pending(Renderer)).toBeNil()
	end)

	It("set text merged pending restyle", function()
		Expect(Renderer.Document.Tokens[1].Style.Size).toBe(26)
	end)

	It("rebuild consumes pending work", function()
		Schedule.Queue(Renderer, LAYOUT)
		Renderer:Rebuild()

		Expect(Schedule.Pending(Renderer)).toBeNil()
	end)

	Describe("bulk", function()
		const Labels: { TextLabel } = {}
		const Renderers: { any } = {}

		BeforeAll(function()
			for Index = 1, 8 do
				Labels[Index] = Label(`bulk {Index}`, 300, 40)
				Renderers[Index] = Create(Labels[Index])
			end

			for Index, Each: TextLabel in Labels do Each.Text = `bulk changed {Index}` end
			Wait(1)
		end)

		AfterAll(function()
			for Index = 1, 8 do
				Renderers[Index]:Destroy()
				Labels[Index]:Destroy()
			end
		end)

		It("zero budget leaves work queued", function()
			local Waiting: number = 0
			for _, Each: any in Renderers do
				if Schedule.Pending(Each) then Waiting += 1 end
			end

			Expect(Waiting).toBeGreaterThanOrEqual(6)
		end)

		for Index = 1, 8 do
			It(`flush settles {Index}`, function()
				if Index == 1 then Library.Runtime.Flush() end

				Expect(Renderers[Index].Document.Source).toBe(`bulk changed {Index}`)
			end)
		end
	end)

	Describe("automatic size", function()
		local Auto: TextLabel
		local AutoRenderer: any

		BeforeAll(function()
			Auto = Label("short", 200, 20)
			Auto.AutomaticSize = Enum.AutomaticSize.Y
			AutoRenderer = Create(Auto)
			Auto.Text = string.rep("wrapping words ", 20)
			Wait(1)
			AutoRenderer:Flush()
		end)

		AfterAll(function()
			AutoRenderer:Destroy()
			Auto:Destroy()
		end)

		It("renderer flush settles one label", function()
			Expect(AutoRenderer.Document.Source).toBe(Auto.Text)
		end)

		It("automatic size grows to content", function()
			Expect(Auto.AbsoluteSize.Y + 1).toBeGreaterThanOrEqual(AutoRenderer.Cull.Bounds.MaxY)
		end)
	end)

	It("negative budget rejected", function()
		Expect((pcall(Library.Runtime.SetFrameBudget, -1))).toBe(false)
	end)

	It("non number budget rejected", function()
		Expect((pcall(Library.Runtime.SetFrameBudget, "fast"))).toBe(false)
	end)

	It("zero budget accepted", function()
		Expect((pcall(Library.Runtime.SetFrameBudget, 0))).toBe(true)
	end)
end)
