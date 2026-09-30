--!strict
--!native
--!optimize 2

const Types = require("../Types/Markdown")
const Config = require("../Config").Markdown
const Scan = require("./Scan")

type Block = Types.Block
type BlockRule = Types.BlockRule
type Parser = Types.Parser
type Dialect = Types.Dialect
type ListItem = Types.ListItem
type ListMatch = Types.ListMatch

const IsBlank = Scan.IsBlank
const Trim = Scan.Trim
const Indentation = Scan.Indentation
const MatchFence = Scan.MatchFence
const MatchHeading = Scan.MatchHeading
const MatchListItem = Scan.MatchListItem
const IsRule = Scan.IsRule
const IsQuote = Scan.IsQuote

const FenceIndentPatterns: { [number]: string } = {
	[1] = "^ ?(.*)$";
	[2] = "^ ? ?(.*)$";
	[3] = "^ ? ? ?(.*)$";
}

const function StartsBlock(Dialect: Dialect, Line: string): boolean
	const First: number? = string.find(Line, "%S"); if not First then return false end

	for _, Test: (Line: string) -> any in (Dialect.Interrupters[string.byte(Line, First :: number)]) do
		if Test(Line) then return true end
	end

	return false
end

local ParseBlocks: (Parser: Parser, Lines: { string }) -> ({ Block }, boolean)

const function Nested(Parser: Parser, Lines: { string }): ({ Block }, boolean)
	Parser.Depth += 1

	const Children: { Block }, EndsBlank: boolean = ParseBlocks(Parser, Lines)

	Parser.Depth -= 1

	return Children, EndsBlank
end

