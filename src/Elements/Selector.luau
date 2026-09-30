--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")

type Element = Types.Element

export type Filter = {
	Kind: "Tag" | "Id" | "Class" | "Attribute" | "Property" | "Not" | "Has" | "State";
	Name: string;
	Value: string?;
	List: { Complex }?;
}

export type Complex = {
	Lead: string?;
	Compounds: { { Filter } };
	Links: { string };
	Dynamic: boolean;
}

export type Compiled = {
	Source: string;
	List: { Complex };
	Dynamic: boolean;
}

type Parser = {
	Source: string;
	Position: number;
}

const CACHE_LIMIT: number = 256

const SPACE: number = string.byte(" ")
const TAB: number = string.byte("\t")
const NEWLINE: number = string.byte("\n")
const RETURN: number = string.byte("\r")
const COMMA: number = string.byte(",")
const GREATER: number = string.byte(">")
const DOT: number = string.byte(".")
const HASH: number = string.byte("#")
const OPEN_BRACKET: number = string.byte("[")
const CLOSE_BRACKET: number = string.byte("]")
const OPEN_PAREN: number = string.byte("(")
const CLOSE_PAREN: number = string.byte(")")
const COLON: number = string.byte(":")
const DOLLAR: number = string.byte("$")
const EQUALS: number = string.byte("=")
const QUOTE: number = string.byte("\"")
const AT: number = string.byte("@")

const StateFields: { [string]: string } = table.freeze({
	Hover = "Hovered";
	Press = "Pressed";
	Focus = "Focused";
	Idle = "";
	NonInteractable = "";
})

const Byte = string.byte
const Sub = string.sub
const Find = string.find
const Lower = string.lower
const Attribute = Styles.Attribute

const Cache: { [string]: Compiled } = {}
local Cached: number = 0

const function Fail(Message: string): never
	error(Message, 0)
end

const function Peek(Parser: Parser): number?
	return Byte(Parser.Source, Parser.Position)
end

const function Skip(Parser: Parser): ()
	local Code: number? = Byte(Parser.Source, Parser.Position)

	while Code == SPACE or Code == TAB or Code == NEWLINE or Code == RETURN do
		Parser.Position += 1
		Code = Byte(Parser.Source, Parser.Position)
	end
end

const function IsName(Code: number?): boolean
	if not Code then return false end

	return (Code >= 97 and Code <= 122) or (Code >= 65 and Code <= 90) or (Code >= 48 and Code <= 57) or Code == 95 or Code == 45
end

const function ReadName(Parser: Parser): string?
	const Start: number = Parser.Position

	while IsName(Byte(Parser.Source, Parser.Position)) do Parser.Position += 1 end

	if Parser.Position == Start then return nil end

	return Sub(Parser.Source, Start, Parser.Position - 1)
end

const function Expect(Parser: Parser, Code: number, Message: string): ()
	if Peek(Parser) ~= Code then Fail(Message) end

	Parser.Position += 1
end

const function ReadValue(Parser: Parser, Kind: string): string
	Skip(Parser)

	if Peek(Parser) == QUOTE then
		const Close: number? = Find(Parser.Source, "\"", Parser.Position + 1, true)
		if not Close then Fail(`Expected '"' to close the {Kind} value`) end

		const Value: string = Sub(Parser.Source, Parser.Position + 1, (Close :: number) - 1)
		Parser.Position = (Close :: number) + 1

		return Value
	end

	const Value: string? = ReadName(Parser)
	if not Value then Fail(`Expected identifier for {if Kind == "attribute" then "an" else "a"} {Kind} value`) end

	return Value :: string
end

const function ReadCombinator(Parser: Parser): string?
	Skip(Parser)
	if Peek(Parser) ~= GREATER then return nil end

	Parser.Position += 1
	if Peek(Parser) ~= GREATER then return ">" end

	Parser.Position += 1

	return ">>"
end

local ReadList: (Parser: Parser, Nested: boolean, Leading: boolean) -> { Complex }

