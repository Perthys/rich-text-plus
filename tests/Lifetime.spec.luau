--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Lifetime = require("../Packages/RichTextPlus/Utility/Lifetime")
const Attributes = require("../Packages/RichTextPlus/Utility/Attributes")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Tracked = {
	Kind: string,
	State: any,
	Successor: any,
	Label: TextLabel,
	Objects: { GuiObject },
	Records: { any },
}

const WHITE: Color3 = Color3.new(1, 1, 1)
const ROUNDS: number = 3
const POOL_NAME: string = "RichTextPlusPool"

const Samples: { string } = {
	"plain words for the segment and native paths",
	[[<b>bold</b> <i>italic</i> <u>under</u> <s>struck</s> <font color="#ff7800" size="22">sized</font>]],
	[[<a href="first">first link</a> and <a href="second">second <b>link</b></a>]],
	[[<gradient colors="#f00,#0f0,#00f" speed="1">moving gradient</gradient> <gradient colors="#fff,#000">static</gradient>]],
	[[<wave amplitude="3">wave</wave> <shake>shake</shake> <customclass><spin>custom</spin></customclass>]],
	[[<mark color="#ffff00">marked</mark> <stroke color="#00a2ff" thickness="2">stroked</stroke> <uc>upper</uc>]],
	"<codeblock lang=\"lua\">local Value = 1\nprint(Value)</codeblock>after code",
	"<md># Title\n**bold** and `code`\n\n```lua\nlocal x = 1\n```\n- item</md>",
	[[<customclass><icon/> icon <tint>tinted</tint> <boxed>boxed</boxed></customclass>]],
	[[<img src="rbxassetid://1" width="16" height="16"/> image <hr/> ruled]],
	"Pneumonoultramicroscopicsilicovolcanoconiosis_Pneumonoultramicroscopicsilicovolcanoconiosis_overflows",
}

const Teardowns: { string } = {"Destroy", "Label", "Takeover", "Owner", "Ancestor"}

const Exercised: { string } = {
	"Animate.Paces", "Culling.Holders", "Culling.Views", "Flatten.Bases", "Flatten.Interned", "Flatten.Tokenizers", "Lines.Sheets",
	"Measure.Sheets", "Measure.Splits", "Native.Remembered", "Pool.Works", "Reflow.Entries", "Reflow.Scratches", "Scale.Brackets",
	"Scale.Memos", "Schedule.Parked", "Shape.Memories",
}

const Library: any = RichTextPlus
local Screen: ScreenGui
local Baseline: { [string]: number }

const function Wait(Count: number): ()
	for _ = 1, Count do task.wait() end
end

const function Settle(): ()
	Wait(2)
	Library.Runtime.Flush()
	Wait(2)
end

const function Label(Text: string, Parent: Instance, Scaled: boolean): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(320, if Scaled then 60 else 160)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextScaled = Scaled
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = WHITE
	Created.Text = Text
	Created.Parent = Parent

	return Created
end

const function Icon(): GuiObject
	const Created: Frame = Instance.new("Frame")
	Created.Size = UDim2.fromOffset(12, 12)

	return Created
end

const CustomClasses: { [string]: any } = {
	Icon = {Kind = "Object", Build = function(): GuiObject return Icon() end},
	Tint = {Kind = "Style", Apply = function(Style: any) Style.Color = Color3.new(1, 0, 0) end},
	Boxed = {Kind = "Container", Wrap = function(): GuiObject return Icon() end},
	Slow = {Kind = "Object", Build = function(): GuiObject
		task.wait()
		return Icon()
	end},
	Spin = {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(math.sin(Frame.Time * 4) * 2, 0) end},
}

const function Build(Target: TextLabel): any
	return Library.new(Target):SetRendering("Passthrough", false):AddCustomClasses(CustomClasses):Flush()
end

