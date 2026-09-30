--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Schedule = require("../Packages/RichTextPlus/Render/Schedule")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Mounted = { Target: TextLabel, Renderer: any }

const API: any = RichTextPlus
const MeasureModule: any = Measure

const Link: string = [[ <a href="x">link</a>]]
const Lead: string = [[<a href="x">link</a> ]]

local Screen: ScreenGui
const Renderers: { any } = {}

const function Settle(): ()
	task.wait()
	API.Runtime.Flush()
end

const function Count(Text: string, Part: string): number
	local Found: number = 0
	local From: number = 1

	while true do
		const Start: number?, Stop: number? = string.find(Text, Part, From, true)
		if not Start then return Found end

		Found += 1
		From = (Stop :: number) + 1
	end
end

const function Label(Text: string, Parent: Instance?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 200)
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

const function Build(Target: TextLabel): any
	const Renderer: any = API.new(Target):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Mount(Text: string, Parent: Instance?): Mounted
	const Target: TextLabel = Label(Text, Parent)

	return {Target = Target, Renderer = Build(Target)}
end

const function Hidden(Visible: boolean): Frame
	const Holder: Frame = Instance.new("Frame")
	Holder.Size = UDim2.fromOffset(400, 200)
	Holder.BackgroundTransparency = 1
	Holder.Visible = Visible
	Holder.Parent = Screen

	return Holder
end

const function Joined(Target: TextLabel): string
	const Parts: { string } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Parts, (Child :: TextLabel).Text) end
	end

	return table.concat(Parts, "|")
end

const function Single(Name: string, Current: () -> Mounted, Expected: string): ()
	It(`{Name} leaves native`, function()
		Expect(Current().Renderer.Native.Active).toBeFalsy()
	end)

	It(`{Name} source`, function()
		Expect(Current().Renderer.Document.Source).toBe(Expected)
	end)

	It(`{Name} host text`, function()
		Expect(Current().Target.Text).toBe(Expected)
	end)

	It(`{Name} renders the link once`, function()
		Expect(Count(Joined(Current().Target), "link")).toBe(1)
	end)
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("FixAppend")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("segment switch applies an edit once", function()
	AfterAll(Release)

	Describe("append", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
		end)

		It("append starts native", function()
			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		Describe("edited", function()
			BeforeAll(function()
				State.Target.Text ..= Link
				Settle()
			end)

			Single("append", function() return State end, "bold &gt; text" .. Link)

			It("append stays settled", function()
				Settle()

				Expect(State.Renderer.Document.Source).toBe("bold &gt; text" .. Link)
			end)

			It("append destroy restores the source once", function()
				State.Renderer:Destroy()

				Expect(State.Target.Text).toBe("bold &gt; text" .. Link)
			end)
		end)
	end)

	Describe("prepend", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.Text = Lead .. State.Target.Text
			Settle()
		end)

		Single("prepend", function() return State end, Lead .. "bold &gt; text")

		It("prepend destroy restores the source once", function()
			State.Renderer:Destroy()

			Expect(State.Target.Text).toBe(Lead .. "bold &gt; text")
		end)
	end)

	Describe("replace", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.Text = [[<a href="x">link</a> only]]
			Settle()
		end)

		Single("replace", function() return State end, [[<a href="x">link</a> only]])
	end)

	Describe("plain", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("plain words")
		end)

		It("plain source native", function()
			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		It("plain markup is the source", function()
			Expect(State.Target.Text).toBe("plain words")
		end)

		Describe("appended", function()
			BeforeAll(function()
				State.Target.Text ..= Link
				Settle()
			end)

			Single("plain append", function() return State end, "plain words" .. Link)
		end)
	end)
end)

Describe("synchronous refresh right after an edit", function()
	AfterAll(Release)

	Describe("prepend then passthrough off", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("typed &gt; words")
			State.Target.Text = "start " .. State.Target.Text
			State.Renderer:SetRendering("Passthrough", false):Flush()
		end)

		It("prepend then passthrough off leaves native", function()
			Expect(State.Renderer.Native.Active).toBeFalsy()
		end)

		It("prepend then passthrough off host", function()
			Expect(State.Target.Text).toBe("start typed &gt; words")
		end)

		It("prepend then passthrough off source", function()
			Settle()

			Expect(State.Renderer.Document.Source).toBe("start typed &gt; words")
		end)
	end)

	Describe("append then rebuild", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("typed &gt; words")
			State.Target.Text ..= Link
			State.Renderer:Rebuild()
		end)

		Single("append then rebuild", function() return State end, "typed &gt; words" .. Link)

		It("append then rebuild settles once", function()
			Settle()

			Expect(State.Renderer.Document.Source).toBe("typed &gt; words" .. Link)
		end)
	end)

	Describe("parked append then grapheme count", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("typed &gt; words", Hidden(false))
			State.Target.Text ..= Link
			task.wait()
		end)

		It("hidden append parks the refresh", function()
			Expect(Schedule.Pending(State.Renderer)).never.toBeNil()
		end)

		It("parked append grapheme count", function()
			Expect(State.Renderer:GetGraphemeCount()).toBeGreaterThanOrEqual(#"typedwordslink")
		end)

		Single("parked append then grapheme count", function() return State end, "typed &gt; words" .. Link)
	end)
