--!strict
--!native
--!optimize 2

const Styles = require("../Utility/Styles")
const Types = require("../Types/Markdown")
const Config = require("../Config").Markdown
const Scan = require("./Scan")

type Inline = Types.Inline
type Delimiter = Types.Delimiter
type Bracket = Types.Bracket
type Piece = Types.Piece
type Scanner = Types.Scanner
type Dialect = Types.Dialect
type InlineRule = Types.InlineRule

const BACKSLASH: number = 92
const BACKTICK: number = 96
const ASTERISK: number = 42
const UNDERSCORE: number = 95
const TILDE: number = 126
const OPEN_BRACKET: number = 91
const CLOSE_BRACKET: number = 93
const BANG: number = 33
const LESS_THAN: number = 60
const NEWLINE: number = 10
const OPEN_PAREN: number = 40
const CLOSE_PAREN: number = 41
const DOUBLE_QUOTE: number = 34
const SINGLE_QUOTE: number = 39
const GREATER_THAN: number = 62

const Unescape: (Text: string) -> string = Styles.Unescape
const Whitespace: { [number]: boolean } = Scan.Whitespace
const Punctuation: { [number]: boolean } = Scan.Punctuation

const RunPatterns: { [number]: string } = {
	[ASTERISK] = "^%*+";
	[UNDERSCORE] = "^_+";
	[TILDE] = "^~+";
}

const EmphasisTypes: { [string]: "Emphasis" | "Strong" | "Strikethrough" } = {
	["i"] = "Emphasis";
	["b"] = "Strong";
	["s"] = "Strikethrough";
}

const BREAK: Types.Break = table.freeze({Type = "Break"}) :: Types.Break

const Scratch: Scanner = {
	Pieces = table.create(64);
	Count = 0;
	Head = nil;
	Tail = nil;
	Bracket = nil;
	Sequence = 0;
	ActiveFloor = 0;
	NoCloser = {};
	BreakCost = 0;
	Allowance = 0;
}

const function Text(Value: string): Inline
	return {Type = "Text", Value = Value}
end

const function Add(State: Scanner, Piece: Piece): ()
	State.Count += 1
	State.Pieces[State.Count] = Piece
end

const function Literal(State: Scanner, Raw: string): ()
	Add(State, Unescape(Raw))
end

const function RemoveDelimiter(State: Scanner, Entry: Delimiter): ()
	const Previous: Delimiter?, Next: Delimiter? = Entry.Previous, Entry.Next

	if Previous then (Previous :: Delimiter).Next = Next else State.Head = Next end
	if Next then (Next :: Delimiter).Previous = Previous else State.Tail = Previous end
end

const function OddMatch(Opener: Delimiter, Closer: Delimiter): boolean
	if not (Opener.CanClose or Closer.CanOpen) then return false end
	if (Opener.Length + Closer.Length) % 3 ~= 0 then return false end

	return not (Opener.Length % 3 == 0 and Closer.Length % 3 == 0)
end

const function ProcessEmphasis(State: Scanner, Bottom: Delimiter?): ()
	local Closer: Delimiter? = if Bottom then (Bottom :: Delimiter).Next else State.Head
	if not Closer then return end

	const Bottoms: { [number]: Delimiter? } = {}

	while Closer do
		const Current: Delimiter = Closer :: Delimiter

		if not Current.CanClose then Closer = Current.Next; continue end

		const Key: number = Current.Byte * 8 + (if Current.CanOpen then 4 else 0) + Current.Length % 3
		const Limit: Delimiter? = Bottoms[Key]
		local Opener: Delimiter? = Current.Previous

		while Opener and Opener ~= Bottom and Opener ~= Limit do
			const Candidate: Delimiter = Opener :: Delimiter
			if Candidate.Byte == Current.Byte and Candidate.CanOpen and (Current.Byte == TILDE or not OddMatch(Candidate, Current)) then break end

			Opener = Candidate.Previous
		end

		if not Opener or Opener == Bottom or Opener == Limit then
			Bottoms[Key] = Current.Previous
			Closer = Current.Next
			if not Current.CanOpen then RemoveDelimiter(State, Current) end

			continue
		end

		const Matched: Delimiter = Opener :: Delimiter
		const Use: number = if Current.Byte == TILDE or (Current.Count >= 2 and Matched.Count >= 2) then 2 else 1
		const Tag: string = if Current.Byte == TILDE then "s" elseif Use == 2 then "b" else "i"

		Matched.Count -= Use
		Current.Count -= Use
		Matched.After = `<{Tag}>` .. Matched.After
		Current.Before ..= `</{Tag}>`

		local Between: Delimiter? = Current.Previous

		while Between and Between ~= Matched do
			const Previous: Delimiter? = (Between :: Delimiter).Previous
			RemoveDelimiter(State, Between :: Delimiter)
			Between = Previous
		end

		if Matched.Count == 0 then RemoveDelimiter(State, Matched) end

		if Current.Count == 0 then
			Closer = Current.Next
			RemoveDelimiter(State, Current)
		end
	end

	while State.Tail and State.Tail ~= Bottom do RemoveDelimiter(State, State.Tail :: Delimiter) end
