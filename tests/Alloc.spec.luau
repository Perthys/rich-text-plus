--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Incremental = require("../Packages/RichTextPlus/Core/Incremental")
const Flatten = require("../Packages/RichTextPlus/Core/Flatten")
const Backdrop = require("../Packages/RichTextPlus/Render/Backdrop")
const Pool = require("../Packages/RichTextPlus/Render/Pool")
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

const Shy: string = "\u{AD}"

local Screen: ScreenGui
const Owned: { any } = {}

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
	const Renderer: any = (RichTextPlus :: any).new(Target):SetRendering("Passthrough", false):Flush()
	table.insert(Owned, Renderer)

	return Renderer
end

const function Signature(Tokens: { any }): string
	const Parts: { string } = {}

	for _, Token: any in Tokens do
		table.insert(Parts, `{Token.Kind}|{Token.Text or ""}|{tostring(Token.SpaceBefore)}|{tostring(Token.Glue)}|{tostring(Token.Hyphen ~= nil)}|{Token.Width}|{Token.Offset or 0}`)
	end

	return table.concat(Parts, "\n")
end

BeforeAll(function()
	Screen = Gui.new("Alloc")
end)

AfterAll(function()
	for _, Renderer: any in Owned do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("uppercase fast path matches the rich measure", function()
	local Renderer: any
	local Style: any

	BeforeAll(function()
		Renderer = Create(Label("<uc>hello world</uc>", 400, 200))
		Style = Renderer.Document.Tokens[1].Style
	end)

	It("uppercased ascii", function()
		Expect((Measure.Uppercased("it's a&b", "Upper"))).toBe("IT'S A&B")
	end)

	It("uppercased skips small caps", function()
		Expect((Measure.Uppercased("abc", "SmallCaps"))).toBeNil()
	end)

	It("uppercased skips plain", function()
		Expect((Measure.Uppercased("abc", nil))).toBeNil()
	end)

	It("uppercased skips non ascii", function()
		Expect((Measure.Uppercased("\u{E9}t\u{E9}", "Upper"))).toBeNil()
	end)

	It("cased keeps rich form", function()
		Expect((Measure.Cased("ab", "Upper"))).toBe("<uc>ab</uc>")
	end)

	for _, Word: string in {"hello", "World", "a&b", "x<y", "fi fl"} do
		It(`uppercase width {Word}`, function()
			const Fast: Vector2 = Measure.WidthOf(Style, 18, Word)
			const Rich: Vector2 = Measure.Bounds(Style, 18, Measure.Cased(Word, "Upper"), true)

			Expect(math.abs(Fast.X - Rich.X) < 0.001 and math.abs(Fast.Y - Rich.Y) < 0.001).toBe(true)
		end)
	end

	It("uppercase token width", function()
		Expect(math.abs(Renderer.Document.Tokens[1].Width - Measure.Bounds(Style, 18, "<uc>hello</uc>", true).X)).toBeLessThan(0.001)
	end)
end)

Describe("incremental patch", function()
	It("patched tokens match a rebuild", function()
		const Target: TextLabel = Label("", 300, 40)
		const Renderer: any = Create(Target)
		const Texts: { string } = {}
		for Index = 1, 40 do Texts[Index] = `<b>Coins:</b> <font color="#FFD700">{1000 + Index}</font>` end

		Renderer.Label.Text = Texts[1]
		Renderer:Flush()

		for Index = 1, 80 do
			Target.Text = Texts[Index % 40 + 1]
			Incremental.Patch(Renderer)
		end

		Renderer.Label.Text = Texts[7]
		Renderer:Flush()
		const Patched: string = Signature(Renderer.Document.Tokens)
		Renderer:Rebuild()

		Expect(Patched).toBe(Signature(Renderer.Document.Tokens))
	end)
end)

Describe("recycled tokens carry no stale fields", function()
	const Sequence: { string } = {
		`alpha co{Shy}op beta, gamma`,
		`alpha coop beta, gamma`,
		"alpha 中文 beta, gamma",
		`alpha x{Shy}y beta. gamma`,
		"alpha plain beta gamma",
		"alpha (paren) beta, gamma",
	}

	local Renderer: any

	BeforeAll(function()
		Renderer = Create(Label("", 400, 200))
	end)

	for Round = 1, 3 do
		for Index: number, Text: string in Sequence do
			It(`round {Round} step {Index}`, function()
				Renderer.Label.Text = Text
				Renderer:Flush()

				const Patched: string = Signature(Renderer.Document.Tokens)
				const Fresh: TextLabel = Label(Text, 400, 200)
				const Reference: any = (RichTextPlus :: any).new(Fresh):SetRendering("Passthrough", false):Flush()
				const Expected: string = Signature(Reference.Document.Tokens)

				Reference:Destroy()
				Fresh:Destroy()

				Expect(Patched).toBe(Expected)
			end)
		end
	end
end)

Describe("flatten context reuse keeps links and documents fresh", function()
	local Renderer: any
	local Tokens: { any }
	local Groups: { any }
	local First: { any }

	BeforeAll(function()
		Renderer = Create(Label([[<a href="one">first link</a> and <a href="two">second link</a>]], 400, 200))
		Tokens = Renderer.Document.Tokens
		Groups = Renderer:QueryDescendants("a")
	end)

	It("two groups", function()
		Expect(#Groups).toBe(2)
	end)

	It("second link text", function()
		Expect(Groups[2].Text).toBe("second link")
	end)

	It("token list replaced", function()
		Renderer.Label.Text = [[<a href="three">only link</a> here]]
		Renderer:Flush()

		Expect(Renderer.Document.Tokens ~= Tokens).toBe(true)
	end)

	It("first link element persists", function()
		Expect(Renderer:QueryFirst("a")).toBe(Groups[1])
	end)

	It("one link", function()
		Expect(#Renderer:QueryDescendants("a")).toBe(1)
	end)

	It("persisted element reads the new text", function()
		Expect(Groups[1].Text).toBe("only link")
	end)

	It("dropped element is retired", function()
		Expect(Groups[2].Text).toBe("")
	end)

	It("each flatten publishes a new token list", function()
		const Tree: any = XML.GenerateTreeFromXML("Coins: 1001")
		Flatten.Run(Renderer, Tree)
		First = Renderer.Document.Tokens
		Flatten.Run(Renderer, Tree)

		Expect(Renderer.Document.Tokens ~= First).toBe(true)
	end)

	It("each flatten publishes new tokens", function()
		Expect(Renderer.Document.Tokens[1] ~= First[1]).toBe(true)
	end)

	It("same text after reuse", function()
		Expect(Renderer.Document.Tokens[2].Text).toBe("1001")
	end)
end)

Describe("base style survives rebuilds until the label changes", function()
	local Target: TextLabel
	local Renderer: any
	local Base: any

	BeforeAll(function()
		Target = Label("plain <b>bold</b>", 400, 200)
		Renderer = Create(Target)
		Base = Renderer.Document.Tokens[1].Style
	end)

	It("base reused", function()
		Renderer:Rebuild()

		Expect(Renderer.Document.Tokens[1].Style).toBe(Base)
	end)

	It("bold differs from base", function()
		Expect(Renderer.Document.Tokens[2].Style ~= Base).toBe(true)
	end)

	It("color change rebuilds base", function()
		Target.TextColor3 = Color3.new(1, 0, 0)
		Renderer:Rebuild()

		Expect(Renderer.Document.Tokens[1].Style ~= Base).toBe(true)
	end)

	It("new base color", function()
		Expect(Renderer.Document.Tokens[1].Style.Color).toBe(Color3.new(1, 0, 0))
	end)
end)

Describe("unchanged styles are interned across flattens", function()
	local Renderer: any
	local Before: { any }
	local Changed: { any }

	const function Styles(): { any }
		const Found: { any } = {}
		for _, Token: any in Renderer.Document.Tokens do
			if Token.Style then table.insert(Found, Token.Style) end
		end

		return Found
	end

	BeforeAll(function()
		Renderer = Create(Label([[plain <b>one</b> and <b>two</b> <font color="#FF0000">red</font> <a href="x">link</a>]], 400, 200))
		Before = Styles()
	end)

	It("separate tags keep separate styles", function()
		Expect(Before[2] ~= Before[4]).toBe(true)
	end)

	It("style reused", function()
		Renderer:Rebuild()
		const After: { any } = Styles()

		for Index: number, Style: any in Before do Expect(After[Index]).toBe(Style) end
	end)

	It("unchanged bold reused", function()
		Renderer.Label.Text = [[plain <b>one</b> and <b>two</b> <font color="#00FF00">red</font> <a href="x">link</a>]]
		Renderer:Flush()
		Changed = Styles()

		Expect(Changed[2]).toBe(Before[2])
	end)

	It("changed color gets a new style", function()
		Expect(Changed[5] ~= Before[5]).toBe(true)
	end)

	It("link after change reused", function()
		Expect(Changed[6]).toBe(Before[6])
	end)

	It("new color applied", function()
		Expect(Changed[5].Color).toBe(Color3.fromRGB(0, 255, 0))
	end)
end)

Describe("ledger flags round trip", function()
	local Entries: { any }

	BeforeAll(function()
		Entries = Create(Label(`alpha <b>be{Shy}</b>ta <i>gamma</i>`, 400, 200)).Document.Ledger.Entries
	end)

	const function Flag(Entry: number, Position: number): any
		return (select(Position, Flatten.Unpack(Entries[Entry].Flags)))
	end

	It("first entry space", function()
		Expect(Flag(1, 1)).toBe(false)
	end)

	It("first entry exit space", function()
		Expect(Flag(1, 2)).toBe(true)
	end)

	It("first entry hooked", function()
		Expect(Flag(1, 3)).toBe(false)
	end)

	It("first entry joint", function()
		Expect(Flag(1, 4)).toBeNil()
	end)

	It("first entry exit joint", function()
		Expect(Flag(1, 5)).toBeNil()
	end)

	It("soft hyphen exit joint", function()
		Expect(Flag(2, 5)).toBe("Hyphen")
	end)

	It("hyphenated continuation not spaced", function()
		Expect(Flag(3, 1)).toBe(false)
	end)

	It("hyphenated continuation hooked", function()
		Expect(Flag(3, 3)).toBe(true)
	end)

	It("hyphenated continuation joint", function()
		Expect(Flag(3, 4)).toBe("Hyphen")
	end)
end)

Describe("coverage reuse recycles pieces", function()
	const Mark: any = {Color = Color3.new(1, 1, 0), Transparency = 0}
	const Style: any = {Mark = {Color = Color3.new(1, 0, 0), Transparency = 0, Parent = Mark}}
	local Coverage: any
	local Pieces: { any }

	BeforeAll(function()
		Coverage = Backdrop.Begin()
		Backdrop.Row(Coverage, 0, 20)
		Backdrop.Cover(Coverage, Style, 0, 50, 2)
	end)

	It("pieces covered", function()
		Expect(#Coverage.Pieces).toBe(2)
	end)

	It("same coverage returned", function()
		Coverage.Pieces[1].Tail = true
		Pieces = table.clone(Coverage.Pieces)

		Expect(Backdrop.Begin(Coverage) == Coverage).toBe(true)
	end)

	It("pieces cleared", function()
		Expect(#Coverage.Pieces).toBe(0)
	end)

	It("latest cleared", function()
		Expect((next(Coverage.Latest))).toBeNil()
	end)

	It("piece records reused", function()
		Backdrop.Row(Coverage, 20, 20)
		Backdrop.Cover(Coverage, Style, 5, 10, 0)

		Expect(table.find(Pieces, Coverage.Pieces[1]) ~= nil and table.find(Pieces, Coverage.Pieces[2]) ~= nil).toBe(true)
	end)

	It("reused head reset", function()
		Expect(Coverage.Pieces[1].Head).toBe(true)
	end)

	It("reused tail reset", function()
		Expect(Coverage.Pieces[1].Tail).toBe(false)
	end)

	It("reused y", function()
		Expect(Coverage.Pieces[1].Y).toBe(20)
	end)

	It("reused start", function()
		Expect(Coverage.Pieces[1].Start).toBe(5)
	end)
end)

Describe("pool assignment reuses its scratch", function()
	local Records: { any }
	local Runs: { any }
	local First: { any }
	local Renderer: any

	BeforeAll(function()
		Renderer = Create(Label("one <b>two</b> three <i>four</i>", 400, 200))
		Renderer:Flush()
		Records = table.clone(Renderer.Instances.Segments)
		Runs = {}
		for _, Record: any in Records do
			table.insert(Runs, {Style = Record.Style, Text = Record.Content.Raw, X = 0, Y = 0, Width = 1, Height = 1})
		end
		First = Pool.Assign(Renderer, Runs)
	end)

	It("sequential match", function()
		Expect(First[2]).toBe(Records[2])
	end)

	It("scratch reused", function()
		Expect((Pool.Assign(Renderer, Runs))).toBe(First)
	end)

	It("fallback twin", function()
		const Reversed: { any } = {}
		for Index = #Runs, 1, -1 do
			const Run: any = Runs[Index]
			table.insert(Reversed, {Style = table.clone(Run.Style), Text = Run.Text, X = 0, Y = 0, Width = 1, Height = 1})
		end

		const Shuffled: { any } = Pool.Assign(Renderer, Reversed)
		for Index: number, Run: any in Reversed do
			const Twin: any = Shuffled[Index]
			Expect(`{Index} {tostring(Twin ~= nil and table.find(Records, Twin) ~= nil and Twin.Style.Bold == Run.Style.Bold)}`).toBe(`{Index} true`)
		end
	end)
end)

Describe("scheduler reuses entries and runner threads", function()
	local Unit: any
	local Copy: ModuleScript
	local Slow: Fake
	local Quick: Fake
	const Order: { string } = {}
	local Yielded: boolean = false

	const function Make(Name: string): Fake
		const Created: TextLabel = Instance.new("TextLabel")
		Created.Name = Name
		Created.Parent = Screen

		return {Name = Name, Label = Created, Rendering = {Culling = false}, Cull = {Culled = false}, Destroyed = false}
	end

	BeforeAll(function()
		const Render: Instance = (script.Parent :: any).Parent.Packages.RichTextPlus.Render
		Copy = (Render:FindFirstChild("Schedule") :: ModuleScript):Clone()
		Copy.Name = "AllocScheduleCopy"
		Copy.Parent = Render
		Unit = (require :: any)(Copy)

		Unit.Bind(function(State: Fake): ()
			if State.Name == "slow" and not Yielded then
				Yielded = true
				task.wait()
			end

			table.insert(Order, State.Name)
		end, math.max)
		Unit.SetBudget(1000)

		Slow = Make("slow")
		Quick = Make("quick")
	end)

	AfterAll(function()
		Slow.Label:Destroy()
		Quick.Label:Destroy()
		Copy:Destroy()
	end)

	It("quick runs while slow is suspended", function()
		Unit.Queue(Slow, 1)
		Unit.Queue(Quick, 1)
		Unit.Step()

		Expect(table.concat(Order, ",")).toBe("quick")
	end)

	It("slow resumes and finishes", function()
		task.wait()
		task.wait()

		Expect(table.concat(Order, ",")).toBe("quick,slow")
	end)

	It("runner still serves after a yield", function()
		Unit.Queue(Quick, 1)
		Unit.Step()

		Expect(Order[3]).toBe("quick")
	end)
end)
