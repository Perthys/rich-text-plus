--!strict

const TextService = game:GetService("TextService")

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const XML = require("../Packages/XML")
const Reflow = require("../Packages/RichTextPlus/Utility/Reflow")
const CodeBlock = require("../Packages/RichTextPlus/Classes/CodeBlock")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Row = {
	Y: number,
	Segments: { TextLabel },
}

const Library: any = RichTextPlus
const Parser: any = XML

const Filler: string = "the quick brown fox jumps over the lazy dog while the text keeps going for a while"

local Screen: ScreenGui
const Renderers: { any } = {}

const function Build(Target: TextLabel): any
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false):Flush()
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Label(Text: string, Width: number): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(Width, 800)
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
	Target.Size = UDim2.fromOffset(Width, 800)
	const _Size: Vector2 = Target.AbsoluteSize
	Renderer:Flush()
end

const function Rows(Target: TextLabel): { Row }
	const ByY: { [number]: Row } = {}
	const List: { Row } = {}

	for _, Child: Instance in Target:GetChildren() do
		if Child.Name ~= "Segment" or not (Child :: GuiObject).Visible then continue end

		const Segment: TextLabel = Child :: TextLabel
		const Y: number = Segment.Position.Y.Offset
		const Found: Row? = ByY[Y]

		if Found then
			table.insert(Found.Segments, Segment)
		else
			const Created: Row = {Y = Y, Segments = {Segment}}
			ByY[Y] = Created
			table.insert(List, Created)
		end
	end

	table.sort(List, function(A: Row, B: Row): boolean return A.Y < B.Y end)

	for _, Entry: Row in List do
		table.sort(Entry.Segments, function(A: TextLabel, B: TextLabel): boolean return A.Position.X.Offset < B.Position.X.Offset end)
	end

	return List
end

const function Left(Entry: Row): number
	for _, Segment: TextLabel in Entry.Segments do
		if not string.find(Segment.Text, "^[\u{A0}%s]*$") then return Segment.Position.X.Offset end
	end

	return -1
end

const function Layers(Target: TextLabel): { Frame }
	const Found: { Frame } = {}
	const Holder: Instance? = Target:FindFirstChild("Backdrops")
	if not Holder then return Found end

	for _, Child: Instance in (Holder :: Instance):GetChildren() do
		if Child.Name == "Backdrop" and (Child :: GuiObject).Visible then table.insert(Found, Child :: Frame) end
	end

	table.sort(Found, function(A: Frame, B: Frame): boolean
		if A.Position.Y.Offset ~= B.Position.Y.Offset then return A.Position.Y.Offset < B.Position.Y.Offset end

		return A.Position.X.Offset < B.Position.X.Offset
	end)

	return Found
end

const function Rounding(Layer: Frame): string
	const Fill: Frame? = Layer:FindFirstChild("Fill") :: Frame?

	if Fill and Fill.Visible then return if Fill.Position.X.Offset == 0 then "left" else "right" end
	if Layer:FindFirstChildOfClass("UICorner") then return "both" end

	return "none"
end

const function Covered(Target: TextLabel, Pattern: string): { TextLabel }
	const Found: { TextLabel } = {}

	for _, Entry: Row in Rows(Target) do
		for _, Segment: TextLabel in Entry.Segments do
			if string.find(Segment.Text, Pattern) then table.insert(Found, Segment) end
		end
	end

	return Found
end

const function Inside(Segment: TextLabel, Layer: Frame): boolean
	const X: number = Segment.Position.X.Offset
	const Y: number = Segment.Position.Y.Offset

	return Y == Layer.Position.Y.Offset
		and X >= Layer.Position.X.Offset - 0.5
		and X + Segment.TextBounds.X <= Layer.Position.X.Offset + Layer.Size.X.Offset + 1
end

const function InsideAny(Segment: TextLabel, Pieces: { Frame }): boolean
	for _, Piece: Frame in Pieces do
		if Inside(Segment, Piece) then return true end
	end

	return false
end