end)

Describe("edits while a refresh is queued", function()
	AfterAll(Release)

	Describe("two appends", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.Text ..= " one"
			State.Target.Text ..= Link
			Settle()
		end)

		Single("two appends", function() return State end, "bold &gt; text one" .. Link)
	end)

	Describe("parked appends", function()
		local State: Mounted
		local Holder: Frame

		BeforeAll(function()
			Holder = Hidden(true)
			State = Mount("bold &gt; text", Holder)

			Holder.Visible = false
			State.Target.Text ..= Link
			task.wait()
		end)

		It("hidden append parks the refresh", function()
			Expect(Schedule.Pending(State.Renderer)).never.toBeNil()
		end)

		It("parked append keeps native", function()
			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		Describe("shown", function()
			BeforeAll(function()
				State.Target.Text ..= " tail"
				Holder.Visible = true
				Settle()
			end)

			Single("parked appends", function() return State end, "bold &gt; text" .. Link .. " tail")
		end)
	end)

	Describe("append after a queued restyle", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.TextSize = 20
			State.Target.Text ..= Link
			Settle()
		end)

		Single("append after a queued restyle", function() return State end, "bold &gt; text" .. Link)
	end)

	Describe("chained", function()
		local State: Mounted
		local First: string

		BeforeAll(function()
			State = Mount("bold &gt; text")
			First = State.Target.Text
			State.Target.Text ..= " more"
			Settle()
		end)

		It("plain append stays native", function()
			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		It("plain append regenerates the markup", function()
			Expect(State.Target.Text ~= First and State.Renderer.Native.Markup == State.Target.Text).toBe(true)
		end)

		It("plain append source", function()
			Expect(State.Renderer.Document.Source).toBe("bold &gt; text more")
		end)

		Describe("linked", function()
			BeforeAll(function()
				State.Target.Text ..= Link
				Settle()
			end)

			Single("append on regenerated markup", function() return State end, "bold &gt; text more" .. Link)
		end)
	end)

	Describe("append then SetText", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.Text ..= " one"
			State.Renderer.Label.Text = State.Target.Text .. Link
			State.Renderer:Flush()
		end)

		Single("append then SetText", function() return State end, "bold &gt; text one" .. Link)
	end)

	Describe("pending append then SetText", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("Hi<b></b>")
		end)

		It("self prefixed markup", function()
			Expect(State.Target.Text).toBe("Hi")
		end)

		Describe("edited", function()
			BeforeAll(function()
				State.Target.Text ..= "!"
				State.Renderer.Label.Text = State.Target.Text .. "?"
				State.Renderer:Flush()
			end)

			It("pending append then SetText is rebased once", function()
				Expect(State.Renderer.Document.Source).toBe("Hi<b></b>!?")
			end)

			It("pending append then SetText stays native", function()
				Expect(State.Renderer.Native.Active).toBeTruthy()
			end)

			It("pending append then SetText markup", function()
				Expect(State.Target.Text).toBe("Hi!?")
			end)

			It("pending append then SetText shows the label", function()
				Expect(State.Target.TextTransparency).toBeCloseTo(0, 3)
			end)

			It("pending append then SetText settles", function()
				Settle()

				Expect(State.Renderer.Document.Source).toBe("Hi<b></b>!?")
			end)

			It("pending append then SetText destroy", function()
				State.Renderer:Destroy()

				Expect(State.Target.Text).toBe("Hi<b></b>!?")
			end)
		end)
	end)

	Describe("literal", function()
		local State: Mounted

		BeforeAll(function()
			State = Mount("bold &gt; text")
			State.Target.Text ..= " more"
			State.Renderer:SetPreset("Plain"):Flush()
		end)

		It("append then RichText off source", function()
			Expect(State.Renderer.Document.Source).toBe("bold &gt; text more")
		end)

		It("literal entity text uses segments", function()
			Expect(State.Renderer.Native.Active).toBeFalsy()
		end)

		It("literal text renders the source once", function()
			Expect(Joined(State.Target)).toBe("bold &gt; text more")
		end)

		Describe("appended", function()
			BeforeAll(function()
				State.Target.Text ..= " end"
				Settle()
			end)

			It("append on literal source", function()
				Expect(State.Renderer.Document.Source).toBe("bold &gt; text more end")
			end)

			It("append on literal source renders", function()
				Expect(Joined(State.Target)).toBe("bold &gt; text more end")
			end)

			It("literal destroy", function()
				State.Renderer:Destroy()

				Expect(State.Target.Text).toBe("bold &gt; text more end")
			end)
		end)
	end)

	Describe("takeover after a pending append", function()
		local State: Mounted

		BeforeAll(function()
			const Taken: TextLabel = Label("bold &gt; text")
			Build(Taken)

			Taken.Text ..= Link
			State = {Target = Taken, Renderer = Build(Taken)}
		end)

		Single("takeover after a pending append", function() return State end, "bold &gt; text" .. Link)
	end)
