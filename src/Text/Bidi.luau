--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Unicode = require("./Unicode")

type Token = Types.Token

const Neutral: number = Unicode.Neutral
const Left: number = Unicode.Left
const Right: number = Unicode.Right
const Digit: number = Unicode.Digit

const Terminals: { [number]: boolean } = {
	[0x21] = true;
	[0x2C] = true;
	[0x2E] = true;
	[0x3A] = true;
	[0x3B] = true;
	[0x3F] = true;
}

const function Classify(Token: Token): number
	const Text: string? = Token.Text

	return if Text then Unicode.Strength(Text :: string) else Neutral
end

const function BaseLevel(Tokens: { Token }, From: number, Classes: { number }): number
	for Index = 1, #Classes do
		const Style: Types.Style? = Tokens[From + Index - 1].Style
		const Direction: string? = if Style then (Style :: Types.Style).Direction else nil

		if Direction then return if Direction == "Rtl" then 1 else 0 end
		if Style then break end
	end

	for _, Class: number in (Classes) do
		if Class == Left then return 0 end
		if Class == Right then return 1 end
	end

	return 0
end

const function Resolve(Classes: { number }, Edge: number): ()
	local Strong: number = Edge

	for Index: number, Class: number in (Classes) do
		if Class == Left or Class == Right then Strong = Class elseif Class == Digit and Strong == Left then Classes[Index] = Left end
	end

	const Count: number = #Classes

	local Index: number = 1

	while Index <= Count do
		if Classes[Index] ~= Neutral then Index += 1; continue end

		local Stop: number = Index
		while Stop < Count and Classes[Stop + 1] == Neutral do Stop += 1 end

		const Before: number = if Index > 1 then Classes[Index - 1] else Edge
		const After: number = if Stop < Count then Classes[Stop + 1] else Edge
		const Resolved: number = if (Before == Left) == (After == Left) then (if Before == Left then Left else Right) else Edge

		for Position = Index, Stop do Classes[Position] = Resolved end

		Index = Stop + 1
	end
end

const function Detach(Token: Token): Token?
	const Text: string = Token.Text :: string

	local Cut: number = #Text
	while Cut > 0 and Terminals[string.byte(Text, Cut)] do Cut -= 1 end

	if Cut == 0 or Cut == #Text then return nil end

	const Detached: Token = {
		Kind = Token.Kind;
		Text = string.sub(Text, Cut + 1);
		Style = Token.Style;
		Glue = true;
		Hyphen = Token.Hyphen;
		Width = 0;
		Height = 0;
		SpaceBefore = false;
		X = 0;
	}

	Token.Text = string.sub(Text, 1, Cut)
	Token.Hyphen = nil

	return Detached
end

const function Paragraph(Tokens: { Token }, From: number, To: number, Into: { Token }): ()
	const Classes: { number } = table.create(To - From + 1)

	local Mixed: boolean = false

	for Index = From, To do
		const Class: number = Classify(Tokens[Index])
		if Class == Right then Mixed = true end

		table.insert(Classes, Class)
	end

	const Base: number = BaseLevel(Tokens, From, Classes)
	if Base == 0 and not Mixed then table.move(Tokens, From, To, #Into + 1, Into); return end

	const Order: { Token } = table.create(To - From + 1)
	const Kinds: { number } = table.create(To - From + 1)

	for Index: number, Class: number in (Classes) do
		const Token: Token = Tokens[From + Index - 1]
		const Detached: Token? = if Class ~= Neutral then Detach(Token) else nil

		table.insert(Order, Token)
		table.insert(Kinds, Class)

		if Detached then
			table.insert(Order, Detached :: Token)
			table.insert(Kinds, Neutral)
		end
	end

	Resolve(Kinds, if Base == 1 then Right else Left)

	for Index: number, Token: Token in (Order) do
		const Class: number = Kinds[Index]

		Token.Level = if Class == Right then 1 elseif Class == Left then Base * 2 else 2
		Token.Rtl = if Base == 1 then true else nil

		table.insert(Into, Token)
	end
end

const function Apply(Tokens: { Token }): { Token }
	const Result: { Token } = table.create(#Tokens)

	local From: number = 1

	for Index = 1, #Tokens + 1 do
		const Token: Token? = Tokens[Index]
		if Token and not (Token.Kind == "Break" or Token.Block) then continue end

		if Index > From then Paragraph(Tokens, From, Index - 1, Result) end
		if Token then table.insert(Result, Token) end

		From = Index + 1
	end

	return Result
end

const function Extent(Token: Token, Last: Token): number
	return Token.Width + (if Token == Last then Token.Hyphen or 0 else 0)
end

const function Arrange(Items: { Token }): ()
	const Count: number = #Items
	const Last: Token = Items[Count]

	local Highest: number = 0
	for _, Token: Token in (Items) do Highest = math.max(Highest, Token.Level or 0) end

	for Target = Highest, 1, -1 do
		local Index: number = 1

		while Index <= Count do
			if (Items[Index].Level or 0) < Target then Index += 1; continue end

			local Stop: number = Index
			while Stop < Count and (Items[Stop + 1].Level or 0) >= Target do Stop += 1 end

			local Low: number = math.huge
			local High: number = -math.huge

			for Position = Index, Stop do
				const Token: Token = Items[Position]

				Low = math.min(Low, Token.X)
				High = math.max(High, Token.X + Extent(Token, Last))
			end

			for Position = Index, Stop do
				const Token: Token = Items[Position]

				Token.X = Low + High - Token.X - Extent(Token, Last)
			end

			Index = Stop + 1
		end
	end
end

return {
	Apply = Apply;
	Arrange = Arrange;
}
