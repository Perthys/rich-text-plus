--!strict
--!native
--!optimize 2

const LAYOUT: number = 1
const SCALE: number = 2
const FLATTEN: number = 3
const PARSE: number = 4
const TEXT: number = 5

const function Merge(Current: number, Incoming: number): number
	const High: number = math.max(Current, Incoming)
	if High ~= TEXT then return High end

	const Low: number = math.min(Current, Incoming)

	return if Low == FLATTEN or Low == PARSE then PARSE else TEXT
end

const function Join(Current: number?, Incoming: number): number
	return if Current then Merge(Current :: number, Incoming) else Incoming
end

return {
	Layout = LAYOUT;
	Scale = SCALE;
	Flatten = FLATTEN;
	Parse = PARSE;
	Text = TEXT;
	Merge = Merge;
	Join = Join;
}
