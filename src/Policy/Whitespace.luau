--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Characters = require("../Utility/Characters")

type Whitespace = Types.Whitespace

const Names: { string } = table.freeze({
	"Preserve";
	"Markup";
})

const Known: { [string]: boolean } = {}
for _, Name: string in (Names) do Known[Name] = true end
table.freeze(Known)

const Default: Whitespace = "Preserve"
const Lines: { string } = {}

const Byte = string.byte
const Find = string.find
const Sub = string.sub
const Blank: { [number]: boolean } = Characters.Separators

const function Check(Mode: unknown): ()
	if type(Mode) ~= "string" or not Known[Mode] then error(`Unknown RichTextPlus whitespace mode "{tostring(Mode)}": use Preserve or Markup`, 3) end
end

const function Resolve(Provided: Whitespace?): Whitespace
	if Provided == nil then return Default end

	Check(Provided)

	return Provided :: Whitespace
end

const function Collapse(Text: string): string
	if not Find(Text, "\n", 1, true) then return Text end

	const Kept: { string } = Lines
	table.clear(Kept)

	local Start: number = 1
	local Leading: boolean = false

	while true do
		const Newline: number? = Find(Text, "\n", Start, true)

		local From: number = Start
		local To: number = if Newline then (Newline :: number) - 1 else #Text

		if Leading then
			while From <= To and Blank[Byte(Text, From)] do From += 1 end
		end

		if Newline then
			while To >= From and Blank[Byte(Text, To)] do To -= 1 end
		end

		if To >= From then table.insert(Kept, Sub(Text, From, To)) end
		if not Newline then break end

		Start = (Newline :: number) + 1
		Leading = true
	end

	const Result: string = table.concat(Kept, " ")
	table.clear(Kept)

	return Result
end

return {
	Names = Names;
	Default = Default;
	Check = Check;
	Resolve = Resolve;
	Collapse = Collapse;
}
