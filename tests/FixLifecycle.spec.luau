--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Pipeline = require("../Packages/RichTextPlus/Renderer/Pipeline")
const Stage = require("../Packages/RichTextPlus/Renderer/Stage")
const Attributes = require("../Packages/RichTextPlus/Utility/Attributes")
const Schedule = require("../Packages/RichTextPlus/Render/Schedule")
const Registry = require("../Packages/RichTextPlus/Render/Registry")
const Incremental = require("../Packages/RichTextPlus/Core/Incremental")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Gradient = require("../Packages/RichTextPlus/Classes/Gradient")
const Effect = require("../Packages/RichTextPlus/Classes/Effect")
const CodeBlock = require("../Packages/RichTextPlus/Classes/CodeBlock")
const XML = require("../Packages/XML")
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
const TEXT: number = 5

const PARAGRAPH: string = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree twentyfour twentyfive"

const Library: any = RichTextPlus
const Probe: Folder = Instance.new("Folder")
local Screen: ScreenGui

const function Wait(Count: number): ()
	for _ = 1, Count do task.wait() end
end

const function Destroyed(Object: Instance): boolean
	if Object.Parent ~= nil then return false end

	const Movable: boolean = pcall(function() Object.Parent = Probe end)
	if Movable then Object.Parent = nil end

	return not Movable
end

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
	Created.Parent = Parent

	return Created
end

const function Create(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):Flush()
end

const function Segments(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}
	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	return Found
end

const function Shown(Target: TextLabel): string
	const Parts: { string } = {}
	for _, Segment: TextLabel in Segments(Target) do table.insert(Parts, Segment.Text) end

	return table.concat(Parts, " ")
end

const function Revealed(Renderer: any): string
	const Parts: { string } = {}
	for _, Record: any in Renderer.Instances.Order do
		if Record.Label then table.insert(Parts, Record.Content.Raw) end
	end

	return table.concat(Parts, " ")
end

const function Objects(Renderer: any): { GuiObject }
	const Found: { GuiObject } = {}
	for _, Token: any in Renderer.Document.Tokens do
		if Token.Object then table.insert(Found, Token.Object) end
	end

	return Found
end

const function Fresh(): (any, ModuleScript)
	const Render: Instance = (script.Parent :: any).Parent.Packages.RichTextPlus.Render
	const Copy: ModuleScript = (Render:FindFirstChild("Schedule") :: ModuleScript):Clone()
	Copy.Name = "LifecycleScheduleCopy"
	Copy.Parent = Render

	return (require :: any)(Copy), Copy
end

const function Fake(Name: string, Parent: Instance?): Fake
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Name = Name
	Created.Parent = Parent

	return {Name = Name, Label = Created, Rendering = {Culling = true}, Cull = {Culled = false}, Destroyed = false}
end

const function Burn(Milliseconds: number): ()
	const Stop: number = os.clock() + Milliseconds / 1000
	while os.clock() < Stop do end
end

const function Problem(Ok: boolean, Error: any): string
	return if Ok then "" else tostring(Error)
end

BeforeAll(function()
	Screen = Gui.new("Lifecycle")
end)

AfterAll(function()
	Gui.Cleanup()
	Probe:Destroy()
end)

Describe("grapheme count consumes pending work", function()
	local Holder: Frame

	BeforeAll(function()
		Holder = Instance.new("Frame")
		Holder.Size = UDim2.fromOffset(400, 200)
		Holder.Parent = Screen
	end)

	AfterAll(function()
		Holder:Destroy()
	end)

	Describe("segment label", function()
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Target = Label("old words here", 300, 60, Holder)
			Renderer = Create(Target)

			Holder.Visible = false
			Target.Text = "brand new sentence"
			Wait(3)
		end)

		AfterAll(function()
			Renderer:Destroy()
			Target:Destroy()
		end)

		It("hidden edit parked", function()
			Expect(Schedule.Pending(Renderer)).toBe(TEXT)
		end)

		It("source still old", function()
			Expect(Renderer.Document.Source).toBe("old words here")
		end)

		It("count covers the new text", function()
			Expect(Renderer:GetGraphemeCount()).toBe(18)
		end)

		It("count settles pending text first", function()
			Expect(Renderer.Document.Source).toBe("brand new sentence")
		end)

		It("count clears the queue", function()
			Expect(Schedule.Pending(Renderer)).toBeNil()
		end)

		It("reveal order is the new text", function()
			Expect(Revealed(Renderer)).toBe("brand new sentence")
		end)
	end)

	Describe("native label", function()
		local Passing: TextLabel
		local Native: any

		BeforeAll(function()
			Passing = Label("native old", 300, 60, Holder)
			Native = Library.new(Passing):Flush()
		end)

		AfterAll(function()
			Native:Destroy()
			Passing:Destroy()
		end)

		It("idle label native", function()
			Expect(Native.Native.Active).toBe(true)
		end)

		It("native hidden edit parked", function()
			Passing.Text = "native new"
			Wait(3)

			Expect(Schedule.Pending(Native)).toBe(TEXT)
		end)

		It("native count covers the new text", function()
			Expect(Native:GetGraphemeCount()).toBe(10)
		end)

		It("counting keeps passthrough", function()
			Expect(Native.Native.Active).toBe(true)
		end)

		It("native count settles pending text", function()
			Expect(Native.Document.Source).toBe("native new")
		end)

		It("native count clears the queue", function()
			Expect(Schedule.Pending(Native)).toBeNil()
		end)
	end)

	Describe("scaled label", function()
		local Solver: any

		BeforeAll(function()
			const Scaled: TextLabel = Label("scaled old", 300, 60, Holder)
			Scaled.TextScaled = true
			Solver = Create(Scaled)

			Scaled.Text = "scaled new"
			Wait(3)
			Solver:Flush()
		end)

		AfterAll(function()
			Solver:Destroy()
		end)

		It("solve scale settles pending text", function()
			Expect(Solver.Document.Source).toBe("scaled new")
		end)

		It("solve scale clears the queue", function()
			Expect(Schedule.Pending(Solver)).toBeNil()
		end)
	end)