const function ReadBracket(Parser: Parser): Filter
	Skip(Parser)

	if Peek(Parser) == DOLLAR then
		Parser.Position += 1

		const Name: string? = ReadName(Parser)
		if not Name then Fail("Expected identifier for an attribute name") end

		Skip(Parser)

		if Peek(Parser) == CLOSE_BRACKET then
			Parser.Position += 1

			return {Kind = "Attribute", Name = Lower(Name :: string), Value = nil, List = nil}
		end

		Expect(Parser, EQUALS, "'=' or ']' expected after attribute name")

		const Value: string = ReadValue(Parser, "attribute")

		Skip(Parser)
		Expect(Parser, CLOSE_BRACKET, "Expected ']' to complete an attribute filter")

		return {Kind = "Attribute", Name = Lower(Name :: string), Value = Value, List = nil}
	end

	const Name: string? = ReadName(Parser)
	if not Name then Fail("Expected identifier for a property name") end

	Skip(Parser)
	Expect(Parser, EQUALS, "'=' expected after property name")

	const Value: string = ReadValue(Parser, "property")

	Skip(Parser)
	Expect(Parser, CLOSE_BRACKET, "Expected ']' to complete a property filter")

	return {Kind = "Property", Name = Name :: string, Value = Value, List = nil}
end

const function ReadPseudo(Parser: Parser): Filter
	if Peek(Parser) == COLON then Fail("Pseudo-instance selectors are not allowed") end

	const Name: string? = ReadName(Parser)
	if not Name then Fail("Expected identifier for a pseudo-class") end

	if Name == "not" or Name == "has" then
		Skip(Parser)
		Expect(Parser, OPEN_PAREN, `Expected '(' after :{Name}`)

		return {Kind = if Name == "not" then "Not" else "Has", Name = Name :: string, Value = nil, List = ReadList(Parser, true, Name == "has")}
	end

	if StateFields[Name :: string] == nil then Fail(`Pseudo-class '{Name}' filter is not supported`) end

	return {Kind = "State", Name = Name :: string, Value = nil, List = nil}
end

const function ReadFilter(Parser: Parser): Filter?
	Skip(Parser)

	const Code: number? = Peek(Parser)

	if IsName(Code) then return {Kind = "Tag", Name = Lower(ReadName(Parser) :: string), Value = nil, List = nil} end

	if Code == DOT then
		Parser.Position += 1

		const Name: string? = ReadName(Parser)
		if not Name then Fail("Expected identifier for a class name") end

		return {Kind = "Class", Name = Name :: string, Value = nil, List = nil}
	end

	if Code == HASH then
		Parser.Position += 1

		const Name: string? = ReadName(Parser)
		if not Name then Fail("Expected identifier for an id") end

		return {Kind = "Id", Name = Name :: string, Value = nil, List = nil}
	end

	if Code == OPEN_BRACKET then
		Parser.Position += 1

		return ReadBracket(Parser)
	end

	if Code == COLON then
		Parser.Position += 1

		return ReadPseudo(Parser)
	end

	if Code == AT then Fail("StyleQuery filters are not allowed") end

	return nil
end

const function Dynamic(Filters: { Filter }): boolean
	for _, Filter: Filter in (Filters) do
		if Filter.Kind == "State" then return true end

		const List: { Complex }? = Filter.List
		if not List then continue end

		for _, Inner: Complex in (List :: { Complex }) do
			if Inner.Dynamic then return true end
		end
	end

	return false
end