end)

Describe("edits during an in flight refresh", function()
	AfterAll(Release)

	const Source: string = "bold &gt; text" .. Link

	type Flow = {
		Target: TextLabel,
		Renderer: any,
		Held: boolean,
		Native: boolean,
		Consumed: string,
		Ok: boolean,
	}

	const function Midway(Edit: (Target: TextLabel, Renderer: any) -> ()): Flow
		const Target: TextLabel = Label("bold &gt; text")
		const Renderer: any = Build(Target)
		const Original: any = MeasureModule.Run
		const Result: Flow = {Target = Target, Renderer = Renderer, Held = false, Native = false, Consumed = "", Ok = false}
		local Held: thread? = nil
		local Once: boolean = true

		MeasureModule.Run = function(State: any, Factor: number): boolean
			if State == Renderer and Once then
				const Generation: number = State.Generation.Refresh

				Once = false
				Held = coroutine.running()
				coroutine.yield()

				if State.Generation.Refresh ~= Generation then return false end
			end

			return Original(State, Factor)
		end

		const Ok: boolean = pcall(function()
			Target.Text ..= Link
			for _ = 1, 3 do task.wait() end

			Result.Held = Held ~= nil
			Result.Native = Renderer.Native.Active == true
			Result.Consumed = Renderer.Document.Source

			Edit(Target, Renderer)
			Settle()

			if Held then task.spawn(Held :: thread) end
			Settle()
		end)

		MeasureModule.Run = Original
		Result.Ok = Ok

		return Result
	end

	const function Flowed(Name: string, Current: () -> Flow): ()
		It(`{Name} refresh parked`, function()
			Expect(Current().Held).toBe(true)
		end)

		It(`{Name} refresh keeps native`, function()
			Expect(Current().Native).toBe(true)
		end)

		It(`{Name} refresh consumed the append`, function()
			Expect(Current().Consumed).toBe(Source)
		end)

		It(`{Name} flow ran`, function()
			Expect(Current().Ok).toBe(true)
		end)
	end

	for _, Row: { any } in {
		{"append midway", function(Target: TextLabel) Target.Text ..= " tail" end, Source .. " tail"},
		{"source write midway", function(Target: TextLabel) Target.Text = Source end, Source},
		{"SetText midway", function(Target: TextLabel, Renderer: any)
			Renderer.Label.Text = Target.Text .. " tail"
			Renderer:Flush()
		end, Source .. " tail"},
	} do
		Describe(Row[1], function()
			local Result: Flow

			BeforeAll(function()
				Result = Midway(Row[2])
			end)

			Flowed(Row[1], function() return Result end)
			Single(Row[1], function() return Result :: any end, Row[3])
		end)
	end

	Describe("destroy midway", function()
		local Result: Flow

		BeforeAll(function()
			Result = Midway(function(_: TextLabel, Renderer: any) Renderer:Destroy() end)
		end)

		Flowed("destroy midway", function() return Result end)

		It("destroy midway host text", function()
			Expect(Result.Target.Text).toBe(Source)
		end)

		It("destroy midway leaves native", function()
			Expect(Result.Renderer.Native.Active).toBeFalsy()
		end)

		It("destroy midway leaves no segments", function()
			Expect(Joined(Result.Target)).toBe("")
		end)
	end)
end)

