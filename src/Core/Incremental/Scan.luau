--!strict
--!native
--!optimize 2

const XML = require("../../../XML")
const Types = require("../../Types/Incremental")
const Characters = require("../../Utility/Characters")

type Window = Types.Window

const OpenByte: number = string.byte("<")
const CloseByte: number = string.byte(">")
const BangByte: number = string.byte("!")
const QuestionByte: number = string.byte("?")
const SlashByte: number = string.byte("/")
const DoubleQuoteByte: number = string.byte("\"")
const SingleQuoteByte: number = string.byte("'")
const UnderscoreByte: number = string.byte("_")
const ColonByte: number = string.byte(":")
const CdataOpen: string = "![CDATA["

const Byte = string.byte
const Find = string.find
const Sub = string.sub
const ReadByte = buffer.readu8
const ReadWord = buffer.readu32
const Escape: (Text: string) -> string = XML.Escape
const Separators: { [number]: boolean } = Characters.Separators
const Spaces: { [number]: boolean } = Characters.Whitespace

const function NameStart(Code: number?): boolean
	if not Code then return false end

	return (Code >= 97 and Code <= 122) or (Code >= 65 and Code <= 90) or Code == UnderscoreByte or Code == ColonByte or Code >= 128
end

const function TagEnd(Source: string, Position: number): (number?, number)
	local Index: number? = Find(Source, "[<>=]", Position)

	while Index do
		const Code: number = Byte(Source, Index :: number)
		if Code == CloseByte then return (Index :: number) + 1, Index :: number end
		if Code == OpenByte then return nil, Index :: number end

		local After: number = (Index :: number) + 1
		while Spaces[Byte(Source, After) :: number] do After += 1 end

		const Quote: number? = Byte(Source, After)

		if Quote == DoubleQuoteByte or Quote == SingleQuoteByte then
			const Closing: number? = Find(Source, if Quote == DoubleQuoteByte then "\"" else "'", After + 1, true)
			if not Closing then return nil, math.huge end

			Index = Find(Source, "[<>=]", (Closing :: number) + 1)
		else
			Index = Find(Source, "[<>=]", After)
		end
	end

	return nil, math.huge
end

const function Terminated(Source: string, Terminator: string, From: number, Length: number): (number?, number)
	const Stop: number? = Find(Source, Terminator, From, true)

	return if Stop then (Stop :: number) + Length else nil, math.huge
end

const function Construct(Source: string, Position: number): (number?, number)
	const Next: number? = Byte(Source, Position + 1)

	if Next == BangByte then
		if Sub(Source, Position + 2, Position + 3) == "--" then return Terminated(Source, "-->", Position + 4, 3) end
		if Sub(Source, Position + 1, Position + 8) == CdataOpen then return Terminated(Source, "]]>", Position + 9, 3) end

		return nil, Position + 8
	end

	if Next == QuestionByte then
		if not NameStart(Byte(Source, Position + 2)) then return nil, Position + 2 end

		return Terminated(Source, "?>", Position + 2, 2)
	end

	if Next == SlashByte then
		if not NameStart(Byte(Source, Position + 2)) then return nil, Position + 2 end

		return TagEnd(Source, Position + 2)
	end

	if not NameStart(Next) then return nil, Position + 1 end

	return TagEnd(Source, Position + 1)
end

const function Seek(Source: string, Position: number): (number?, number, number)
	local Search: number = Position
	local Reach: number = 0

	while true do
		const Open: number? = Find(Source, "<", Search, true); if not Open then break end
		const Resume: number?, Examined: number = Construct(Source, Open :: number)

		if Resume then return Open, Resume :: number, Reach end
		if Examined > Reach then Reach = Examined end

		Search = (Open :: number) + 1
	end

	return nil, #Source + 1, Reach
end

const function Crossing(Reach: number, Stop: number): number
	return if Reach > Stop + 1 then Reach else 0
end

const function Strings(Tree: XMLNode): { XMLNode }
	const Found: { XMLNode } = {}
	const Stack: { XMLNode } = {Tree}

	while #Stack > 0 do
		const Current: XMLNode = table.remove(Stack) :: XMLNode
		if Current.Type == "STRING" then table.insert(Found, Current); continue end

		const Children: { XMLNode } = Current.Children
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end

	return Found
end

const function Scan(Source: string, Tree: XMLNode): Spans?
	const Starts: { number } = {}
	const Stops: { number } = {}
	const Reaches: { number } = {}
	const Sealed: { [number]: boolean } = {}
	const Size: number = #Source

	local Position: number = 1
	local Crossed: number = 0

	while true do
		const Open: number?, Resume: number, Reach: number = Seek(Source, Position)
		const Stop: number = if Open then (Open :: number) - 1 else Size

		if Stop >= Position then
			const Count: number = #Stops + 1
			const Far: number = Crossing(Reach, Stop)

			Starts[Count] = Position
			Stops[Count] = Stop
			Reaches[Count] = Far
			if Far > 0 then Crossed += 1 end
		end

		if not Open then break end

		if Sub(Source, (Open :: number) + 1, (Open :: number) + 8) == CdataOpen then
			const Count: number = #Stops + 1

			Starts[Count] = (Open :: number) + 9
			Stops[Count] = Resume - 4
			Reaches[Count] = 0
			Sealed[Count] = true
		end

		Position = Resume
	end

	const Nodes: { XMLNode } = Strings(Tree)
	if #Nodes ~= #Starts then return nil end

	for Index: number, Node: XMLNode in (Nodes) do
		const Raw: string = Sub(Source, Starts[Index], Stops[Index])
		if Node.Text ~= (if Sealed[Index] then Escape(Raw) else Raw) then return nil end
	end

	return {Source = buffer.fromstring(Source), Size = Size, Starts = Starts, Stops = Stops, Reaches = Reaches, Sealed = Sealed, Crossing = Crossed, Nodes = Nodes}
