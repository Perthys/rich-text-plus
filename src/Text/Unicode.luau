--!strict
--!native
--!optimize 2

const Types = require("../Types")

type Joint = Types.Joint

type Ranges = { { number } }

const Neutral: number = 0
const Left: number = 1
const Right: number = 2
const Digit: number = 3

const Closed: number = 0
const Sticky: number = 1
const Open: number = 2

const ComplexPattern: string = "[\r\128-\255]"

const Find = string.find
const Byte = string.byte
const Length = utf8.len
const Codepoint = utf8.codepoint
const Graphemes = utf8.graphemes

const Controls: { [number]: Joint } = {
	[0x200B] = "Break";
	[0x2060] = "Glue";
	[0xFEFF] = "Glue";
	[0xAD] = "Hyphen";
}

const WideRanges: Ranges = {
	{0x1100, 0x115F};
	{0x2E80, 0x2FFF};
	{0x3000, 0x33FF};
	{0x3400, 0x4DBF};
	{0x4E00, 0x9FFF};
	{0xA000, 0xA4CF};
	{0xA960, 0xA97F};
	{0xAC00, 0xD7AF};
	{0xF900, 0xFAFF};
	{0xFE10, 0xFE1F};
	{0xFE30, 0xFE4F};
	{0xFF00, 0xFFEF};
	{0x1B000, 0x1B2FF};
	{0x20000, 0x3FFFD};
}

const RightRanges: Ranges = {
	{0x0590, 0x08FF};
	{0x200F, 0x200F};
	{0xFB1D, 0xFDFF};
	{0xFE70, 0xFEFE};
	{0x10800, 0x10FFF};
	{0x1E800, 0x1EFFF};
}

const DigitRanges: Ranges = {
	{0x0030, 0x0039};
	{0x0660, 0x0669};
	{0x06F0, 0x06F9};
	{0xFF10, 0xFF19};
}

const NeutralRanges: Ranges = {
	{0x0080, 0x00A9};
	{0x00AB, 0x00B4};
	{0x00B6, 0x00B9};
	{0x00BB, 0x00BF};
	{0x00D7, 0x00D7};
	{0x00F7, 0x00F7};
	{0x0300, 0x036F};
	{0x2000, 0x200D};
	{0x2010, 0x2BFF};
	{0x2E00, 0x2E7F};
	{0x3000, 0x3004};
	{0x3008, 0x3020};
	{0x3030, 0x3030};
	{0xFE00, 0xFE6F};
	{0xFF00, 0xFF20};
	{0xFF3B, 0xFF40};
	{0xFF5B, 0xFF65};
	{0xFFF0, 0xFFFF};
	{0x1F000, 0x1FAFF};
	{0xE0000, 0xE007F};
}

const NoStart: { [number]: boolean } = {}
const NoEnd: { [number]: boolean } = {}

for _, Code: number in ({
	0x21, 0x29, 0x2C, 0x2E, 0x3A, 0x3B, 0x3F, 0x5D, 0x7D, 0x2019, 0x201D, 0x2025, 0x2026, 0x203C, 0x2047, 0x2048, 0x2049,
	0x3001, 0x3002, 0x3003, 0x3005, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 0x3017, 0x3019, 0x301B, 0x301C, 0x301E,
	0x301F, 0x303B, 0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087, 0x308E, 0x3095, 0x3096, 0x309B,
	0x309C, 0x309D, 0x309E, 0x30A0, 0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x30F5,
	0x30F6, 0x30FB, 0x30FC, 0x30FD, 0x30FE, 0xFF01, 0xFF09, 0xFF0C, 0xFF0E, 0xFF1A, 0xFF1B, 0xFF1F, 0xFF3D, 0xFF5D, 0xFF60,
	0xFF61, 0xFF63, 0xFF64, 0xFF65, 0xFF9E, 0xFF9F,
}) do NoStart[Code] = true end

for Code = 0x31F0, 0x31FF do NoStart[Code] = true end
for Code = 0xFF67, 0xFF70 do NoStart[Code] = true end

for _, Code: number in ({
	0x28, 0x5B, 0x7B, 0x2018, 0x201C, 0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 0x3018, 0x301A, 0x301D,
	0xFF08, 0xFF3B, 0xFF5B, 0xFF5F, 0xFF62,
}) do NoEnd[Code] = true end

const function Locate(Code: number, List: Ranges): number?
	local Low: number = 1
	local High: number = #List

	while Low <= High do
		const Middle: number = (Low + High) // 2
		const Range: { number } = List[Middle]

		if Code < Range[1] then High = Middle - 1 elseif Code > Range[2] then Low = Middle + 1 else return Middle end
	end

	return nil
end

const function Within(Code: number, List: Ranges): boolean
	return Locate(Code, List) ~= nil
end

const function Plain(Text: string): boolean
	return Find(Text, ComplexPattern) == nil
end

const function Wide(Code: number): boolean
	return Code >= 0x1100 and Within(Code, WideRanges)
end

const function Trailing(Before: number?): number
	if not Before then return Closed end
	if NoEnd[Before :: number] then return Sticky end

	return if Wide(Before :: number) then Closed else Open
end

const function Joins(Before: number?, After: number): boolean
	if NoStart[After] then return true end

	const Kind: number = Trailing(Before)
	if Kind ~= Open then return Kind == Sticky end

	return not Wide(After)
end

const function Class(Code: number): number
	if Code < 0x80 then
		if (Code >= 0x41 and Code <= 0x5A) or (Code >= 0x61 and Code <= 0x7A) then return Left end

		return if Code >= 0x30 and Code <= 0x39 then Digit else Neutral
	end

	if Within(Code, DigitRanges) then return Digit end
	if Within(Code, RightRanges) then return Right end

	return if Within(Code, NeutralRanges) then Neutral else Left
end

const function Strength(Text: string): number
	local Found: number = Neutral

	if Plain(Text) then
		for Index = 1, #Text do
			const Current: number = Class(Byte(Text, Index))
			if Current == Left then return Left end
			if Current == Digit then Found = Digit end
		end

		return Found
	end

	if not Length(Text) then return Left end

	for _, Code: number in utf8.codes(Text) do
		const Current: number = Class(Code)
		if Current == Left or Current == Right then return Current end
		if Current == Digit then Found = Digit end
	end

	return Found
end

const function Starts(Text: string): { number }
	const Offsets: { number } = {}

	if Plain(Text) or not Length(Text) then
		for Index = 1, #Text + 1 do Offsets[Index] = Index end

		return Offsets
	end

	for First: number in Graphemes(Text) do table.insert(Offsets, First) end
	table.insert(Offsets, #Text + 1)

	return Offsets
end

const function Count(Text: string): number
	if Plain(Text) or not Length(Text) then return #Text end

	local Total: number = 0
	for _ in Graphemes(Text) do Total += 1 end

	return Total
end

const function Control(Code: number): Joint?
	return Controls[Code]
end

return {
	Neutral = Neutral;
	Left = Left;
	Right = Right;
	Digit = Digit;
	Codepoint = Codepoint;
	Graphemes = Graphemes;
	Length = Length;
	Wide = Wide;
	Trailing = Trailing;
	Joins = Joins;
	Class = Class;
	Strength = Strength;
	Starts = Starts;
	Count = Count;
	Control = Control;
	Locate = Locate;
	Within = Within;
}
