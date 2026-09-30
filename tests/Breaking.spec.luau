--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Unicode = require("../Packages/RichTextPlus/Text/Unicode")
const Bidi = require("../Packages/RichTextPlus/Text/Bidi")
const Measure = require("../Packages/RichTextPlus/Text/Measure")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Family: string = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
const Thumb: string = "\u{1F44D}\u{1F3FD}"
const Heart: string = "\u{2764}\u{FE0F}"
const Rainbow: string = "\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}"
const Flags: { string } = {"\u{1F1FA}\u{1F1F8}", "\u{1F1EF}\u{1F1F5}", "\u{1F1EB}\u{1F1F7}", "\u{1F1E9}\u{1F1EA}"}
const Shy: string = "\u{AD}"
const Zwsp: string = "\u{200B}"
const Joiner: string = "\u{2060}"
const Nbsp: string = "\u{A0}"

const Japanese: string = "日本語の文章は、句読点（、。）や括弧「」を含みます。これは禁則処理のテストです！「開き括弧」は行末に来てはいけません。閉じ括弧」も行頭に来てはいけません？ちょっと待ってください。"
const Chinese: string = "你好，世界。我们在测试中文换行：每个汉字之间都可以断开，但是标点符号不能出现在行首。【重要】请注意《书名号》和（括号）的位置！"
const Korean: string = "안녕하세요 세계. 한국어 줄바꿈을 시험합니다."

const NoStart: { [string]: boolean } = {}
for _, Mark: string in {"、", "。", "，", "．", "）", "」", "』", "】", "〉", "》", "！", "？", "：", "ー", "っ", "ょ"} do NoStart[Mark] = true end

const NoEnd: { [string]: boolean } = {}
for _, Mark: string in {"（", "「", "『", "【", "〈", "《"} do NoEnd[Mark] = true end

local Screen: ScreenGui
const Renderers: { any } = {}

const function Build(Target: TextLabel): any
	const Renderer: any = RichTextPlus.new(Target):SetRendering("Passthrough", false):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Label(Text: string, Width: number, Height: number?): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width, Height or 400)
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

const function Resize(Target: TextLabel, Renderer: any, Width: number): ()
	Target.Size = UDim2.fromOffset(Width, Target.Size.Y.Offset)
	const _Size: Vector2 = Target.AbsoluteSize
	Renderer:Flush()
end

const function Segments(Target: TextLabel): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Found, Child :: TextLabel) end
	end

	table.sort(Found, function(A: TextLabel, B: TextLabel): boolean
		if A.Position.Y.Offset ~= B.Position.Y.Offset then return A.Position.Y.Offset < B.Position.Y.Offset end

		return A.Position.X.Offset < B.Position.X.Offset
	end)

	return Found
end

