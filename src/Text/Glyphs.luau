--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Characters = require("../Utility/Characters")
const Unicode = require("./Unicode")

type Table = Types.GlyphTable

type Ranges = { { number } }

const Core: number = 1
const Edge: number = 2
const AsciiLimit: number = Characters.ASCII_LIMIT
const IdLimit: number = Config.Glyphs.ID_LIMIT
const PairBase: number = IdLimit
const PairLimit: number = Config.Glyphs.PAIR_LIMIT

const LigaturePattern: string = "f[fijlt]"
const WidePattern: string = Characters.WIDE_PATTERN
const Digits: string = "0123456789"
const EndMarks: string = ".,!?"
const LeadMarks: string = "$#"

const Corpus: string = "the of and to in is you that it he was for on are as with his they at be this have from or one had by word but not what all were we when your can said there use an each which she do how their if will up other about out many then them these so some her would make like him into time has look two more write go see number no way could people my than first water been call who its now find long down day did get come made may part over new sound take only little work know place year live me back give most very after thing our just name good man think say great where help through much before line right too mean old any same tell boy follow came want show also around form three small set put end does another well large must big even such because turn here why ask went men read need land different home us move try kind hand picture again change off play spell air away animal house point page letter mother answer found study still learn should world level coins player round win lose team quest gold health"

const Byte = string.byte
const Sub = string.sub
const Find = string.find
const Char = string.char
const Upper = string.upper
const Codepoint = utf8.codepoint
const Graphemes = utf8.graphemes

const Contextual: { string } = {"Creepster", "FredokaOne", "PermanentMarker"}

const CoreRanges: Ranges = {
	{0x00C0, 0x00D6};
	{0x00D8, 0x00F6};
	{0x00F8, 0x024F};
	{0x0370, 0x03FF};
	{0x0400, 0x04FF};
	{0x1E00, 0x1EFF};
	{0x3040, 0x30FF};
	{0x3400, 0x4DBF};
	{0x4E00, 0x9FFF};
	{0xAC00, 0xD7AF};
	{0xFF10, 0xFF19};
	{0xFF21, 0xFF3A};
	{0xFF41, 0xFF5A};
}

const EdgeRanges: Ranges = {
	{0x00A0, 0x00BF};
	{0x00D7, 0x00D7};
	{0x00F7, 0x00F7};
	{0x3000, 0x303F};
	{0xFF01, 0xFF0F};
	{0xFF1A, 0xFF20};
	{0xFF3B, 0xFF40};
	{0xFF5B, 0xFF65};
}

const EmojiRanges: Ranges = {
	{0x2600, 0x27BF};
	{0x1F1E6, 0x1F1FF};
	{0x1F300, 0x1FAFF};
}

const Kinds: { [number]: number } = {}
const Names: { [number]: string } = {}
const Ids: { [string]: number } = {}
const Buffer: { number } = {}

local NextId: number = AsciiLimit

for Code = 0x20, 0x7E do
	Kinds[Code] = if Find(Char(Code), "%w") then Core else Edge
	Names[Code] = Char(Code)
end

const Inside = Unicode.Within

const function Span(Code: number): number
	if Code < 0x80 then return 1 end
	if Code < 0x800 then return 2 end

	return if Code < 0x10000 then 3 else 4
end

const function Classify(Code: number, Single: boolean): number?
	if Inside(Code, EmojiRanges) then return Core end
	if not Single then return nil end
	if Inside(Code, CoreRanges) then return Core end

	return if Inside(Code, EdgeRanges) then Edge else nil
end

const function Intern(Grapheme: string): number?
	const Known: number? = Ids[Grapheme]; if Known then return Known end
	if NextId >= IdLimit then return nil end

	const Id: number = NextId
	NextId += 1
	Ids[Grapheme] = Id
	Names[Id] = Grapheme

	return Id
end

const function Parse(Text: string, Into: { number }): (number, boolean)
	local Count: number = 0
	local Seen: boolean = false
	local Trailing: boolean = false
	local Valid: boolean = Find(Text, LigaturePattern) == nil

	if not Find(Text, WidePattern) then
		for Index = 1, #Text do
			const Code: number = Byte(Text, Index)
			const Kind: number? = Kinds[Code]; if not Kind then return 0, false end

			if Kind == Core then
				if Trailing then Valid = false end
				Seen = true
			elseif Seen then
				Trailing = true
			end

			Into[Index] = Code
		end

		Count = #Text
	else
		if not utf8.len(Text) then return 0, false end

		for Start: number, Stop: number in Graphemes(Text) do
			const Code: number = Codepoint(Text, Start)
			const Kind: number? = if Code < AsciiLimit then Kinds[Code] else Classify(Code, Stop - Start + 1 == Span(Code))
			if not Kind then return 0, false end

			const Id: number? = if Code < AsciiLimit and Start == Stop then Code else Intern(Sub(Text, Start, Stop))
			if not Id then return 0, false end

			if Kind == Core then
				if Trailing then Valid = false end
				Seen = true
			elseif Seen then
				Trailing = true
			end

			Count += 1
			Into[Count] = Id :: number
		end
	end

	return Count, Valid and (Seen or Count == 1)
