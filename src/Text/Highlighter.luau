--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")

const XML = require("../../XML")
const Profiler = require("../Utility/Profiler")

type Syntax = Types.Syntax

const Escape: (Text: string) -> string = XML.Escape

type Palette = { [string]: string }

const Defaults: Syntax = Config.Syntax

const function WordSet(List: { string }): { [string]: boolean }
	const Set: { [string]: boolean } = {}
	for _, Word: string in (List) do Set[Word] = true end

	return table.freeze(Set)
end

const Keywords: { [string]: boolean } = WordSet({
	"and", "break", "continue", "do", "else", "elseif", "end", "for", "goto", "if", "in", "not", "or", "repeat", "return", "then",
	"until", "while",
})

const Storage: { [string]: boolean } = WordSet({"local", "const", "function", "export", "type"})

const Literals: { [string]: boolean } = WordSet({"true", "false", "nil", "self"})

const Builtins: { [string]: boolean } = WordSet({
	"game", "workspace", "script", "plugin", "shared", "_G", "_VERSION", "Enum", "Instance", "Vector2", "Vector3", "Vector2int16",
	"Vector3int16", "CFrame", "Color3", "UDim", "UDim2", "BrickColor", "TweenInfo", "Ray", "Rect", "Region3", "NumberRange",
	"NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Font", "DateTime", "RaycastParams",
	"OverlapParams", "PhysicalProperties", "Random", "Axes", "Faces", "PathWaypoint", "SharedTable", "math", "string", "table",
	"coroutine", "task", "os", "debug", "utf8", "bit32", "buffer", "vector", "print", "warn", "error", "assert", "pcall", "xpcall",
	"require", "select", "typeof", "tostring", "tonumber", "pairs", "ipairs", "next", "rawget", "rawset", "rawequal", "rawlen",
	"setmetatable", "getmetatable", "unpack", "tick", "time", "wait", "spawn", "delay", "newproxy", "loadstring", "gcinfo",
	"collectgarbage", "elapsedTime", "settings", "UserSettings",
})

const QuoteStops: { [number]: string } = {
	[34] = "[\\\"\n]";
	[39] = "[\\'\n]";
}

const BacktickStops: string = "[\\`{\n]"

const EscapedSymbols: { [number]: string } = {
	[60] = "&lt;";
	[62] = "&gt;";
	[38] = "&amp;";
}

const function BuildPalette(Syntax: Syntax?): Palette
	const Overrides: Syntax = Syntax or Defaults
	const TextHex: string = (Overrides.Text or Defaults.Text):ToHex()
	const Result: Palette = {}

	for Class: string, Default: Color3 in (Defaults) do
		const Hex: string = (Overrides[Class] or Default):ToHex()
		if Hex ~= TextHex then Result[Class] = Hex end
	end

	return Result
end

const DefaultPalette: Palette = BuildPalette(nil)
const PaletteCache: { [Syntax]: Palette } = setmetatable({}, {__mode = "k"}) :: any

const function Resolve(Syntax: Syntax?): Palette
	if not Syntax then return DefaultPalette end

	const Cached: Palette? = PaletteCache[Syntax :: Syntax]; if Cached then return Cached end

	const Built: Palette = BuildPalette(Syntax)
	PaletteCache[Syntax :: Syntax] = Built

	return Built
end

const function IsIdentifierStart(Byte: number): boolean
	return (Byte >= 97 and Byte <= 122) or (Byte >= 65 and Byte <= 90) or Byte == 95
end

const function IsDigit(Byte: number?): boolean
	return Byte ~= nil and (Byte :: number) >= 48 and (Byte :: number) <= 57
end

const function NumberEnd(Code: string, Position: number, Byte: number, Next: number?): number
	if Byte == 48 and (Next == 120 or Next == 88) then return (select(2, string.find(Code, "^0[xX][%x_]*", Position)) :: number) end
	if Byte == 48 and (Next == 98 or Next == 66) then return (select(2, string.find(Code, "^0[bB][01_]*", Position)) :: number) end

	const Mantissa: number = select(2, string.find(Code, "^[%d_]*%.?[%d_]*", Position)) :: number
	const Exponent: number? = select(2, string.find(Code, "^[eE][%+%-]?[%d_]+", Mantissa + 1))

	return Exponent or Mantissa
end

const function QuotedEnd(Code: string, Position: number, Byte: number): number
	local Cursor: number = Position + 1

	while true do
		const Found: number? = string.find(Code, QuoteStops[Byte], Cursor); if not Found then return #Code end

		const Hit: number = string.byte(Code, Found :: number)

		if Hit ~= 92 then return if Hit == 10 then (Found :: number) - 1 else Found :: number end

		Cursor = (Found :: number) + 2
	end
