--!strict
--!native
--!optimize 2

const TextService = game:GetService("TextService")

const Config = require("../../Config")
const XML = require("../../../XML")
const Types = require("../../Types")
const Styles = require("../../Utility/Styles")
const Glyphs = require("../Glyphs")
const Profiler = require("../../Utility/Profiler")
const Characters = require("../../Utility/Characters")

type Sized = { [string]: Vector2 }
type Bucket = { [number]: Sized }

type Face = {
	Font: Font;
	Bucket: Bucket;
	Older: Bucket;
	Tables: { [number]: Types.GlyphTable };
	Blocks: { [number]: boolean };
	Ready: boolean;
	Trusted: boolean;
	Broken: boolean;
	Checks: number;
}

type Lesson = {
	Face: Face;
	Size: number;
	Text: string;
}

const CacheLimit: number = Config.Measure.CACHE_LIMIT
const CasedLimit: number = Config.Measure.CASED_LIMIT
const FamilyLimit: number = Config.Measure.FAMILY_LIMIT
const TableLimit: number = Config.Measure.TABLE_LIMIT
const LessonLimit: number = Config.Measure.LESSON_LIMIT
const CheckLimit: number = Config.Measure.CHECK_LIMIT
const Tolerance: number = Config.Measure.TOLERANCE
const TeachBudget: number = Config.Measure.TEACH_BUDGET
const BlockSize: number = Config.Measure.BLOCK_SIZE
const BoldWeight: number = Enum.FontWeight.Bold.Value
const CodePadRatio: number = Config.Measure.CODE_PAD_RATIO
const MeasureWidth: number = Config.Measure.MEASURE_WIDTH
const UpperKey: string = "^"
const WidePattern: string = Characters.WIDE_PATTERN
const FallbackFont: Font = Font.fromEnum(Enum.Font.SourceSans)
const GuessRatio: number = Config.Measure.GUESS_RATIO
const TagPattern: string = "<[^>]*>"

const Find = string.find

const CaseTags: { [string]: string } = {
	["Upper"] = "uc";
	["SmallCaps"] = "sc";
}

const Faces: { [string]: { [number]: Face } } = {}
const Retired: { [string]: { [number]: Face } } = {}
const Generations: { { [string]: { [number]: Face } } } = {Faces, Retired}
const StyleFaces: { [Types.Style]: Face } = setmetatable({}, {__mode = "k"}) :: any
const Lessons: { Lesson } = {}
const CasedTexts: { [string]: { [string]: string } } = {}

local Entries: number = 0
local CasedCount: number = 0
local Tables: number = 0
local Families: number = 0
local Teaching: boolean = false
local Idle: GetTextBoundsParams? = nil

const function Retire(): ()
	table.clear(Retired)

	for Name: string, Family: { [number]: Face } in (Faces) do Retired[Name] = Family end

	table.clear(Faces)
	table.clear(StyleFaces)
	Families = 0
end

const function Admit(Family: string): { [number]: Face }
	const Kept: { [number]: Face }? = Retired[Family]

	if Families >= FamilyLimit then Retire() else Retired[Family] = nil end

	const Admitted: { [number]: Face } = Kept or {}
	Faces[Family] = Admitted
	Families += 1

	return Admitted
end

const function FaceOf(Style: Types.Style): Face
	const Cached: Face? = StyleFaces[Style]; if Cached then return Cached end

	const Weight: number = (Style.Weight or Enum.FontWeight.Regular).Value
	const Resolved: number = if Style.Bold and Weight < BoldWeight then BoldWeight else Weight
	const Code: number = Resolved * 2 + (if Style.Italic then 1 else 0)

	const Family: { [number]: Face } = Faces[Style.Family] or Admit(Style.Family)

	const Found: Face = Family[Code] or {
		Font = Styles.FontFor(Style);
		Bucket = {};
		Older = {};
		Tables = {};
		Blocks = {};
		Ready = false;
		Trusted = Glyphs.Trusted(Style.Family);
		Broken = false;
		Checks = 0;
	}

	Family[Code] = Found
	StyleFaces[Style] = Found

	return Found
end

const function FontOf(Style: Types.Style): Font
	return FaceOf(Style).Font
end

const function Evict(): ()
	for _, Generation: { [string]: { [number]: Face } } in (Generations) do
		for _, Family: { [number]: Face } in (Generation) do
			for _, Found: Face in (Family) do
				Found.Older = Found.Bucket
				Found.Bucket = {}
			end
		end
	end

	Entries = 0
end