const function Rows(Target: TextLabel): { { TextLabel } }
	const Result: { { TextLabel } } = {}
	local Y: number? = nil

	for _, Segment: TextLabel in Segments(Target) do
		if Segment.Position.Y.Offset ~= Y then
			Y = Segment.Position.Y.Offset
			table.insert(Result, {})
		end

		table.insert(Result[#Result], Segment)
	end

	return Result
end

const function RowTexts(Target: TextLabel): { string }
	const Texts: { string } = {}

	for _, Row: { TextLabel } in Rows(Target) do
		const Parts: { string } = {}
		for _, Segment: TextLabel in Row do table.insert(Parts, Segment.Text) end
		table.insert(Texts, table.concat(Parts))
	end

	return Texts
end

const function Clusters(Text: string): { string }
	const Found: { string } = {}
	for First: number, Last: number in utf8.graphemes(Text) do table.insert(Found, string.sub(Text, First, Last)) end

	return Found
end

const function Widest(Target: TextLabel): number
	local Right: number = 0
	for _, Segment: TextLabel in Segments(Target) do Right = math.max(Right, Segment.Position.X.Offset + Segment.Size.X.Offset) end

	return Right
end

const function Find(Target: TextLabel, Needle: string): TextLabel?
	local Found: TextLabel? = nil

	for _, Segment: TextLabel in Segments(Target) do
		if string.find(Segment.Text, Needle, 1, true) then Found = Segment end
	end

	return Found
end

const function Visual(Target: TextLabel): string
	const Order: { string } = {}
	for _, Segment: TextLabel in Segments(Target) do table.insert(Order, Segment.Text) end

	return table.concat(Order, "|")
end

const function RightEdge(Segment: TextLabel): number
	return Segment.Position.X.Offset + Segment.Size.X.Offset
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("Breaking")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("unicode helpers", function()
	AfterAll(Release)

	It("count ascii", function()
		Expect(Unicode.Count("hello")).toBe(5)
	end)

	It("count family", function()
		Expect(Unicode.Count(Family)).toBe(1)
	end)

	It("count mixed", function()
		Expect(Unicode.Count(`{Family}{Thumb}{Flags[1]}{Heart}x`)).toBe(5)
	end)

	It("count combining", function()
		Expect(Unicode.Count("e\u{301}a")).toBe(2)
	end)

	It("count invalid utf8 falls back to bytes", function()
		Expect(Unicode.Count("a\255b")).toBe(3)
	end)

	It("starts ascii", function()
		Expect(table.concat(Unicode.Starts("abc"), ",")).toBe("1,2,3,4")
	end)

	It("starts cluster", function()
		Expect(table.concat(Unicode.Starts(`a{Thumb}b`), ",")).toBe(`1,2,{2 + #Thumb},{3 + #Thumb}`)
	end)

	It("wide ideograph", function()
		Expect(Unicode.Wide(utf8.codepoint("中"))).toBeTruthy()
	end)

	It("wide kana", function()
		Expect(Unicode.Wide(utf8.codepoint("あ"))).toBeTruthy()
	end)

	It("wide hangul", function()
		Expect(Unicode.Wide(utf8.codepoint("한"))).toBeTruthy()
	end)

	It("latin not wide", function()
		Expect(Unicode.Wide(utf8.codepoint("e"))).toBeFalsy()
	end)

	It("cjk pair breaks", function()
		Expect(Unicode.Joins(utf8.codepoint("中"), utf8.codepoint("文"))).toBeFalsy()
	end)

	It("closing joins", function()
		Expect(Unicode.Joins(utf8.codepoint("好"), utf8.codepoint("。"))).toBeTruthy()
	end)

	It("opening joins", function()
		Expect(Unicode.Joins(utf8.codepoint("「"), utf8.codepoint("日"))).toBeTruthy()
	end)

	It("latin joins", function()
		Expect(Unicode.Joins(string.byte("a"), string.byte("b"))).toBeTruthy()
	end)

	It("class hebrew", function()
		Expect(Unicode.Class(utf8.codepoint("ש"))).toBe(Unicode.Right)
	end)

	It("class arabic", function()
		Expect(Unicode.Class(utf8.codepoint("م"))).toBe(Unicode.Right)
	end)

	It("class latin", function()
		Expect(Unicode.Class(string.byte("q"))).toBe(Unicode.Left)
	end)

	It("class digit", function()
		Expect(Unicode.Class(string.byte("7"))).toBe(Unicode.Digit)
	end)

	It("class punctuation", function()
		Expect(Unicode.Class(string.byte("!"))).toBe(Unicode.Neutral)
	end)

	It("strength first strong", function()
		Expect(Unicode.Strength("123 שלום abc")).toBe(Unicode.Right)
	end)

	It("strength number", function()
		Expect(Unicode.Strength("3.14")).toBe(Unicode.Digit)
	end)
end)

Describe("tokens", function()
	AfterAll(Release)

	local Texts: { string }
	const ByText: { [string]: any } = {}

	BeforeAll(function()
		const Target: TextLabel = Label(`你好，世界。「日本」{Joiner} a{Shy}b c{Zwsp}d e{Nbsp}f g{Joiner}h foo<b>bar</b>`, 600)
		const Renderer: any = Build(Target)

		Texts = {}
		for _, Token: any in Renderer.Document.Tokens do
			table.insert(Texts, Token.Text or "?")
			ByText[Token.Text] = Token
		end
	end)

	It("cjk tokens with kinsoku", function()
		Expect(table.concat(Texts, "|")).toBe("你|好，|世|界。|「日|本」|a|b|c|d|e\u{A0}f|gh|foo|bar")
	end)

	It("cjk no inserted space", function()
		Expect(ByText["好，"].SpaceBefore).toBe(false)
	end)

	It("cjk breakable", function()
		Expect(ByText["好，"].Glue).toBeFalsy()
	end)

	It("soft hyphen marks previous", function()
		Expect(ByText["a"].Hyphen).toBeGreaterThan(0)
	end)

	It("soft hyphen fragment breakable", function()
		Expect(ByText["b"].Glue).toBeFalsy()
	end)

	It("zwsp breakable", function()
		Expect(not ByText["d"].Glue and not ByText["c"].Hyphen).toBe(true)
	end)

	It("style boundary glued", function()
		Expect(ByText["bar"].Glue).toBe(true)
	end)

	It("no bidi levels in ltr text", function()
		Expect(ByText["foo"].Level).toBeNil()
	end)
end)

Describe("emoji clusters never split", function()
	AfterAll(Release)

	const Allowed: { [string]: boolean } = {[Family] = true, [Thumb] = true, [Heart] = true, [Rainbow] = true}
	for _, Flag: string in Flags do Allowed[Flag] = true end

	const Parts: { string } = {}
	for Index = 1, 6 do
		table.insert(Parts, Family)
		table.insert(Parts, Flags[(Index - 1) % #Flags + 1])
		table.insert(Parts, Thumb)
		table.insert(Parts, Heart)
		table.insert(Parts, Rainbow)
	end
	const Source: string = table.concat(Parts)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(Source, 70)
		Renderer = Build(Target)
	end)

	for _, Width: number in {70, 95, 130, 170, 230} do
		Describe(`at {Width}`, function()
			local Rendered: { TextLabel }

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Rendered = Segments(Target)
			end)

			It(`emoji wraps at {Width}`, function()
				Expect(#Rendered).toBeGreaterThan(1)
			end)

			It(`every segment holds whole clusters at {Width}`, function()
				local Broken: string? = nil
				for _, Segment: TextLabel in Rendered do
					for _, Cluster: string in Clusters(Segment.Text) do if not Allowed[Cluster] then Broken = Cluster end end
				end

				Expect(Broken).toBeNil()
			end)

			It(`emoji text preserved at {Width}`, function()
				const Joined: { string } = {}
				for _, Segment: TextLabel in Rendered do table.insert(Joined, Segment.Text) end

				Expect(table.concat(Joined)).toBe(Source)
			end)
		end)
	end
end)

Describe("emoji inside overlong word", function()
	AfterAll(Release)

	const Source: string = `abc{Family}def{Thumb}ghi{Flags[1]}{Flags[2]}jkl{Heart}mno{Rainbow}pqr`
	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(Source, 45)
		Renderer = Build(Target)
	end)

	for _, Width: number in {45, 60, 75} do
		Describe(`at {Width}`, function()
			local Rendered: { TextLabel }

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Rendered = Segments(Target)
			end)

			It(`no dangling joiner at {Width}`, function()
				for _, Segment: TextLabel in Rendered do
					Expect(string.find(Segment.Text, "\u{200D}$") or string.find(Segment.Text, "^\u{200D}")).toBeNil()
				end
			end)

			It(`flags stay paired at {Width}`, function()
				local Odd: boolean = false
				for _, Segment: TextLabel in Rendered do
					local Indicators: number = 0
					for _, Code: number in utf8.codes(Segment.Text) do if Code >= 0x1F1E6 and Code <= 0x1F1FF then Indicators += 1 end end
					if Indicators % 2 == 1 then Odd = true end
				end

				Expect(Odd).toBe(false)
			end)

			It(`overlong text preserved at {Width}`, function()
				const Joined: { string } = {}
				for _, Segment: TextLabel in Rendered do table.insert(Joined, Segment.Text) end

				Expect(table.concat(Joined)).toBe(Source)
			end)
		end)
	end
end)

Describe("reveal counts clusters", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`{Family}{Thumb}{Flags[1]} ok`, 400)
		Renderer = Build(Target)
	end)

	It("record graphemes", function()
		const Record: any = Renderer.Instances.Order[1]
		Expect(Record and Record.Content.Graphemes).toBe(6)
	end)

	It("grapheme count counts clusters", function()
		Expect(Renderer:GetGraphemeCount()).toBe(6)
	end)

	It("first cluster revealed", function()
		Target.MaxVisibleGraphemes = 1
		task.wait()

		Expect(Segments(Target)[1].MaxVisibleGraphemes).toBe(1)
	end)

	It("count reveals every cluster", function()
		Target.MaxVisibleGraphemes = Renderer:GetGraphemeCount()
		task.wait()

		Expect(Segments(Target)[1].MaxVisibleGraphemes).toBe(-1)
	end)
