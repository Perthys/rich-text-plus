--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Trove = require("../../../Trove")
const Types = require("../../Types")
const Attributes = require("../../Utility/Attributes")
const Styles = require("../../Utility/Styles")
const Characters = require("../../Utility/Characters")
const Unicode = require("../../Text/Unicode")
const Whitespace = require("../../Policy/Whitespace")

type XMLNode = Types.Node
type Style = Types.Style
type Joint = Types.Joint
type Context = Types.FlattenContext
type Emit = Types.EmitData

const NewlineByte: number = Characters.NEWLINE
const RightStart: number = 0x590
const RecycleLimit: number = Config.Flatten.RECYCLE_LIMIT
const SpaceFlag: number = 1
const ExitSpaceFlag: number = 2
const HookedFlag: number = 4
const JointShift: number = 8
const ExitJointShift: number = 32
const JointCodes: { [string]: number } = {["Break"] = 1, ["Glue"] = 2, ["Hyphen"] = 3}
const JointNames: { Joint } = {"Break", "Glue", "Hyphen"}

const Recycled: { Types.Token } = {}
const Pieces: { string } = {}

const Byte = string.byte
const Sub = string.sub
const Unescape = Styles.Unescape
const Sanitize = Styles.Sanitize
const LowerName = Styles.LowerName
const Separators: { [number]: boolean } = Characters.Separators
const Collapse = Whitespace.Collapse

const function Pack(Space: boolean, ExitSpace: boolean, Hooked: boolean, Joint: Joint?, ExitJoint: Joint?): number
	return (if Space then SpaceFlag else 0)
		+ (if ExitSpace then ExitSpaceFlag else 0)
		+ (if Hooked then HookedFlag else 0)
		+ (if Joint then JointCodes[Joint :: string] else 0) * JointShift
		+ (if ExitJoint then JointCodes[ExitJoint :: string] else 0) * ExitJointShift
end