end)

Describe("hidden gates promote", function()
	Describe("disabled collector", function()
		local Closed: ScreenGui
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Closed = Gui.new("LifecycleClosed")
			Closed.Enabled = false
			Target = Label("before", 300, 40, Closed)
			Renderer = Library.new(Target):Flush()
		end)

		AfterAll(function()
			Renderer:Destroy()
			Closed:Destroy()
		end)

		It("disabled collector label native", function()
			Expect(Renderer.Native.Active).toBe(true)
		end)

		It("disabled collector parks native edit", function()
			Target.Text = "after"
			Wait(4)

			Expect(Schedule.Pending(Renderer)).toBe(TEXT)
		end)

		It("parked source unchanged", function()
			Expect(Renderer.Document.Source).toBe("before")
		end)

		It("enabling the collector promotes native entry", function()
			Closed.Enabled = true
			Wait(3)

			Expect(Renderer.Document.Source).toBe("after")
		end)

		It("promoted native entry left the queue", function()
			Expect(Schedule.Pending(Renderer)).toBeNil()
		end)

		It("native label shows new text", function()
			Expect(Target.Text).toBe("after")
		end)
	end)

	Describe("label without collector", function()
		local Loose: TextLabel
		local Floating: any

		BeforeAll(function()
			Loose = Label("loose before", 300, 40, nil)
			Floating = Library.new(Loose):Flush()
		end)

		AfterAll(function()
			Floating:Destroy()
			Loose:Destroy()
		end)

		It("label without collector parks", function()
			Loose.Text = "loose after"
			Wait(4)

			Expect(Schedule.Pending(Floating)).toBe(TEXT)
		end)

		It("parenting under a collector promotes", function()
			Loose.Parent = Screen
			Wait(3)

			Expect(Floating.Document.Source).toBe("loose after")
		end)

		It("parented entry left the queue", function()
			Expect(Schedule.Pending(Floating)).toBeNil()
		end)
	end)

	Describe("segment label without collector", function()
		local Orphan: TextLabel
		local Segmented: any

		BeforeAll(function()
			Orphan = Label("orphan before", 300, 40, nil)
			Segmented = Create(Orphan)
		end)

		AfterAll(function()
			Segmented:Destroy()
			Orphan:Destroy()
		end)

		It("segment label without collector parks", function()
			Orphan.Text = "orphan <b>after</b>"
			Wait(4)

			Expect(Schedule.Pending(Segmented)).toBe(TEXT)
		end)

		It("segment label promoted when parented", function()
			Orphan.Parent = Screen
			Wait(3)
			Driver.Tick(Segmented, 0)

			Expect(Segmented.Document.Source).toBe("orphan <b>after</b>")
		end)

		It("segment label shows new text", function()
			Expect(Shown(Orphan)).toBe("orphan after")
		end)
	end)
end)

