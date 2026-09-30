--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const STYLED: string = "<b>Hello</b> there my friend, how are you"

type Snapshot = { Renderer: any, Refresh: number, Layout: number, Streak: number }

const Library: any = RichTextPlus
local Screen: ScreenGui
local Marked: Snapshot? = nil

const function Label(Text: string, Width: number?, Height: number?, Parent: Instance?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width or 400, Height or 200)
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

const function Segments(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	table.sort(Found, function(Left: TextLabel, Right: TextLabel): boolean
		if Left.Position.Y.Offset ~= Right.Position.Y.Offset then return Left.Position.Y.Offset < Right.Position.Y.Offset end

		return Left.Position.X.Offset < Right.Position.X.Offset
	end)

	return Found
end

const function Rows(Target: TextLabel): number
	const Seen: { [number]: boolean } = {}
	local Count: number = 0

	for _, Segment: TextLabel in Segments(Target) do
		const Y: number = Segment.Position.Y.Offset
		if Seen[Y] then continue end

		Seen[Y] = true
		Count += 1
	end

	return Count
end

const function Expected(Text: string, Segmented: boolean, Configure: ((Target: TextLabel) -> ())?): (number, number)
	const Target: TextLabel = Label(Text)
	if Configure then Configure(Target) end

	const Renderer: any = Library.new(Target):SetRendering("Passthrough", not Segmented):Flush()
	const Count: number = Renderer:GetGraphemeCount()
	const Lines: number = Rows(Target)

	Renderer:Destroy()
	Target:Destroy()

	return Count, Lines
end

const function Mark(Renderer: any): ()
	Marked = {
		Renderer = Renderer,
		Refresh = Renderer.Generation.Refresh,
		Layout = Renderer.Generation.Layout,
		Streak = Renderer.Native.Streak,
	}
end

const function Quiet(Name: string): ()
	local Snapshot: Snapshot

	It(`{Name}: deferred event runs no refresh`, function()
		Snapshot = Marked :: Snapshot
		task.wait()

		Expect(Snapshot.Renderer.Generation.Refresh).toBe(Snapshot.Refresh)
	end)

	It(`{Name}: deferred event runs no layout`, function()
		Expect(Snapshot.Renderer.Generation.Layout).toBe(Snapshot.Layout)
	end)

	It(`{Name}: change churned once`, function()
		Expect(Snapshot.Renderer.Native.Streak).toBe(Snapshot.Streak)
	end)
end

BeforeAll(function()
	Screen = Gui.new("HostSync")
	task.wait()
end)

AfterAll(function()
	Gui.Cleanup()
end)

Describe("grapheme count right after a text write", function()
	local Want: number
	local Tail: number
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Want = Expected(STYLED, true)
		Tail = Expected(STYLED .. " <i>and more</i>", true)
		Target = Label("first words")
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("count sees the new text", function()
		Target.Text = STYLED

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(Want)
	end)

	It("source follows the write", function()
		Expect(Renderer.Document.Source).toBe(STYLED)
	end)

	Quiet("segment write")

	It("append counted", function()
		Target.Text ..= " <i>and more</i>"

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(Tail)
	end)

	It("append source", function()
		Expect(Renderer.Document.Source).toBe(STYLED .. " <i>and more</i>")
	end)

	Quiet("segment append")

	It("unchanged label does not refresh", function()
		const Refresh: number = Renderer.Generation.Refresh
		Renderer:GetGraphemeCount()

		Expect(Renderer.Generation.Refresh).toBe(Refresh)
	end)
end)

Describe("native label leaves passthrough on an immediate count", function()
	local Want: number
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Want = Expected(STYLED, false)
		Target = Label("plain words")
		Renderer = Library.new(Target):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("starts native", function()
		Expect(Renderer.Native.Active).toBe(true)
	end)

	It("count is not the raw markup length", function()
		Target.Text = STYLED

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(Want)
	end)

	It("left native passthrough", function()
		Expect(not Renderer.Native.Active).toBe(true)
	end)

	It("source follows the write", function()
		Expect(Renderer.Document.Source).toBe(STYLED)
	end)

	Quiet("native to segments")

	It("native count", function()
		Target.Text = "other plain text"

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(16)
	end)

	It("native again", function()
		Expect(Renderer.Native.Active).toBe(true)
	end)

	It("native host text", function()
		Expect(Target.Text).toBe("other plain text")
	end)

	Quiet("segments to native")

	It("reveal count right after the write", function()
		Target.MaxVisibleGraphemes = 0
		Target.Text = "a new line to reveal"

		Expect(Renderer:GetGraphemeCount()).toBe(20)
	end)
end)

Describe("native appends settle on flush", function()
	local Target: TextLabel
	local Renderer: any
	local Refresh: number

	BeforeAll(function()
		Target = Label("bold &gt; text")
		Renderer = Library.new(Target):Flush()
	end)

	AfterAll(function()
		Target:Destroy()
	end)

	It("markup decodes the source", function()
		Expect(Target.Text).toBe("bold > text")
	end)

	It("append rebased on the source", function()
		Target.Text ..= " more"
		Renderer:Flush()
		Mark(Renderer)

		Expect(Renderer.Document.Source).toBe("bold &gt; text more")
	end)

	It("append regenerates the markup", function()
		Expect(Target.Text).toBe("bold > text more")
	end)

	It("host shown again", function()
		Expect(Target.TextTransparency).toBe(0)
	end)

	Quiet("native append")

	It("prepend counted", function()
		Target.Text = "start " .. Target.Text

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(#"start bold > text more")
	end)

	It("prepend rebased on the source", function()
		Expect(Renderer.Document.Source).toBe("start bold &gt; text more")
	end)

	Quiet("native prepend")

	It("source write keeps the markup", function()
		Refresh = Renderer.Generation.Refresh
		Target.Text = "start bold &gt; text more"
		Renderer:Flush()
		Mark(Renderer)

		Expect(Target.Text).toBe("start bold > text more")
	end)

	It("source write keeps the source", function()
		Expect(Renderer.Document.Source).toBe("start bold &gt; text more")
	end)

	It("source write needs no refresh", function()
		Expect(Renderer.Generation.Refresh).toBe(Refresh)
	end)

	Quiet("native round trip")

	It("destroy restores the source", function()
		Renderer:Destroy()

		Expect(Target.Text).toBe("start bold &gt; text more")
	end)
end)

Describe("a queued refresh settles once", function()
	local Holder: Frame
	local Second: number
	local Fourth: number
	local Target: TextLabel
	local Renderer: any
	local Streak: number

	BeforeAll(function()
		Holder = Instance.new("Frame")
		Holder.Size = UDim2.fromOffset(400, 200)
		Holder.BackgroundTransparency = 1
		Holder.Visible = false
		Holder.Parent = Screen

		Second = Expected("second words here", true)
		Fourth = Expected("fourth <b>and</b> last", true)
		Target = Label("first", 400, 200, Holder)
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Holder:Destroy()
	end)

	It("hidden refresh parked", function()
		Target.Text = "second words here"
		task.wait()

		Expect(Renderer.Document.Source).toBe("first")
	end)

	It("parked text counted", function()
		Streak = Renderer.Native.Streak

		Expect(Renderer:GetGraphemeCount()).toBe(Second)
	end)

	It("parked source", function()
		Expect(Renderer.Document.Source).toBe("second words here")
	end)

	It("parked write churned once", function()
		Expect(Renderer.Native.Streak).toBe(Streak)
	end)

	It("newer write over a parked one", function()
		Target.Text = "third"
		task.wait()
		Target.Text = "fourth <b>and</b> last"

		const Count: number = Renderer:GetGraphemeCount()
		Mark(Renderer)

		Expect(Count).toBe(Fourth)
	end)

	It("newest source wins", function()
		Expect(Renderer.Document.Source).toBe("fourth <b>and</b> last")
	end)

	Quiet("parked")

	It("showing the label keeps the source", function()
		Holder.Visible = true
		task.wait()

		Expect(Renderer.Document.Source).toBe("fourth <b>and</b> last")
	end)
end)

Describe("restyles settle synchronously", function()
	const Arial: Font = Font.fromEnum(Enum.Font.Arial)
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("<b>bold</b> and plain words", 400, 200)
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("flush applies the new size", function()
		Target.TextSize = 30
		Renderer:Flush()
		Mark(Renderer)

		Expect(Segments(Target)[1].TextSize).toBe(30)
	end)

	Quiet("text size")

	It("layout applies the new face", function()
		Target.FontFace = Arial
		Renderer:Flush()
		Mark(Renderer)

		Expect(Segments(Target)[2].FontFace.Family).toBe(Arial.Family)
	end)

	Quiet("font face")

	It("global flush applies the new color", function()
		Target.TextColor3 = Color3.fromRGB(255, 0, 0)
		Library.Runtime.Flush()
		Mark(Renderer)

		Expect(Segments(Target)[2].TextColor3).toBe(Color3.fromRGB(255, 0, 0))
	end)

	Quiet("text color")

	It("set text renders its text", function()
		Target.TextSize = 24
		Renderer.Label.Text = "<i>new</i> words"
		Renderer:Flush()

		Expect(Renderer.Document.Source).toBe("<i>new</i> words")
	end)

	It("a restyle next to set text lands with its event", function()
		task.wait()
		Mark(Renderer)

		Expect(Segments(Target)[1].TextSize).toBe(24)
	end)

	Quiet("set text restyle")
end)

Describe("layout inputs settle synchronously", function()
	const Long: string = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron"
	local Narrow: number
	local Padded: number
	local Wide: number
	local Target: TextLabel
	local Renderer: any
	local Padding: UIPadding
	local Refresh: number
	local Layout: number

	BeforeAll(function()
		const _Count: number, NarrowRows: number = Expected(Long, true, function(Target: TextLabel) Target.Size = UDim2.fromOffset(100, 400) end)
		const _Padded: number, PaddedRows: number = Expected(Long, true, function(Target: TextLabel)
			const Inset: UIPadding = Instance.new("UIPadding")
			Inset.PaddingLeft = UDim.new(0, 200)
			Inset.Parent = Target
		end)
		Narrow = NarrowRows
		Padded = PaddedRows

		Target = Label(Long, 400, 400)
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()
		Wide = Rows(Target)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("wide label wraps less than a narrow one", function()
		Expect(Wide).toBeLessThan(Narrow)
	end)

	It("resize rewraps right away", function()
		Target.Size = UDim2.fromOffset(100, 400)
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(Narrow)
	end)

	It("host width follows", function()
		Expect(Renderer.Host.Width).toBe(100)
	end)

	Quiet("resize")

	It("unwrapped is one line", function()
		Target.TextWrapped = false
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(1)
	end)

	Quiet("wrapping")

	It("back to the wide wrap", function()
		Target.TextWrapped = true
		Target.Size = UDim2.fromOffset(400, 400)
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(Wide)
	end)

	Quiet("rewrap")

	It("added padding narrows the content", function()
		Padding = Instance.new("UIPadding")
		Padding.PaddingLeft = UDim.new(0, 200)
		Padding.Parent = Target
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(Padded)
	end)

	Quiet("padding added")

	It("padding change widens the content", function()
		Padding.PaddingLeft = UDim.new(0, 0)
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(Wide)
	end)

	Quiet("padding changed")

	It("removed zero padding needs no layout", function()
		Padding:Destroy()
		Renderer:Flush()
		Mark(Renderer)

		Expect(Rows(Target)).toBe(Wide)
	end)

	Quiet("padding removed")

	It("alignment is a layout only change", function()
		Refresh = Renderer.Generation.Refresh
		Layout = Renderer.Generation.Layout
		Target.TextXAlignment = Enum.TextXAlignment.Right
		Renderer:Flush()
		Mark(Renderer)

		Expect(Renderer.Generation.Refresh).toBe(Refresh)
	end)

	It("alignment lays out once", function()
		Expect(Renderer.Generation.Layout).toBe(Layout + 1)
	end)

	It("alignment applied", function()
		Expect(Segments(Target)[1].Position.X.Offset).toBeGreaterThan(0)
	end)

	Quiet("alignment")
end)

Describe("scale solve sees the new text", function()
	const Short: string = "tiny"
	const Long: string = "a much longer sentence that has to shrink to fit inside the same box"
	local Factor: number
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		const Reference: TextLabel = Label(Long, 200, 60)
		Reference.TextScaled = true

		const ReferenceRenderer: any = Library.new(Reference):SetRendering("Passthrough", false):Flush()
		Factor = ReferenceRenderer.Scale.Factor
		ReferenceRenderer:Destroy()
		Reference:Destroy()

		Target = Label(Short, 200, 60)
		Target.TextScaled = true
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()

		Target.Text = Long
		Renderer:Flush()
		Mark(Renderer)
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("scale solve parses the new text", function()
		Expect(Renderer.Document.Source).toBe(Long)
	end)

	It("scale matches a fresh renderer", function()
		Expect(Renderer.Scale.Factor).toBe(Factor)
	end)

	Quiet("scale")
end)

Describe("global flush settles every label", function()
	local First: TextLabel
	local Second: TextLabel
	local FirstRenderer: any
	local SecondRenderer: any

	BeforeAll(function()
		First = Label("one")
		Second = Label("two")
		FirstRenderer = Library.new(First):SetRendering("Passthrough", false):Flush()
		SecondRenderer = Library.new(Second):Flush()

		First.Text = "<b>one</b> changed"
		Second.Text = "two changed"
		Library.Runtime.Flush()
		Mark(FirstRenderer)
	end)

	AfterAll(function()
		FirstRenderer:Destroy()
		SecondRenderer:Destroy()
		First:Destroy()
		Second:Destroy()
	end)

	It("segment label settled", function()
		Expect(FirstRenderer.Document.Source).toBe("<b>one</b> changed")
	end)

	It("native label settled", function()
		Expect(SecondRenderer.Document.Source).toBe("two changed")
	end)

	Quiet("global first")

	It("destroyed renderer ignored", function()
		const Dead: TextLabel = Label("gone")
		const DeadRenderer: any = Library.new(Dead):Flush()
		DeadRenderer:Destroy()
		Dead.Text = "written after destroy"
		Library.Runtime.Flush()

		const Text: string = Dead.Text
		Dead:Destroy()

		Expect(Text).toBe("written after destroy")
	end)
end)

Describe("rebuild and set text consume a pending write", function()
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("start")
		Renderer = Library.new(Target):SetRendering("Passthrough", false):Flush()
	end)

	AfterAll(function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	It("rebuild parses the write", function()
		Target.Text = "<i>rebuilt</i> text"
		Renderer:Rebuild()
		Mark(Renderer)

		Expect(Renderer.Document.Source).toBe("<i>rebuilt</i> text")
	end)

	Quiet("rebuild")

	It("set text wins", function()
		Target.Text = "<u>raw</u> write"
		Renderer.Label.Text = "<s>set</s> text"
		Renderer:Flush()
		Mark(Renderer)

		Expect(Renderer.Document.Source).toBe("<s>set</s> text")
	end)

	It("host holds the set text", function()
		Expect(Target.Text).toBe("<s>set</s> text")
	end)

	Quiet("set text")
end)