const function Unpack(Flags: number): (boolean, boolean, boolean, Joint?, Joint?)
	return bit32.btest(Flags, SpaceFlag),
		bit32.btest(Flags, ExitSpaceFlag),
		bit32.btest(Flags, HookedFlag),
		JointNames[(Flags // JointShift) % 4],
		JointNames[(Flags // ExitJointShift) % 4]
end

const function Settle(Emit: Emit, Last: number?): ()
	Emit.Space = false
	Emit.Code = Last
	Emit.Joint = nil
end

const function NewToken(Emit: Emit, Kind: string, Text: string?, Style: Style?, SpaceBefore: boolean): Types.Token
	const Reused: Types.Token? = if Emit.Recycle then table.remove(Recycled) else nil
	if not Reused then return {Kind = Kind, Text = Text, Style = Style, Width = 0, Height = 0, SpaceBefore = SpaceBefore, X = 0, Offset = Emit.Offset} end

	const Token: Types.Token = Reused :: Types.Token
	Token.Kind = Kind
	Token.Text = Text
	Token.Style = Style
	Token.SpaceBefore = SpaceBefore
	Token.Offset = Emit.Offset

	return Token
end

const function Recycle(Token: Types.Token): ()
	if #Recycled >= RecycleLimit then return end

	Token.Text = nil
	Token.Style = nil
	Token.Object = nil
	Token.Block = nil
	Token.Glue = nil
	Token.Hyphen = nil
	Token.Level = nil
	Token.Rtl = nil
	Token.Width = 0
	Token.Height = 0
	Token.X = 0

	table.insert(Recycled, Token)
end

const function AddBreak(Emit: Emit): ()
	table.insert(Emit.Tokens, NewToken(Emit, "Break", nil, nil, false))
	Settle(Emit, nil)
end

const function Joined(Emit: Emit, Previous: Types.Token, First: number): boolean
	if Previous.Kind == "Break" then return false end

	const Joint: Joint? = Emit.Joint
	if Joint then return Joint == "Glue" end

	return Unicode.Joins(Emit.Code, First)
end

const function AddWord(_Context: Context, Emit: Emit, Word: string, Style: Style, First: number, Last: number): ()
	const Tokens: { Types.Token } = Emit.Tokens
	const Previous: Types.Token? = Tokens[#Tokens] or Emit.Anchor
	const SpaceBefore: boolean = Emit.Space and Previous ~= nil
	const Token: Types.Token = NewToken(Emit, "Word", Word, Style, SpaceBefore)

	if not SpaceBefore and Previous then
		if Joined(Emit, Previous, First) then Token.Glue = true end
		if Emit.Joint == "Hyphen" and Previous.Kind == "Word" then Previous.Hyphen = 0 end
	end

	if Style.Direction then Emit.Bidi = true end

	table.insert(Tokens, Token)
	Settle(Emit, Last)
end

const function AddPiece(Context: Context, Emit: Emit, Parts: { string }, Style: Style, Joint: Joint?, First: number, Last: number): ()
	Emit.Joint = Joint
	AddWord(Context, Emit, table.concat(Parts), Style, First, Last)
	table.clear(Parts)
end

const function AddScript(Context: Context, Emit: Emit, Word: string, Style: Style): ()
	if not Unicode.Length(Word) then AddWord(Context, Emit, Word, Style, Byte(Word, 1), Byte(Word, #Word)); return end

	const Parts: { string } = Pieces
	table.clear(Parts)

	local Joint: Joint? = Emit.Joint
	local Leading: Joint? = nil
	local From: number = 0
	local To: number = 0
	local First: number = 0
	local Last: number? = nil

	for Start: number, Stop: number in Unicode.Graphemes(Word) do
		const Code: number = Unicode.Codepoint(Word, Start)
		const Control: Joint? = Unicode.Control(Code)

		if Control then
			if From > 0 then table.insert(Parts, Sub(Word, From, To)); From = 0 end

			Joint = Control

			continue
		end

		if Code >= RightStart and Unicode.Class(Code) == Unicode.Right then Emit.Bidi = true end

		if Last and (if Joint then Joint == "Glue" else Unicode.Joins(Last, Code)) then
			if From == 0 then From = Start end

			To = Stop
			Last = Code
			Joint = nil

			continue
		end

		if Last then
			if From > 0 then table.insert(Parts, Sub(Word, From, To)) end

			AddPiece(Context, Emit, Parts, Style, Leading, First, Last :: number)
			Leading = Joint or "Break"
		else
			Leading = Joint
		end

		From = Start
		To = Stop
		First = Code
		Last = Code
		Joint = nil
	end

	if Last then
		if From > 0 then table.insert(Parts, Sub(Word, From, To)) end

		AddPiece(Context, Emit, Parts, Style, Leading, First, Last :: number)
	end

	Emit.Joint = Joint
end

const function Budget(Context: Context, Text: string): string
	const Counts: Types.CountData = Context.Counts
	const Limit: number = Context.Limits.Characters
	const Remaining: number = Limit - Counts.Characters
	const Count: number? = utf8.len(Text)
	const Characters: number = Count or #Text

	if Characters <= Remaining then Counts.Characters += Characters; return Text end

	Counts.Characters = Limit
	Context.Flags.Halted = true

	if Remaining <= 0 then return "" end
	if not Count then return Sub(Text, 1, Remaining) end

	const Cut: number = (utf8.offset(Text, Remaining + 1) :: number) - 1

	local Kept: number = 0
	for _, Stop: number in Unicode.Graphemes(Text) do
		if Stop > Cut then break end

		Kept = Stop
	end

	return Sub(Text, 1, Kept)
end

const function AddText(Context: Context, Source: string, Style: Style): ()
	const Flags: Types.FlagData = Context.Flags
	if Flags.Halted then return end

	const Clean: string = if Flags.Strip then Sanitize(Source) else Source
	const Text: string = if Context.Limits.Characters == math.huge then Clean else Budget(Context, Clean)
	const Length: number = #Text
	const Emit: Emit = Context.Emit

	local Index: number = 1

	while Index <= Length do
		const Code: number = Byte(Text, Index)

		Emit.Offset = Index

		if Separators[Code] then
			if Code == NewlineByte then
				AddBreak(Emit)
			else
				Emit.Space = true
				Emit.Joint = nil
			end

			Index += 1

			continue
		end

		local Stop: number = Index + 1
		local Plain: boolean = Code < 0x80

		while Stop <= Length do
			const Next: number = Byte(Text, Stop)
			if Separators[Next] then break end
			if Next >= 0x80 then Plain = false end

			Stop += 1
		end

		const Word: string = Sub(Text, Index, Stop - 1)

		if Plain then AddWord(Context, Emit, Word, Style, Code, Byte(Text, Stop - 1)) else AddScript(Context, Emit, Word, Style) end

		Index = Stop
	end
end

const function Decode(Context: Context, Raw: string): string
	return Unescape(if Context.Flags.Collapse then Collapse(Raw) else Raw)
end

const function AddSource(Context: Context, Node: XMLNode, Style: Style): ()
	const Emit: Emit = Context.Emit
	const Counts: Types.CountData = Context.Counts
	const Tokens: { Types.Token } = Emit.Tokens
	const First: number = #Tokens + 1
	const Before: Types.Token? = Tokens[First - 1]
	const Space: boolean = Emit.Space
	const Code: number? = Emit.Code
	const Entered: Joint? = Emit.Joint
	const Characters: number = Counts.Characters

	AddText(Context, Decode(Context, Node.Text :: string), Style)

	const Ledger: Types.Ledger = Context.Ledger
	const Entries: { Types.Entry } = Ledger.Entries

	table.insert(Entries, {
		Node = Node;
		Style = Style;
		First = First;
		Count = #Tokens - First + 1;
		Characters = Counts.Characters - Characters;
		Code = Code;
		ExitCode = Emit.Code;
		Flags = Pack(Space, Emit.Space, Before ~= nil and Before.Hyphen ~= nil, Entered, Emit.Joint);
	})

	Ledger.Slots[Node] = #Entries
end

const function Own(Context: Context, Object: GuiObject, Key: string): ()
	const Reuse: Types.ReuseData = Context.Reuse

	Reuse.Cache[Object] = Key
	if Context.State.Objects.Cache[Object] then return end

	Object:SetAttribute(Attributes.Marker, true)

	const Owner: Trove.Trove = Reuse.Trove or Context.State.Troves.Main:Extend()
	Reuse.Trove = Owner
	Owner:Add(Object)
end

const function AddObject(Context: Context, Object: GuiObject, Block: boolean, Key: string): ()
	Own(Context, Object, Key)
	Context.Counts.Objects += 1

	const Emit: Emit = Context.Emit
	const Tokens: { Types.Token } = Emit.Tokens
	const Base: Vector2? = Context.State.Objects.Sizes[Object]
	const Size: UDim2 = Object.Size

	table.insert(Tokens, {
		Kind = "Object";
		Object = Object;
		Block = if Block then true else nil;
		Width = if Base then (Base :: Vector2).X else Size.X.Offset;
		Height = if Base then (Base :: Vector2).Y else Size.Y.Offset;
		SpaceBefore = Emit.Space and #Tokens > 0;
		X = 0;
	})

	Settle(Emit, nil)
end

return {
	Pack = Pack;
	Unpack = Unpack;
	Settle = Settle;
	Recycle = Recycle;
	AddBreak = AddBreak;
	AddText = AddText;
	Decode = Decode;
	AddSource = AddSource;
	AddObject = AddObject;
}
