--!strict

const TextService = game:GetService("TextService")

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const GlyphsModule = require("../Packages/RichTextPlus/Text/Glyphs")
const MeasureModule = require("../Packages/RichTextPlus/Text/Measure")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const API: any = RichTextPlus
const Glyphs: any = GlyphsModule
const Measure: any = MeasureModule

const Sentences: { string } = {
	"The quick brown fox jumps over the lazy dog while Wawa and AVATAR keep Today in view.",
	"Players gathered at the arena before sunrise, Voyage number 42 costs $100 or 50%!",
	"(Quoted) \"words\" end here. Kerning Tokyo Mississippi YES no maybe? LTyo 1234567890",
}

const ParseCases: { { any } } = {
	{"hello", 5, true};
	{"Hello,", 6, true};
	{"(quoted)", 8, true};
	{"\"quote\"", 7, true};
	{"$100", 4, true};
	{"50%", 3, true};
	{"!", 1, true};
	{" ", 1, true};
	{"it's", 4, false};
	{"Type-Writer", 11, false};
	{"x*y", 3, false};
	{"3.14", 4, false};
	{"office", 6, false};
	{"after", 5, false};
	{"fjord", 5, false};
	{"Fjord", 5, true};
	{"FIFTY", 5, true};
	{"...", 3, false};
	{"--", 2, false};
	{"café", 4, true};
	{"Ærøskøbing", 10, true};
	{"Καλημέρα", 8, true};
	{"Привет", 6, true};
	{"日本語", 3, true};
	{"「括弧」", 4, true};
	{"한국어", 3, true};
	{"😀😃", 2, true};
	{"👍🏽", 1, true};
	{"👨‍👩‍👧", 1, true};
	{"🎉party", 6, true};
	{"مرحبا", 0, false};
	{"שלום", 0, false};
	{"สวัสดี", 0, false};
	{"it’s", 0, false};
	{"wait…", 0, false};
	{"a\tb", 0, false};
	{"", 0, false};
}

const Parameters: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
Parameters.Width = 100000

const function Exact(Face: Font, Size: number, Text: string): Vector2
	Parameters.Font = Face
	Parameters.Size = Size
	Parameters.Text = Text

	return TextService:GetTextBoundsAsync(Parameters)
end

const function Style(Face: Font, Size: number): any
	return {
		Bold = false, Italic = Face.Style == Enum.FontStyle.Italic, Underline = false, Strike = false, Color = Color3.new(1, 1, 1),
		Size = Size, Family = Face.Family, Weight = Face.Weight, Transparency = 0,
	}
end

const function Words(): { string }
	const List: { string } = {}
	for _, Line: string in Sentences do
		for Word: string in string.gmatch(Line, "%S+") do table.insert(List, Word) end
	end

	return List
end

AfterAll(function()
	Gui.Cleanup()
end)

Describe("parse rules", function()
	const Into: { number } = {}

	const function Parsed(Text: string): (number, boolean)
		return Glyphs.Parse(Text, Into)
	end

	for _, Case: { any } in ParseCases do
		It(`parse count {Case[1]}`, function()
			Expect((Parsed(Case[1]))).toBe(Case[2])
		end)

		It(`parse valid {Case[1]}`, function()
			Expect(select(2, Parsed(Case[1]))).toBe(Case[3])
		end)
	end

	local First: number = 0
	local Id: number = 0

	It("interned grapheme id stable", function()
		First = select(1, Parsed("中")) :: number
		Id = Into[1]
		Parsed("中文")
		Expect(Into[1]).toBe(Id)
	end)

	It("interned ids above ascii", function()
		Expect(Id >= 128 and First == 1).toBe(true)
	end)

	It("ascii id is byte", function()
		Parsed("ab")
		Expect(Into[1]).toBe(string.byte("a"))
	end)
end)

