--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Styles = require("../../Utility/Styles")
const Glyphs = require("../Glyphs")
const Profiler = require("../../Utility/Profiler")
const Characters = require("../../Utility/Characters")
const Metrics = require("./Metrics")

type Sized = { [string]: Vector2 }
type Bucket = { [number]: Sized }
type Job = () -> ()

type Face = {
	Font: Font;
	Bucket: Bucket;
	Older: Bucket;
	Tables: { [number]: Types.GlyphTable };
	Blocks: { [number]: boolean };
	Ready: boolean;
	Trusted: boolean;
	Broken: boolean;
	Checks: number;
}

const PreloadBudget: number = Config.Measure.PRELOAD_BUDGET
const BlockSize: number = Config.Measure.BLOCK_SIZE
const WidePattern: string = Characters.WIDE_PATTERN
const White: Color3 = Color3.new(1, 1, 1)

const Find = string.find

const FaceOf = Metrics.FaceOf
const Lookup = Metrics.Lookup
const TableFor = Metrics.TableFor
const Query = Metrics.Query
const Bounds = Metrics.Bounds
const Scaled = Metrics.Scaled

const function Gather(Jobs: { Job }): ()
	local Remaining: number = #Jobs
	if Remaining == 0 then return end

	const Waiter: thread = coroutine.running()
	local Waiting: boolean = false

	for _, Work: Job in (Jobs) do
		task.spawn(function()
			pcall(Work)
			Remaining -= 1

			if Remaining == 0 and Waiting then task.spawn(Waiter) end
		end)
	end

	if Remaining == 0 then return end

	Waiting = true

	const Held: { string }? = Profiler.Suspend()
	coroutine.yield()
	Profiler.Resume(Held)
end

const function Unloaded(Found: Face, Text: string): number?
	if not Found.Ready then return 0 end
	if not utf8.len(Text) then return nil end

	for _, Code: number in utf8.codes(Text) do
		if Code >= 0x80 and not Found.Blocks[Code // BlockSize] then return Code // BlockSize end
	end

	return nil
end

const function Warm(Tokens: { Types.Token }, From: number, To: number, Factor: number): ()
	local Jobs: { Job }? = nil
	local Claimed: { [Face]: { [number]: boolean } }? = nil
	local Current: Types.Style? = nil
	local Found: Face? = nil
	local Size: number = 0

	for Index = From, To do
		const Token: Types.Token = Tokens[Index]
		const Style: Types.Style? = Token.Style
		const Text: string? = Token.Text
		if not (Style and Text) then continue end

		if Style ~= Current then
			Current = Style
			Found = FaceOf(Style :: Types.Style)
			Size = Scaled((Style :: Types.Style).Size, Factor)
		end

		if Lookup(Found :: Face, Size, Text :: string) then continue end

		const Target: Face = Found :: Face
		if Target.Ready and not Find(Text :: string, WidePattern) then continue end

		const Block: number? = Unloaded(Target, Text :: string); if not Block then continue end

		const Owned: { [Face]: { [number]: boolean } } = Claimed or {}
		Claimed = Owned

		const Blocks: { [number]: boolean } = Owned[Target] or {}
		Owned[Target] = Blocks
		if Blocks[Block :: number] then continue end

		Blocks[Block :: number] = true

		const Pending: { Job } = Jobs or {}
		Jobs = Pending

		const Measured: Types.Style = Style :: Types.Style
		const Word: string = Text :: string
		const Pixels: number = Size

		table.insert(Pending, function() Bounds(Measured, Pixels, Word, false) end)
	end

	if Jobs and #(Jobs :: { Job }) > 1 then Gather(Jobs :: { Job }) end
end

const function Variant(Base: Font, Bold: boolean, Italic: boolean): Types.Style
	return {
		Bold = Bold;
		Italic = Italic or Base.Style == Enum.FontStyle.Italic;
		Underline = false;
		Strike = false;
		Color = White;
		Size = 0;
		Family = Base.Family;
		Weight = Base.Weight;
		Transparency = 0;
	}
end

const function Preload(Fonts: { Font }, Sizes: { number }): ()
	const Targets: { Face } = {}
	const Seen: { [Face]: boolean } = {}
	const Pixels: { number } = {}

	for _, Size: number in (Sizes) do table.insert(Pixels, math.clamp(math.floor(Size + 0.5), 1, Styles.MaximumTextSize)) end
	if #Pixels == 0 then return end

	for _, Base: Font in (Fonts) do
		for Index = 0, 3 do
			const Found: Face = FaceOf(Variant(Base, Index >= 2, Index % 2 == 1))
			if Seen[Found] then continue end

			Seen[Found] = true
			table.insert(Targets, Found)
		end
	end

	const Jobs: { Job } = {}

	for _, Found: Face in (Targets) do
		if not Found.Ready then table.insert(Jobs, function() Query(Found, Pixels[1], " ", false) end) end
	end

	Gather(Jobs)

	local Started: number = os.clock()

	for _, Found: Face in (Targets) do
		if not (Found.Ready and Found.Trusted) then continue end

		for _, Size: number in (Pixels) do
			const Target: Types.GlyphTable = TableFor(Found, Size)

			for _, Piece: string in (Glyphs.Warm) do
				if not Glyphs.Needs(Target, Piece) then continue end

				const Result: Vector2, Exact: boolean = Query(Found, Size, Piece, false)
				if Exact then Glyphs.Record(Target, Piece, Result.X, Result.Y) end

				if os.clock() - Started < PreloadBudget then continue end

				task.wait()
				Started = os.clock()
			end
		end
	end
end

const function TableOf(Style: Types.Style, Size: number): Types.GlyphTable?
	return FaceOf(Style).Tables[Size]
end

return {
	Gather = Gather;
	Warm = Warm;
	Preload = Preload;
	TableOf = TableOf;
}
