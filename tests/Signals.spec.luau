--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Signal = require("../Packages/RichTextPlus/Utility/Signal")
const Segment = require("../Packages/RichTextPlus/Render/Segment")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Signals: any = Signal
local Screen: ScreenGui

const function Wait(Count: number): ()
	for _ = 1, Count do task.wait() end
end

const function Errors(Body: () -> ()): string
	const Ok: boolean, Error: any = pcall(Body)

	return if Ok then "" else tostring(Error)
end

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(320, 120)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Links(Renderer: any): { any }
	const Found: { any } = {}

	for _, Record: any in Renderer.Instances.Records do
		if Record.Element then table.insert(Found, Record) end
	end

	return Found
end

const function Plain(Renderer: any): any
	for _, Record: any in Renderer.Instances.Records do
		if not Record.Element then return Record end
	end

	return nil
end

const function Contains(Haystack: string, Needle: string): boolean
	return string.find(Haystack, Needle, 1, true) ~= nil
end

BeforeAll(function()
	Screen = Gui.new("Signals")
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("signal connect and fire", function()
	const Subject: any = Signals.new()
	const Seen: { any } = {}

	BeforeAll(function()
		Subject:Connect(function(Left: string, Right: number) table.insert(Seen, {Left, Right}) end)
		Subject:Connect(function() table.insert(Seen, "second") end)
		Subject:Fire("a", 1)
	end)

	It("fire is deferred", function()
		Expect(#Seen).toBe(0)
	end)

	It("both handlers ran", function()
		Wait(1)

		Expect(#Seen).toBe(2)
	end)

	It("arguments pass through", function()
		Expect(type(Seen[1]) == "table" and Seen[1][1] == "a" and Seen[1][2] == 1).toBe(true)
	end)

	It("handlers run in connect order", function()
		Expect(Seen[2]).toBe("second")
	end)

	It("rejects non-function handlers", function()
		Expect(Errors(function() Subject:Connect(nil) end)).never.toBe("")
	end)
end)

Describe("signal disconnect", function()
	const Subject: any = Signals.new()
	local Count: number = 0
	local Connection: any

	BeforeAll(function()
		Connection = Subject:Connect(function() Count += 1 end)
	end)

	It("connected", function()
		Expect(Connection.Connected).toBe(true)
	end)

	It("disconnect before the deferred run cancels it", function()
		Subject:Fire()
		Connection:Disconnect()
		Wait(1)

		Expect(Count).toBe(0)
	end)

	It("disconnected", function()
		Expect(Connection.Connected).toBe(false)
	end)

	It("disconnect is idempotent", function()
		Connection:Disconnect()
		Subject:Fire()
		Wait(1)

		Expect(Count).toBe(0)
	end)

	It("handler list emptied", function()
		Expect(#Subject.Handlers).toBe(0)
	end)
end)

Describe("signal once", function()
	const Subject: any = Signals.new()
	local Count: number = 0
	local Value: any = nil
	local Connection: any

	BeforeAll(function()
		Connection = Subject:Once(function(Given: any)
			Count += 1
			Value = Given
		end)

		Subject:Fire("first")
		Subject:Fire("second")
		Wait(1)
	end)

	It("once runs one time", function()
		Expect(Count).toBe(1)
	end)

	It("once gets the first fire", function()
		Expect(Value).toBe("first")
	end)

	It("once disconnects", function()
		Expect(Connection.Connected).toBe(false)
	end)

	It("once leaves no handler", function()
		Expect(#Subject.Handlers).toBe(0)
	end)
end)

Describe("signal wait", function()
	const Subject: any = Signals.new()
	local Received: { any }? = nil

	It("wait yields", function()
		task.spawn(function() Received = {Subject:Wait()} end)

		Expect(Received).toBeNil()
	end)

	It("wait returns the fired values", function()
		Subject:Fire("href", "text")
		Wait(2)

		Expect(Received ~= nil and (Received :: { any })[1] == "href" and (Received :: { any })[2] == "text").toBe(true)
	end)

	It("wait leaves no handler", function()
		Expect(#Subject.Handlers).toBe(0)
	end)
end)

Describe("signal disconnect all and destroy", function()
	const Subject: any = Signals.new()
	local Count: number = 0
	local First: any
	local Second: any
	local Late: any

	BeforeAll(function()
		First = Subject:Connect(function() Count += 1 end)
		Second = Subject:Connect(function() Count += 1 end)
	end)

	It("disconnect all stops handlers", function()
		Subject:DisconnectAll()
		Subject:Fire()
		Wait(1)

		Expect(Count).toBe(0)
	end)

	It("disconnect all flags connections", function()
		Expect(not First.Connected and not Second.Connected).toBe(true)
	end)

	It("destroy cancels pending handlers", function()
		Subject:Connect(function() Count += 1 end)
		Subject:Fire()
		Subject:Destroy()
		Wait(1)

		Expect(Count).toBe(0)
	end)

	It("destroyed signal never fires", function()
		Late = Subject:Connect(function() Count += 1 end)
		Subject:Fire()
		Wait(1)

		Expect(Count).toBe(0)
	end)

	It("connect after destroy is disconnected", function()
		Expect(Late.Connected).toBe(false)
	end)
end)

Describe("yielding handler isolation", function()
	const Subject: any = Signals.new()
	local Resumed: boolean = false
	local Other: boolean = false

	BeforeAll(function()
		Subject:Connect(function()
			task.wait(0.25)
			Resumed = true
		end)
		Subject:Connect(function() Other = true end)

		Subject:Fire()
	end)

	It("other handler runs while one yields", function()
		Wait(1)

		Expect(Other).toBe(true)
	end)

	It("yielding handler still suspended", function()
		Expect(Resumed).toBe(false)
	end)

	It("yielding handler finishes", function()
		task.wait(0.4)

		Expect(Resumed).toBe(true)
	end)
end)

Describe("removed options table", function()
	local Target: TextLabel
	local Message: string
	local Renderer: any

	BeforeAll(function()
		Target = Label("text")
		Message = Errors(function() Library.new(Target, {OnLinkClicked = function() end}) end)
		Renderer = Library.new(Target):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("options table errors", function()
		Expect(Message).toContain("RichTextPlus.new takes only the label")
	end)

	It("error names the setters", function()
		Expect(Contains(Message, "SetIntents") and Contains(Message, "AddCustomClass")).toBe(true)
	end)

	It("reading OnLinkClicked points at Bind", function()
		Expect(Errors(function() return Renderer.OnLinkClicked end)).toContain('Renderer:Bind("a"')
	end)

	It("assigning OnLinkClicked points at Bind", function()
		Expect(Errors(function() Renderer.OnLinkClicked = function() end end)).toContain('Renderer:Bind("a"')
	end)

	It("unknown renderer fields stay nil", function()
		Expect(Renderer.NotAField).toBeNil()
	end)

	It("Links points at Bind", function()
		Expect(Errors(function() return Renderer.Links end)).toContain('Renderer:Bind("a"')
	end)

	It("Links names the element reads", function()
		Expect(Errors(function() return Renderer.Links.Clicked end)).toContain('Element:GetAttribute("href")')
	end)

	It("old LinkClicked points at Activated", function()
		Expect(Errors(function() return Renderer.LinkClicked end)).toContain("Activated")
	end)

	It("old LinkHovered points at HoverChanged", function()
		Expect(Errors(function() return Renderer.LinkHovered end)).toContain("HoverChanged")
	end)

	It("old LinkLeft points at HoverChanged", function()
		Expect(Errors(function() return Renderer.LinkLeft end)).toContain("HoverChanged")
	end)
end)

Describe("link activated through the segment path", function()
	local Target: TextLabel
	local Renderer: any
	local Records: { any }
	local Href: string? = nil
	local Text: string? = nil
	local Count: number = 0

	BeforeAll(function()
		Target = Label([[read <a href="rules">the rules</a> now]])
		Renderer = Library.new(Target):SetPreset("Trusted"):Flush()
		Renderer:Flush()
		Records = Links(Renderer)

		Renderer:Bind("a", {
			Activated = function(Element: any)
				Count += 1
				Href = Element:GetAttribute("href")
				Text = Element.Text
			end,
		})
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("link segments exist", function()
		Expect(#Records).toBeGreaterThan(0)
	end)

	It("click is deferred", function()
		Segment.Activate(Records[1])

		Expect(Count).toBe(0)
	end)

	It("click fires once", function()
		Wait(1)

		Expect(Count).toBe(1)
	end)

	It("href", function()
		Expect(Href).toBe("rules")
	end)

	It("text", function()
		Expect(Text).toBe("the rules")
	end)

	It("plain segments never fire", function()
		const Other: any = Plain(Renderer)
		if Other then Segment.Activate(Other) end
		Wait(1)

		Expect(Count).toBe(1)
	end)

	It("link hidden by the reveal", function()
		Target.MaxVisibleGraphemes = 0
		Renderer:Flush()
		Wait(2)

		Expect(Records[1].Content.Revealed).toBe(0)
	end)

	It("hidden link reports not visible", function()
		Expect(Renderer:QueryFirst("a").State.Visible).toBe(false)
	end)

	It("hidden links do not fire", function()
		Segment.Activate(Records[1])
		Wait(1)

		Expect(Count).toBe(1)
	end)
end)

Describe("link hover and leave", function()
	local Target: TextLabel
	local Renderer: any
	const Seen: { string } = {}
	local First: any = nil
	local Second: any = nil

	BeforeAll(function()
		Target = Label([[<a href="one">first</a> and <a href="two">second</a>]])
		Renderer = Library.new(Target):SetPreset("Trusted"):Flush()

		Renderer:Bind("a", {
			HoverChanged = function(Element: any, Hovering: boolean)
				table.insert(Seen, `{if Hovering then "hover" else "leave"} {Element:GetAttribute("href")}`)
			end,
		})
		Renderer:Flush()

		for _, Record: any in Links(Renderer) do
			if Record.Element:GetAttribute("href") == "one" then First = Record else Second = Record end
		end
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("both links built", function()
		Expect(First ~= nil and Second ~= nil).toBe(true)
	end)

	It("crossing segments of one link reports one hover", function()
		Segment.Enter(First)
		Segment.Leave(First)
		Segment.Enter(First)
		Wait(2)

		Expect(table.concat(Seen, ",")).toBe("hover one")
	end)

	It("hovered state set", function()
		Expect(First.Element.State.Hovered).toBe(true)
	end)

	It("leaving fires left", function()
		Segment.Leave(First)
		Wait(2)

		Expect(table.concat(Seen, ",")).toBe("hover one,leave one")
	end)

	It("moving to another link", function()
		table.clear(Seen)
		Segment.Enter(First)
		Segment.Enter(Second)
		Segment.Leave(First)
		Wait(2)

		Expect(table.concat(Seen, ",")).toBe("hover one,leave one,hover two")
	end)

	It("the dropped element is no longer hovered", function()
		const Kept: any = Second.Element
		Renderer.Label.Text = [[<a href="three">third</a>]]
		Renderer:Flush()
		Segment.Leave(Links(Renderer)[1])
		Wait(2)

		Expect(Kept.State.Hovered).toBe(false)
	end)
end)

Describe("cleanup on destroy", function()
	local Target: TextLabel
	local Renderer: any
	local Record: any
	local Element: any
	local Count: number = 0
	local Binding: any
	local Direct: any

	BeforeAll(function()
		Target = Label([[<a href="x">link</a>]])
		Renderer = Library.new(Target):SetPreset("Trusted"):Flush()
		Renderer:Flush()

		Record = Links(Renderer)[1]
		Element = Renderer:QueryFirst("a")
		Binding = Renderer:Bind("a", {Activated = function() Count += 1 end, HoverChanged = function() Count += 1 end})
		Direct = Element.Activated:Connect(function() Count += 1 end)

		Segment.Activate(Record)
		Renderer:Destroy()
		Wait(1)
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("pending activation dropped on destroy", function()
		Expect(Count).toBe(0)
	end)

	It("bindings disconnected", function()
		Expect(Binding.Connected).toBe(false)
	end)

	It("element signals disconnected", function()
		Expect(Direct.Connected).toBe(false)
	end)

	It("no bindings kept", function()
		Expect(#Renderer.Elements.Bindings).toBe(0)
	end)

	It("pointer released", function()
		Expect(Renderer.Elements.Pointer.Element).toBeNil()
	end)

	It("no fire after destroy", function()
		Segment.Activate(Record)
		Element.Activated:Fire()
		Wait(1)

		Expect(Count).toBe(0)
	end)
end)

Describe("cleanup on label destroy and takeover", function()
	local Target: TextLabel
	local Connection: any
	local Successor: any

	BeforeAll(function()
		Target = Label([[<a href="x">link</a>]])
		const Renderer: any = Library.new(Target):SetPreset("Trusted"):Flush()
		Connection = Renderer:Bind("a", {Activated = function() end})
		Successor = Library.new(Target):SetPreset("Trusted"):Flush()
	end)

	It("takeover disconnects the old renderer", function()
		Expect(Connection.Connected).toBe(false)
	end)

	It("label destroy disconnects", function()
		const Next: any = Successor:Bind("a", {Activated = function() end})
		Target:Destroy()
		Wait(3)
		Library.Runtime.Flush()

		Expect(Next.Connected).toBe(false)
	end)
end)