Describe("teardown aborts yielded refresh", function()
	local Target: TextLabel
	local Renderer: any
	local Image: GuiObject
	const Built: { Frame } = {}
	local Parked: thread? = nil

	BeforeAll(function()
		Target = Label([[<img src="rbxassetid://1" size="20"/> start]], 300, 60, Screen)
		Renderer = Create(Target)
		Image = Objects(Renderer)[1]

		Renderer:AddCustomClass("slow", {Kind = "Object", Build = function(): GuiObject?
			Parked = coroutine.running()
			coroutine.yield()

			const Created: Frame = Instance.new("Frame")
			Created.Size = UDim2.fromOffset(12, 12)
			table.insert(Built, Created)

			return Created
		end})

		task.spawn(function()
			Renderer.Label.Text = "<customclass><slow/></customclass> next"
			Renderer:Flush()
		end)
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("refresh parked inside build", function()
		Expect(Parked).never.toBeNil()
	end)

	It("old object intact while flatten is pending", function()
		Expect(Image.Parent == Target and not Destroyed(Image)).toBe(true)
	end)

	It("teardown bumps generation", function()
		const Before: number = Renderer.Generation.Refresh
		Renderer:Destroy()

		Expect(Renderer.Generation.Refresh).toBeGreaterThan(Before)
	end)

	It("abandoned build produced one object", function()
		if Parked then task.spawn(Parked :: thread) end
		Wait(2)

		Expect(#Built).toBe(1)
	end)

	It("abandoned object destroyed", function()
		Expect(Built[1] ~= nil and Destroyed(Built[1]) and Built[1].Parent == nil).toBe(true)
	end)

	It("no segments after teardown", function()
		Expect(#Segments(Target)).toBe(0)
	end)

	It("host transparency restored", function()
		Expect(Target.TextTransparency).toBe(0)
	end)

	It("owner cleared", function()
		Expect(Target:GetAttribute(Attributes.Owner)).toBeNil()
	end)
end)

Describe("superseded refresh requeues", function()
	Describe("custom object", function()
		local Target: TextLabel
		local Renderer: any
		local Image: GuiObject
		const Built: { Frame } = {}
		local Parked: thread? = nil
		local Gate: boolean = true

		BeforeAll(function()
			Target = Label([[<img src="rbxassetid://1" size="20"/> start]], 300, 60, Screen)
			Renderer = Create(Target)
			Image = Objects(Renderer)[1]

			Renderer:AddCustomClass("slow", {Kind = "Object", Build = function(): GuiObject?
				if Gate then
					Gate = false
					Parked = coroutine.running()
					coroutine.yield()
				end

				const Created: Frame = Instance.new("Frame")
				Created.Size = UDim2.fromOffset(12, 12)
				table.insert(Built, Created)

				return Created
			end})

			task.spawn(function()
				Renderer.Label.Text = "<customclass><slow/></customclass> next"
				Renderer:Flush()
			end)
		end)

		AfterAll(function()
			Renderer:Destroy()
			Target:Destroy()
		end)

		It("flatten parked", function()
			Expect(Parked).never.toBeNil()
		end)

		It("old object survives a pending flatten", function()
			Pipeline.Refresh(Renderer, Stage.Scale)

			Expect(Image.Parent == Target and not Destroyed(Image)).toBe(true)
		end)

		It("abandoned and requeued builds", function()
			if Parked then task.spawn(Parked :: thread) end
			Wait(4)

			Expect(#Built).toBe(2)
		end)

		It("abandoned flatten object destroyed", function()
			Expect(Built[1] ~= nil and Destroyed(Built[1])).toBe(true)
		end)

		It("requeued object mounted", function()
			Expect(if Built[2] then Built[2].Parent else nil).toBe(Target)
		end)

		It("source is the new text", function()
			Expect(Renderer.Document.Source).toBe("<customclass><slow/></customclass> next")
		end)

		It("segments show the new text", function()
			Expect(Shown(Target)).toBe("next")
		end)

		It("replaced object destroyed on commit", function()
			Expect(Destroyed(Image)).toBe(true)
		end)
	end)

	Describe("incremental patch", function()
		const Original: any = Incremental.Patch
		local Patchy: TextLabel
		local Patcher: any
		local Held: thread? = nil
		local Once: boolean = true

		BeforeAll(function()
			Patchy = Label("alpha beta gamma", 300, 60, Screen)
			Patcher = Create(Patchy)

			Incremental.Patch = function(State: any): boolean
				if State == Patcher and Once then
					Once = false
					Held = coroutine.running()
					coroutine.yield()

					return true
				end

				return Original(State)
			end
		end)

		AfterAll(function()
			Incremental.Patch = Original
			Patcher:Destroy()
			Patchy:Destroy()
		end)

		It("patch parked", function()
			Patchy.Text = "alpha beta delta"
			Wait(3)

			Expect(Held).never.toBeNil()
		end)

		It("patch flow ran", function()
			const Ok: boolean, Error: any = pcall(function()
				Pipeline.Refresh(Patcher, Stage.Scale)
				if Held then task.spawn(Held :: thread) end
				Wait(4)
			end)
			Incremental.Patch = Original

			Expect(Problem(Ok, Error)).toBe("")
		end)

		It("abandoned patch requeued newest text", function()
			Expect(Patcher.Document.Source).toBe("alpha beta delta")
		end)

		It("requeued patch rendered", function()
			Expect(Shown(Patchy)).toBe("alpha beta delta")
		end)

		It("queue drained", function()
			Expect(Schedule.Pending(Patcher)).toBeNil()
		end)
	end)
end)

Describe("code block build yield", function()
	const Original: any = CodeBlock.Build
	const Built: { GuiObject } = {}
	local Held: thread? = nil
	local Parking: boolean = true
	local Target: TextLabel
	local Renderer: any
	local Doomed: TextLabel
	local Dying: any
	local Ok: boolean
	local Error: any

	BeforeAll(function()
		CodeBlock.Build = function(...: any): GuiObject?
			if Parking then
				Parking = false
				Held = coroutine.running()
				coroutine.yield()
			end

			const Result: GuiObject? = Original(...)
			if Result then table.insert(Built, Result :: GuiObject) end

			return Result
		end

		Target = Label("plain", 300, 200, Screen)
		Renderer = Create(Target)
		Doomed = Label("doomed", 300, 200, Screen)
		Dying = Create(Doomed)
	end)

	AfterAll(function()
		CodeBlock.Build = Original
		Renderer:Destroy()
		Target:Destroy()
		Doomed:Destroy()
	end)

	It("code block build parked", function()
		task.spawn(function()
			Renderer.Label.Text = "<codeblock>print(1)</codeblock>after"
			Renderer:Flush()
		end)

		Expect(Held).never.toBeNil()
	end)

	It("second build parked", function()
		Ok, Error = pcall(function()
			Pipeline.Refresh(Renderer, Stage.Scale)
			if Held then task.spawn(Held :: thread) end
			Wait(4)

			Held = nil
			Parking = true
			task.spawn(function()
				Dying.Label.Text = "<codeblock>print(2)</codeblock>gone"
				Dying:Flush()
			end)
		end)

		Expect(Held).never.toBeNil()
	end)

	It("code block flow ran", function()
		if Ok then
			Ok, Error = pcall(function()
				Dying:Destroy()
				if Held then task.spawn(Held :: thread) end
				Wait(2)
			end)
		end
		CodeBlock.Build = Original

		Expect(Problem(Ok, Error)).toBe("")
	end)

	It("superseded and requeued code blocks", function()
		Expect(#Built).toBe(3)
	end)

	It("superseded code block destroyed", function()
		Expect(Built[1] ~= nil and Destroyed(Built[1])).toBe(true)
	end)

	It("requeued code block mounted", function()
		Expect(if Built[2] then Built[2].Parent else nil).toBe(Target)
	end)

	It("text after code block rendered", function()
		Expect(Shown(Target)).toBe("after")
	end)

	It("code block built after teardown destroyed", function()
		Expect(Built[3] ~= nil and Destroyed(Built[3])).toBe(true)
	end)

	It("destroyed renderer left no segments", function()
		Expect(#Segments(Doomed)).toBe(0)
	end)
end)

Describe("inline objects reused", function()
	const Markup: string = [[<img src="rbxassetid://1" size="20"/> %s <img src="rbxassetid://2" size="30"/><codeblock lang="lua">print(1)</codeblock>]]

	Describe("text edits", function()
		local Target: TextLabel
		local Renderer: any
		local First: { GuiObject }
		local Second: { GuiObject }
		local Third: { GuiObject }
		local Fourth: { GuiObject }

		BeforeAll(function()
			Target = Label(string.format(Markup, "one"), 360, 200, Screen)
			Renderer = Create(Target)
			First = Objects(Renderer)

			Renderer.Label.Text = string.format(Markup, "<b>two</b>")
			Renderer:Flush()
			Second = Objects(Renderer)
		end)

		AfterAll(function()
			Target:Destroy()
		end)

		It("three objects built", function()
			Expect(#First).toBe(3)
		end)

		for Index = 1, 3 do
			It(`object {Index} reused across text edits`, function()
				Expect(Second[Index]).toBe(First[Index])
			end)
		end

		for Index = 1, 3 do
			It(`object {Index} still mounted`, function()
				Expect(First[Index].Parent).toBe(Target)
			end)
		end

		It("image keeps base size", function()
			Expect(Renderer.Document.Tokens[1].Width).toBe(20)
		end)

		for Index = 1, 3 do
			It(`object {Index} reused across restyle`, function()
				if Index == 1 then
					Renderer:AddCustomClass("still", {Kind = "Effect", Update = function(): () end}):Flush()
					Third = Objects(Renderer)
				end

				Expect(Third[Index]).toBe(First[Index])
			end)
		end

		It("changed image rebuilt", function()
			Renderer.Label.Text = [[<img src="rbxassetid://1" size="24"/> two <img src="rbxassetid://2" size="30"/>]]
			Renderer:Flush()
			Fourth = Objects(Renderer)

			Expect(Fourth[1] ~= First[1]).toBe(true)
		end)

		It("old image destroyed", function()
			Expect(Destroyed(First[1])).toBe(true)
		end)

		It("unchanged image reused", function()
			Expect(Fourth[2]).toBe(First[2])
		end)

		It("dropped code block destroyed", function()
			Expect(Destroyed(First[3])).toBe(true)
		end)

		It("teardown destroys reused objects", function()
			Renderer:Destroy()

			Expect(Destroyed(Fourth[2])).toBe(true)
		end)
	end)

	Describe("scaled", function()
		local Scaled: TextLabel
		local Solver: any
		local Image: GuiObject

		BeforeAll(function()
			Scaled = Label([[<img src="rbxassetid://1" size="40"/> scaled words]], 120, 30, Screen)
			Scaled.TextScaled = true
			Solver = Create(Scaled)
			Image = Solver.Document.Tokens[1].Object
		end)

		AfterAll(function()
			Solver:Destroy()
			Scaled:Destroy()
		end)

		It("scaled object sized from base", function()
			Expect(Solver.Document.Tokens[1].Width).toBe(math.floor(40 * Solver.Scale.Factor + 0.5))
		end)

		It("scaled object reused", function()
			Solver.Label.Text = [[<img src="rbxassetid://1" size="40"/> <font color="#ff0000">scaled</font> words]]
			Solver:Flush()

			Expect(Solver.Document.Tokens[1].Object).toBe(Image)
		end)

		It("reused scaled object sized from base", function()
			Expect(Solver.Document.Tokens[1].Width).toBe(math.floor(40 * Solver.Scale.Factor + 0.5))
		end)
	end)
end)

Describe("developer transparency writes", function()
	Describe("segments", function()
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Target = Label("visible words", 300, 60, Screen)
			Renderer = Create(Target)
		end)

		AfterAll(function()
			Target:Destroy()
		end)

		It("host hidden", function()
			Expect(math.abs(Target.TextTransparency - 1)).toBeLessThanOrEqual(0.001)
		end)

		It("host hidden with a value a developer write of 1 changes", function()
			Expect(Target.TextTransparency).never.toBe(1)
		end)

		It("developer write of 1 recorded", function()
			Target.TextTransparency = 1
			Wait(2)

			Expect(Renderer.Developer.Transparency).toBe(1)
		end)

		It("segment hidden", function()
			for _, Segment: TextLabel in Segments(Target) do Expect(`{Segment.Text} {Segment.TextTransparency}`).toBe(`{Segment.Text} 1`) end
		end)

		It("attribute stores 1", function()
			Expect(Target:GetAttribute(Attributes.DeveloperTransparency)).toBe(1)
		end)

		It("developer write of 0 recorded", function()
			Target.TextTransparency = 0
			Wait(2)

			Expect(Renderer.Developer.Transparency).toBe(0)
		end)

		It("segment shown", function()
			for _, Segment: TextLabel in Segments(Target) do Expect(`{Segment.Text} {Segment.TextTransparency}`).toBe(`{Segment.Text} 0`) end
		end)

		It("synchronous refresh captures pending write", function()
			Target.TextTransparency = 0.5
			Renderer:Rebuild()

			Expect(math.abs(Renderer.Developer.Transparency - 0.5)).toBeLessThanOrEqual(0.001)
		end)

		It("deferred echo keeps developer write", function()
			Wait(2)

			Expect(math.abs(Renderer.Developer.Transparency - 0.5)).toBeLessThanOrEqual(0.001)
		end)

		It("segment faded", function()
			for _, Segment: TextLabel in Segments(Target) do
				Expect(`{Segment.Text} {math.abs(Segment.TextTransparency - 0.5) <= 0.001}`).toBe(`{Segment.Text} true`)
			end
		end)

		It("host stays hidden", function()
			Expect(math.abs(Target.TextTransparency - 1)).toBeLessThanOrEqual(0.001)
		end)

		It("teardown keeps last developer write", function()
			Target.TextTransparency = 0.25
			Renderer:Destroy()

			Expect(math.abs(Target.TextTransparency - 0.25)).toBeLessThanOrEqual(0.001)
		end)
	end)

	Describe("native", function()
		local Passing: TextLabel
		local Native: any

		BeforeAll(function()
			Passing = Label("native words", 300, 60, Screen)
			Native = Library.new(Passing):Flush()
		end)

		AfterAll(function()
			Native:Destroy()
			Passing:Destroy()
		end)

		It("native", function()
			Expect(Native.Native.Active).toBe(true)
		end)

		It("native keeps developer write across rebuild", function()
			Passing.TextTransparency = 0.5
			Native:Rebuild()
			Wait(2)

			Expect(math.abs(Native.Developer.Transparency - 0.5)).toBeLessThanOrEqual(0.001)
		end)

		It("native host shows developer value", function()
			Expect(math.abs(Passing.TextTransparency - 0.5)).toBeLessThanOrEqual(0.001)
		end)
	end)
end)

Describe("developer size", function()
	Describe("unfrozen", function()
		local Target: TextLabel
		local Renderer: any

		BeforeAll(function()
			Target = Label("scaled", 200, 40, Screen)
			Target.TextScaled = true
			Renderer = Create(Target)
		end)

		AfterAll(function()
			Target:Destroy()
		end)

		It("unfrozen size not recorded", function()
			Target.Size = UDim2.fromOffset(150, 50)
			Wait(2)

			Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBeNil()
		end)

		It("teardown keeps latest developer size", function()
			Target.TextScaled = false
			Wait(1)
			Target.Size = UDim2.fromOffset(170, 60)
			Wait(2)
			Renderer:Destroy()

			Expect(Target.Size).toBe(UDim2.fromOffset(170, 60))
		end)
	end)

	Describe("frozen", function()
		local Frozen: TextLabel
		local Freezer: any

		BeforeAll(function()
			Frozen = Label("frozen", 200, 40, Screen)
			Frozen.AutomaticSize = Enum.AutomaticSize.Y
			Frozen.TextScaled = true
			Freezer = Create(Frozen)
			Wait(1)
		end)

		AfterAll(function()
			Frozen:Destroy()
		end)

		It("frozen", function()
			Expect(Frozen.AutomaticSize).toBe(Enum.AutomaticSize.None)
		end)

		It("developer size recorded while frozen", function()
			Frozen.Size = UDim2.fromOffset(260, 50)
			Wait(2)

			Expect(Frozen:GetAttribute(Attributes.DeveloperSize)).toBe(UDim2.fromOffset(260, 50))
		end)

		It("teardown restores developer size", function()
			Freezer:Destroy()

			Expect(Frozen.Size).toBe(UDim2.fromOffset(260, 50))
		end)

		It("teardown restores automatic size", function()
			Expect(Frozen.AutomaticSize).toBe(Enum.AutomaticSize.Y)
		end)
	end)
end)

Describe("enforce waits for a real box", function()
	const Original: UDim2 = UDim2.new(0.5, 0, 0, 40)
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("scaled automatic", 200, 40, nil)
		Target.Size = Original
		Target.AutomaticSize = Enum.AutomaticSize.Y
		Target.TextScaled = true
		Renderer = Create(Target)
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("zero box does not freeze", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)

	It("zero box records nothing", function()
		Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBeNil()
	end)

	It("zero box keeps size", function()
		Expect(Target.Size).toBe(Original)
	end)

	It("freezes once laid out", function()
		Target.Parent = Screen
		Wait(3)

		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.None)
	end)

	It("width keeps scale sizing", function()
		Expect(Target.Size.X).toBe(Original.X)
	end)

	It("height frozen at real size", function()
		Expect(Target.Size.Y.Offset).toBe(Target.AbsoluteSize.Y)
	end)

	It("not frozen at the minimum box", function()
		Expect(Target.AbsoluteSize.X).toBeGreaterThan(40)
	end)

	It("stored developer size", function()
		Expect(Target:GetAttribute(Attributes.DeveloperSize)).toBe(Original)
	end)

	It("teardown restores size", function()
		Renderer:Destroy()

		Expect(Target.Size).toBe(Original)
	end)

	It("teardown restores automatic size", function()
		Expect(Target.AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end)
end)

Describe("height resize relayouts clipped text", function()
	local Target: TextLabel
	local Renderer: any
	local Before: number

	BeforeAll(function()
		Target = Label(PARAGRAPH, 160, 40, Screen)
		Renderer = Create(Target)
		Before = #Segments(Target)

		Target.Size = UDim2.fromOffset(160, 400)
		Wait(3)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("taller box shows more lines", function()
		Expect(#Segments(Target)).toBeGreaterThan(Before)
	end)

	It("last height tracked", function()
		Expect(Renderer.Host.Height).toBe(400)
	end)
end)

Describe("finite gradient speed", function()
	const function Node(Markup: string): any
		return XML.GenerateTreeFromXML(Markup).Children[1]
	end

	It("infinite speed falls back", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" speed="1e999"/>]])).Speed).toBe(0)
	end)

	It("negative infinite speed falls back", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" speed="-1e999"/>]])).Speed).toBe(0)
	end)

	It("huge speed clamped", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" speed="100"/>]])).Speed).toBe(4)
	end)

	It("huge negative speed clamped", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" speed="-100"/>]])).Speed).toBe(-4)
	end)

	It("normal speed kept", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" speed="1.5"/>]])).Speed).toBe(1.5)
	end)

	It("infinite rotation falls back", function()
		Expect(Gradient.Parse(Node([[<gradient colors="#f00,#00f" rotation="1e999"/>]])).Rotation).toBe(0)
	end)

	Describe("effect", function()
		const Style: any = {Effect = nil}

		BeforeAll(function()
			Effect.Apply(Style, Node([[<wave amplitude="1e999" frequency="-1e999"/>]]), {})
		end)

		It("infinite amplitude falls back", function()
			Expect(Style.Effect.Amplitude).toBe(2.5)
		end)

		It("infinite frequency falls back", function()
			Expect(Style.Effect.Frequency).toBe(6)
		end)
	end)

	It("gradient frames stay finite", function()
		const Target: TextLabel = Label([[<gradient colors="#f00,#00f" speed="1e999">hot</gradient> <gradient colors="#0f0,#00f" speed="50">cold</gradient>]], 300, 60, Screen)
		const Renderer: any = Create(Target)

		for _ = 1, 5 do Driver.Tick(Renderer, 0.05) end

		local Finite: boolean = true
		for _, Record: any in Renderer.Instances.Segments do
			const Shade: UIGradient? = Record.Decor.Gradient
			if not Shade then continue end

			for _, Point: ColorSequenceKeypoint in (Shade :: UIGradient).Color.Keypoints do
				if Point.Value.R ~= Point.Value.R or Point.Time ~= Point.Time then Finite = false end
			end
		end

		Renderer:Destroy()
		Target:Destroy()

		Expect(Finite).toBe(true)
	end)
end)

Describe("promotion respects budget", function()
	local Unit: any
	local Copy: ModuleScript
	local Holder: Frame
	local Waiting: Fake
	const Gated: { Fake } = {}
	const Order: { string } = {}

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(State: Fake): ()
			table.insert(Order, State.Name)
			Burn(1)
		end, math.max)
		Unit.SetBudget(0.5)

		Holder = Instance.new("Frame")
		Holder.Visible = false
		Holder.Parent = Screen

		Waiting = Fake("waiting", Screen)
		for Index = 1, 4 do Gated[Index] = Fake(`gated{Index}`, Holder) end
		for _, Entry: Fake in Gated do Unit.Queue(Entry, LAYOUT) end
		Unit.Queue(Waiting, LAYOUT)

		Holder.Visible = true
		for _, Entry: Fake in Gated do Unit.Touch(Entry) end
	end)

	AfterAll(function()
		Holder:Destroy()
		Waiting.Label:Destroy()
		Copy:Destroy()
	end)

	It("first promotion runs at once", function()
		Expect(table.concat(Order, ",")).toBe("gated1")
	end)

	for Index = 2, 4 do
		It(`promotion {Index} deferred`, function()
			Expect(Unit.Pending(Gated[Index])).toBe(LAYOUT)
		end)
	end

	It("everything ran", function()
		for _ = 1, 8 do Unit.Step() end

		Expect(#Order).toBe(5)
	end)

	It("promoted entries run before older visible work", function()
		Expect(Order[5]).toBe("waiting")
	end)

	It("queue empty", function()
		Expect(Unit.Pending(Waiting)).toBeNil()
	end)
end)

Describe("queue compaction", function()
	local Unit: any
	local Copy: ModuleScript
	local Anchor: Fake
	local Churn: Fake

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(): () end, math.max)
		Unit.SetBudget(0)

		Anchor = Fake("anchor", Screen)
		Churn = Fake("churn", Screen)
		Unit.Queue(Anchor, LAYOUT)

		for _ = 1, 2000 do
			Unit.Queue(Churn, LAYOUT)
			Unit.Take(Churn)
		end
	end)

	AfterAll(function()
		Anchor.Label:Destroy()
		Churn.Label:Destroy()
		Copy:Destroy()
	end)

	It("queue stays bounded while work is live", function()
		Expect(Unit.Size()).toBeLessThanOrEqual(256)
	end)

	It("anchor still queued", function()
		Expect(Unit.Pending(Anchor)).toBe(LAYOUT)
	end)

	It("anchor runs after compaction", function()
		Unit.Step()

		Expect(Unit.Pending(Anchor)).toBeNil()
	end)
end)

Describe("drain isolates failures", function()
	local Unit: any
	local Copy: ModuleScript
	local Fakes: { Fake }
	const Order: { string } = {}

	BeforeAll(function()
		Unit, Copy = Fresh()
		Unit.Bind(function(State: Fake): ()
			if State.Name == "bad" then error("lifecycle spec expected failure") end
			table.insert(Order, State.Name)
		end, math.max)
		Unit.SetBudget(0)

		Fakes = {Fake("first", Screen), Fake("bad", Screen), Fake("last", Screen)}
		for _, Entry: Fake in Fakes do Unit.Queue(Entry, LAYOUT) end
	end)

	AfterAll(function()
		for _, Entry: Fake in Fakes do Entry.Label:Destroy() end
		Copy:Destroy()
	end)

	It("drain survives a failing entry", function()
		Expect((pcall(Unit.Drain))).toBe(true)
	end)

	It("other entries still ran", function()
		table.sort(Order)

		Expect(table.concat(Order, ",")).toBe("first,last")
	end)
end)

Describe("layout ticket", function()
	const Original: any = Measure.Split
	local Target: TextLabel
	local Renderer: any
	local Held: thread? = nil
	local Parking: boolean = false
	local Ok: boolean
	local Error: any

	BeforeAll(function()
		Target = Label(PARAGRAPH, 300, 300, Screen)
		Renderer = Create(Target)

		Measure.Split = function(State: any, MaxWidth: number): any
			if State == Renderer and Parking then
				Parking = false
				Held = coroutine.running()
				coroutine.yield()
			end

			return Original(State, MaxWidth)
		end
	end)

	AfterAll(function()
		Measure.Split = Original
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("first layout parked", function()
		Ok, Error = pcall(function()
			Target.Size = UDim2.fromOffset(200, 300)
			const _Wide: Vector2 = Target.AbsoluteSize

			Parking = true
			task.spawn(function() Renderer:Flush() end)
			Parking = false
		end)

		Expect(Held).never.toBeNil()
	end)

	It("layout flow ran", function()
		if Ok then
			Ok, Error = pcall(function()
				Target.Size = UDim2.fromOffset(120, 300)
				const _Absolute: Vector2 = Target.AbsoluteSize
				Renderer:Flush()

				if Held then task.spawn(Held :: thread) end
			end)
		end
		Measure.Split = Original

		Expect(Problem(Ok, Error)).toBe("")
	end)

	It("stale layout never commits", function()
		local Widest: number = 0
		for _, Segment: TextLabel in Segments(Target) do Widest = math.max(Widest, Segment.Position.X.Offset + Segment.Size.X.Offset) end

		Expect(Widest).toBeLessThanOrEqual(122)
	end)

	It("width tracks newest layout", function()
		Expect(Renderer.Host.Width).toBe(120)
	end)
end)

Describe("bad custom effect dropped", function()
	local Target: TextLabel
	local Renderer: any
	local Busy: boolean = true

	BeforeAll(function()
		Target = Label([[<customclass><boom>bad</boom></customclass> <wave>good</wave> tail]], 400, 60, Screen)
		Renderer = Create(Target):AddCustomClasses({boom = {Kind = "Effect", Update = function(): () error("lifecycle spec expected effect failure") end}}):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("both effects moving", function()
		Expect(#Renderer.Animation.Moving).toBe(2)
	end)

	It("bad effect dropped", function()
		for Step = 1, 10 do Busy = Driver.Tick(Renderer, 0.05 + Step * 0.001) end

		Expect(#Renderer.Animation.Moving).toBe(1)
	end)

	It("label keeps animating", function()
		Expect(Busy).toBe(true)
	end)

	It("good effect still moves", function()
		const Good: any = Renderer.Animation.Moving[1]
		const Before: number = Good.Instance.Position.Y.Offset
		for Step = 1, 10 do Driver.Tick(Renderer, 0.1 + Step * 0.01) end

		Expect(Good.Instance.Position.Y.Offset ~= Before or Good.Instance.Position.Y.Offset ~= Good.Y).toBe(true)
	end)

	It("non finite offsets dropped", function()
		Renderer:AddCustomClass("nan", {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(0 / 0, 0) end}):Flush()
		Target.Text = [[<customclass><nan>nan</nan></customclass>]]
		Renderer:Flush()
		for _ = 1, 3 do Driver.Tick(Renderer, 0.05) end

		Expect(#Renderer.Animation.Moving).toBe(0)
	end)
end)

Describe("font failures fall back", function()
	local Target: TextLabel
	local Ok: boolean
	local Renderer: any

	BeforeAll(function()
		Target = Label([[<font face="NoSuchLifecycleFamily">broken</font> fine]], 300, 60, Screen)
		Ok, Renderer = pcall(Create, Target)
	end)

	AfterAll(function()
		if Ok then Renderer:Destroy() end
		Target:Destroy()
	end)

	It("renderer survives a failing font", function()
		Expect(Problem(Ok, Renderer)).toBe("")
	end)

	It("both words rendered", function()
		Expect(#Segments(Target)).toBe(2)
	end)

	It("token measured", function()
		for _, Token: any in Renderer.Document.Tokens do
			Expect(`{Token.Text} {Token.Width > 0}`).toBe(`{Token.Text} true`)
		end
	end)

	It("later refresh works", function()
		Renderer.Label.Text = [[<font face="NoSuchLifecycleFamily">still broken</font> fine]]
		Renderer:Flush()

		Expect(Renderer.Document.Source).toBe([[<font face="NoSuchLifecycleFamily">still broken</font> fine]])
	end)
end)

Describe("registry does not root states", function()
	const Names: { string } = {"destroyed", "foreign", "dropped", "taken"}
	const Labels: { [string]: TextLabel } = {}
	const States: { any } = {}
	local Successor: any

	const function Listed(State: any): boolean
		for _, Found: any in Registry.List() do
			if Found == State then return true end
		end

		return false
	end

	BeforeAll(function()
		for Index: number, Name: string in Names do
			Labels[Name] = Label(Name, 200, 40, Screen)
			States[Index] = Create(Labels[Name])
		end
	end)

	AfterAll(function()
		for _, Target: TextLabel in Labels do Target:Destroy() end
	end)

	for Index: number, Name: string in Names do
		It(`registered {Name}`, function()
			const State: any = States[Index]

			Expect(Listed(State) and Registry.Get(State.Label) == State).toBe(true)
		end)
	end

	for Index: number, Name: string in Names do
		It(`unreferenced state is collectable ({Name})`, function()
			if Index == 1 then
				States[1]:Destroy()
				Labels.foreign:SetAttribute(Attributes.Owner, "someone else")
				Labels.dropped:Destroy()
				Successor = Create(Labels.taken)

				Wait(1)
			end

			Expect(Listed(States[Index])).toBe(false)
		end)
	end

	It("destroyed renderer unregistered", function()
		Expect(Registry.Get(Labels.destroyed)).toBeNil()
	end)

	It("foreign owned renderer unregistered", function()
		Expect(Registry.Get(Labels.foreign)).toBeNil()
	end)

	It("developer destroyed label unregistered", function()
		Expect(Registry.Get(Labels.dropped)).toBeNil()
	end)

	It("takeover registers the successor", function()
		Expect(Registry.Get(Labels.taken)).toBe(Successor)
	end)

	It("successor unregistered", function()
		Successor:Destroy()

		Expect(Registry.Get(Labels.taken)).toBeNil()
	end)
end)