const function Continuations(Found: { Row }, Anchor: number, Tolerance: number): ()
	for Index = 2, #Found do
		Expect(math.abs(Left(Found[Index]) - Anchor)).toBeLessThanOrEqual(Tolerance)
	end
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("Layout")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("explicit indent", function()
	AfterAll(Release)

	local Target: TextLabel
	local Found: { Row }

	BeforeAll(function()
		Target = Label(`<indent by="40">{Filler}</indent>`, 220)
		Build(Target)
		Found = Rows(Target)
	end)

	It("explicit indent wraps", function()
		Expect(#Found).toBeGreaterThanOrEqual(3)
	end)

	It("explicit indent first line flush", function()
		Expect(Left(Found[1])).toBe(0)
	end)

	It("explicit indent continuation", function()
		Continuations(Found, 40, 0.5)
	end)

	It("em indent continuation", function()
		Target.Text = `<indent by="2em">{Filler}</indent>`
		task.wait()

		Continuations(Rows(Target), 36, 0.5)
	end)

	Describe("broken", function()
		local Broken: { Row }

		BeforeAll(function()
			Target.Text = `<indent by="40">short<br/>{Filler}</indent>`
			task.wait()
			Broken = Rows(Target)
		end)

		It("explicit break line flush", function()
			Expect(Left(Broken[2])).toBe(0)
		end)

		It("wrap after break indented", function()
			Expect(math.abs(Left(Broken[3]) - 40)).toBeLessThanOrEqual(0.5)
		end)
	end)

	It("oversized indent stays inside", function()
		Target.Text = `<indent by="500">{Filler}</indent>`
		task.wait()

		for _, Entry: Row in Rows(Target) do
			const Last: TextLabel = Entry.Segments[#Entry.Segments]
			Expect(Last.Position.X.Offset + Last.TextBounds.X).toBeLessThanOrEqual(221)
		end
	end)
end)

Describe("auto indent", function()
	AfterAll(Release)

	local Found: { Row }
	local Anchor: number

	BeforeAll(function()
		const Target: TextLabel = Label(`Label: <indent>{Filler}</indent>`, 240)
		Build(Target)
		Found = Rows(Target)
		Anchor = Found[1].Segments[2].Position.X.Offset
	end)

	It("auto anchor after label", function()
		Expect(Anchor).toBeGreaterThan(0)
	end)

	It("auto indent wraps", function()
		Expect(#Found).toBeGreaterThanOrEqual(3)
	end)

	It("auto continuation", function()
		Continuations(Found, Anchor, 0.5)
	end)
end)

Describe("markdown lists", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`<md>- {Filler}\n  - nested {Filler}\n1. {Filler}</md>`, 260)
		Renderer = Build(Target)
	end)

	for _, Width: number in {260, 180, 340} do
		Describe(`at {Width}`, function()
			local Found: { Row }
			local Items: number = 0

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Found = Rows(Target)
			end)

			It(`list {Width} markers and continuations`, function()
				local Anchor: number = -1

				for _, Entry: Row in Found do
					const First: string = Entry.Segments[1].Text
					const Marker: boolean = string.find(First, "•", 1, true) ~= nil or string.find(First, "◦", 1, true) ~= nil or string.find(First, "1.", 1, true) ~= nil

					if Marker then
						Items += 1
						Anchor = Entry.Segments[2].Position.X.Offset
						Expect(Entry.Segments[1].Position.X.Offset).toBeLessThan(Anchor)

						continue
					end

					Expect(math.abs(Left(Entry) - Anchor)).toBeLessThanOrEqual(0.5)
				end
			end)

			It(`list {Width} item count`, function()
				Expect(Items).toBe(3)
			end)

			It(`list {Width} wrapped`, function()
				Expect(#Found).toBeGreaterThan(3)
			end)
		end)
	end
end)

Describe("markdown quotes", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`<md>> {Filler}\n> > {Filler}</md>`, 260)
		Renderer = Build(Target)
	end)

	for _, Width: number in {260, 200} do
		Describe(`at {Width}`, function()
			local Found: { Row }
			local Outer: number = 0
			local Nested: number = 0

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Found = Rows(Target)
			end)

			It(`quote {Width} bars and nested alignment`, function()
				local ContentX: number = -1

				for _, Entry: Row in Found do
					local Bars: number = 0
					local Content: number = -1

					for _, Segment: TextLabel in Entry.Segments do
						if Segment.Text == "▍" then
							Bars += 1
							Expect(Segment.Position.X.Offset).toBeLessThan(40)

							continue
						end

						if Content < 0 then Content = Segment.Position.X.Offset end
					end

					Expect(Bars).toBeGreaterThanOrEqual(1)
					if Bars == 1 then Outer += 1 elseif Bars == 2 then Nested += 1 end

					if Bars == 2 and ContentX < 0 then ContentX = Content end
					if Bars == 2 and ContentX >= 0 then Expect(math.abs(Content - ContentX)).toBeLessThanOrEqual(0.5) end
				end
			end)

			It(`quote {Width} outer wraps with bars`, function()
				Expect(Outer).toBeGreaterThanOrEqual(2)
			end)

			It(`quote {Width} nested wraps with two bars`, function()
				Expect(Nested).toBeGreaterThanOrEqual(2)
			end)
		end)
	end