const function Create(Kind: string, Text: string, Parent: Instance, Mode: number): Tracked
	const Target: TextLabel = Label(Text, Parent, Mode == 3)

	if Mode == 2 then
		const Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.Thickness = 1
		Stroke.Parent = Target
	end

	const Renderer: any = Library.new(Target):SetRendering("Passthrough", Mode == 1):AddCustomClasses(CustomClasses):Flush()

	return {Kind = Kind, State = Renderer, Successor = nil, Label = Target, Objects = {}, Records = {}}
end

const function Exercise(Entry: Tracked): ()
	const Renderer: any = Entry.State

	for Step = 1, 4 do Driver.Tick(Renderer, 1 / 60 + Step * 0.001) end

	Renderer.Label.Text = Entry.Label.Text .. " more"
	Renderer:Flush()
	Renderer:Flush()
	Entry.Label.TextSize = 19

	for Step = 1, 2 do Driver.Tick(Renderer, 1 / 30 + Step * 0.001) end

	for _, Token: any in Renderer.Document.Tokens do
		if Token.Object then table.insert(Entry.Objects, Token.Object) end
	end

	for _, List: { any } in {Renderer.Instances.Segments, Renderer.Instances.Spare} do
		for _, Record: any in List do table.insert(Entry.Records, Record) end
	end
end

const function Held(Key: any): string
	return table.concat(Lifetime.Holding(Key), ",")
end

const function Release(Entry: Tracked): ()
	const Kind: string = Entry.Kind
	const Renderer: any = Entry.State
	const Target: TextLabel = Entry.Label

	if Kind == "Destroy" then
		Renderer:Destroy()
	elseif Kind == "Label" then
		Target:Destroy()
	elseif Kind == "Takeover" then
		const Successor: any = Library.new(Target):SetRendering("Passthrough", false):Flush()
		Entry.Successor = Successor
		Expect(`takeover retires the prior renderer: {tostring(Renderer.Destroyed)}`).toBe("takeover retires the prior renderer: true")
		Driver.Tick(Successor, 1 / 60)
		Successor:Destroy()
	elseif Kind == "Owner" then
		Target:SetAttribute(Attributes.Owner, "foreign")
		Wait(1)
		Expect(`foreign owner revokes ownership: {tostring(Renderer.Destroyed)}`).toBe("foreign owner revokes ownership: true")
	end
end

const function Clean(Entries: { Tracked }): ()
	for _, Entry: Tracked in Entries do
		if Entry.Label.Parent then Entry.Label:Destroy() end
	end
end

const function Released(Tag: string, Key: any): ()
	Expect(`{Tag}: {Held(Key)}`).toBe(`{Tag}: `)
end

const function Compare(Name: string): ()
	const Current: { [string]: number } = Lifetime.Counts()

	for Table: string, Count: number in Baseline do
		Expect(`{Name}: {Table} {tostring(Current[Table])}`).toBe(`{Name}: {Table} {Count}`)
	end

	for Table: string in Current do
		Expect(`{Name}: {Table} known at baseline {tostring(Baseline[Table] ~= nil)}`).toBe(`{Name}: {Table} known at baseline true`)
	end
end

const function Verify(Name: string, Entries: { Tracked }): ()
	for Index: number, Entry: Tracked in Entries do
		const Tag: string = `{Name} {Entry.Kind} #{Index}`

		Released(`{Tag} state released`, Entry.State)
		Released(`{Tag} label released`, Entry.Label)
		if Entry.Successor then Released(`{Tag} successor released`, Entry.Successor) end

		for _, Object: GuiObject in Entry.Objects do Released(`{Tag} object {Object.Name} released`, Object) end

		for _, Record: any in Entry.Records do
			const Parent: Instance? = Record.Instance.Parent
			if not (Parent and Parent.Name == POOL_NAME) then continue end

			Expect(`{Tag} pooled record owner cleared {tostring(Record.Owner)}`).toBe(`{Tag} pooled record owner cleared nil`)
			Expect(`{Tag} pooled record motion cleared {tostring(Record.Motion)}`).toBe(`{Tag} pooled record motion cleared nil`)
			Expect(`{Tag} pooled record decoration sources cleared {#Record.Decoration.Sources}`).toBe(`{Tag} pooled record decoration sources cleared 0`)
		end
	end