const function Fence(_: Parser, Lines: { string }, Index: number): (Block?, number)
	const Indent: string?, Run: string?, Info: string? = MatchFence(Lines[Index]); if not Indent then return nil, Index end

	const Opening: string = Run :: string
	const ClosePattern: string = if string.byte(Opening) == 96 then "^ ? ? ?(`+)[ \t]*$" else "^ ? ? ?(~+)[ \t]*$"
	const IndentPattern: string? = FenceIndentPatterns[#(Indent :: string)]
	const Code: { string } = {}
	local Cursor: number = Index + 1

	while Cursor <= #Lines do
		const Line: string = Lines[Cursor]
		Cursor += 1

		const Close: string? = string.match(Line, ClosePattern)
		if Close and #(Close :: string) >= #Opening then break end

		table.insert(Code, if IndentPattern then string.match(Line, IndentPattern) :: string else Line)
	end

	return {Type = "CodeBlock", Language = string.match(Info :: string, "^%S+"), Body = table.concat(Code, "\n"), Spaced = false}, Cursor
end

const function Heading(_: Parser, Lines: { string }, Index: number): (Block?, number)
	const Level: number?, Title: string? = MatchHeading(Lines[Index]); if not Level then return nil, Index end

	return {Type = "Heading", Level = Level :: number, Source = Title :: string, Spaced = false}, Index + 1
end

const function Rule(_: Parser, Lines: { string }, Index: number): (Block?, number)
	if not IsRule(Lines[Index]) then return nil, Index end

	return {Type = "ThematicBreak", Spaced = false}, Index + 1
end

const function Quote(Parser: Parser, Lines: { string }, Index: number): (Block?, number)
	if not IsQuote(Lines[Index]) then return nil, Index end

	const Inner: { string } = {}
	local Cursor: number = Index

	while Cursor <= #Lines do
		const Line: string = Lines[Cursor]
		const Rest: string? = string.match(Line, "^ ? ? ?> ?(.*)$")

		if Rest then
			table.insert(Inner, Rest :: string)
		elseif IsBlank(Line) or IsBlank(Inner[#Inner]) or StartsBlock(Parser.Dialect, Line) then
			break
		else
			table.insert(Inner, Line)
		end

		Cursor += 1
	end

	const Children: { Block }, EndsBlank: boolean = Nested(Parser, Inner)

	return {Type = "BlockQuote", Children = Children, EndsBlank = EndsBlank, Spaced = false}, Cursor
end

const function CollectItem(Dialect: Dialect, Lines: { string }, Index: number, Item: ListMatch): ({ string }, number)
	const Collected: { string } = if IsBlank(Item.Content) then {} else {Item.Content}
	const Threshold: number = math.min(Item.Width, Item.Indent + 2)
	local Cursor: number = Index + 1
	local Lazy: boolean = #Collected > 0 and not StartsBlock(Dialect, Item.Content)

	while Cursor <= #Lines do
		const Line: string = Lines[Cursor]

		if IsBlank(Line) then
			local Ahead: number = Cursor + 1
			while Ahead <= #Lines and IsBlank(Lines[Ahead]) do Ahead += 1 end

			if Ahead > #Lines or Indentation(Lines[Ahead]) < Threshold then break end

			for _ = Cursor, Ahead - 1 do table.insert(Collected, "") end

			Cursor = Ahead
			Lazy = false

			continue
		end

		const Indent: number = Indentation(Line)

		if Indent >= Threshold then
			const Stripped: string = string.sub(Line, math.min(Indent, Item.Width) + 1)
			table.insert(Collected, Stripped)
			Lazy = not StartsBlock(Dialect, Stripped)
		elseif Lazy and not StartsBlock(Dialect, Line) then
			table.insert(Collected, Line)
		else
			break
		end

		Cursor += 1
	end

	return Collected, Cursor
end

const function TakeCheckbox(Collected: { string }): boolean?
	const First: string = Collected[1] or ""
	const Checkbox: string?, Rest: string? = string.match(First, "^%[([ xX])%][ \t]*(.*)$")
	if not Checkbox or (Rest ~= "" and not string.find(First, "^%[.%][ \t]")) then return nil end

	if Rest == "" then table.remove(Collected, 1) else Collected[1] = Rest :: string end

	return Checkbox ~= " "
end

const function List(Parser: Parser, Lines: { string }, Index: number): (Block?, number)
	const First: ListMatch? = MatchListItem(Lines[Index]); if not First then return nil, Index end

	const Opening: ListMatch = First :: ListMatch
	const Items: { ListItem } = {}
	local Item: ListMatch = Opening
	local Cursor: number = Index

	while true do
		const Collected: { string }, Next: number = CollectItem(Parser.Dialect, Lines, Cursor, Item)
		const Checked: boolean? = TakeCheckbox(Collected)
		const Children: { Block }, EndsBlank: boolean = Nested(Parser, Collected)

		table.insert(Items, {Type = "ListItem", Checked = Checked, Children = Children, EndsBlank = EndsBlank})

		local Ahead: number = Next
		while Ahead <= #Lines and IsBlank(Lines[Ahead]) do Ahead += 1 end

		const Following: ListMatch? = if Ahead <= #Lines then MatchListItem(Lines[Ahead]) else nil
		const Continues: boolean = Following ~= nil
			and (Following :: ListMatch).Ordered == Opening.Ordered
			and (Following :: ListMatch).Delimiter == Opening.Delimiter
			and not IsRule(Lines[Ahead])

		if not Continues then
			return {Type = "List", Ordered = Opening.Ordered, Start = Opening.Number, Delimiter = Opening.Delimiter, Items = Items, Spaced = false}, Next
		end

		Item = Following :: ListMatch
		Cursor = Ahead
	end
end

const function Paragraph(Parser: Parser, Lines: { string }, Index: number): (Block?, number)
	const Collected: { string } = {Trim(Lines[Index])}
	local Cursor: number = Index + 1
	local Level: number? = nil

	while Cursor <= #Lines do
		const Line: string = Lines[Cursor]
		if IsBlank(Line) then break end

		if string.find(Line, "^ ? ? ?=+[ \t]*$") then Level = 1; Cursor += 1; break end
		if string.find(Line, "^ ? ? ?%-%-+[ \t]*$") then Level = 2; Cursor += 1; break end
		if StartsBlock(Parser.Dialect, Line) then break end

		table.insert(Collected, Trim(Line))
		Cursor += 1
	end

	const Source: string = table.concat(Collected, "\n")

	if Level then return {Type = "Heading", Level = Level :: number, Source = Source, Spaced = false}, Cursor end

	return {Type = "Paragraph", Source = Source, Spaced = false}, Cursor
end

const function ParseBlock(Parser: Parser, Lines: { string }, Index: number): (Block, number)
	const Dialect: Dialect = Parser.Dialect
	const Line: string = Lines[Index]
	const Byte: number = string.byte(Line, string.find(Line, "%S") :: number)
	const Rules: { BlockRule } = if Parser.Depth < Config.MAX_DEPTH then Dialect.Routes[Byte] else Dialect.Shallow[Byte]

	for _, Rule: BlockRule in (Rules) do
		const Node: Block?, Next: number = Rule.Parse(Parser, Lines, Index)
		if Node then return Node :: Block, Next end
	end

	const Node: Block?, Next: number = Paragraph(Parser, Lines, Index)

	return Node :: Block, Next
end

ParseBlocks = function(Parser: Parser, Lines: { string }): ({ Block }, boolean)
	const Children: { Block } = {}
	local Spaced: boolean = false
	local Index: number = 1

	while Index <= #Lines do
		if IsBlank(Lines[Index]) then Spaced = true; Index += 1; continue end

		const Node: Block, Next: number = ParseBlock(Parser, Lines, Index)

		if Spaced then (Node :: any).Spaced = true end

		Spaced = false
		table.insert(Children, Node)
		Index = Next
	end

	return Children, Spaced
end

const Rules: { BlockRule } = {
	{Name = "Fence", Leads = "`~", Interrupts = true, Nested = false, Test = MatchFence, Parse = Fence};
	{Name = "Heading", Leads = "#", Interrupts = true, Nested = false, Test = MatchHeading, Parse = Heading};
	{Name = "Rule", Leads = "*%-_", Interrupts = true, Nested = false, Test = IsRule, Parse = Rule};
	{Name = "Quote", Leads = ">", Interrupts = true, Nested = true, Test = IsQuote, Parse = Quote};
	{Name = "List", Leads = "%-+*%d", Interrupts = true, Nested = true, Test = MatchListItem, Parse = List};
	{Name = "Paragraph", Interrupts = false, Nested = false, Parse = Paragraph};
}

return {
	Rules = Rules;
	Parse = ParseBlocks;
}