end

const function New(): Table
	return {Advances = {}, Heights = {}, Kerns = {}, Pairs = 0}
end

const function Estimate(Target: Table, Text: string): (number?, number)
	const Count: number, Valid: boolean = Parse(Text, Buffer)
	if not Valid then return nil, 0 end

	const Advances: { [number]: number } = Target.Advances
	const Heights: { [number]: number } = Target.Heights
	const Kerns: { [number]: number } = Target.Kerns

	local Total: number = 0
	local Height: number = 0
	local Previous: number = 0

	for Index = 1, Count do
		const Id: number = Buffer[Index]
		const Advance: number? = Advances[Id]; if not Advance then return nil, 0 end

		Total += Advance :: number

		const Tall: number = Heights[Id]
		if Tall > Height then Height = Tall end

		if Index > 1 then
			const Kern: number? = Kerns[Previous * PairBase + Id]; if not Kern then return nil, 0 end

			Total += Kern :: number
		end

		Previous = Id
	end

	return Total, Height
end

const function Record(Target: Table, Text: string, Measured: number, Height: number): ()
	if Measured <= 0 then return end

	const Count: number, Valid: boolean = Parse(Text, Buffer)
	if Count == 0 or (Count > 2 and not Valid) then return end

	const Advances: { [number]: number } = Target.Advances
	const Kerns: { [number]: number } = Target.Kerns

	if Count == 1 then
		Advances[Buffer[1]] = Measured
		Target.Heights[Buffer[1]] = Height

		return
	end

	local Known: number = 0
	local Missing: number? = nil
	local Times: number = 0
	local Previous: number = 0

	for Index = 1, Count do
		const Id: number = Buffer[Index]
		const Advance: number? = Advances[Id]; if not Advance then return end

		Known += Advance :: number

		if Index > 1 then
			const Key: number = Previous * PairBase + Id
			const Kern: number? = Kerns[Key]

			if Kern then
				Known += Kern :: number
			elseif Missing == nil or Missing == Key then
				Missing = Key
				Times += 1
			else
				return
			end
		end

		Previous = Id
	end

	if not Missing or Target.Pairs >= PairLimit then return end

	Kerns[Missing :: number] = (Measured - Known) / Times
	Target.Pairs += 1
end

const function Lesson(Target: Table, Text: string): { string }?
	const Count: number, Valid: boolean = Parse(Text, Buffer)
	if not Valid or Count < 2 then return nil end

	const Advances: { [number]: number } = Target.Advances
	const Kerns: { [number]: number } = Target.Kerns
	const Wanted: { [string]: boolean } = {}
	const Plan: { string } = {}

	for Index = 1, Count do
		const Id: number = Buffer[Index]
		const Name: string = Names[Id]

		if not Advances[Id] and not Wanted[Name] then
			Wanted[Name] = true
			table.insert(Plan, Name)
		end
	end

	for Index = 2, Count do
		const Previous: number = Buffer[Index - 1]
		const Id: number = Buffer[Index]
		if Kerns[Previous * PairBase + Id] then continue end

		const Name: string = Names[Previous] .. Names[Id]

		if not Wanted[Name] then
			Wanted[Name] = true
			table.insert(Plan, Name)
		end
	end

	return if #Plan > 0 then Plan else nil
end

const function Needs(Target: Table, Text: string): boolean
	const Count: number = Parse(Text, Buffer)
	if Count == 1 then return Target.Advances[Buffer[1]] == nil end
	if Count ~= 2 then return false end

	return Target.Kerns[Buffer[1] * PairBase + Buffer[2]] == nil
end

const function Trusted(Family: string): boolean
	for _, Name: string in (Contextual) do
		if Find(Family, Name, 1, true) then return false end
	end

	return true
end

const function Collect(): { string }
	const Seen: { [string]: boolean } = {}
	const List: { string } = {}

	const function Add(Text: string): ()
		if Seen[Text] then return end

		Seen[Text] = true
		table.insert(List, Text)
	end

	const function Pairs(Word: string): ()
		for Index = 2, #Word do Add(Sub(Word, Index - 1, Index)) end
	end

	for Code = 0x20, 0x7E do Add(Char(Code)) end

	for Word: string in string.gmatch(Corpus, "%a+") do
		Pairs(Word)
		Pairs(Upper(Sub(Word, 1, 1)) .. Sub(Word, 2, 2))
	end

	for First = 1, #Digits do
		for Second = 1, #Digits do Add(Sub(Digits, First, First) .. Sub(Digits, Second, Second)) end
		for Mark = 1, #LeadMarks do Add(Sub(LeadMarks, Mark, Mark) .. Sub(Digits, First, First)) end
	end

	for Code = Byte("a"), Byte("z") do
		for Mark = 1, #EndMarks do Add(Char(Code) .. Sub(EndMarks, Mark, Mark)) end
	end

	return List
end

return {
	Warm = table.freeze(Collect());
	New = New;
	Parse = Parse;
	Estimate = Estimate;
	Record = Record;
	Lesson = Lesson;
	Needs = Needs;
	Trusted = Trusted;
}