const function Store(Found: Face, Key: number, Text: string, Result: Vector2): ()
	if Entries >= CacheLimit then Evict() end

	const Bucket: Bucket = Found.Bucket
	const Target: Sized = Bucket[Key] or {}
	Bucket[Key] = Target
	Target[Text] = Result
	Entries += 1
end

const function Lookup(Found: Face, Key: number, Text: string): Vector2?
	const Current: Sized? = Found.Bucket[Key]
	const Hit: Vector2? = if Current then (Current :: Sized)[Text] else nil
	if Hit then return Hit end

	const Previous: Sized? = Found.Older[Key]
	const Kept: Vector2? = if Previous then (Previous :: Sized)[Text] else nil
	if not Kept then return nil end

	(Previous :: Sized)[Text] = nil
	Store(Found, Key, Text, Kept :: Vector2)

	return Kept
end

const function Forget(): ()
	for _, Generation: { [string]: { [number]: Face } } in (Generations) do
		for _, Family: { [number]: Face } in (Generation) do
			for _, Found: Face in (Family) do table.clear(Found.Tables) end
		end
	end

	Tables = 0
end

const function TableFor(Found: Face, Size: number): Types.GlyphTable
	const Existing: Types.GlyphTable? = Found.Tables[Size]; if Existing then return Existing end

	if Tables >= TableLimit then Forget() end

	const Created: Types.GlyphTable = Glyphs.New()
	Found.Tables[Size] = Created
	Tables += 1

	return Created
end

