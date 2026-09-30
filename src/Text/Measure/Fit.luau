--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Unicode = require("../Unicode")
const Lifetime = require("../../Utility/Lifetime")
const Metrics = require("./Metrics")
const Preload = require("./Preload")


type Sheet = {
	Results: { Vector2 };
	Hyphens: { [number]: number };
	Spaces: { [Types.Style]: number };
	Busy: boolean;
}

type Pieces = {
	List: { Types.Token };
	Busy: boolean;
}

const MinimumAdvance: number = Config.Measure.MINIMUM_ADVANCE
const HyphenText: string = "-"

const BreakAfter: { [number]: boolean } = {
	[0xA0] = true;
	[0x2D] = true;
	[0x2F] = true;
	[0x5F] = true;
	[0x2E] = true;
	[0x2C] = true;
}

const CaseTags: { [string]: string } = Metrics.CaseTags

const Sheets = Lifetime.Own("Measure.Sheets", {} :: { [Types.Fields]: Sheet })
const Splits = Lifetime.Own("Measure.Splits", {} :: { [Types.Fields]: Pieces })

const Guess = Metrics.Guess
const Bounds = Metrics.Bounds
const WidthOf = Metrics.WidthOf
const Scaled = Metrics.Scaled
const Pad = Metrics.Pad
const Warm = Preload.Warm

const function Fits(Style: Types.Style, Size: number, Text: string, Offsets: { number }, From: number, Stop: number, Limit: number): boolean
	return WidthOf(Style, Size, string.sub(Text, Offsets[From], Offsets[Stop + 1] - 1)).X <= Limit
end

const function Fit(Style: Types.Style, Size: number, Text: string, Offsets: { number }, From: number, Limit: number, Valid: boolean, Per: number): number
	const Last: number = #Offsets - 1
	const Guess: number = math.clamp(From + math.floor(Limit / Per) - 1, From, Last)

	local Low: number = From
	local High: number = Last
	local Step: number = 1

	if Guess > From and not Fits(Style, Size, Text, Offsets, From, Guess, Limit) then
		High = Guess - 1

		while Low < High do
			const Probe: number = math.max(High - Step, Low + 1)
			if Fits(Style, Size, Text, Offsets, From, Probe, Limit) then Low = Probe; break end

			High = Probe - 1
			Step *= 2
		end
	else
		Low = Guess

		while Low < High do
			const Probe: number = math.min(Low + Step, High)
			if not Fits(Style, Size, Text, Offsets, From, Probe, Limit) then High = Probe - 1; break end

			Low = Probe
			Step *= 2
		end
	end

	while Low < High do
		const Middle: number = (Low + High + 1) // 2

		if Fits(Style, Size, Text, Offsets, From, Middle, Limit) then Low = Middle else High = Middle - 1 end
	end

	if Low >= Last then return Low end

	for Index = Low, From + 1, -1 do
		const Code: number = if Valid then Unicode.Codepoint(Text, Offsets[Index]) else string.byte(Text, Offsets[Index])
		if BreakAfter[Code] then return Index end
	end

	return Low
end

const function Chop(Token: Types.Token, Style: Types.Style, Size: number, Limit: number, Into: { Types.Token }): ()
	const Text: string = Token.Text :: string
	const Offsets: { number } = Unicode.Starts(Text)
	const Count: number = #Offsets - 1
	const Valid: boolean = Unicode.Length(Text) ~= nil

	if Count <= 1 then table.insert(Into, Token); return end

	const Per: number = math.max(Token.Width / Count, MinimumAdvance)

	local From: number = 1

	while From <= Count do
		const Last: number = Fit(Style, Size, Text, Offsets, From, Limit, Valid, Per)
		const Piece: string = string.sub(Text, Offsets[From], Offsets[Last + 1] - 1)
		const Result: Vector2 = WidthOf(Style, Size, Piece)

		table.insert(Into, {
			Kind = Token.Kind;
			Text = Piece;
			Style = Style;
			Glue = if From == 1 then Token.Glue else nil;
			Hyphen = if Last == Count then Token.Hyphen else nil;
			Level = Token.Level;
			Rtl = Token.Rtl;
			Width = Result.X;
			Height = Result.Y;
			SpaceBefore = Token.SpaceBefore and From == 1;
			X = 0;
		})

		From = Last + 1
	end
end