end

const function Newline(State: Scanner): ()
	Add(State, BREAK)
	State.Allowance -= State.BreakCost
end

const function Backslash(State: Scanner, Source: string, Start: number): number
	const Next: number? = string.byte(Source, Start + 1)

	if Next == NEWLINE then Newline(State); return Start + 2 end
	if Next and Punctuation[Next :: number] then Add(State, string.char(Next :: number)); return Start + 2 end

	Add(State, "\\")

	return Start + 1
end

const function CodeSpan(State: Scanner, Source: string, Start: number): number
	const RunEnd: number = select(2, string.find(Source, "^`+", Start)) :: number
	const Size: number = RunEnd - Start + 1

	if not State.NoCloser[Size] then
		local Cursor: number = RunEnd + 1

		while true do
			const Found: number?, FoundEnd: number? = string.find(Source, "`+", Cursor)
			if not Found then State.NoCloser[Size] = true; break end

			if (FoundEnd :: number) - (Found :: number) + 1 == Size then
				local Content: string = (string.gsub(string.sub(Source, RunEnd + 1, (Found :: number) - 1), "\n", " "))

				const Padded: boolean = #Content >= 2 and string.byte(Content, 1) == 32 and string.byte(Content, -1) == 32
				if Padded and string.find(Content, "[^ ]") then Content = string.sub(Content, 2, -2) end

				Add(State, {Type = "Code", Value = Content})

				return (FoundEnd :: number) + 1
			end

			Cursor = (FoundEnd :: number) + 1
		end
	end

	Add(State, string.sub(Source, Start, RunEnd))

	return RunEnd + 1
end

const function DelimiterRun(State: Scanner, Source: string, Start: number): number
	const Byte: number = string.byte(Source, Start)
	const RunEnd: number = select(2, string.find(Source, RunPatterns[Byte], Start)) :: number
	const Size: number = RunEnd - Start + 1
	const Run: string = string.sub(Source, Start, RunEnd)

	if Byte == TILDE and Size ~= 2 then Add(State, Run); return RunEnd + 1 end

	const Before: number? = if Start > 1 then string.byte(Source, Start - 1) else nil
	const After: number? = string.byte(Source, RunEnd + 1)

	const BeforeSpace: boolean = Before == nil or Whitespace[Before :: number] == true
	const AfterSpace: boolean = After == nil or Whitespace[After :: number] == true
	const BeforePunctuation: boolean = Before ~= nil and Punctuation[Before :: number] == true
	const AfterPunctuation: boolean = After ~= nil and Punctuation[After :: number] == true

	const LeftFlanking: boolean = not AfterSpace and (not AfterPunctuation or BeforeSpace or BeforePunctuation)
	const RightFlanking: boolean = not BeforeSpace and (not BeforePunctuation or AfterSpace or AfterPunctuation)

	const CanOpen: boolean = if Byte == UNDERSCORE then LeftFlanking and (not RightFlanking or BeforePunctuation) else LeftFlanking
	const CanClose: boolean = if Byte == UNDERSCORE then RightFlanking and (not LeftFlanking or AfterPunctuation) else RightFlanking

	if not (CanOpen or CanClose) then Add(State, Run); return RunEnd + 1 end

	const Entry: Delimiter = {
		Byte = Byte;
		Char = string.sub(Run, 1, 1);
		Count = Size;
		Length = Size;
		CanOpen = CanOpen;
		CanClose = CanClose;
		Before = "";
		After = "";
		Previous = State.Tail;
		Next = nil;
	}

	if State.Tail then (State.Tail :: Delimiter).Next = Entry else State.Head = Entry end
	State.Tail = Entry

	Add(State, Entry)

	return RunEnd + 1
