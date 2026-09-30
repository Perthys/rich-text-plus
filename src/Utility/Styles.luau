--!strict
--!native
--!optimize 2

const Config = require("../Config")
const XML = require("../../XML")
const Types = require("../Types")
const Characters = require("../Utility/Characters")

type Cache<T> = {
	Values: { [string]: T };
	Count: number;
}

type FaceData = {
	Family: string;
	Weight: Enum.FontWeight?;
	Italic: boolean;
	Asset: boolean;
}

const MinimumBoxWidth: number = Config.Styles.MINIMUM_BOX_WIDTH
const MaximumTextSize: number = Config.Styles.MAXIMUM_TEXT_SIZE
const CacheLimit: number = Config.Styles.CACHE_LIMIT
const SnapSteps: number = Config.Styles.SNAP_STEPS
const MaximumIdDigits: number = Config.Styles.MAXIMUM_ID_DIGITS
const MaximumThumbSize: number = Config.Styles.MAXIMUM_THUMB_SIZE
const HashByte: number = string.byte("#")

const AssetScheme: string = "rbxassetid://"
const EngineScheme: string = "rbxasset://"
const ThumbScheme: string = "rbxthumb://"
const FontFolder: string = "rbxasset://fonts/"

const ControlPattern: string = "[%c\226]"
const OverridePattern: string = "\226\128[\170-\174]"
const IsolatePattern: string = "\226\129[\166-\169]"

const Find = string.find
const Match = string.match
const Gsub = string.gsub
const Lower = string.lower
const Upper = string.upper
const Sub = string.sub
const Byte = string.byte
const Extract = bit32.extract
const EscapedUnescape: (Value: string) -> string = XML.Unescape

const Blank: { [number]: boolean } = Characters.Separators

const Controls: { [string]: string } = {["\127"] = ""}
for Code = 0, 31 do
	if Code ~= 9 and Code ~= 10 then Controls[string.char(Code)] = "" end
end

const LowerNames: Cache<string> = {Values = {}, Count = 0}
const PascalNames: Cache<string> = {Values = {}, Count = 0}
const Colors: Cache<Color3 | false> = {Values = {}, Count = 0}
const Faces: Cache<FaceData | false> = {Values = {}, Count = 0}

const WeightNames: { [string]: Enum.FontWeight } = {}
const WeightValues: { [number]: Enum.FontWeight } = {}
for _, Weight: Enum.FontWeight in (Enum.FontWeight:GetEnumItems() :: { Enum.FontWeight }) do
	WeightNames[Lower(Weight.Name)] = Weight
	WeightValues[Weight.Value] = Weight
end

const FontEnums: { [string]: Enum.Font } = {}
for _, Item: Enum.Font in (Enum.Font:GetEnumItems() :: { Enum.Font }) do
	if Item ~= Enum.Font.Unknown then FontEnums[Lower(Item.Name)] = Item end
end

const NamedColors: { [string]: Color3 } = Config.Styles.NamedColors

const function Remember<T>(Store: Cache<T>, Key: string, Value: T): T
	if Store.Count >= CacheLimit then table.clear(Store.Values); Store.Count = 0 end

	Store.Values[Key] = Value
	Store.Count += 1

	return Value
end

const function TrimEnd(Value: string): string
	local Last: number = #Value
	while Last > 0 and Blank[Byte(Value, Last)] do Last -= 1 end

	return if Last == #Value then Value else Sub(Value, 1, Last)
end

const function Trim(Value: string): string
	const First: number? = Find(Value, "%S"); if not First then return "" end

	return TrimEnd(if First == 1 then Value else Sub(Value, First :: number))
end

const function Unescape(Value: string): string
	return if Find(Value, "&", 1, true) then EscapedUnescape(Value) else Value
end

const function Sanitize(Value: string): string
	if not Find(Value, ControlPattern) then return Value end

	return (Gsub(Gsub(Gsub(Value, "%c", Controls), OverridePattern, ""), IsolatePattern, ""))
end

const function LowerName(Value: string): string
	return LowerNames.Values[Value] or Remember(LowerNames, Value, Lower(Value))
end

const function PascalName(Value: string): string
	const Cached: string? = PascalNames.Values[Value]; if Cached then return Cached end

	const Lowered: string = LowerName(Value)

	return Remember(PascalNames, Value, Upper(Sub(Lowered, 1, 1)) .. Sub(Lowered, 2))
end

