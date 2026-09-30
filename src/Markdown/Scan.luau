--!strict
--!native
--!optimize 2

const MarkdownTypes = require("../Types/Markdown")

const Styles = require("../Utility/Styles")
const Config = require("../Config").Markdown
const Characters = require("../Utility/Characters")

type ListMatch = MarkdownTypes.ListMatch

const HASH_BYTE: number = Characters.HASH
const SPACE_BYTE: number = Characters.SPACE
const TAB_BYTE: number = Characters.TAB
const TAB_SPACES: string = string.rep(" ", Config.TAB_WIDTH)

const Trim: (Text: string) -> string = Styles.Trim

const RulePatterns: { [string]: string } = {
	["*"] = "^ ? ? ?%*[ \t]*%*[ \t]*%*[%* \t]*$";
	["-"] = "^ ? ? ?%-[ \t]*%-[ \t]*%-[%- \t]*$";
	["_"] = "^ ? ? ?_[ \t]*_[ \t]*_[_ \t]*$";
}

const Whitespace: { [number]: boolean } = Characters.Whitespace

const Punctuation: { [number]: boolean } = {}
for Byte = 33, 126 do
	if string.find(string.char(Byte), "%p") then Punctuation[Byte] = true end
end

const function IsBlank(Line: string): boolean
	return string.find(Line, "%S") == nil
end

const function Indentation(Line: string): number
	return (select(2, string.find(Line, "^ *")) :: number)
end

const function ExpandTabs(Lead: string): string
	return (string.gsub(Lead, "\t", TAB_SPACES))
end

const function SplitLines(Source: string): { string }
	const Lines: { string } = string.split((string.gsub(Source, "\r\n?", "\n")), "\n")
	local Common: number = math.huge

	for Index: number, Line: string in (Lines) do
		const Expanded: string = if string.find(Line, "\t", 1, true) then (string.gsub(Line, "^[ \t]+", ExpandTabs)) else Line
		Lines[Index] = Expanded

		const First: number? = string.find(Expanded, "%S")
		if First and (First :: number) - 1 < Common then Common = (First :: number) - 1 end
	end

	if Common == 0 or Common == math.huge then return Lines end

	for Index: number, Line: string in (Lines) do Lines[Index] = string.sub(Line, Common + 1) end

	return Lines
end

const function MatchFence(Line: string): (string?, string?, string?)
	const Indent: string?, Run: string?, After: number? = string.match(Line, "^( ? ? ?)(```+)[ \t]*()")

	if Indent then
		if string.find(Line, "`", After :: number, true) then return nil, nil, nil end

		return Indent, Run, string.sub(Line, After :: number)
	end

	return string.match(Line, "^( ? ? ?)(~~~+)[ \t]*(.*)$")
end

const function StripClosing(Title: string): string
	local Stop: number = #Title
	while Stop > 0 and string.byte(Title, Stop) == HASH_BYTE do Stop -= 1 end

	local Keep: number = Stop
	while Keep > 0 and (string.byte(Title, Keep) == SPACE_BYTE or string.byte(Title, Keep) == TAB_BYTE) do Keep -= 1 end

	return if Stop < #Title and Keep < Stop then string.sub(Title, 1, Keep) else Title
end

const function MatchHeading(Line: string): (number?, string?)
	const Hashes: string?, Rest: string? = string.match(Line, "^ ? ? ?(#+)(.*)$")
	if not Hashes or #(Hashes :: string) > Config.MAX_HEADING_LEVEL then return nil, nil end
	if Rest ~= "" and not string.find(Rest :: string, "^[ \t]") then return nil, nil end

	const Title: string = Trim(Rest :: string)
	if string.find(Title, "^#+$") then return #(Hashes :: string), "" end

	return #(Hashes :: string), StripClosing(Title)
end

const function IsRule(Line: string): boolean
	const Char: string? = string.match(Line, "^ ? ? ?([%*%-_])"); if not Char then return false end

	return string.find(Line, RulePatterns[Char :: string]) ~= nil
end

const function IsQuote(Line: string): boolean
	return string.find(Line, "^ ? ? ?>") ~= nil
end

const function MatchListItem(Line: string): ListMatch?
	local Indent: string?, Marker: string?, Spaces: string?, Content: string? = string.match(Line, "^( *)([%-%+%*])( *)(.*)$")
	local Number: string? = nil

	if not Indent then
		Indent, Number, Marker, Spaces, Content = string.match(Line, "^( *)(%d+)([%.%)])( *)(.*)$")
		if not Indent or #(Number :: string) > Config.MAX_ORDERED_DIGITS then return nil end
	end

	const Blank: boolean = Content == ""
	const Gap: number = #(Spaces :: string)
	if Gap == 0 and not Blank then return nil end

	const MarkerWidth: number = #(Marker :: string) + (if Number then #(Number :: string) else 0)

	return {
		Indent = #(Indent :: string);
		Ordered = Number ~= nil;
		Delimiter = Marker :: string;
		Number = if Number then tonumber(Number) :: number else 1;
		Width = #(Indent :: string) + MarkerWidth + (if Blank or Gap > 4 then 1 else Gap);
		Content = Content :: string;
	}
end

return {
	Whitespace = Whitespace;
	Punctuation = Punctuation;
	Trim = Trim;
	IsBlank = IsBlank;
	Indentation = Indentation;
	SplitLines = SplitLines;
	MatchFence = MatchFence;
	MatchHeading = MatchHeading;
	IsRule = IsRule;
	IsQuote = IsQuote;
	MatchListItem = MatchListItem;
}