Describe("edits then release", function()
	AfterAll(Release)

	It("destroy before refresh rebases once", function()
		const State: Mounted = Mount("bold &gt; text")
		State.Target.Text ..= Link
		State.Renderer:Destroy()

		Expect(State.Target.Text).toBe("bold &gt; text" .. Link)
	end)

	It("destroy after refresh keeps one append", function()
		const State: Mounted = Mount("bold &gt; text")
		State.Target.Text ..= Link
		Settle()
		State.Renderer:Destroy()

		Expect(State.Target.Text).toBe("bold &gt; text" .. Link)
	end)

	Describe("regenerated markup", function()
		local Again: TextLabel
		local Renderer: any

		BeforeAll(function()
			Again = Label("bold &gt; text")
			Again.RichText = false
			Renderer = Build(Again)

			Again.Text ..= " more"
			Settle()
		end)

		It("plain append re-enters native", function()
			Expect(Renderer.Native.Active).toBeTruthy()
		end)

		Describe("destroyed", function()
			BeforeAll(function()
				Renderer:Destroy()
			end)

			It("destroy after regenerated markup", function()
				Expect(Again.Text).toBe("bold &gt; text more")
			end)

			It("destroy restores RichText after regenerated markup", function()
				Expect(Again.RichText).toBe(false)
			end)
		end)
	end)

	Describe("destroy while parked", function()
		local Holder: Frame
		local State: Mounted

		BeforeAll(function()
			Holder = Hidden(true)
			State = Mount("bold &gt; text", Holder)

			Holder.Visible = false
			State.Target.Text ..= Link
			task.wait()
			State.Renderer:Destroy()
		end)

		It("destroy while parked rebases once", function()
			Expect(State.Target.Text).toBe("bold &gt; text" .. Link)
		end)

		It("destroy while parked drops the queue", function()
			Expect(Schedule.Pending(State.Renderer)).toBeNil()
		end)

		It("next renderer parses the single append", function()
			Holder.Visible = true
			const Next: any = Build(State.Target)

			Expect(Next.Document.Source).toBe("bold &gt; text" .. Link)
		end)
	end)

	It("label destroyed before refresh rebases once", function()
		const Dying: TextLabel = Label("bold &gt; text")
		Build(Dying)

		Dying.Text ..= Link
		Dying:Destroy()
		task.wait()

		Expect(Dying.Text).toBe("bold &gt; text" .. Link)
	end)
end)

Describe("content that turns plain again", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	const function Current(): Mounted return {Target = Target, Renderer = Renderer} end

	BeforeAll(function()
		Target = Label("<b>bold</b> text")
		Target.RichText = false
		Renderer = Build(Target)
	end)

	It("tagged source uses segments", function()
		Expect(Renderer.Native.Active).toBeFalsy()
	end)

	It("tagged source keeps RichText off", function()
		Expect(Target.RichText).toBe(false)
	end)

	Describe("tagged append", function()
		BeforeAll(function()
			Target.Text ..= Link
			Settle()
		end)

		Single("tagged append", Current, "<b>bold</b> text" .. Link)

		It("segment switch keeps RichText off", function()
			Expect(Target.RichText).toBe(false)
		end)
	end)

	Describe("plain rewrite", function()
		BeforeAll(function()
			Target.Text = "plain words"
			Settle()
		end)

		It("plain rewrite native again", function()
			Expect(Renderer.Native.Active).toBeTruthy()
		end)

		It("plain rewrite markup", function()
			Expect(Target.Text).toBe("plain words")
		end)

		It("plain rewrite keeps RichText", function()
			Expect(Target.RichText).toBe(false)
		end)
	end)

	Describe("plain append", function()
		BeforeAll(function()
			Target.Text ..= " more"
			Settle()
		end)

		It("plain append stays native", function()
			Expect(Renderer.Native.Active).toBeTruthy()
		end)

		It("plain append host", function()
			Expect(Target.Text).toBe("plain words more")
		end)

		It("plain append source", function()
			Expect(Renderer.Document.Source).toBe("plain words more")
		end)
	end)

	Describe("tag append", function()
		BeforeAll(function()
			Renderer.Native.Clock = -math.huge
			Target.Text ..= " <b>b</b>"
			Settle()
		end)

		It("tag append leaves native", function()
			Expect(Renderer.Native.Active).toBeFalsy()
		end)

		It("tag append keeps RichText off", function()
			Expect(Target.RichText).toBe(false)
		end)

		It("tag append source", function()
			Expect(Renderer.Document.Source).toBe("plain words more <b>b</b>")
		end)
	end)

	Describe("link after plain", function()
		BeforeAll(function()
			Target.Text ..= Link
			Settle()
		end)

		Single("link after plain", Current, "plain words more <b>b</b>" .. Link)

		It("link after plain restores RichText", function()
			Expect(Target.RichText).toBe(false)
		end)
	end)

	Describe("destroyed", function()
		BeforeAll(function()
			Renderer:Destroy()
		end)

		It("destroy keeps the final source", function()
			Expect(Target.Text).toBe("plain words more <b>b</b>" .. Link)
		end)

		It("destroy keeps RichText", function()
			Expect(Target.RichText).toBe(false)
		end)
	end)
end)

