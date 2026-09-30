--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Profiler = require("../Packages/RichTextPlus/Utility/Profiler")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const LogService = game:GetService("LogService")

const Mixed: string = [[<b>Welcome</b> to the <font color="#FF7800">arena</font>, traveler! Today we test <i>italic words</i>, <u>underlined phrases</u>, <mark color="#FFD000">marked words</mark> and a <a href="https://example.com">clickable link here</a>. The quick brown fox jumps over the lazy dog while text keeps going for a while.]]
const Animated: string = [[<gradient colors="#ff0000,#0000ff" speed="1">shiny words</gradient> and <wave>wavy</wave> text]]
const Document: string = [[<md>
# Title

Some **bold** text and `code`.

```lua
local Value = 1
print(Value)
```
</md>]]

const Expected: { string } = {
	"RTP:New", "RTP:Refresh", "RTP:Parse", "RTP:Flatten", "RTP:Native", "RTP:Measure", "RTP:Layout", "RTP:Split", "RTP:Lines",
	"RTP:Collect", "RTP:Place", "RTP:Pool", "RTP:Apply", "RTP:Backdrop", "RTP:Reveal", "RTP:Patch", "RTP:Scale", "RTP:Markdown", "RTP:Highlight",
	"RTP:CodeBlock", "RTP:Destroy", "RTP:Drain", "RTP:Cull", "RTP:Animate", "RTP:Frame", "RTP:Schedule", "RTP:Release",
}

const Optional: { string } = {"RTP:Glyphs", "RTP:Suppress", "RTP:Restore", "RTP:Reflow"}

const PIPELINE_RESULTS: number = 8

const Library: any = RichTextPlus
const Tracker: any = Profiler
const Begin: (Name: string) -> () = Tracker.Begin
const Seen: { [string]: number } = {}
local Warnings: number = 0
local Listener: RBXScriptConnection
local Screen: ScreenGui

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

const function Snapshot(Target: TextLabel): string
	const Parts: { string } = {}

	for _, Child: Instance in Target:GetDescendants() do
		if not Child:IsA("GuiObject") or not (Child :: GuiObject).Visible then continue end

		const Object: GuiObject = Child :: GuiObject
		const Text: string = if Object:IsA("TextLabel") or Object:IsA("TextButton") then (Object :: TextLabel).Text else Object.ClassName
		table.insert(Parts, `{Text}@{Object.Position.X.Offset},{Object.Position.Y.Offset}:{Object.Size.X.Offset}x{Object.Size.Y.Offset}`)
	end

	table.sort(Parts)

	return table.concat(Parts, "|")
end