end

const function Prefix(Left: buffer, LeftAt: number, Right: buffer, RightAt: number, Limit: number): number
	local Count: number = 0

	while Count + 4 <= Limit and ReadWord(Left, LeftAt + Count) == ReadWord(Right, RightAt + Count) do Count += 4 end
	while Count < Limit and ReadByte(Left, LeftAt + Count) == ReadByte(Right, RightAt + Count) do Count += 1 end

	return Count
end

const function Suffix(Left: buffer, LeftEnd: number, Right: buffer, RightEnd: number, Limit: number): number
	local Count: number = 0

	while Count + 4 <= Limit and ReadWord(Left, LeftEnd - Count - 4) == ReadWord(Right, RightEnd - Count - 4) do Count += 4 end
	while Count < Limit and ReadByte(Left, LeftEnd - Count - 1) == ReadByte(Right, RightEnd - Count - 1) do Count += 1 end

	return Count
end

const function Locate(Stops: { number }, Position: number): number
	local Low: number = 1
	local High: number = #Stops + 1

	while Low < High do
		const Middle: number = (Low + High) // 2

		if Stops[Middle] + 1 >= Position then High = Middle else Low = Middle + 1 end
	end

	return Low
end

const function Shadowed(Spans: Spans, First: number, Last: number, Head: number): boolean
	const Sealed: { [number]: boolean } = Spans.Sealed

	if next(Sealed) ~= nil then
		for Index = First, Last do
			if Sealed[Index] then return true end
		end
	end

	if Spans.Crossing == 0 then return false end

	const Reaches: { number } = Spans.Reaches

	for Index = 1, First - 1 do
		if Reaches[Index] > Head then return true end
	end

	return false
end

const function Realign(Spans: Spans, New: buffer, Source: string, Window: Window): (number, boolean)
	const SpanStarts: { number } = Spans.Starts
	const SpanStops: { number } = Spans.Stops
	const Old: buffer = Spans.Source
	const OldSize: number = Spans.Size
	const NewSize: number = #Source
	const Limit: number = math.min(OldSize, NewSize)
	const Head: number = Prefix(Old, 0, New, 0, Limit)
	const Tail: number = Suffix(Old, OldSize, New, NewSize, Limit - Head)
	const First: number = Locate(SpanStops, Head + 1)
	const Last: number = math.max(First, Locate(SpanStops, OldSize - Tail + 1))

	if Last > #SpanStops or SpanStarts[First] > Head + 1 or Shadowed(Spans, First, Last, Head) then return First, false end

	const Starts: { number } = Window.Starts
	const Stops: { number } = Window.Stops
	const Reaches: { number } = Window.Reaches

	table.clear(Starts)
	table.clear(Stops)
	table.clear(Reaches)

	local Position: number = SpanStarts[First]

	for Index = First, Last do
		const Open: number?, _Resume: number, Reach: number = Seek(Source, Position)
		const Stop: number = if Open then (Open :: number) - 1 else NewSize
		if Stop < Position then return First, false end

		table.insert(Starts, Position)
		table.insert(Stops, Stop)
		table.insert(Reaches, Crossing(Reach, Stop))

		if Index == Last then
			if NewSize - Stop ~= OldSize - SpanStops[Last] then return First, false end

			break
		end

		const Gap: number = SpanStarts[Index + 1] - SpanStops[Index] - 1
		if not Open or (Open :: number) + Gap - 1 > NewSize then return First, false end
		if Prefix(Old, SpanStops[Index], New, (Open :: number) - 1, Gap) ~= Gap then return First, false end

		Position = (Open :: number) + Gap
	end

	return First, true
end

const function Bounds(Old: buffer, OldStart: number, OldSize: number, New: buffer, NewStart: number, NewSize: number): (number, number, number, boolean)
	const Limit: number = math.min(OldSize, NewSize)
	const Head: number = Prefix(Old, OldStart - 1, New, NewStart - 1, Limit)
	const Tail: number = Suffix(Old, OldStart + OldSize - 1, New, NewStart + NewSize - 1, Limit - Head)

	local Start: number = Head + 1
	while Start > 1 and not Separators[ReadByte(Old, OldStart + Start - 3)] do Start -= 1 end

	for Index = OldSize - Tail + 1, OldSize do
		if Separators[ReadByte(Old, OldStart + Index - 2)] then return Start, Index - 1, Index - 1 + NewSize - OldSize, true end
	end

	return Start, OldSize, NewSize, false
end

return {
	Crossing = Crossing;
	Scan = Scan;
	Prefix = Prefix;
	Realign = Realign;
	Bounds = Bounds;
}