end

BeforeAll(function()
	Screen = Gui.new("Lifetime")
	Settle()
	Baseline = Lifetime.Counts()
end)

AfterAll(function()
	Gui.Cleanup()
	Settle()
end)

Describe("tracked tables", function()
	for _, Name: string in {"Registry.Active", "Flatten.Contexts", "Classes.Owned", table.unpack(Exercised)} do
		It(`{Name} tracked`, function()
			Expect(Baseline[Name]).never.toBeNil()
		end)
	end
end)

for Round = 1, ROUNDS do
	Describe(`round {Round}`, function()
		local Holder: Frame
		local Live: { [string]: number }
		local Created: number
		const Entries: { Tracked } = {}
		const Nested: { Tracked } = {}

		BeforeAll(function()
			Holder = Instance.new("Frame")
			Holder.Size = UDim2.fromScale(1, 1)
			Holder.BackgroundTransparency = 1
			Holder.Parent = Screen

			for Index: number, Text: string in Samples do
				for Mode = 1, 3 do
					const Kind: string = Teardowns[(Index + Mode + Round) % #Teardowns + 1]
					const Entry: Tracked = Create(Kind, Text, if Kind == "Ancestor" then Holder else Screen, Mode)

					Exercise(Entry)
					table.insert(if Kind == "Ancestor" then Nested else Entries, Entry)
				end
			end

			Settle()

			Live = Lifetime.Counts()
			Created = #Entries + #Nested
		end)

		AfterAll(function()
			Holder:Destroy()
			Clean(Entries)
		end)

		It(`round {Round} registers every renderer`, function()
			Expect(Live["Registry.Active"]).toBeGreaterThanOrEqual(Baseline["Registry.Active"] + Created)
		end)

		It(`round {Round} flatten contexts live`, function()
			Expect(Live["Flatten.Contexts"]).toBeGreaterThanOrEqual(Baseline["Flatten.Contexts"] + Created)
		end)

		It(`round {Round} custom classes owned`, function()
			Expect(Live["Classes.Owned"]).toBeGreaterThanOrEqual(Baseline["Classes.Owned"] + Created)
		end)

		for _, Name: string in Exercised do
			It(`round {Round} exercises {Name}`, function()
				Expect(Live[Name]).toBeGreaterThan(Baseline[Name])
			end)
		end

		It(`round {Round} native path exercised`, function()
			local Natives: number = 0
			for _, Entry: Tracked in Entries do
				if Entry.State.Native.Active then Natives += 1 end
			end
			for _, Entry: Tracked in Nested do
				if Entry.State.Native.Active then Natives += 1 end
			end

			Expect(Natives).toBeGreaterThan(0)
		end)

		It(`round {Round} takeover and foreign owner teardowns retire renderers`, function()
			for _, Entry: Tracked in Entries do Release(Entry) end
		end)

		It(`round {Round} released`, function()
			Holder:Destroy()
			Settle()

			Verify(`round {Round}`, Entries)
		end)

		It(`round {Round} ancestor released`, function()
			Verify(`round {Round} ancestor`, Nested)
		end)

		It(`round {Round} back to baseline`, function()
			Clean(Entries)
			Settle()

			Compare(`round {Round}`)
		end)
	end)
end

Describe("destroyed mid flatten", function()
	local Spawned: TextLabel
	local Target: TextLabel
	local Renderer: any
	local Early: any = nil
	local Finished: boolean = false

	It("construction yields inside the class build", function()
		Spawned = Label("<customclass><slow/> spawned</customclass>", Screen, false)

		task.spawn(function() Early = Build(Spawned) end)
		const Yielded: boolean = Early == nil
		Spawned:Destroy()

		Expect(Yielded).toBe(true)
	end)

	It("text change yields inside the class build", function()
		Target = Label("ready", Screen, false)
		Renderer = Build(Target)

		task.spawn(function()
			Renderer.Label.Text = "<customclass><slow/> late</customclass>"
			Renderer:Flush()
			Finished = true
		end)
		const Yielded: boolean = not Finished
		Renderer:Destroy()

		Expect(Yielded).toBe(true)
	end)

	It("spawned renderer returned", function()
		Wait(4)
		Settle()

		Expect(Early).never.toBeNil()
	end)

	It("yielding text change finished", function()
		Expect(Finished).toBe(true)
	end)

	It("spawned renderer released", function()
		Expect(if Early then Held(Early) else nil).toBe("")
	end)

	It("yielding renderer released", function()
		Expect(Held(Renderer)).toBe("")
	end)

	It("spawned label released", function()
		Expect(Held(Spawned)).toBe("")
	end)

	It("yielding label released", function()
		Expect(Held(Target)).toBe("")
	end)

	It("mid flatten back to baseline", function()
		Target:Destroy()
		Settle()

		Compare("mid flatten")
	end)
end)

Describe("foreign owner releases queued work", function()
	local Hidden: ScreenGui
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Hidden = Gui.new("LifetimeHidden")
		Hidden.Enabled = false

		Target = Label("queued <b>work</b>", Hidden, false)
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()

		Target.TextSize = 24
		Wait(1)
	end)

	It("work waits behind a disabled gui", function()
		Expect(table.find(Lifetime.Holding(Renderer), "Schedule.Entries")).never.toBeNil()
	end)

	It("foreign owner detected", function()
		Target:SetAttribute(Attributes.Owner, "foreign")
		Wait(1)

		Expect(Renderer.Destroyed).toBe(true)
	end)

	It("foreign owner releases the renderer", function()
		Expect(Held(Renderer)).toBe("")
	end)

	It("foreign owned renderer stays released", function()
		Hidden:Destroy()
		Settle()

		Expect(Held(Renderer)).toBe("")
	end)

	It("foreign owned label released", function()
		Expect(Held(Target)).toBe("")
	end)

	It("foreign owner back to baseline", function()
		Compare("foreign owner")
	end)
end)