end

const function OpenBracket(State: Scanner, Image: boolean): ()
	State.Sequence += 1

	Add(State, if Image then "![" else "[")

	State.Bracket = {
		Index = State.Count;
		Image = Image;
		Bottom = State.Tail;
		Sequence = State.Sequence;
		Previous = State.Bracket;
	}
end

const function SkipSpace(Source: string, Position: number): number
	return (select(2, string.find(Source, "^[ \t\n]*", Position)) :: number) + 1
end

const function LinkDestination(Source: string, Position: number): (string?, number)
	if string.byte(Source, Position) ~= OPEN_PAREN then return nil, Position end

	local Cursor: number = SkipSpace(Source, Position + 1)
	local Destination: string = ""

	if string.byte(Source, Cursor) == LESS_THAN then
		const Close: number? = string.find(Source, "[<>\n]", Cursor + 1)
		if not Close or string.byte(Source, Close :: number) ~= GREATER_THAN then return nil, Position end

		Destination = string.sub(Source, Cursor + 1, (Close :: number) - 1)
		Cursor = (Close :: number) + 1
	else
		const Limit: number = math.min(#Source, Cursor + Config.MAX_DESTINATION)
		local Scanned: number = Cursor
		local Depth: number = 0

		while Scanned <= Limit do
			const Byte: number = string.byte(Source, Scanned)

			if Byte == BACKSLASH then Scanned += 2; continue end
			if Byte <= 32 then break end

			if Byte == OPEN_PAREN then
				Depth += 1
			elseif Byte == CLOSE_PAREN then
				if Depth == 0 then break end
				Depth -= 1
			end

			Scanned += 1
		end

		if Scanned > Limit or Depth ~= 0 then return nil, Position end

		Destination = string.sub(Source, Cursor, Scanned - 1)
		Cursor = Scanned
	end

	Cursor = SkipSpace(Source, Cursor)

	const Quote: number? = string.byte(Source, Cursor)

	if Quote == DOUBLE_QUOTE or Quote == SINGLE_QUOTE or Quote == OPEN_PAREN then
		const Closing: string = if Quote == OPEN_PAREN then ")" else string.char(Quote :: number)
		const Offset: number? = string.find(string.sub(Source, Cursor + 1, Cursor + Config.MAX_DESTINATION), Closing, 1, true)
		if not Offset then return nil, Position end

		Cursor = SkipSpace(Source, Cursor + (Offset :: number) + 1)
	end

	if string.byte(Source, Cursor) ~= CLOSE_PAREN then return nil, Position end

	return (string.gsub(Destination, "\\(%p)", "%1")), Cursor + 1
end

const function CloseBracket(State: Scanner, Source: string, Start: number): number
	const Opener: Bracket? = State.Bracket
	if not Opener then Add(State, "]"); return Start + 1 end

	const Current: Bracket = Opener :: Bracket
	State.Bracket = Current.Previous

	if not Current.Image and Current.Sequence <= State.ActiveFloor then Add(State, "]"); return Start + 1 end

	const Destination: string?, After: number = LinkDestination(Source, Start + 1)
	if not Destination then Add(State, "]"); return Start + 1 end

	ProcessEmphasis(State, Current.Bottom)

	const Target: string = Unescape(Destination :: string)

	if Current.Image then
		for Index = Current.Index + 1, State.Count do State.Pieces[Index] = false end
		State.Pieces[Current.Index] = {Type = "Image", Source = Target}
	else
		State.Pieces[Current.Index] = {Type = "Open", Destination = Target}
		Add(State, {Type = "Close"})
		State.ActiveFloor = State.Sequence
	end

	return After
end

const function Bang(State: Scanner, Source: string, Start: number): number
	if string.byte(Source, Start + 1) == OPEN_BRACKET then OpenBracket(State, true); return Start + 2 end

	Add(State, "!")

	return Start + 1
end

const function Autolink(State: Scanner, Source: string, Start: number): number
	const Url: string? = string.match(Source, "^<(%a[%w%+%.%-]+:[^%s<>]*)>", Start)
	if not Url then Add(State, "<"); return Start + 1 end

	Add(State, {Type = "Link", Destination = Url :: string, Children = {Text(Url :: string)}})

	return Start + #(Url :: string) + 2
end

const Rules: { [number]: InlineRule } = {
	[BACKSLASH] = Backslash;
	[BACKTICK] = CodeSpan;
	[ASTERISK] = DelimiterRun;
	[UNDERSCORE] = DelimiterRun;
	[TILDE] = DelimiterRun;
	[OPEN_BRACKET] = function(State: Scanner, _: string, Start: number): number OpenBracket(State, false); return Start + 1 end;
	[BANG] = Bang;
	[CLOSE_BRACKET] = CloseBracket;
	[LESS_THAN] = Autolink;
	[NEWLINE] = function(State: Scanner, _: string, Start: number): number Newline(State); return Start + 1 end;
}

const function Specials(Inlines: { [number]: InlineRule }): string
	const Bytes: { number } = {}
	for Byte: number in (Inlines) do table.insert(Bytes, Byte) end
	table.sort(Bytes)

	const Parts: { string } = {}

	for _, Byte: number in (Bytes) do
		const Char: string = string.char(Byte)
		table.insert(Parts, if string.find(Char, "[%]%%%^%-]") then `%{Char}` else Char)
	end

	return `[{table.concat(Parts)}]`
end

const function Build(State: Scanner): { Inline }
	const Root: { Inline } = {}
	const Stack: { { Inline } } = {Root}
	const Pieces: { Piece } = State.Pieces
	local Top: { Inline } = Root

	for Index = 1, State.Count do
		const Piece: any = Pieces[Index]

		if Piece == false then continue end

		if type(Piece) == "string" then
			table.insert(Top, Text(Piece))
		elseif Piece == BREAK then
			table.insert(Top, {Type = "Break"})
		elseif Piece.Byte then
			for _ in string.gmatch(Piece.Before, "</") do
				table.remove(Stack)
				Top = Stack[#Stack]
			end

			if Piece.Count > 0 then table.insert(Top, Text(string.rep(Piece.Char, Piece.Count))) end

			for Tag: string in string.gmatch(Piece.After, "<(%a)>") do
				const Children: { Inline } = {}
				table.insert(Top, {Type = EmphasisTypes[Tag], Children = Children})
				table.insert(Stack, Children)
				Top = Children
			end
		elseif Piece.Type == "Open" then
			const Children: { Inline } = {}
			table.insert(Top, {Type = "Link", Destination = Piece.Destination, Children = Children})
			table.insert(Stack, Children)
			Top = Children
		elseif Piece.Type == "Close" then
			table.remove(Stack)
			Top = Stack[#Stack]
		else
			table.insert(Top, Piece :: Inline)
		end
	end

	return Root
end

const function Tokenize(Source: string, Dialect: Dialect, BreakCost: number?, Allowance: number?): Scanner
	const State: Scanner = Scratch

	if next(State.NoCloser) ~= nil then table.clear(State.NoCloser) end
	State.Count = 0
	State.Head = nil
	State.Tail = nil
	State.Bracket = nil
	State.Sequence = 0
	State.ActiveFloor = 0
	State.BreakCost = BreakCost or 0
	State.Allowance = Allowance or math.huge

	const Inlines: { [number]: InlineRule } = Dialect.Inlines
	const Pattern: string = Dialect.Specials
	const Length: number = #Source
	local Position: number = 1

	while Position <= Length and State.Allowance >= 0 do
		const Start: number? = string.find(Source, Pattern, Position)
		if not Start then Literal(State, string.sub(Source, Position)); break end

		if (Start :: number) > Position then Literal(State, string.sub(Source, Position, (Start :: number) - 1)) end

		Position = Inlines[string.byte(Source, Start :: number)](State, Source, Start :: number)
	end

	ProcessEmphasis(State, nil)

	return State
end

const function Release(State: Scanner): ()
	const Pieces: { Piece } = State.Pieces
	for Index = 1, State.Count do Pieces[Index] = nil end

	State.Count = 0
	State.Head = nil
	State.Tail = nil
	State.Bracket = nil
end

const function Parse(Source: string, Dialect: Dialect): { Inline }
	const State: Scanner = Tokenize(Source, Dialect)
	const Nodes: { Inline } = Build(State)

	Release(State)

	return Nodes
end

return {
	Rules = Rules;
	Specials = Specials;
	Break = BREAK;
	Tokenize = Tokenize;
	Release = Release;
	Parse = Parse;
}