const function Pipeline(): { string }
	const Results: { string } = {}

	const Target: TextLabel = Label(Mixed, 400, 300)
	const Renderer: any = Library.new(Target):Flush()
	table.insert(Results, Snapshot(Target))

	Renderer.Label.Text = (string.gsub(Mixed, "lazy dog", "sleepy cat"))
	Renderer:Flush()
	table.insert(Results, Snapshot(Target))

	Target.Size = UDim2.fromOffset(320, 300)
	const _Size: Vector2 = Target.AbsoluteSize
	Renderer:Flush()
	table.insert(Results, Snapshot(Target))

	Target.Size = UDim2.fromOffset(360, 300)
	Library.Runtime.Flush()
	table.insert(Results, Snapshot(Target))

	Renderer:Destroy()
	Target:Destroy()

	const Scaled: TextLabel = Label(Mixed, 260, 90)
	Scaled.TextScaled = true
	const Fitted: any = Library.new(Scaled):Flush()
	table.insert(Results, Snapshot(Scaled))
	Fitted:Destroy()
	Scaled:Destroy()

	const Markdown: TextLabel = Label(Document, 420, 300)
	const Rendered: any = Library.new(Markdown):Flush()
	table.insert(Results, Snapshot(Markdown))
	Rendered:Destroy()
	Markdown:Destroy()

	const Plain: TextLabel = Label("plain words only", 300, 40)
	const Native: any = Library.new(Plain):Flush()
	Native.Label.Text = "other plain words"
	Native:Flush()
	table.insert(Results, Plain.Text)
	Native:Destroy()
	Plain:Destroy()

	const Moving: TextLabel = Label(Animated, 400, 60)
	const Animator: any = Library.new(Moving):Flush()
	for _ = 1, 3 do Driver.Tick(Animator, 1 / 60) end
	table.insert(Results, tostring(#Moving:GetChildren()))
	Animator:Destroy()
	Moving:Destroy()

	return Results
end

const function Disable(): ()
	AfterAll(function()
		Tracker.Enabled = false
	end)
end

BeforeAll(function()
	Screen = Gui.new("Profiler")

	Tracker.Begin = function(Name: string): ()
		Seen[Name] = (Seen[Name] or 0) + 1
		Begin(Name)
	end

	Listener = LogService.MessageOut:Connect(function(Message: string)
		if string.find(Message, "profile annotation", 1, true) then Warnings += 1 end
	end)
end)

AfterAll(function()
	Listener:Disconnect()
	Tracker.Begin = Begin
	Tracker.Enabled = false
	Gui.Cleanup()
end)

Describe("api", function()
	Disable()

	It("SetProfiling exists", function()
		Expect(type(Library.Runtime.SetProfiling)).toBe("function")
	end)

	It("rejects string", function()
		Expect((pcall(Library.Runtime.SetProfiling, "on"))).toBe(false)
	end)

	It("rejects nil", function()
		Expect((pcall(Library.Runtime.SetProfiling, nil))).toBe(false)
	end)

	It("rejects number", function()
		Expect((pcall(Library.Runtime.SetProfiling, 1))).toBe(false)
	end)

	It("accepts true", function()
		Expect((pcall(Library.Runtime.SetProfiling, true))).toBe(true)
	end)

	It("enabled", function()
		Expect(Tracker.Enabled).toBe(true)
	end)

	It("accepts false", function()
		Expect((pcall(Library.Runtime.SetProfiling, false))).toBe(true)
	end)

	It("disabled", function()
		Expect(Tracker.Enabled).toBe(false)
	end)
end)

Describe("stack", function()
	Disable()

	const Depths: { [string]: number } = {}
	local Leftover: any

	BeforeAll(function()
		Depths.Empty = Tracker.Depth()

		Tracker.Begin("RTP:A")
		Tracker.Begin("RTP:B")
		Tracker.Begin("RTP:C")
		Depths.Three = Tracker.Depth()

		Tracker.Unwind(1)
		Depths.Unwound = Tracker.Depth()

		const Held: any = Tracker.Suspend()
		Depths.Suspended = Tracker.Depth()
		Tracker.Resume(Held)
		Depths.Resumed = Tracker.Depth()

		Tracker.End()
		Depths.Ended = Tracker.Depth()

		Tracker.End()
		Depths.Extra = Tracker.Depth()
		Leftover = Tracker.Suspend()
	end)

	It("starts empty", function()
		Expect(Depths.Empty).toBe(0)
	end)

	It("depth three", function()
		Expect(Depths.Three).toBe(3)
	end)

	It("unwind to one", function()
		Expect(Depths.Unwound).toBe(1)
	end)

	It("suspend clears", function()
		Expect(Depths.Suspended).toBe(0)
	end)

	It("resume restores", function()
		Expect(Depths.Resumed).toBe(1)
	end)

	It("end closes", function()
		Expect(Depths.Ended).toBe(0)
	end)

	It("extra end ignored", function()
		Expect(Depths.Extra).toBe(0)
	end)

	It("suspend empty", function()
		Expect(Leftover).toBeNil()
	end)
end)

Describe("await", function()
	Disable()

	local Sum: number
	local Word: string
	local AsyncDepth: number
	local ErrorDepth: number

	BeforeAll(function()
		Sum, Word = Tracker.Await(function(Left: number, Right: number): (number, string) return Left + Right, "done" end, 2, 3)
	end)

	It("sync first result", function()
		Expect(Sum).toBe(5)
	end)

	It("sync second result", function()
		Expect(Word).toBe("done")
	end)

	It("async result", function()
		Tracker.Begin("RTP:Await")
		const Late: number = Tracker.Await(function(): number
			task.wait()
			return 7
		end)
		AsyncDepth = Tracker.Depth()
		Tracker.End()

		Expect(Late).toBe(7)
	end)

	It("async keeps label", function()
		Expect(AsyncDepth).toBe(1)
	end)

	It("sync error propagates", function()
		const Ok: boolean, Problem: any = pcall(Tracker.Await, function() error("boom", 0) end)

		Expect(not Ok and Problem == "boom").toBe(true)
	end)

	It("async error propagates", function()
		Tracker.Begin("RTP:Await")
		const Ok: boolean, Problem: any = pcall(Tracker.Await, function()
			task.wait()
			error("late", 0)
		end)
		ErrorDepth = Tracker.Depth()
		Tracker.End()

		Expect(not Ok and Problem == "late").toBe(true)
	end)

	It("async error keeps label", function()
		Expect(ErrorDepth).toBe(1)
	end)

	It("gather keeps label", function()
		Tracker.Begin("RTP:Gather")
		Measure.Gather({function() task.wait() end, function() task.wait() end})
		const Depth: number = Tracker.Depth()
		Tracker.End()

		Expect(Depth).toBe(1)
	end)

	It("balanced", function()
		Expect(Tracker.Depth()).toBe(0)
	end)
end)

Describe("off by default", function()
	Disable()

	It("default flag", function()
		table.clear(Seen)

		Expect(Tracker.Enabled).toBe(false)
	end)

	It("no labels when off", function()
		Pipeline()
		for _ = 1, 3 do task.wait() end

		Expect((next(Seen))).toBeNil()
	end)
end)

Describe("pipeline", function()
	Disable()

	local Plain: { string }
	local Profiled: { string }

	BeforeAll(function()
		Plain = Pipeline()

		table.clear(Seen)
		Library.Runtime.SetProfiling(true)

		Profiled = Pipeline()

		const Target: TextLabel = Label(Animated, 400, 60)
		const Renderer: any = Library.new(Target):Flush()
		for _ = 1, 4 do task.wait() end
		Target.Size = UDim2.fromOffset(300, 60)
		for _ = 1, 4 do task.wait() end
		Renderer:Destroy()
		Target:Destroy()

		for _, Family: string in {"IndieFlower", "PatrickHand", "Sarpanch"} do
			const Cold: TextLabel = Label(`<b>Cold</b> {Family} words, <i>italic</i> and a <a href="x">link</a> ÀÉÎ ΑΒΓ`, 300, 60)
			Cold.FontFace = Font.new(`rbxasset://fonts/families/{Family}.json`)

			Library.new(Cold):Destroy()
			Cold:Destroy()
		end

		Library.Runtime.SetProfiling(false)
	end)

	It("depth balanced", function()
		Expect(Tracker.Depth()).toBe(0)
	end)

	It("result count", function()
		Expect(#Profiled).toBe(#Plain)
	end)

	for Index = 1, PIPELINE_RESULTS do
		It(`same output {Index}`, function()
			Expect(Profiled[Index]).toBe(Plain[Index])
		end)
	end

	for _, Name: string in Expected do
		It(`label {Name}`, function()
			Expect(Seen[Name] or 0).toBeGreaterThan(0)
		end)
	end

	It("known label", function()
		for Name: string in Seen do
			Expect(`{Name} {tostring(table.find(Expected, Name) ~= nil or table.find(Optional, Name) ~= nil)}`).toBe(`{Name} true`)
		end
	end)
end)

It("no unbalanced profile warnings", function()
	for _ = 1, 3 do task.wait() end

	Expect(Warnings).toBe(0)
end)