const function Attribute(Node: Types.Node, Name: string): string?
	const Target: string = LowerName(Name)

	for _, Entry: Types.Attribute in (Node.Attributes) do
		const Key: string = Entry.Name
		if Key ~= Name and LowerName(Key) ~= Target then continue end

		return Unescape(Entry.Value)
	end

	return nil
end

const function InnerText(Node: Types.Node): string
	const Parts: { string } = {}
	const Stack: { Types.Node } = {Node}

	while #Stack > 0 do
		const Current: Types.Node = table.remove(Stack) :: Types.Node
		const Type: string = Current.Type

		if Type == "STRING" then table.insert(Parts, Unescape(Current.Text or "")); continue end
		if Type == "SINGLE" and LowerName(Current.TagType or "") == "br" then table.insert(Parts, "\n"); continue end

		const Children: { Types.Node } = Current.Children
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end

	return table.concat(Parts)
end

const function Truthy(Value: string?, Default: boolean): boolean
	if Value == nil then return Default end

	const Lowered: string = LowerName(Trim(Value :: string))

	return not (Lowered == "false" or Lowered == "0" or Lowered == "no" or Lowered == "off")
end

const function IsFinite(Value: number): boolean
	return Value == Value and Value ~= math.huge and Value ~= -math.huge
end

const function AttributeNumber(Node: Types.Node, Name: string, Default: number?): number?
	const Value: number? = tonumber(Attribute(Node, Name))

	return if Value ~= nil and IsFinite(Value :: number) then Value else Default
end

const function AttributeBoolean(Node: Types.Node, Name: string, Default: boolean): boolean
	return Truthy(Attribute(Node, Name), Default)
end

const function AssetNumber(Digits: string): string?
	const Stripped: string = Match(Digits, "^0*(%d+)$") :: string
	if Stripped == "0" or #Stripped > MaximumIdDigits then return nil end

	return AssetScheme .. Stripped
end

const function ThumbId(Query: string): string?
	const Kind: string?, Target: string?, Width: string?, Height: string?, Rest: string? = Match(Query, "^type=(%a+)&id=(%d+)&w=(%d+)&h=(%d+)(.*)$")
	if not Kind or #(Target :: string) > MaximumIdDigits or #(Width :: string) > MaximumThumbSize or #(Height :: string) > MaximumThumbSize then return nil end

	const Filter: string? = if Rest == "" then "" else Match(Rest :: string, "^&filters=%a+$")
	if not Filter then return nil end

	return `{ThumbScheme}type={Kind}&id={Target}&w={Width}&h={Height}{Filter}`
end