end)

Describe("cjk wrapping and kinsoku", function()
	AfterAll(Release)

	for _, Source: string in {Japanese, Chinese} do
		Describe(string.sub(Source, 1, 9), function()
			local Target: TextLabel
			local Renderer: any

			BeforeAll(function()
				Target = Label(Source, 90)
				Renderer = Build(Target)
			end)

			for Width = 90, 330, 11 do
				Describe(`at {Width}`, function()
					local Texts: { string }

					BeforeAll(function()
						Resize(Target, Renderer, Width)
						Texts = RowTexts(Target)
					end)

					It(`cjk wraps at {Width}`, function()
						Expect(#Texts).toBeGreaterThan(1)
					end)

					It(`cjk text preserved at {Width}`, function()
						Expect(table.concat(Texts)).toBe(Source)
					end)

					It(`cjk fits at {Width}`, function()
						Expect(Widest(Target)).toBeLessThanOrEqual(Width + 1)
					end)

					It(`lines at {Width} insert no space and obey kinsoku`, function()
						for Index: number, Text: string in Texts do
							const Found: { string } = Clusters(Text)
							Expect((string.find(Text, " ", 1, true))).toBeNil()
							if Index > 1 then Expect(`line {Index} starts with {Found[1]}: {NoStart[Found[1]] == true}`).toBe(`line {Index} starts with {Found[1]}: false`) end
							if Index < #Texts then Expect(`line {Index} ends with {Found[#Found]}: {NoEnd[Found[#Found]] == true}`).toBe(`line {Index} ends with {Found[#Found]}: false`) end
						end
					end)
				end)
			end
		end)
	end
end)

Describe("cjk fills lines", function()
	AfterAll(Release)

	It("cjk lines are filled, not word wrapped", function()
		const Target: TextLabel = Label(Chinese, 200)
		Build(Target)
		const Texts: { string } = RowTexts(Target)

		local Short: number = 0
		for Index = 1, #Texts - 1 do if Unicode.Count(Texts[Index]) < 8 then Short += 1 end end

		Expect(#Texts > 2 and Short == 0).toBe(true)
	end)
end)

Describe("hangul and mixed scripts", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Texts: { string }

	BeforeAll(function()
		Target = Label(Korean, 110)
		Renderer = Build(Target)
		Texts = RowTexts(Target)
	end)

	It("korean wraps", function()
		Expect(#Texts).toBeGreaterThan(1)
	end)

	It("korean fits", function()
		Expect(Widest(Target)).toBeLessThanOrEqual(111)
	end)

	It("latin run inside cjk kept whole", function()
		Renderer.Label.Text = "中文(English)中文"
		Renderer:Flush()

		local Kept: boolean = false
		for _, Text: string in RowTexts(Target) do if string.find(Text, "(English)", 1, true) then Kept = true end end

		Expect(Kept).toBe(true)
	end)
end)

Describe("soft hyphen", function()
	AfterAll(Release)

	const Source: string = `Donau{Shy}dampf{Shy}schiff{Shy}fahrts{Shy}gesell{Shy}schaft`
	const Plain: string = "Donaudampfschifffahrtsgesellschaft"
	local Target: TextLabel
	local Renderer: any
	local Wide: { string }

	BeforeAll(function()
		Target = Label(Source, 800)
		Renderer = Build(Target)
		Wide = RowTexts(Target)
	end)

	It("single line when it fits", function()
		Expect(#Wide).toBe(1)
	end)

	It("soft hyphen invisible", function()
		Expect(Wide[1]).toBe(Plain)
	end)

	for _, Width: number in {90, 120, 160, 220} do
		Describe(`at {Width}`, function()
			local Texts: { string }

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Texts = RowTexts(Target)
			end)

			It(`hyphenated wraps at {Width}`, function()
				Expect(#Texts).toBeGreaterThan(1)
			end)

			It(`hyphenated fits at {Width}`, function()
				Expect(Widest(Target)).toBeLessThanOrEqual(Width + 1)
			end)

			It(`lines at {Width} end with hyphens and hide soft hyphens`, function()
				for Index: number, Text: string in Texts do
					if Index < #Texts then Expect(`line {Index} {Text}`).toBe(`line {Index} {string.sub(Text, 1, -2)}-`) end
					Expect((string.find(Text, Shy, 1, true))).toBeNil()
				end
			end)

			It(`hyphen removed text at {Width}`, function()
				Expect((string.gsub(table.concat(Texts), "%-", ""))).toBe(Plain)
			end)

			It(`last line has no hyphen at {Width}`, function()
				Expect(string.sub(Texts[#Texts], -1)).never.toBe("-")
			end)
		end)
	end

	It("soft hyphen before space ignored", function()
		Renderer.Label.Text = `well{Shy} known`
		Renderer:Flush()

		Expect(table.concat(RowTexts(Target))).toBe("well known")
	end)
end)

Describe("hard hyphen fallback", function()
	AfterAll(Release)

	local Texts: { string }

	BeforeAll(function()
		const Target: TextLabel = Label("state-of-the-art/extraordinarily", 90)
		Build(Target)
		Texts = RowTexts(Target)
	end)

	It("overlong hyphenated word splits", function()
		Expect(#Texts).toBeGreaterThan(1)
	end)

	It("prefers break after hyphen or slash", function()
		Expect((string.find(Texts[1], "[%-/]$"))).never.toBeNil()
	end)

	It("hard hyphen text preserved", function()
		Expect(table.concat(Texts)).toBe("state-of-the-art/extraordinarily")
	end)
end)

Describe("zero width space", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`aaaaaa{Zwsp}bbbbbb{Zwsp}cccccc{Zwsp}dddddd`, 800)
		Renderer = Build(Target)
	end)

	It("zwsp invisible when unbroken", function()
		Expect(table.concat(RowTexts(Target))).toBe("aaaaaabbbbbbccccccdddddd")
	end)

	It("zwsp single line", function()
		Expect(#RowTexts(Target)).toBe(1)
	end)

	Describe("wrapped", function()
		local Texts: { string }

		BeforeAll(function()
			Resize(Target, Renderer, 80)
			Texts = RowTexts(Target)
		end)

		It("zwsp wraps", function()
			Expect(#Texts).toBeGreaterThanOrEqual(2)
		end)

		It("zwsp breaks only at opportunities", function()
			for _, Text: string in Texts do
				Expect(string.match(Text, "^[a-d]+$") ~= nil and #Text % 6 == 0).toBe(true)
			end
		end)
	end)
end)

Describe("no break joiners", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`xxxxxxxx alpha{Nbsp}beta`, 800)
		Renderer = Build(Target)

		const Style: any = Renderer.Document.Tokens[1].Style
		const Head: number = Measure.Bounds(Style, 18, "xxxxxxxx alpha", false).X
		Resize(Target, Renderer, math.ceil(Head) + 4)
	end)

	It("nbsp moves together", function()
		Expect(RowTexts(Target)[2]).toBe(`alpha{Nbsp}beta`)
	end)

	It("word joiner holds and hides", function()
		Renderer.Label.Text = `xxxxxxxx alpha{Joiner}beta`
		Renderer:Flush()

		Expect(RowTexts(Target)[2]).toBe("alphabeta")
	end)

	Describe("styled", function()
		local Styled: { string }

		BeforeAll(function()
			Renderer.Label.Text = "xxxxxxxx alpha<b>beta</b>"
			Renderer:Flush()
			Styled = RowTexts(Target)
		end)

		It("style change mid word holds", function()
			Expect(Styled[#Styled]).toBe("alphabeta")
		end)

		It("style change first line", function()
			Expect(Styled[1]).toBe("xxxxxxxx")
		end)
	end)

	It("nbsp fallback splits overlong run", function()
		Renderer.Label.Text = `{string.rep("n", 30)}{Nbsp}{string.rep("m", 30)}`
		Renderer:Flush()

		Expect(#RowTexts(Target)).toBeGreaterThan(1)
	end)
end)

Describe("bidi arrange", function()
	AfterAll(Release)

	const function Make(X: number, Width: number, Level: number?): any
		return {Kind = "Word", Text = "w", Width = Width, Height = 10, X = X, SpaceBefore = false, Level = Level}
	end

	const Line: { any } = {Make(0, 10, 1), Make(14, 20, 1), Make(38, 10, 2), Make(52, 6, 2), Make(62, 8, 1)}
	const Mixed: { any } = {Make(0, 10, 0), Make(14, 10, 1), Make(28, 10, 1), Make(42, 10, 0)}

	BeforeAll(function()
		Bidi.Arrange(Line)
		Bidi.Arrange(Mixed)
	end)

	for _, Row: { any } in {
		{"rtl first word rightmost", Line, 1, 60},
		{"rtl second word", Line, 2, 36},
		{"ltr run keeps order a", Line, 3, 12},
		{"ltr run keeps order b", Line, 4, 26},
		{"rtl last word leftmost", Line, 5, 0},
		{"ltr paragraph keeps ltr", Mixed, 1, 0},
		{"embedded rtl reversed a", Mixed, 2, 28},
		{"embedded rtl reversed b", Mixed, 3, 14},
		{"ltr after rtl", Mixed, 4, 42},
	} do
		It(Row[1], function()
			Expect(Row[2][Row[3]].X).toBe(Row[4])
		end)
	end
end)

Describe("rtl paragraphs", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("שלום עולם abc def 123", 400)
		Renderer = Build(Target)
	end)

	Describe("hebrew with latin", function()
		local Hebrew: TextLabel?
		local Latin: TextLabel?
		local Number: TextLabel?

		BeforeAll(function()
			Hebrew = Find(Target, "שלום")
			Latin = Find(Target, "abc")
			Number = Find(Target, "123")
		end)

		It("hebrew run", function()
			Expect(Hebrew).never.toBeNil()
		end)

		It("latin run", function()
			Expect(Latin).never.toBeNil()
		end)

		It("rtl places latin left of hebrew", function()
			if not (Hebrew and Latin) then return end
			Expect(Latin.Position.X.Offset).toBeLessThan(Hebrew.Position.X.Offset)
		end)

		It("hebrew run keeps logical text", function()
			if not (Hebrew and Latin) then return end
			Expect(Hebrew.Text).toBe("שלום עולם")
		end)

		It("rtl aligns right", function()
			if not (Hebrew and Latin) then return end
			Expect(math.abs(RightEdge(Hebrew) - 400)).toBeLessThanOrEqual(1)
		end)

		It("latin keeps internal order", function()
			if not (Hebrew and Latin) then return end
			Expect((string.find(Latin.Text, "abc def", 1, true))).never.toBeNil()
		end)

		It("number follows latin in visual ltr run", function()
			if not (Number and Latin) then return end
			Expect(Number.Position.X.Offset).toBeGreaterThanOrEqual(Latin.Position.X.Offset)
		end)
	end)

	Describe("ltr paragraph with rtl words", function()
		BeforeAll(function()
			Renderer.Label.Text = "Hello שלום עולם world"
			Renderer:Flush()
		end)

		It("ltr paragraph with rtl words", function()
			Expect(Visual(Target)).toBe("Hello|שלום עולם|world")
		end)

		It("ltr paragraph aligns left", function()
			Expect(Segments(Target)[1].Position.X.Offset).toBe(0)
		end)
	end)

	Describe("arabic", function()
		local Lines: { { TextLabel } }

		BeforeAll(function()
			Renderer.Label.Text = "مرحبا بالعالم هذا نص طويل جدا يلتف على عدة أسطر في هذه التسمية الضيقة"
			Renderer:Flush()
			Resize(Target, Renderer, 160)
			Lines = Rows(Target)
		end)

		It("arabic wraps", function()
			Expect(#Lines).toBeGreaterThan(1)
		end)

		It("arabic lines right aligned", function()
			for _, Row: { TextLabel } in Lines do
				Expect(math.abs(RightEdge(Row[#Row]) - 160)).toBeLessThanOrEqual(1)
			end
		end)

		It("first logical word on first line right side", function()
			Expect((string.find(Lines[1][#Lines[1]].Text, "مرحبا", 1, true))).never.toBeNil()
		end)
	end)

	Describe("rtl sentence", function()
		local Year: TextLabel?
		local Stop: TextLabel?

		BeforeAll(function()
			Renderer.Label.Text = "מספר 2026."
			Renderer:Flush()

			for _, Segment: TextLabel in Segments(Target) do
				if Segment.Text == "2026" then Year = Segment end
				if Segment.Text == "." then Stop = Segment end
			end
		end)

		It("rtl sentence period detached from number", function()
			Expect(Year ~= nil and Stop ~= nil).toBe(true)
		end)

		It("rtl period sits left of number", function()
			if not (Year and Stop) then return end
			Expect(Stop.Position.X.Offset).toBeLessThan(Year.Position.X.Offset)
		end)
	end)

	It("ltr period after rtl word stays right", function()
		Renderer.Label.Text = "abc שלום. def"
		Renderer:Flush()

		Expect(Visual(Target)).toBe("abc|שלום|. def")
	end)

	It("direction resolved per paragraph", function()
		Renderer.Label.Text = "שלום<br/>hello"
		Renderer:Flush()
		const Split: { { TextLabel } } = Rows(Target)

		Expect(if Split[2] then Split[2][1].Position.X.Offset else nil).toBe(0)
	end)
end)

Describe("dir tag", function()
	AfterAll(Release)

	local Lines: { { TextLabel } }

	BeforeAll(function()
		const Target: TextLabel = Label([[<dir value="rtl">abc def</dir><br/>plain<br/><dir value="ltr">שלום עולם</dir>]], 300)
		Build(Target)
		Lines = Rows(Target)
	end)

	It("dir rows", function()
		Expect(#Lines).toBe(3)
	end)

	It("dir rtl aligns right", function()
		if #Lines ~= 3 then return end
		Expect(math.abs(RightEdge(Lines[1][#Lines[1]]) - 300)).toBeLessThanOrEqual(1)
	end)

	It("dir rtl keeps latin order", function()
		if #Lines ~= 3 then return end
		Expect(Lines[1][#Lines[1]].Text).toBe("abc def")
	end)

	It("plain stays left", function()
		if #Lines ~= 3 then return end
		Expect(Lines[2][1].Position.X.Offset).toBe(0)
	end)

	It("dir ltr aligns left", function()
		if #Lines ~= 3 then return end
		Expect(Lines[3][1].Position.X.Offset).toBe(0)
	end)
end)