end

const function LongBracketEnd(Code: string, From: number, Equals: string): number
	const _, Close: number? = string.find(Code, `]{Equals}]`, From, true)

	return Close or #Code
end

const function Highlight(Code: string, Syntax: Syntax?): string
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Highlight") end

	const Colors: Palette = Resolve(Syntax)
	const Length: number = #Code

	const Parts: { string } = table.create(64)
	local Count: number = 0
	local Open: string? = nil

	const function Emit(Hex: string?, Text: string): ()
		if Hex ~= Open then
			if Open then Count += 1; Parts[Count] = "</font>" end
			if Hex then Count += 1; Parts[Count] = `<font color="#{Hex}">` end
			Open = Hex
		end

		Count += 1; Parts[Count] = Text
	end

	const InterpolationDepth: { number } = {}
	local InterpolationTop: number = 0

	local Declaring: boolean = false
	local ExpectName: boolean = false
	local PendingParameters: boolean = false
	local ParameterDepth: number = 0
	local ExpectParameter: boolean = false
	local AfterDot: boolean = false
	local AfterColon: boolean = false
	local TypeNext: boolean = false

	const function Backtick(Start: number, From: number): number
		local Cursor: number = From

		while true do
			const Stop: number? = string.find(Code, BacktickStops, Cursor)

			if not Stop then Emit(Colors.String, Escape(string.sub(Code, Start))); return Length + 1 end

			const Byte: number = string.byte(Code, Stop :: number)

			if Byte == 92 then Cursor = (Stop :: number) + 2; continue end
			if Byte == 96 then Emit(Colors.String, Escape(string.sub(Code, Start, Stop :: number))); return (Stop :: number) + 1 end
			if Byte == 10 then Emit(Colors.String, Escape(string.sub(Code, Start, (Stop :: number) - 1))); return Stop :: number end

			Emit(Colors.String, Escape(string.sub(Code, Start, (Stop :: number) - 1)))
			Emit(Colors.Interpolation, "{")

			InterpolationTop += 1
			InterpolationDepth[InterpolationTop] = 0

			return (Stop :: number) + 1
		end
	end

	const function IsCall(Stop: number): boolean
		return string.find(Code, "^[ \t]*[%(\"'`{]", Stop + 1) ~= nil
	end

	const function Identifier(Word: string, Stop: number): ()
		const WasDot: boolean, WasColon: boolean, WasType: boolean = AfterDot, AfterColon, TypeNext

		AfterDot, AfterColon, TypeNext = false, false, false

		if WasDot or WasColon then
			Emit(if IsCall(Stop) then Colors.Function elseif WasColon then Colors.Type else nil, Word)

			return
		end

		if Keywords[Word] then
			if Word == "for" then Declaring = true; ExpectName = true
			elseif Word == "in" or Word == "do" then Declaring = false end

			Emit(Colors.Keyword, Word)

			return
		end

		if Literals[Word] then Emit(Colors.Literal, Word); return end

		if Storage[Word] and not (Word == "type" and IsCall(Stop)) then
			if Word == "local" or Word == "const" then Declaring = true; ExpectName = true
			elseif Word == "function" then Declaring = false; PendingParameters = true
			elseif Word == "type" then TypeNext = true end

			Emit(Colors.Storage, Word)

			return
		end

		if Declaring and ExpectName then ExpectName = false; Emit(Colors.Local, Word); return end
		if ParameterDepth == 1 and ExpectParameter then ExpectParameter = false; Emit(Colors.Local, Word); return end

		if WasType then Emit(Colors.Type, Word); return end
		if IsCall(Stop) then Emit(Colors.Function, Word); return end
		if Builtins[Word] then Emit(Colors.Builtin, Word); return end

		Emit(nil, Word)
	end

	const function Symbol(Position: number, Byte: number): number
		const Next: number? = string.byte(Code, Position + 1)

		AfterDot, AfterColon, TypeNext = false, false, false

		if Byte == 58 then
			if Next == 58 then TypeNext = true; Emit(Colors.Operator, "::"); return Position + 2 end

			if Declaring or ParameterDepth > 0 then
				TypeNext = true
				ExpectName = false
				ExpectParameter = false
			else
				AfterColon = true
			end
		elseif Byte == 45 and Next == 62 then
			TypeNext = true
			Emit(Colors.Operator, "-&gt;")

			return Position + 2
		elseif Byte == 46 then
			if Next == 46 then
				const Run: string = if string.byte(Code, Position + 2) == 46 then "..." else ".."
				Emit(Colors.Operator, Run)

				return Position + #Run
			end

			AfterDot = true
		elseif Byte == 44 then
			if Declaring then ExpectName = true end
			if ParameterDepth == 1 then ExpectParameter = true end
		elseif Byte == 61 then
			if Next == 61 then Emit(Colors.Operator, "=="); return Position + 2 end

			Declaring = false
		elseif Byte == 40 then
			if PendingParameters then
				PendingParameters = false
				ParameterDepth = 1
				ExpectParameter = true
			elseif ParameterDepth > 0 then
				ParameterDepth += 1
			end
		elseif Byte == 41 then
			if ParameterDepth > 0 then ParameterDepth -= 1 end
		elseif Byte == 123 then
			if InterpolationTop > 0 then InterpolationDepth[InterpolationTop] += 1 end
		elseif Byte == 125 and InterpolationTop > 0 then
			if InterpolationDepth[InterpolationTop] == 0 then
				InterpolationTop -= 1
				Emit(Colors.Interpolation, "}")

				return Backtick(Position + 1, Position + 1)
			end

			InterpolationDepth[InterpolationTop] -= 1
		end

		Emit(Colors.Operator, EscapedSymbols[Byte] or string.char(Byte))

		return Position + 1
	end

	local Position: number = 1

	while Position <= Length do
		const Byte: number = string.byte(Code, Position)

		if Byte == 32 or Byte == 9 or Byte == 10 or Byte == 13 then
			const Stop: number = select(2, string.find(Code, "^[ \t\r\n]+", Position)) :: number
			const Space: string = string.sub(Code, Position, Stop)

			if string.find(Space, "\n", 1, true) then Declaring = false; ExpectName = false end

			Count += 1; Parts[Count] = Space
			Position = Stop + 1

			continue
		end

		if IsIdentifierStart(Byte) then
			const Stop: number = select(2, string.find(Code, "^[%w_]+", Position)) :: number
			Identifier(string.sub(Code, Position, Stop), Stop)
			Position = Stop + 1

			continue
		end

		const Next: number? = string.byte(Code, Position + 1)

		if IsDigit(Byte) or (Byte == 46 and IsDigit(Next)) then
			const Stop: number = NumberEnd(Code, Position, Byte, Next)

			AfterDot, AfterColon, TypeNext = false, false, false
			Emit(Colors.Number, string.sub(Code, Position, Stop))
			Position = Stop + 1

			continue
		end

		if Byte == 34 or Byte == 39 then
			const Stop: number = QuotedEnd(Code, Position, Byte)

			AfterDot, AfterColon, TypeNext = false, false, false
			Emit(Colors.String, Escape(string.sub(Code, Position, Stop)))
			Position = Stop + 1

			continue
		end

		if Byte == 96 then
			AfterDot, AfterColon, TypeNext = false, false, false
			Position = Backtick(Position, Position + 1)

			continue
		end

		if Byte == 45 and Next == 45 then
			const Equals: string? = string.match(Code, "^%[(=*)%[", Position + 2)
			const Newline: number? = if Equals then nil else string.find(Code, "\n", Position + 2, true)
			const Stop: number =
				if Equals then LongBracketEnd(Code, Position + 4 + #(Equals :: string), Equals :: string)
				elseif Newline then (Newline :: number) - 1
				else Length

			Emit(Colors.Comment, Escape(string.sub(Code, Position, Stop)))
			Position = Stop + 1

			continue
		end

		const Bracket: string? = if Byte == 91 then string.match(Code, "^%[(=*)%[", Position) else nil

		if Bracket then
			const Stop: number = LongBracketEnd(Code, Position + 2 + #(Bracket :: string), Bracket :: string)

			AfterDot, AfterColon, TypeNext = false, false, false
			Emit(Colors.String, Escape(string.sub(Code, Position, Stop)))
			Position = Stop + 1

			continue
		end

		if Byte >= 128 then
			const Stop: number = select(2, string.find(Code, "^[\128-\255]+", Position)) :: number
			Emit(nil, string.sub(Code, Position, Stop))
			Position = Stop + 1

			continue
		end

		Position = Symbol(Position, Byte)
	end

	if Open then Count += 1; Parts[Count] = "</font>" end

	const Result: string = table.concat(Parts, "", 1, Count)

	if Profiling then Profiler.End() end

	return Result
end

return {
	Defaults = Defaults;
	Highlight = Highlight;
}