const function CanonicalId(Source: string): string?
	const Trimmed: string = Trim(Source)
	const Lowered: string = Lower(Trimmed)

	const Digits: string? = Match(Lowered, "^%d+$")
		or Match(Lowered, "^rbxassetid://(%d+)$")
		or Match(Lowered, "^https?://www%.roblox%.com/asset/?%?id=(%d+)$")
		or Match(Lowered, "^https?://roblox%.com/asset/?%?id=(%d+)$")

	if Digits then return AssetNumber(Digits :: string) end

	const Scheme: string = Sub(Lowered, 1, #EngineScheme)

	if Scheme == EngineScheme then
		const Path: string? = Match(Sub(Trimmed, #EngineScheme + 1), "^[%w_%-%./]+$")

		return if Path and not Find(Path :: string, "..", 1, true) then EngineScheme .. Path :: string else nil
	end

	if Scheme == ThumbScheme then return ThumbId(Sub(Trimmed, #ThumbScheme + 1)) end

	return nil
end

const function DecodeFace(Face: string): FaceData?
	const Trimmed: string = Trim(Face)

	if Find(Trimmed, "^%d+$") or Find(Trimmed, ":", 1, true) then
		const Canonical: string? = CanonicalId(Trimmed); if not Canonical then return nil end

		const Asset: boolean = Sub(Canonical :: string, 1, #AssetScheme) == AssetScheme
		if not Asset and Sub(Canonical :: string, 1, #FontFolder) ~= FontFolder then return nil end

		const Found: FaceData = {Family = Canonical :: string, Weight = nil, Italic = false, Asset = Asset}

		return Found
	end

	const Compact: string = (Gsub(Trimmed, "%s", ""))
	const Item: Enum.Font? = FontEnums[Lower(Compact)]

	if not Item then
		if not Find(Compact, "^[%w_%-]+$") then return nil end

		return {Family = `rbxasset://fonts/families/{Compact}.json`, Weight = nil, Italic = false, Asset = false}
	end

	const Resolved: Font = Font.fromEnum(Item :: Enum.Font)

	return {
		Family = Resolved.Family;
		Weight = if Resolved.Weight == Enum.FontWeight.Regular then nil else Resolved.Weight;
		Italic = Resolved.Style == Enum.FontStyle.Italic;
		Asset = false;
	}
end

const function ResolveFace(Face: string): FaceData?
	const Cached: (FaceData | false)? = Faces.Values[Face]
	if Cached ~= nil then return if Cached then Cached :: FaceData else nil end

	const Decoded: FaceData? = DecodeFace(Face)
	const Entry: FaceData | false = if Decoded then Decoded :: FaceData else false
	Remember(Faces, Face, Entry)

	return Decoded
end

const function ResolveFamily(Face: string): string
	const Found: FaceData? = ResolveFace(Face)

	return if Found then (Found :: FaceData).Family else Face
end

const function ParseWeight(Value: string?): Enum.FontWeight?
	if not Value then return nil end

	const Named: Enum.FontWeight? = WeightNames[LowerName(Value :: string)]; if Named then return Named end

	const Numeric: number? = tonumber(Value)
	if Numeric then return WeightValues[math.clamp(math.floor(Numeric :: number / 100 + 0.5), 1, 9) * 100] end

	return WeightNames[(string.gsub(Lower(Value :: string), "[%s%-_]", ""))]
end

const function DecodeColor(Value: string): Color3?
	const Trimmed: string = Lower(Trim(Value))
	const Named: Color3? = NamedColors[Trimmed]; if Named then return Named end

	const Hex: string = if Byte(Trimmed, 1) == HashByte then Sub(Trimmed, 2) else Trimmed
	const Length: number = #Hex

	if (Length == 6 or Length == 3) and not Find(Hex, "%X") then
		const Number: number = tonumber(Hex, 16) :: number

		if Length == 6 then return Color3.fromRGB(Extract(Number, 16, 8), Extract(Number, 8, 8), Extract(Number, 0, 8)) end

		return Color3.fromRGB(Extract(Number, 8, 4) * 17, Extract(Number, 4, 4) * 17, Extract(Number, 0, 4) * 17)
	end

	const Red: string?, Green: string?, Blue: string? = Match(Trimmed, "^rgb%s*%(%s*(%d+)[%s,]+(%d+)[%s,]+(%d+)%s*%)$")
	if not (Red and Green and Blue) then return nil end

	return Color3.fromRGB(
		math.min(tonumber(Red) :: number, 255),
		math.min(tonumber(Green) :: number, 255),
		math.min(tonumber(Blue) :: number, 255)
	)
end

const function ParseColor(Value: string?): Color3?
	if not Value then return nil end

	const Cached: (Color3 | false)? = Colors.Values[Value :: string]
	if Cached ~= nil then return if Cached then Cached :: Color3 else nil end

	const Decoded: Color3? = DecodeColor(Value :: string)
	const Entry: Color3 | false = if Decoded then Decoded :: Color3 else false
	Remember(Colors, Value :: string, Entry)

	return Decoded
end

const function Channel(Value: number): number
	return math.clamp(math.floor(Value * 255 + 0.5), 0, 255)
end

const function FormatColor(Color: Color3): string
	return `rgb({Channel(Color.R)}, {Channel(Color.G)}, {Channel(Color.B)})`
end

const function CombineTransparency(Dev: number, Extra: number): number
	return 1 - (1 - Dev) * (1 - Extra)
end

const function Finite(Value: number?, Default: number): number
	return if Value ~= nil and IsFinite(Value :: number) then Value :: number else Default
end

const function FontFor(Style: Types.Style): Font
	local Weight: Enum.FontWeight = Style.Weight or Enum.FontWeight.Regular
	if Style.Bold and Weight.Value < Enum.FontWeight.Bold.Value then Weight = Enum.FontWeight.Bold end

	const Slant: Enum.FontStyle = if Style.Italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal

	return Font.new(Style.Family, Weight, Slant)
end

const function Clone(Style: Types.Style): Types.Style
	const Created: Types.Style = {
		Bold = Style.Bold;
		Italic = Style.Italic;
		Underline = Style.Underline;
		Strike = Style.Strike;
		Color = Style.Color;
		Size = Style.Size;
		Family = Style.Family;
		Weight = Style.Weight;
		Transparency = Style.Transparency;
	}

	if Style.Stroke then Created.Stroke = Style.Stroke end
	if Style.Mark then Created.Mark = Style.Mark end
	if Style.Indent then Created.Indent = Style.Indent end
	if Style.Case then Created.Case = Style.Case end
	if Style.Code then Created.Code = Style.Code end
	if Style.Direction then Created.Direction = Style.Direction end
	if Style.Container then Created.Container = Style.Container end
	if Style.Link then Created.Link = Style.Link end
	if Style.Element then Created.Element = Style.Element end
	if Style.Gradient then Created.Gradient = Style.Gradient end
	if Style.Effect then Created.Effect = Style.Effect end

	return Created
end

const function EffectiveScale(State: Types.Fields): number
	return State.Options.Scale
end

const function BaseSize(State: Types.Fields): number
	return math.clamp(math.floor(State.Label.TextSize * EffectiveScale(State) + 0.5), 8, MaximumTextSize)
end

const function AncestorScale(Label: GuiObject): number
	local Product: number = 1
	local Current: Instance? = Label

	while Current do
		const Node: Instance = Current :: Instance
		if not Node:IsA("GuiBase2d") then break end

		const Scaler: UIScale? = Node:FindFirstChildWhichIsA("UIScale")
		if Scaler then Product *= (Scaler :: UIScale).Scale end
		if Node:IsA("LayerCollector") then break end

		Current = Node.Parent
	end

	return if Product > 0 and Product < math.huge then Product else 1
end

const function Snap(Value: number): number
	return math.floor(Value * SnapSteps + 0.5) / SnapSteps
end

const function LocalSize(Label: GuiObject, Scale: number?): Vector2
	const Size: Vector2 = Label.AbsoluteSize
	const Ratio: number = Scale or AncestorScale(Label)
	if Ratio == 1 then return Size end

	return Vector2.new(Snap(Size.X / Ratio), Snap(Size.Y / Ratio))
end

const function ContentSize(Label: GuiObject, Scale: number?): Vector2
	const Size: Vector2 = LocalSize(Label, Scale)
	const Padding: UIPadding? = Label:FindFirstChildWhichIsA("UIPadding"); if not Padding then return Size end

	const Left: UDim, Right: UDim = (Padding :: UIPadding).PaddingLeft, (Padding :: UIPadding).PaddingRight
	const Top: UDim, Bottom: UDim = (Padding :: UIPadding).PaddingTop, (Padding :: UIPadding).PaddingBottom

	const Width: number = Size.X * (1 - Left.Scale - Right.Scale) - Left.Offset - Right.Offset
	const Height: number = Size.Y * (1 - Top.Scale - Bottom.Scale) - Top.Offset - Bottom.Offset

	return Vector2.new(math.max(math.floor(Width), 0), math.max(math.floor(Height), 0))
end

const function Base(State: Types.Fields, Previous: Types.Style?): Types.Style
	const Label: TextLabel = State.Label
	const Face: Font = Label.FontFace

	if Previous then
		const Kept: Types.Style = Previous :: Types.Style

		if Kept.Family == Face.Family
			and Kept.Weight == Face.Weight
			and Kept.Italic == (Face.Style == Enum.FontStyle.Italic)
			and Kept.Color == Label.TextColor3
			and Kept.Size == BaseSize(State)
		then
			return Kept
		end
	end

	return {
		Bold = false;
		Italic = Face.Style == Enum.FontStyle.Italic;
		Underline = false;
		Strike = false;
		Color = Label.TextColor3;
		Size = BaseSize(State);
		Family = Face.Family;
		Weight = Face.Weight;
		Transparency = 0;
	}
end

return {
	MinimumBoxWidth = MinimumBoxWidth;
	MaximumTextSize = MaximumTextSize;
	Unescape = Unescape;
	Sanitize = Sanitize;
	Trim = Trim;
	TrimEnd = TrimEnd;
	CanonicalId = CanonicalId;
	LowerName = LowerName;
	PascalName = PascalName;
	Attribute = Attribute;
	InnerText = InnerText;
	Truthy = Truthy;
	AttributeNumber = AttributeNumber;
	AttributeBoolean = AttributeBoolean;
	ResolveFace = ResolveFace;
	ResolveFamily = ResolveFamily;
	ParseWeight = ParseWeight;
	ParseColor = ParseColor;
	FormatColor = FormatColor;
	CombineTransparency = CombineTransparency;
	Finite = Finite;
	FontFor = FontFor;
	Clone = Clone;
	EffectiveScale = EffectiveScale;
	BaseSize = BaseSize;
	AncestorScale = AncestorScale;
	LocalSize = LocalSize;
	ContentSize = ContentSize;
	Base = Base;
}