const function ReadComplex(Parser: Parser, Leading: boolean): Complex
	const Lead: string? = ReadCombinator(Parser)
	if Lead and not Leading then Fail("Selector cannot start with a combinator here") end

	const Compounds: { { Filter } } = {}
	const Links: { string } = {}
	local Moving: boolean = false

	while true do
		const Filters: { Filter } = {}

		while true do
			const Filter: Filter? = ReadFilter(Parser)
			if not Filter then break end

			table.insert(Filters, Filter :: Filter)
		end

		if #Filters == 0 then Fail("Expected at least one filter") end
		if Dynamic(Filters) then Moving = true end

		table.insert(Compounds, Filters)

		const Link: string? = ReadCombinator(Parser)
		if not Link then break end

		table.insert(Links, Link :: string)
	end

	return {Lead = Lead, Compounds = Compounds, Links = Links, Dynamic = Moving}
end

ReadList = function(Parser: Parser, Nested: boolean, Leading: boolean): { Complex }
	const List: { Complex } = {}

	while true do
		table.insert(List, ReadComplex(Parser, Leading))
		Skip(Parser)

		const Code: number? = Peek(Parser)

		if Code == COMMA then
			Parser.Position += 1
			Skip(Parser)

			const Next: number? = Peek(Parser)
			if Next == nil or (Nested and Next == CLOSE_PAREN) then Fail("Expected at least one combinator or a filter") end

			continue
		end

		if Nested then
			if Code == CLOSE_PAREN then
				Parser.Position += 1

				return List
			end

			if Code == nil then Fail("Expected ')' to close the pseudo-class") end
		elseif Code == nil then
			return List
		end

		Fail(`Unexpected trailing character: '{Sub(Parser.Source, Parser.Position, Parser.Position)}'`)
	end
end

const function Parse(Source: string): Compiled
	const Parser: Parser = {Source = Source, Position = 1}

	Skip(Parser)

	if Peek(Parser) == nil then return {Source = Source, List = {}, Dynamic = false} end

	const List: { Complex } = ReadList(Parser, false, true)
	local Moving: boolean = false

	for _, Complex: Complex in (List) do
		if Complex.Dynamic then Moving = true end
	end

	return {Source = Source, List = List, Dynamic = Moving}
end

const function Compile(Source: any, Level: number): Compiled
	if type(Source) ~= "string" then error("RichTextPlus selectors are strings, for example \"a\", \".nav > a\" or \"#buy\"", Level + 1) end

	const Existing: Compiled? = Cache[Source]
	if Existing then return Existing :: Compiled end

	const Ok: boolean, Result: any = pcall(Parse, Source)
	if not Ok then error(`RichTextPlus selector "{Source}": {Result}`, Level + 1) end

	if Cached >= CACHE_LIMIT then
		table.clear(Cache)
		Cached = 0
	end

	Cache[Source] = Result
	Cached += 1

	return Result
end

const function HasClass(Target: Element, Name: string): boolean
	const Node: Types.Node? = Target.Node
	const Text: string? = if Node then Attribute(Node :: Types.Node, "class") else nil
	if not Text then return false end

	if Target.ClassText ~= Text then
		const Set: { [string]: boolean } = Target.ClassSet or {}
		table.clear(Set)

		for Word: string in string.gmatch(Text :: string, "%S+") do Set[Word] = true end

		Target.ClassText = Text
		Target.ClassSet = Set
	end

	return (Target.ClassSet :: { [string]: boolean })[Name] == true
end

const function PropertyText(Target: Element, Name: string): string?
	if Name == "Tag" then return Target.Tag end
	if Name == "Id" then return Target.Id end
	if Name == "Text" then return Target.Text end
	if Name == "Interactive" then return if Target.Interactive then "true" else "false" end

	const Field: string? = if Name == "Hovered" or Name == "Pressed" or Name == "Focused" or Name == "Visible" then Name else nil
	if not Field then return nil end

	return if (Target.State :: any)[Field :: string] then "true" else "false"
end

local MatchComplex: (Complex: Complex, Target: Element, Scope: Element?, Assume: boolean) -> boolean

const function MatchState(Target: Element, Name: string): boolean
	const State: Types.ElementState = Target.State

	if Name == "Idle" then return Target.Interactive and not State.Hovered and not State.Pressed end
	if Name == "NonInteractable" then return not Target.Interactive end

	return (State :: any)[StateFields[Name]] == true