end)

Describe("quote bars pooled", function()
	AfterAll(Release)

	It("quote relayout creates no instances", function()
		const Target: TextLabel = Label(`<md>> {Filler}</md>`, 200)
		const Renderer: any = Build(Target)
		const Before: number = #Target:GetChildren()

		for _, Width: number in {300, 200, 160, 200} do Resize(Target, Renderer, Width) end
		Resize(Target, Renderer, 200)

		Expect(#Target:GetChildren()).toBeLessThanOrEqual(Before + 2)
	end)
end)

Describe("code block hanging wrap", function()
	AfterAll(Release)

	const Style = {
		Bold = false, Italic = false, Underline = false, Strike = false, Color = Color3.new(1, 1, 1), Size = 16,
		Family = "rbxasset://fonts/families/BuilderSans.json", Transparency = 0,
	}
	const Source: string = "local function Example(Argument)\n    return Argument .. \" a long string literal that keeps on going\"\nend"
	const function Plain(Text: string): string return Parser.Unescape((string.gsub(Text, "<[^>]*>", ""))) end

	local Built: Frame
	local Body: TextLabel
	local Padding: number

	BeforeAll(function()
		const Node: any = Parser:GenerateTreeFromXML(`<codeblock lang="lua">{Parser.Escape(Source)}</codeblock>`).Children[1]
		Built = CodeBlock.Build(Node, table.clone(Style), 1, nil)

		const Panel: Frame = Built:FindFirstChild("Panel") :: Frame
		Body = Panel:FindFirstChild("Code") :: TextLabel
		Padding = (Panel:FindFirstChildOfClass("UIPadding") :: UIPadding).PaddingLeft.Offset
	end)

	AfterAll(function()
		Built:Destroy()
	end)

	for _, Width: number in {260, 200, 150} do
		Describe(`at {Width}`, function()
			local Height: number
			local Lines: { string }

			BeforeAll(function()
				Height = Reflow.Height(Built, Width)
				Lines = string.split(Plain(Body.Text), "\n")
			end)

			It(`code {Width} wrapped`, function()
				Expect(#Lines).toBeGreaterThan(3)
			end)

			It(`code {Width} height grows`, function()
				Expect(Height).toBeGreaterThan(3 * 16)
			end)

			It(`code {Width} body height`, function()
				Expect(Body.Size.Y.Offset).toBe(math.ceil(#Lines * 16))
			end)

			It(`code {Width} lines fit`, function()
				const Parameters: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
				Parameters.Font = Body.FontFace
				Parameters.Size = Body.TextSize
				Parameters.Width = 100000

				for _, Line: string in Lines do
					Parameters.Text = if Line == "" then " " else Line
					Expect(TextService:GetTextBoundsAsync(Parameters).X).toBeLessThanOrEqual(Width - Padding * 2 + 1)
				end
			end)

			It(`code {Width} continuation under indentation`, function()
				local Hanging: number = 0
				for Index: number, Line: string in Lines do
					if Index > 1 and string.find(Lines[Index - 1], "^    ") and string.find(Line, "^    %S") then Hanging += 1 end
				end

				Expect(Hanging).toBeGreaterThanOrEqual(1)
			end)

			It(`code {Width} highlight kept`, function()
				Expect(Body.RichText and string.find(Body.Text, "<font", 1, true) ~= nil).toBe(true)
			end)

			It(`code {Width} content preserved`, function()
				Expect((string.gsub(Plain(Body.Text), "%s", ""))).toBe((string.gsub(Source, "%s", "")))
			end)
		end)
	end
end)

Describe("joined mark", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Found: { Frame }

	BeforeAll(function()
		Target = Label(`A <mark color="#806000">alpha <b>bold</b> <i>word</i> gamma</mark> B`, 600)
		Renderer = Build(Target)
		Found = Layers(Target)
	end)

	It("mark one piece", function()
		Expect(#Found).toBe(1)
	end)

	It("mark covers and clears segments", function()
		if not Found[1] then return end

		for _, Segment: TextLabel in Covered(Target, "^[%a ]+$") do
			if Segment.Text == "A" or Segment.Text == "B" then continue end
			Expect(Inside(Segment, Found[1])).toBe(true)
			Expect(Segment.BackgroundTransparency).toBe(1)
		end
	end)

	It("mark square", function()
		if not Found[1] then return end
		Expect(Rounding(Found[1])).toBe("none")
	end)

	for _, Width: number in {140, 90, 60} do
		Describe(`at {Width}`, function()
			local Pieces: { Frame }
			local RowCount: number = 0

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Pieces = Layers(Target)
			end)

			It(`mark {Width} covers segments`, function()
				const Marked: { [number]: boolean } = {}

				for _, Segment: TextLabel in Covered(Target, "%a") do
					if Segment.Text == "A" or Segment.Text == "B" then continue end

					const Y: number = Segment.Position.Y.Offset
					if not Marked[Y] then Marked[Y] = true; RowCount += 1 end

					Expect(InsideAny(Segment, Pieces)).toBe(true)
				end
			end)

			It(`mark {Width} one piece per row`, function()
				Expect(#Pieces).toBe(RowCount)
			end)

			It(`mark {Width} piece square`, function()
				for _, Piece: Frame in Pieces do Expect(Rounding(Piece)).toBe("none") end
			end)
		end)
	end

	Describe("separate marks", function()
		local Separate: { Frame }

		BeforeAll(function()
			Target.Text = `<mark color="#306090">one</mark> <mark color="#306090">two</mark>`
			task.wait()
			Resize(Target, Renderer, 600)
			Separate = Layers(Target)
		end)

		It("separate marks separate pieces", function()
			Expect(#Separate).toBe(2)
		end)

		It("separate marks gap", function()
			if #Separate ~= 2 then return end
			Expect(Separate[2].Position.X.Offset).toBeGreaterThan(Separate[1].Position.X.Offset + Separate[1].Size.X.Offset)
		end)
	end)
end)

Describe("joined code", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Single: { Frame }

	BeforeAll(function()
		Target = Label("x <code>alpha beta gamma delta epsilon zeta</code> y", 600)
		Renderer = Build(Target)
		Single = Layers(Target)
	end)

	It("code one piece", function()
		Expect(#Single).toBe(1)
	end)

	It("code single rounded both", function()
		if not Single[1] then return end
		Expect(Rounding(Single[1])).toBe("both")
	end)

	It("code left pad once", function()
		if not Single[1] then return end
		const Pad: number = Covered(Target, "alpha")[1].Position.X.Offset - Single[1].Position.X.Offset
		Expect(Pad >= 3 and Pad <= 6).toBe(true)
	end)

	for _, Width: number in {200, 150, 120} do
		Describe(`at {Width}`, function()
			local Pieces: { Frame }

			BeforeAll(function()
				Resize(Target, Renderer, Width)
				Pieces = Layers(Target)
			end)

			It(`code {Width} wraps into pieces`, function()
				Expect(#Pieces).toBeGreaterThanOrEqual(2)
			end)

			It(`code {Width} piece rounding and rows`, function()
				for Index: number, Piece: Frame in Pieces do
					const Expected: string = if Index == 1 then "left" elseif Index == #Pieces then "right" else "none"
					Expect(Rounding(Piece)).toBe(Expected)
					if Index > 1 then Expect(Piece.Position.Y.Offset).toBeGreaterThan(Pieces[Index - 1].Position.Y.Offset) end
				end
			end)

			It(`code {Width} covers segments`, function()
				for _, Segment: TextLabel in Covered(Target, "^%l[%l ]*$") do
					if Segment.Text == "x" or Segment.Text == "y" then continue end
					Expect(InsideAny(Segment, Pieces)).toBe(true)
				end
			end)
		end)
	end

	Describe("nested style", function()
		local Nested: { Frame }
		local Parts: { TextLabel }

		BeforeAll(function()
			Target.Text = "<code>a <b>b</b> c</code>"
			task.wait()
			Resize(Target, Renderer, 600)
			Nested = Layers(Target)
			Parts = Covered(Target, "%a")
		end)

		It("code with nested style one piece", function()
			Expect(#Nested).toBe(1)
		end)

		It("code nested pad right equals left", function()
			if not (Nested[1] and #Parts >= 2) then return end
			const Pad: number = Parts[1].Position.X.Offset - Nested[1].Position.X.Offset
			const Right: number = Nested[1].Position.X.Offset + Nested[1].Size.X.Offset
			const Last: TextLabel = Parts[#Parts]

			Expect(math.abs(Right - (Last.Position.X.Offset + Last.Size.X.Offset) - Pad)).toBeLessThanOrEqual(1.5)
		end)

		It("code nested no inner pad", function()
			if not (Nested[1] and #Parts >= 2) then return end
			const Pad: number = Parts[1].Position.X.Offset - Nested[1].Position.X.Offset
			const Gap: number = Parts[2].Position.X.Offset - (Parts[1].Position.X.Offset + Parts[1].TextBounds.X)

			Expect(Gap).toBeLessThan(Pad + 11)
		end)
	end)

	It("adjacent code spans separate", function()
		Target.Text = "<code>a</code> <code>b</code>"
		task.wait()

		Expect(#Layers(Target)).toBe(2)
	end)

	Describe("mark around code", function()
		local Stacked: { Frame }

		BeforeAll(function()
			Target.Text = `<mark color="#604000">m <code>c</code> n</mark>`
			task.wait()
			Stacked = Layers(Target)
		end)

		It("mark around code two pieces", function()
			Expect(#Stacked).toBe(2)
		end)

		It("code drawn above mark", function()
			const Holder: Instance? = Target:FindFirstChild("Backdrops")
			if not (Holder and #Stacked == 2) then return end

			local MarkIndex: number, CodeIndex: number = 0, 0
			for Index: number, Child: Instance in (Holder :: Instance):GetChildren() do
				if Child == Stacked[1] or Child == Stacked[2] then
					if (Child :: Frame):FindFirstChildOfClass("UICorner") then CodeIndex = Index else MarkIndex = Index end
				end
			end

			Expect(CodeIndex).toBeGreaterThan(MarkIndex)
		end)
	end)
end)

Describe("backdrop order", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label("plain words first", 400)
		Renderer = Build(Target)

		Renderer.Label.Text = `now <mark color="#806000">marked text</mark>`
		Renderer:Flush()
	end)

	It("backdrops behind every segment", function()
		local HolderIndex: number = 0
		local FirstSegment: number = math.huge
		for Index: number, Child: Instance in Target:GetChildren() do
			if Child.Name == "Backdrops" then HolderIndex = Index end
			if Child.Name == "Segment" and Index < FirstSegment then FirstSegment = Index end
		end

		Expect(HolderIndex > 0 and HolderIndex < FirstSegment).toBe(true)
	end)

	It("destroy removes backdrops", function()
		Renderer:Destroy()

		Expect(Target:FindFirstChild("Backdrops")).toBeNil()
	end)
end)

Describe("backdrop pooling", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any
	local Holder: Instance

	BeforeAll(function()
		Target = Label(`<mark color="#806000">{Filler}</mark> and <code>{Filler}</code>`, 300)
		Renderer = Build(Target)
		Holder = Target:FindFirstChild("Backdrops") :: Instance
	end)

	It("relayout reuses backdrop instances", function()
		const Widths: { number } = {260, 300, 240, 300}
		const Known: { [Instance]: boolean } = {}

		for _, Width: number in Widths do Resize(Target, Renderer, Width) end
		for _, Child: Instance in Holder:GetDescendants() do Known[Child] = true end
		for _, Width: number in Widths do Resize(Target, Renderer, Width) end

		local Fresh: number = 0
		for _, Child: Instance in Holder:GetDescendants() do if not Known[Child] then Fresh += 1 end end

		Expect(Fresh).toBe(0)
	end)

	It("backdrop follows developer transparency", function()
		Target.TextTransparency = 0.5
		task.wait()

		for _, Layer: Frame in Layers(Target) do
			if Layer.BackgroundTransparency < 1 then Expect(Layer.BackgroundTransparency).toBeCloseTo(0.5, 3) end
		end
	end)

	Describe("no marks", function()
		BeforeAll(function()
			Renderer.Label.Text = "no marks"
			Renderer:Flush()
		end)

		It("backdrops hidden without marks", function()
			Expect(#Layers(Target)).toBe(0)
		end)

		It("backdrops kept for reuse", function()
			Expect(#Holder:GetChildren()).toBeGreaterThan(0)
		end)
	end)
end)

Describe("indent scaling", function()
	AfterAll(Release)

	Describe("scale option", function()
		local Found: { Row }

		BeforeAll(function()
			const Scaled: TextLabel = Label(`<indent by="20">{Filler}</indent>`, 240)
			Build(Scaled):SetScale(2):Flush()
			Found = Rows(Scaled)
		end)

		It("scaled option wraps", function()
			Expect(#Found).toBeGreaterThanOrEqual(3)
		end)

		It("scale option continuation", function()
			Continuations(Found, 40, 0.5)
		end)
	end)

	Describe("text scaled", function()
		local Factor: number
		local Rescaled: { Row }

		BeforeAll(function()
			const Fitted: TextLabel = Label(`<indent by="40">{Filler} {Filler}</indent>`, 240)
			Fitted.Size = UDim2.fromOffset(240, 120)
			Fitted.TextScaled = true

			Factor = Build(Fitted).Scale.Factor
			Rescaled = Rows(Fitted)
		end)

		It("text scaled factor below one", function()
			Expect(Factor).toBeLessThan(1)
		end)

		It("text scaled continuation", function()
			Continuations(Rescaled, 40 * Factor, 1)
		end)
	end)
end)

Describe("indent policy and alignment", function()
	AfterAll(Release)

	It("chat policy escapes indent", function()
		const Chat: TextLabel = Label(`<indent by="40">text</indent>`, 300)
		Build(Chat):SetPreset("Chat"):Flush()

		local Literal: boolean = false
		for _, Entry: Row in Rows(Chat) do
			for _, Segment: TextLabel in Entry.Segments do
				if string.find(Segment.Text, "indent", 1, true) then Literal = true end
			end
		end

		Expect(Literal).toBe(true)
	end)

	Describe("centered", function()
		local Found: { Row }

		BeforeAll(function()
			const Centered: TextLabel = Label(`<md>> {Filler}</md>`, 220)
			Centered.TextXAlignment = Enum.TextXAlignment.Center
			Build(Centered)
			Found = Rows(Centered)
		end)

		It("centered quote renders every row", function()
			Expect(#Found).toBeGreaterThanOrEqual(3)
		end)

		It("centered rows inside box", function()
			for _, Entry: Row in Found do
				const Last: TextLabel = Entry.Segments[#Entry.Segments]
				Expect(Entry.Segments[1].Position.X.Offset >= 0 and Last.Position.X.Offset + Last.TextBounds.X <= 221).toBe(true)
			end
		end)
	end)
end)

Describe("reveal with repeated bars", function()
	AfterAll(Release)

	local Target: TextLabel
	local Renderer: any

	BeforeAll(function()
		Target = Label(`<md>> {Filler}</md>`, 200)
		Renderer = Build(Target)
	end)

	It("every bar joins reveal order", function()
		local Bars: number = 0
		for _, Entry: Row in Rows(Target) do
			for _, Segment: TextLabel in Entry.Segments do if Segment.Text == "▍" then Bars += 1 end end
		end

		local Ordered: number = 0
		for _, Record: any in Renderer.Instances.Order do if Record.Content.Text == "▍" then Ordered += 1 end end

		Expect(Ordered).toBe(Bars)
	end)

	It("count reveals across bars", function()
		Target.MaxVisibleGraphemes = Renderer:GetGraphemeCount()
		task.wait()

		local Hidden: number = 0
		for _, Record: any in Renderer.Instances.Order do if Record.Content.Revealed ~= -1 then Hidden += 1 end end

		Expect(Hidden).toBe(0)
	end)
end)

Describe("mark across break", function()
	AfterAll(Release)

	local Found: { Frame }

	BeforeAll(function()
		const Target: TextLabel = Label(`<mark color="#806000">first<br/>second</mark>`, 400)
		Build(Target)
		Found = Layers(Target)
	end)

	It("mark across break pieces", function()
		Expect(#Found).toBe(2)
	end)

	It("mark across break rows", function()
		if #Found ~= 2 then return end
		Expect(Found[2].Position.Y.Offset).toBeGreaterThan(Found[1].Position.Y.Offset)
	end)
end)

Describe("trusted markdown indent", function()
	AfterAll(Release)

	local Found: { Row }
	local Anchor: number

	BeforeAll(function()
		const Target: TextLabel = Label(`<md>- {Filler}</md>`, 220)
		Build(Target):SetPreset("Trusted"):Flush()
		Found = Rows(Target)
		Anchor = Found[1].Segments[2].Position.X.Offset
	end)

	It("trusted wraps", function()
		Expect(#Found).toBeGreaterThanOrEqual(2)
	end)

	It("trusted continuation", function()
		Continuations(Found, Anchor, 0.5)
	end)
end)