Describe("public calls after destroy stay inert", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label([[<b>dead</b> <wave>renderer</wave> <codeblock>x</codeblock>]], Screen, true)
		Renderer = Build(Target)

		Renderer:Destroy()

		Renderer:Flush()
		Renderer:Flush()
		Renderer:AddCustomClass("late", {Kind = "Object", Build = function(): GuiObject return Icon() end}):Flush()
		Renderer:AddCustomClass("spin", CustomClasses.Spin):Flush()
		Renderer:SetRendering("Culling", false):Flush()
		Renderer:SetPreset("Chat"):Flush()
		Renderer.Label.Text = "<i>after</i>"
		Renderer:Flush()
		Renderer:Rebuild()
		Driver.Tick(Renderer, 1 / 60)
		Renderer:GetGraphemeCount()
		Renderer:Flush()

		Settle()
	end)

	It("destroyed renderer holds nothing", function()
		Expect(Held(Renderer)).toBe("")
	end)

	It("destroyed label holds nothing", function()
		Expect(Held(Target)).toBe("")
	end)

	It("no segments recreated", function()
		local Segments: number = 0
		for _, Child: Instance in Target:GetChildren() do
			if Child:GetAttribute(Attributes.Marker) then Segments += 1 end
		end

		Expect(Segments).toBe(0)
	end)

	It("after destroy back to baseline", function()
		Target:Destroy()
		Settle()

		Compare("after destroy")
	end)
end)