end

const function MatchAny(List: { Complex }, Target: Element, Scope: Element?, Assume: boolean): boolean
	for _, Complex: Complex in (List) do
		if MatchComplex(Complex, Target, Scope, Assume) then return true end
	end

	return false
end

const function MatchHas(List: { Complex }, Target: Element, Assume: boolean): boolean
	const Stack: { Element } = {}

	for Index = #Target.Children, 1, -1 do table.insert(Stack, Target.Children[Index]) end

	while #Stack > 0 do
		const Current: Element = table.remove(Stack) :: Element

		if MatchAny(List, Current, Target, Assume) then return true end

		const Children: { Element } = Current.Children
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end

	return false
end

const function MatchFilter(Filter: Filter, Target: Element, Scope: Element?, Assume: boolean): boolean
	const Kind: string = Filter.Kind

	if Kind == "Tag" then return Target.Tag == Filter.Name end
	if Kind == "Id" then return Target.Id == Filter.Name end
	if Kind == "Class" then return HasClass(Target, Filter.Name) end

	if Kind == "Attribute" then
		const Node: Types.Node? = Target.Node
		const Value: string? = if Node then Attribute(Node :: Types.Node, Filter.Name) else nil
		if Value == nil then return false end

		return Filter.Value == nil or Value == Filter.Value
	end

	if Kind == "Property" then return PropertyText(Target, Filter.Name) == Filter.Value end
	if Kind == "State" then return Assume or MatchState(Target, Filter.Name) end

	const List: { Complex } = Filter.List :: { Complex }

	if Kind == "Not" then
		if Assume then
			for _, Complex: Complex in (List) do
				if Complex.Dynamic then return true end
			end
		end

		return not MatchAny(List, Target, Scope, Assume)
	end

	return MatchHas(List, Target, Assume)
end

const function MatchCompound(Filters: { Filter }, Target: Element, Scope: Element?, Assume: boolean): boolean
	for _, Filter: Filter in (Filters) do
		if not MatchFilter(Filter, Target, Scope, Assume) then return false end
	end

	return true
end

const function MatchFrom(Complex: Complex, Index: number, Target: Element, Scope: Element?, Assume: boolean): boolean
	if not MatchCompound(Complex.Compounds[Index], Target, Scope, Assume) then return false end

	if Index == 1 then
		if Complex.Lead == ">" then return Target.Parent == Scope end

		return true
	end

	local Parent: Element? = Target.Parent

	if Complex.Links[Index - 1] == ">" then
		if Parent == nil or Parent == Scope then return false end

		return MatchFrom(Complex, Index - 1, Parent :: Element, Scope, Assume)
	end

	while Parent and Parent ~= Scope do
		if MatchFrom(Complex, Index - 1, Parent :: Element, Scope, Assume) then return true end

		Parent = (Parent :: Element).Parent
	end

	return false
end

MatchComplex = function(Complex: Complex, Target: Element, Scope: Element?, Assume: boolean): boolean
	return MatchFrom(Complex, #Complex.Compounds, Target, Scope, Assume)
end

const function Matches(Compiled: Compiled, Target: Element, Scope: Element?, Assume: boolean): boolean
	return MatchAny(Compiled.List, Target, Scope, Assume)
end

const function Collect(Compiled: Compiled, Roots: { Element }, Scope: Element?, Into: { Element }, First: boolean): { Element }
	if #Compiled.List == 0 then return Into end

	const Stack: { Element } = {}

	for Index = #Roots, 1, -1 do table.insert(Stack, Roots[Index]) end

	while #Stack > 0 do
		const Current: Element = table.remove(Stack) :: Element

		if Matches(Compiled, Current, Scope, false) then
			table.insert(Into, Current)
			if First then return Into end
		end

		const Children: { Element } = Current.Children
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end

	return Into
end

return {
	Compile = Compile;
	Matches = Matches;
	Collect = Collect;
}