const function Split(State: Types.Fields, MaxWidth: number): { Types.Token }?
	const Tokens: { Types.Token } = State.Document.Tokens
	if MaxWidth == math.huge then return Tokens end

	const Factor: number = State.Scale.Measured

	local Needed: boolean = false

	for _, Token: Types.Token in (Tokens) do
		const Style: Types.Style? = Token.Style
		if Style and Token.Text and Token.Width + Pad(Style :: Types.Style, Factor) * 2 > MaxWidth then Needed = true; break end
	end

	if not Needed then return Tokens end

	const Generation: number = State.Generation.Refresh
	const Existing: Pieces? = Splits[State]
	const Shared: Pieces? = if Existing and not Existing.Busy then Existing else nil
	const Rebuilt: { Types.Token } = if Shared then Shared.List else table.create(#Tokens)

	if Shared then
		table.clear(Rebuilt)
		Shared.Busy = true
	elseif not Existing then
		Splits[State] = {List = Rebuilt, Busy = true}
	end

	for _, Token: Types.Token in (Tokens) do
		const Style: Types.Style? = Token.Style
		const Limit: number = if Style then MaxWidth - Pad(Style :: Types.Style, Factor) * 2 else MaxWidth

		if not (Style and Token.Text and Token.Width > Limit) then table.insert(Rebuilt, Token); continue end

		Chop(Token, Style :: Types.Style, Scaled((Style :: Types.Style).Size, Factor), math.max(Limit, 1), Rebuilt)
	end

	const Owned: Pieces? = Splits[State]
	if Owned and Owned.List == Rebuilt then Owned.Busy = false end

	if State.Generation.Refresh ~= Generation or State.Destroyed then return nil end

	return Rebuilt
end

const function Fill(State: Types.Fields, Tokens: { Types.Token }, From: number, To: number): boolean
	const Generation: number = State.Generation.Refresh
	const Factor: number = State.Scale.Measured
	const Spaces: { [Types.Style]: number } = State.Document.SpaceWidths

	Warm(Tokens, From, To, Factor)
	if State.Generation.Refresh ~= Generation or State.Destroyed then return false end

	for Index = From, To do
		const Token: Types.Token = Tokens[Index]
		const Style: Types.Style? = Token.Style
		const Text: string? = Token.Text
		if not (Style and Text) then continue end

		const Size: number = Scaled((Style :: Types.Style).Size, Factor)
		const Result: Vector2 = WidthOf(Style :: Types.Style, Size, Text :: string)

		Token.Width = Result.X
		Token.Height = Result.Y

		if Token.Hyphen then Token.Hyphen = Bounds(Style :: Types.Style, Size, HyphenText, false).X end
		if not Spaces[Style :: Types.Style] then Spaces[Style :: Types.Style] = Bounds(Style :: Types.Style, Size, " ", false).X end
	end

	return State.Generation.Refresh == Generation and not State.Destroyed
end

const function Claim(State: Types.Fields): Sheet
	const Existing: Sheet? = Sheets[State]
	if Existing and not Existing.Busy then return Existing end

	const Created: Sheet = {Results = {}, Hyphens = {}, Spaces = {}, Busy = false}
	if not Existing then Sheets[State] = Created end

	return Created
end

const function Collect(State: Types.Fields, Factor: number, Sheet: Sheet): boolean
	const Generation: number = State.Generation.Refresh
	const Tokens: { Types.Token } = State.Document.Tokens
	const Results: { Vector2 } = Sheet.Results
	const Hyphens: { [number]: number } = Sheet.Hyphens
	const Spaces: { [Types.Style]: number } = Sheet.Spaces

	table.clear(Results)
	table.clear(Hyphens)
	table.clear(Spaces)

	Warm(Tokens, 1, #Tokens, Factor)
	if State.Generation.Refresh ~= Generation or State.Destroyed then return false end

	local Current: Types.Style? = nil
	local Size: number = 0
	local Case: string? = nil

	for Index: number, Token: Types.Token in (Tokens) do
		const Style: Types.Style? = Token.Style
		const Text: string? = Token.Text
		if not (Style and Text) then continue end

		if Style ~= Current then
			const Named: string? = (Style :: Types.Style).Case

			Current = Style
			Size = Scaled((Style :: Types.Style).Size, Factor)
			Case = if Named then CaseTags[Named :: string] else nil

			if not Spaces[Style :: Types.Style] then Spaces[Style :: Types.Style] = Bounds(Style :: Types.Style, Size, " ", false).X end
		end

		Results[Index] = if Case then WidthOf(Style :: Types.Style, Size, Text :: string) else Bounds(Style :: Types.Style, Size, Text :: string, false)
		if Token.Hyphen then Hyphens[Index] = Bounds(Style :: Types.Style, Size, HyphenText, false).X end
	end

	if State.Generation.Refresh ~= Generation or State.Destroyed then return false end

	const ObjectSizes: { [GuiObject]: Vector2 } = State.Objects.Sizes

	State.Generation.Measure += 1

	for Index: number, Token: Types.Token in (Tokens) do
		const Result: Vector2? = Results[Index]

		if Result then
			Token.Width = (Result :: Vector2).X
			Token.Height = (Result :: Vector2).Y
			if Token.Hyphen then Token.Hyphen = Hyphens[Index] end

			continue
		end

		const Object: GuiObject? = Token.Object
		if not Object then continue end

		const Base: Vector2 = ObjectSizes[Object :: GuiObject] or Vector2.new(Token.Width, Token.Height)
		ObjectSizes[Object :: GuiObject] = Base

		Token.Width = math.floor(Base.X * Factor + 0.5)
		Token.Height = math.floor(Base.Y * Factor + 0.5)
	end

	Sheet.Spaces = State.Document.SpaceWidths
	State.Document.SpaceWidths = Spaces
	State.Scale.Measured = Factor

	table.clear(Results)

	return true
end

const function Run(State: Types.Fields, Factor: number): boolean
	const Sheet: Sheet = Claim(State)

	Sheet.Busy = true

	const Measured: boolean = Collect(State, Factor, Sheet)

	Sheet.Busy = false

	return Measured
end

return {
	Split = Split;
	Fill = Fill;
	Run = Run;
}