const function Settle(Found: Face, Text: string): ()
	Found.Ready = true

	if not Find(Text, WidePattern) or not utf8.len(Text) then return end

	for _, Code: number in utf8.codes(Text) do
		if Code >= 0x80 then Found.Blocks[Code // BlockSize] = true end
	end
end

const function Guess(Size: number, Text: string, Rich: boolean): Vector2
	const Plain: string = if Rich then (string.gsub(Text, TagPattern, "")) else Text

	return Vector2.new((utf8.len(Plain) or #Plain) * Size * GuessRatio, Size)
end

const function Fetch(Parameters: GetTextBoundsParams): (boolean, any)
	if Profiler.Depth() == 0 then return pcall(TextService.GetTextBoundsAsync, TextService, Parameters) end

	return pcall(Profiler.Await, TextService.GetTextBoundsAsync, TextService, Parameters)
end

const function Query(Found: Face, Size: number, Text: string, Rich: boolean): (Vector2, boolean)
	local Parameters: GetTextBoundsParams? = Idle
	Idle = nil

	if not Parameters then
		const Created: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
		Created.Width = MeasureWidth
		Parameters = Created
	end

	const Active: GetTextBoundsParams = Parameters :: GetTextBoundsParams
	Active.Text = Text
	Active.Size = Size
	Active.RichText = Rich

	if not Found.Broken then
		Active.Font = Found.Font

		const Ok: boolean, Result: any = Fetch(Active)

		if Ok then
			Idle = Active
			if (Result :: Vector2).X > 0 then Settle(Found, Text) end

			return Result :: Vector2, true
		end

		Found.Broken = true
		Found.Trusted = false
	end

	Active.Font = FallbackFont

	const Retried: boolean, Fallback: any = Fetch(Active)
	Idle = Active

	return if Retried then Fallback :: Vector2 else Guess(Size, Text, Rich), false
end

const function Study(Item: Lesson): ()
	const Found: Face = Item.Face
	const Target: Types.GlyphTable? = Found.Tables[Item.Size]
	if not (Target and Found.Trusted) then return end

	const Plan: { string }? = Glyphs.Lesson(Target :: Types.GlyphTable, Item.Text); if not Plan then return end

	for _, Piece: string in (Plan :: { string }) do
		if not Glyphs.Needs(Target :: Types.GlyphTable, Piece) then continue end

		const Result: Vector2, Exact: boolean = Query(Found, Item.Size, Piece, false)
		if not Exact then return end

		Glyphs.Record(Target :: Types.GlyphTable, Piece, Result.X, Result.Y)
	end
end

const function Teach(): ()
	while #Lessons > 0 do
		const Started: number = os.clock()
		const Profiling: boolean = Profiler.Enabled
		const Depth: number = if Profiling then Profiler.Depth() else 0

		if Profiling then Profiler.Begin("RTP:Glyphs") end

		repeat
			pcall(Study, table.remove(Lessons) :: Lesson)
		until #Lessons == 0 or os.clock() - Started >= TeachBudget

		if Profiling then Profiler.Unwind(Depth) end
		if #Lessons > 0 then task.wait() end
	end

	Teaching = false
end

const function Learn(Found: Face, Size: number, Text: string, Result: Vector2): ()
	Glyphs.Record(TableFor(Found, Size), Text, Result.X, Result.Y)

	if #Lessons >= LessonLimit then table.clear(Lessons) end

	table.insert(Lessons, {Face = Found, Size = Size, Text = Text})

	if Teaching then return end

	Teaching = true
	task.defer(Teach)
end

const function Resolve(Found: Face, Size: number, Text: string, Rich: boolean): (Vector2, boolean)
	const Target: Types.GlyphTable? = if Found.Trusted and not Rich then Found.Tables[Size] else nil

	if Target then
		const Width: number?, Height: number = Glyphs.Estimate(Target :: Types.GlyphTable, Text)

		if Width then
			if Found.Checks >= CheckLimit then return Vector2.new(Width :: number, Height), true end

			Found.Checks += 1

			const Checked: Vector2, Exact: boolean = Query(Found, Size, Text, false)
			if Exact and math.abs(Checked.X - (Width :: number)) > Tolerance then Found.Trusted = false end

			return Checked, Exact
		end
	end

	const Result: Vector2, Exact: boolean = Query(Found, Size, Text, Rich)
	if Exact and not Rich and Found.Trusted and Result.X > 0 then Learn(Found, Size, Text, Result) end

	return Result, Exact
end

const function Holds(Bucket: Bucket, Key: number, Text: string): boolean
	const Stored: Sized? = Bucket[Key]

	return Stored ~= nil and (Stored :: Sized)[Text] ~= nil
end

const function Cached(Style: Types.Style, Size: number, Text: string, Rich: boolean?): boolean
	const Found: Face = FaceOf(Style)
	const Key: number = if Rich then -Size else Size

	return Holds(Found.Bucket, Key, Text) or Holds(Found.Older, Key, Text)
end

const function Bounds(Style: Types.Style, Size: number, Text: string, Rich: boolean): Vector2
	const Found: Face = FaceOf(Style)
	const Key: number = if Rich then -Size else Size

	const Known: Vector2? = Lookup(Found, Key, Text)
	if Known then return Known :: Vector2 end

	const Result: Vector2, Exact: boolean = Resolve(Found, Size, Text, Rich)
	if not Exact or (Result.X <= 0 and Text ~= "") then return Result end

	Store(Found, Key, Text, Result)

	return Result
end

const function Wrap(Text: string, Tag: string?): string
	if not Tag then return XML.Escape(Text) end

	return `<{Tag}>{XML.Escape(Text)}</{Tag}>`
end

const function Remember(Key: string, Text: string, Created: string): string
	if CasedCount >= CasedLimit then
		table.clear(CasedTexts)
		CasedCount = 0
	end

	const Target: { [string]: string } = CasedTexts[Key] or {}

	CasedTexts[Key] = Target
	Target[Text] = Created
	CasedCount += 1

	return Created
end

const function Recall(Key: string, Text: string): string?
	const Known: { [string]: string }? = CasedTexts[Key]

	return if Known then (Known :: { [string]: string })[Text] else nil
end

const function Cased(Text: string, Case: string?): string
	const Tag: string? = if Case then CaseTags[Case :: string] else nil
	const Key: string = Tag or ""

	return Recall(Key, Text) or Remember(Key, Text, Wrap(Text, Tag))
end

const function Uppercased(Text: string, Case: string?): string?
	if Case ~= "Upper" or Find(Text, WidePattern) then return nil end

	return Recall(UpperKey, Text) or Remember(UpperKey, Text, string.upper(Text))
end

const function Scaled(Size: number, Factor: number): number
	if Factor == 1 then return Size end

	return math.clamp(math.floor(Size * Factor + 0.5), 1, Styles.MaximumTextSize)
end

const function Pad(Style: Types.Style, Factor: number): number
	if not Style.Code then return 0 end

	return math.floor(Scaled(Style.Size, Factor) * CodePadRatio + 0.5)
end

const function WidthOf(Style: Types.Style, Size: number, Text: string): Vector2
	const Case: string? = Style.Case
	if not Case then return Bounds(Style, Size, Text, false) end

	const Upper: string? = Uppercased(Text, Case)
	if Upper then return Bounds(Style, Size, Upper :: string, false) end

	return Bounds(Style, Size, Cased(Text, Case), true)
end

return {
	CaseTags = CaseTags;
	CacheLimit = CacheLimit;
	FontOf = FontOf;
	FaceOf = FaceOf;
	Lookup = Lookup;
	TableFor = TableFor;
	Query = Query;
	Guess = Guess;
	Cached = Cached;
	Bounds = Bounds;
	Cased = Cased;
	Uppercased = Uppercased;
	WidthOf = WidthOf;
	Scaled = Scaled;
	Pad = Pad;
}