Describe("advance table math", function()
	local Target: any

	BeforeAll(function()
		Target = Glyphs.New()
		Glyphs.Record(Target, "a", 5, 10)
		Glyphs.Record(Target, "b", 6, 10)
		Glyphs.Record(Target, "c", 7, 12)
	end)

	It("single glyph estimate", function()
		Expect((Glyphs.Estimate(Target, "a"))).toBe(5)
	end)

	It("single glyph height", function()
		Expect(select(2, Glyphs.Estimate(Target, "a"))).toBe(10)
	end)

	It("unknown pair not estimated", function()
		Expect((Glyphs.Estimate(Target, "ab"))).toBeNil()
	end)

	It("pair needed", function()
		Expect(Glyphs.Needs(Target, "ab")).toBeTruthy()
	end)

	It("pair learned", function()
		Glyphs.Record(Target, "ab", 10, 10)
		Expect(Glyphs.Needs(Target, "ab")).toBeFalsy()
	end)

	It("pair estimate uses kern", function()
		Expect((Glyphs.Estimate(Target, "ab"))).toBe(10)
	end)

	It("single unknown pair solved from word", function()
		Glyphs.Record(Target, "abc", 17.5, 12)
		Expect(math.abs((Glyphs.Estimate(Target, "bc")) - 13.5)).toBeLessThanOrEqual(1e-9)
	end)

	It("word estimate sums advances and kerns", function()
		Expect(math.abs((Glyphs.Estimate(Target, "abc")) - 17.5)).toBeLessThanOrEqual(1e-9)
	end)

	It("word height is tallest glyph", function()
		Expect(select(2, Glyphs.Estimate(Target, "abc"))).toBe(12)
	end)

	It("repeated unknown pair divides residual", function()
		Glyphs.Record(Target, "aaa", 14, 10)
		Expect(math.abs((Glyphs.Estimate(Target, "aa")) - 9.5)).toBeLessThanOrEqual(1e-9)
	end)

	It("repeated pair word", function()
		Expect(math.abs((Glyphs.Estimate(Target, "aaaa")) - 18.5)).toBeLessThanOrEqual(1e-9)
	end)

	It("known pairs keep value", function()
		Glyphs.Record(Target, "cab", 30, 12)
		Expect(math.abs((Glyphs.Estimate(Target, "ab")) - 10)).toBeLessThanOrEqual(1e-9)
	end)

	It("new pair from word with one unknown", function()
		Expect(math.abs((Glyphs.Estimate(Target, "ca")) - (7 + 5 + (30 - 17)))).toBeLessThanOrEqual(1e-9)
	end)

	It("several unknown pairs learn nothing", function()
		Glyphs.Record(Target, "cbba", 40, 12)
		Expect(Glyphs.Needs(Target, "cb") and Glyphs.Needs(Target, "bb") and Glyphs.Needs(Target, "ba")).toBeTruthy()
	end)

	It("zero width not recorded", function()
		Glyphs.Record(Target, "d", 0, 10)
		Expect(Glyphs.Needs(Target, "d")).toBeTruthy()
	end)

	It("ineligible pair still learned", function()
		Glyphs.Record(Target, "x", 4, 10)
		Glyphs.Record(Target, "*", 3, 10)
		Glyphs.Record(Target, "x*", 6, 10)
		Expect(Glyphs.Needs(Target, "x*")).toBeFalsy()
	end)

	It("ineligible word never estimated", function()
		Glyphs.Record(Target, "*x", 7, 10)
		Expect((Glyphs.Estimate(Target, "x*x"))).toBeNil()
	end)

	It("ineligible word never teaches", function()
		Glyphs.Record(Target, "x*xa", 99, 10)
		Expect(Glyphs.Needs(Target, "xa")).toBeTruthy()
	end)

	It("cjk pair estimate", function()
		Glyphs.Record(Target, "中", 18, 20)
		Glyphs.Record(Target, "文", 18, 20)
		Glyphs.Record(Target, "中文", 36, 20)
		Expect((Glyphs.Estimate(Target, "中文"))).toBe(36)
	end)
end)

