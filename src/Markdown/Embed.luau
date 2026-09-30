--!strict
--!native
--!optimize 2

const XML = require("../../XML")
const Scan = require("./Scan")

const Escape: (Text: string) -> string = XML.Escape
const Whitespace: { [number]: boolean } = Scan.Whitespace

const OPENER_PATTERN: string = "<[Mm][Dd]"
const GREATER_THAN: number = 62
const SLASH: number = 47

const function FindOpener(Lower: string, From: number): (number?, number?)
	local Cursor: number = From

	while true do
		const Start: number? = string.find(Lower, "<md", Cursor, true); if not Start then return nil, nil end

		const Next: number? = string.byte(Lower, (Start :: number) + 3)

		if Next == GREATER_THAN then return Start, (Start :: number) + 3 end

		if Next and Whitespace[Next :: number] then
			const Stop: number? = string.find(Lower, "[<>]", (Start :: number) + 4)
			const Valid: boolean = Stop ~= nil and string.byte(Lower, Stop :: number) == GREATER_THAN and string.byte(Lower, (Stop :: number) - 1) ~= SLASH
			if Valid then return Start, Stop end
		end

		Cursor = (Start :: number) + 3
	end
end

const function Preprocess(Text: string): string
	if not string.find(Text, OPENER_PATTERN) then return Text end

	const Lower: string = string.lower(Text)
	const Parts: { string } = {}
	local Count: number = 0
	local Position: number = 1
	local Closable: boolean = true

	while true do
		const Open: number?, OpenEnd: number? = FindOpener(Lower, Position); if not Open then break end

		local Close: number?, CloseEnd: number? = nil, nil
		if Closable then Close, CloseEnd = string.find(Lower, "</md%s*>", (OpenEnd :: number) + 1) end

		Count += 1; Parts[Count] = string.sub(Text, Position, (Open :: number) - 1)

		if Close then
			Count += 1; Parts[Count] = "<md" .. string.sub(Text, (Open :: number) + 3, OpenEnd :: number)
			Count += 1; Parts[Count] = Escape(string.sub(Text, (OpenEnd :: number) + 1, (Close :: number) - 1))
			Count += 1; Parts[Count] = "</md>"
			Position = (CloseEnd :: number) + 1
		else
			Closable = false
			Count += 1; Parts[Count] = Escape(string.sub(Text, Open :: number, OpenEnd :: number))
			Position = (OpenEnd :: number) + 1
		end
	end

	Count += 1; Parts[Count] = string.sub(Text, Position)

	return table.concat(Parts, "", 1, Count)
end

return {
	Pattern = OPENER_PATTERN;
	Preprocess = Preprocess;
}