Describe("incremental patch path", function()
	AfterAll(Release)

	Describe("segmented", function()
		local State: Mounted
		local Tree: any

		BeforeAll(function()
			State = Mount([[<a href="x">link</a> tail]])
			Tree = State.Renderer.Document.Tree
		end)

		It("link source in segment mode", function()
			Expect(State.Renderer.Native.Active).toBeFalsy()
		end)

		Describe("appended", function()
			BeforeAll(function()
				State.Target.Text ..= " more"
				Settle()
			end)

			It("segment append patched", function()
				Expect(State.Renderer.Document.Tree).toBe(Tree)
			end)

			Single("segment append", function() return State end, [[<a href="x">link</a> tail more]])
		end)

		It("segment rewrite enters native", function()
			State.Target.Text = "plain now"
			Settle()

			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		Describe("linked", function()
			BeforeAll(function()
				State.Target.Text ..= Link
				Settle()
			end)

			Single("append after patch and native", function() return State end, "plain now" .. Link)
		end)
	end)

	Describe("escaped", function()
		local State: Mounted
		local Ledger: any

		BeforeAll(function()
			State = Mount("a &gt; b")
		end)

		It("escaped source native", function()
			Expect(State.Renderer.Native.Active).toBeTruthy()
		end)

		It("escaped markup differs from the source", function()
			Expect(State.Target.Text).toBe("a > b")
		end)

		Describe("patched", function()
			BeforeAll(function()
				State.Renderer.Scale.Measured = State.Renderer.Scale.Factor
				Ledger = State.Renderer.Document.Tree
				State.Target.Text ..= " c"
				Settle()
			end)

			It("native append patched", function()
				Expect(State.Renderer.Document.Tree).toBe(Ledger)
			end)

			It("native patch reads the rebased host text", function()
				Expect(State.Renderer.Document.Source).toBe("a &gt; b c")
			end)

			It("native patch stays native", function()
				Expect(State.Renderer.Native.Active).toBeTruthy()
			end)

			It("native patch markup", function()
				Expect(State.Target.Text).toBe("a > b c")
			end)

			It("native patch destroy", function()
				State.Renderer:Destroy()

				Expect(State.Target.Text).toBe("a &gt; b c")
			end)
		end)
	end)

	Describe("typed", function()
		local State: Mounted
		local Last: any

		BeforeAll(function()
			State = Mount("<b>bold</b>")

			for Step = 1, 6 do
				Last = State.Renderer.Document.Tree
				State.Target.Text ..= tostring(Step)
				Settle()
			end
		end)

		It("rapid appends stay in segments", function()
			Expect(State.Renderer.Native.Active).toBeFalsy()
		end)

		It("rapid appends source", function()
			Expect(State.Renderer.Document.Source).toBe("<b>bold</b>123456")
		end)

		It("rapid appends host", function()
			Expect(State.Target.Text).toBe("<b>bold</b>123456")
		end)

		It("rapid appends render once", function()
			Expect(Count(Joined(State.Target), "123456")).toBe(1)
		end)

		It("segment appends patch", function()
			Expect(State.Renderer.Document.Tree).toBe(Last)
		end)

		Describe("calm", function()
			BeforeAll(function()
				State.Renderer.Native.Clock = -math.huge
				State.Target.Text ..= "7"
				Settle()
			end)

			It("calm tagged patch stays in segments", function()
				Expect(State.Renderer.Native.Active).toBeFalsy()
			end)

			It("calm patch source", function()
				Expect(State.Renderer.Document.Source).toBe("<b>bold</b>1234567")
			end)
		end)

		Describe("linked", function()
			BeforeAll(function()
				State.Target.Text ..= Link
				Settle()
			end)

			Single("append after calm patch", function() return State end, "<b>bold</b>1234567" .. Link)
		end)
	end)
end)