Describe("lessons", function()
	local Target: any
	local Plan: { string }?

	BeforeAll(function()
		Target = Glyphs.New()
		Glyphs.Record(Target, "o", 5, 10)
		Plan = Glyphs.Lesson(Target, "Tool")
	end)

	It("lesson exists", function()
		Expect(Plan).never.toBeNil()
	end)

	It("lesson glyphs then pairs", function()
		Expect(table.concat(Plan or {}, "|")).toBe("T|l|To|oo|ol")
	end)

	It("lesson completes word", function()
		for _, Piece: string in Plan or {} do
			Glyphs.Record(Target, Piece, if #Piece == 1 then 6 else 11, 10)
		end

		Expect((Glyphs.Estimate(Target, "Tool"))).toBe(6 + 5 + 5 + 6 + (11 - 11) + (11 - 10) + (11 - 11))
	end)

	It("no lesson when known", function()
		Expect(Glyphs.Lesson(Target, "Tool")).toBeNil()
	end)

	It("no lesson for ineligible", function()
		Expect(Glyphs.Lesson(Target, "it's")).toBeNil()
	end)

	It("no lesson for single glyph", function()
		Expect(Glyphs.Lesson(Target, "Q")).toBeNil()
	end)
end)

Describe("fallback rules", function()
	const Present: { [string]: boolean } = {}
	const Creepster: Font = Font.new("rbxasset://fonts/families/Creepster.json")
	local Contextual: any
	local Measured: Vector2

	BeforeAll(function()
		for _, Piece: string in Glyphs.Warm :: { string } do Present[Piece] = true end

		Contextual = Style(Creepster, 19)
		Measured = Measure.Bounds(Contextual, 19, "AVATAR", false)
	end)

	It("gotham trusted", function()
		Expect(Glyphs.Trusted(Font.fromEnum(Enum.Font.Gotham).Family)).toBeTruthy()
	end)

	It("creepster exact", function()
		Expect(Glyphs.Trusted("rbxasset://fonts/families/Creepster.json")).toBeFalsy()
	end)

	It("fredoka exact", function()
		Expect(Glyphs.Trusted("rbxasset://fonts/families/FredokaOne.json")).toBeFalsy()
	end)

	It("marker exact", function()
		Expect(Glyphs.Trusted("rbxasset://fonts/families/PermanentMarker.json")).toBeFalsy()
	end)

	It("warm set covers printable ascii", function()
		local Printable: boolean = true
		for Code = 0x20, 0x7E do if not Present[string.char(Code)] then Printable = false end end

		Expect(Printable).toBe(true)
	end)

	It("warm set has digit pairs", function()
		Expect(Present["07"] and Present["99"]).toBeTruthy()
	end)

	It("warm set has capital pairs", function()
		Expect(Present["Th"] and Present["Wh"]).toBeTruthy()
	end)

	It("warm set has sentence ends", function()
		Expect(Present["e."] and Present["s,"]).toBeTruthy()
	end)

	It("untrusted face exact", function()
		Expect(Measured.X).toBe(Exact(Creepster, 19, "AVATAR").X)
	end)

	It("untrusted face learns nothing", function()
		Expect(Measure.TableOf(Contextual, 19)).toBeNil()
	end)
end)

Describe("preload accuracy", function()
	const Face: Font = Font.fromEnum(Enum.Font.Gotham)
	const Size: number = 21
	const List: { string } = Words()

	type Sample = { Real: Vector2, Width: number?, Height: number, Measured: Vector2 }

	local Plain: any
	local Target: any
	const Samples: { Sample } = {}

	BeforeAll(function()
		API.Runtime.Preload({Face}, {Size})

		Plain = Style(Face, Size)
		Target = Measure.TableOf(Plain, Size)

		for Index: number, Word: string in List do
			const Real: Vector2 = Exact(Face, Size, Word)
			local Width: number? = nil
			local Height: number = 0
			if Target then Width, Height = Glyphs.Estimate(Target, Word) end

			Samples[Index] = {Real = Real, Width = Width, Height = Height, Measured = Measure.Bounds(Plain, Size, Word, false)}
		end
	end)

	It("preload builds table", function()
		Expect(Target).never.toBeNil()
	end)

	It("preload measured printable ascii", function()
		local Covered: boolean = true
		for Code = 0x20, 0x7E do if Glyphs.Needs(Target, string.char(Code)) then Covered = false end end

		Expect(Covered).toBe(true)
	end)

	It("preload builds bold variant", function()
		const Bold: any = Style(Face, Size)
		Bold.Bold = true

		Expect(Measure.TableOf(Bold, Size)).never.toBeNil()
	end)

	It("estimate height for every estimable word", function()
		for Index: number, Word: string in List do
			const Sample: Sample = Samples[Index]
			if Sample.Width then Expect(`{Word} {math.abs(Sample.Height - Sample.Real.Y) <= 0.01}`).toBe(`{Word} true`) end
		end
	end)

	for Index: number, Word: string in List do
		It(`bounds {Word}`, function()
			Expect(math.abs(Samples[Index].Measured.X - Samples[Index].Real.X)).toBeLessThanOrEqual(1)
		end)

		It(`bounds height {Word}`, function()
			Expect(math.abs(Samples[Index].Measured.Y - Samples[Index].Real.Y)).toBeLessThanOrEqual(0.01)
		end)
	end

	It("some words estimable after preload", function()
		local Estimated: number = 0
		for _, Sample: Sample in Samples do if Sample.Width then Estimated += 1 end end

		Expect(Estimated).toBeGreaterThan(0)
	end)

	It("estimates within one pixel", function()
		local Worst: number = 0
		local WorstWord: string = ""

		for Index: number, Sample: Sample in Samples do
			if not Sample.Width then continue end

			const Error: number = math.abs(Sample.Real.X - (Sample.Width :: number))
			if Error > Worst then Worst = Error; WorstWord = List[Index] end
		end

		Expect(`{WorstWord} {Worst <= 1}`).toBe(`{WorstWord} true`)
	end)

	for Word: string in string.gmatch("The people could make water and come back to their house again.", "%S+") do
		It(`common word estimable after preload {Word}`, function()
			Expect((Glyphs.Estimate(Target, Word))).never.toBeNil()
		end)
	end
end)

Describe("gather", function()
	local Started: number = 0
	local Finished: number = 0
	local Overlapped: boolean = true

	BeforeAll(function()
		const function Job(): ()
			Started += 1
			task.wait(0.05)
			if Started < 3 then Overlapped = false end
			Finished += 1
		end

		Measure.Gather({Job, Job, function() error("job failure is contained") end, Job})
	end)

	It("gather runs every job", function()
		Expect(Finished).toBe(3)
	end)

	It("gather overlaps waits", function()
		Expect(Overlapped).toBe(true)
	end)

	It("gather without yields", function()
		local Immediate: number = 0
		Measure.Gather({function() Immediate += 1 end, function() Immediate += 1 end})

		Expect(Immediate).toBe(2)
	end)

	It("gather empty returns", function()
		Expect(function() Measure.Gather({}) end).never.toThrow()
	end)
end)

Describe("renderer uses tables", function()
	type Row = { Text: string, Width: number, Height: number, Real: Vector2 }

	local Renderer: any
	const Rows: { Row } = {}

	BeforeAll(function()
		const Face: Font = Font.fromEnum(Enum.Font.Gotham)

		const Label: TextLabel = Instance.new("TextLabel")
		Label.Size = UDim2.fromOffset(360, 400)
		Label.TextSize = 21
		Label.TextWrapped = true
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.TextYAlignment = Enum.TextYAlignment.Top
		Label.FontFace = Face
		Label.Text = "<b>Brave</b> words " .. Sentences[1]
		Label.Parent = Gui.new("Glyphs")

		Renderer = API.new(Label):SetRendering("Passthrough", false):Flush()
		Renderer.Label.Text = Label.Text .. " " .. Sentences[2]
		Renderer:Flush()

		for _, Token: any in Renderer.Document.Tokens do
			if not (Token.Text and Token.Style) then continue end

			table.insert(Rows, {Text = Token.Text, Width = Token.Width, Height = Token.Height, Real = Exact(Measure.FontOf(Token.Style), 21, Token.Text)})
		end
	end)

	AfterAll(function()
		if Renderer then Renderer:Destroy() end
	end)

	It("token width for every token", function()
		for _, Row: Row in Rows do
			Expect(`{Row.Text} {math.abs(Row.Width - Row.Real.X) <= 1}`).toBe(`{Row.Text} true`)
		end
	end)

	It("token height for every token", function()
		for _, Row: Row in Rows do
			Expect(`{Row.Text} {math.abs(Row.Height - Row.Real.Y) <= 0.01}`).toBe(`{Row.Text} true`)
		end
	end)
end)
