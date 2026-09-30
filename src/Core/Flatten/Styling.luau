--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Styles = require("../../Utility/Styles")
const Assets = require("../../Policy/Assets")
const Tokens = require("./Tokens")

type XMLNode = Types.Node
type Style = Types.Style
type Context = Types.FlattenContext
type Handler = Types.FlattenHandler
type Applier = Types.FlattenApplier

const MaximumStroke: number = Config.Flatten.MAXIMUM_STROKE
const DefaultStrokeColor: Color3 = Config.Flatten.STROKE_COLOR
const DefaultMarkColor: Color3 = Config.Flatten.MARK_COLOR
const Sketch: Style = {Bold = false, Italic = false, Underline = false, Strike = false, Color = Color3.new(), Size = 0, Family = "", Transparency = 0}

const JoinModes: { [string]: Enum.LineJoinMode } = {
	["round"] = Enum.LineJoinMode.Round;
	["bevel"] = Enum.LineJoinMode.Bevel;
	["miter"] = Enum.LineJoinMode.Miter;
}

const Find = string.find
const LowerName = Styles.LowerName
const Unescape = Styles.Unescape
const Clone = Styles.Clone
const ParseColor = Styles.ParseColor
const AddText = Tokens.AddText
const AddBreak = Tokens.AddBreak

local Walk: Handler

const function OpenMarkup(Node: XMLNode): string
	const Parts: { string } = {"<", Node.TagType or ""}

	for _, Entry: Types.Attribute in (Node.Attributes) do
		const Quote: string = if Find(Entry.Value, "\"", 1, true) then "'" else "\""
		table.insert(Parts, ` {Entry.Name}={Quote}{Entry.Value}{Quote}`)
	end

	table.insert(Parts, if Node.Type == "SINGLE" then "/>" else ">")

	return table.concat(Parts)
end

const function Reject(Context: Context, Node: XMLNode, Style: Style): ()
	if Context.Flags.Generated then Walk(Context, Node, Style); return end

	AddText(Context, OpenMarkup(Node), Style)

	if Node.Type == "SINGLE" then return end

	Walk(Context, Node, Style)
	AddText(Context, `</{Node.TagType or ""}>`, Style)
end

const function ScaledSize(Context: Context, Value: number): number
	const Range: Types.RangeData = Context.Limits.TextSize
	const Requested: number = math.clamp(Value, Range.Min, Range.Max)

	return math.clamp(math.floor(Requested * Context.Scale + 0.5), 1, Styles.MaximumTextSize)
end

const function ApplyFace(Context: Context, Style: Style, Value: string): ()
	const Face = Styles.ResolveFace(Value)
	if not Face or (Face.Asset and not Assets.Allows(Context.Access.Assets, Face.Family)) then return end

	Style.Family = Face.Family
	if Face.Weight then Style.Weight = Face.Weight end
	if Face.Italic then Style.Italic = true end
end

const function StrokeOf(Context: Context, Style: Style): Types.StrokeData
	const Draft: Types.StrokeData? = Context.Draft.Stroke; if Draft then return Draft end

	const Created: Types.StrokeData = {Color = DefaultStrokeColor, Thickness = Context.Scale, Transparency = 0, Joins = Enum.LineJoinMode.Round}
	Context.Draft.Stroke = Created
	Style.Stroke = Created

	return Created
end

const function MarkOf(Context: Context, Style: Style): Types.MarkData
	const Draft: Types.MarkData? = Context.Draft.Mark; if Draft then return Draft end

	const Created: Types.MarkData = {Color = DefaultMarkColor, Transparency = 0}
	Context.Draft.Mark = Created
	Style.Mark = Created

	return Created
end

const function ApplyAttributes(Context: Context, Style: Style, Node: XMLNode, Appliers: { [string]: Applier }): ()
	for _, Entry: Types.Attribute in (Node.Attributes) do
		const Applier: Applier? = Appliers[LowerName(Entry.Name)]
		if Applier then Applier(Context, Style, Unescape(Entry.Value)) end
	end

	Context.Draft.Stroke = nil
	Context.Draft.Mark = nil
end

const FontAppliers: { [string]: Applier } = {
	["color"] = function(_Context: Context, Style: Style, Value: string): ()
		const Color: Color3? = ParseColor(Value); if Color then Style.Color = Color :: Color3 end
	end;
	["size"] = function(Context: Context, Style: Style, Value: string): ()
		const Size: number? = tonumber(Value); if Size then Style.Size = ScaledSize(Context, Size :: number) end
	end;
	["face"] = ApplyFace;
	["family"] = ApplyFace;
	["weight"] = function(_Context: Context, Style: Style, Value: string): ()
		const Weight: Enum.FontWeight? = Styles.ParseWeight(Value); if not Weight then return end

		Style.Weight = Weight
		Style.Bold = false
	end;
	["transparency"] = function(_Context: Context, Style: Style, Value: string): ()
		const Transparency: number? = tonumber(Value); if Transparency then Style.Transparency = math.clamp(Transparency :: number, 0, 1) end
	end;
}

const StrokeAppliers: { [string]: Applier } = {
	["color"] = function(Context: Context, Style: Style, Value: string): ()
		const Color: Color3? = ParseColor(Value); if Color then StrokeOf(Context, Style).Color = Color :: Color3 end
	end;
	["thickness"] = function(Context: Context, Style: Style, Value: string): ()
		const Thickness: number? = tonumber(Value)
		if Thickness then StrokeOf(Context, Style).Thickness = math.clamp(Thickness :: number, 0, MaximumStroke) * Context.Scale end
	end;
	["transparency"] = function(Context: Context, Style: Style, Value: string): ()
		const Transparency: number? = tonumber(Value)
		if Transparency then StrokeOf(Context, Style).Transparency = math.clamp(Transparency :: number, 0, 1) end
	end;
	["joins"] = function(Context: Context, Style: Style, Value: string): ()
		const Mode: Enum.LineJoinMode? = JoinModes[LowerName(Value)]; if Mode then StrokeOf(Context, Style).Joins = Mode :: Enum.LineJoinMode end
	end;
}

const MarkAppliers: { [string]: Applier } = {
	["color"] = function(Context: Context, Style: Style, Value: string): ()
		const Color: Color3? = ParseColor(Value); if Color then MarkOf(Context, Style).Color = Color :: Color3 end
	end;
	["transparency"] = function(Context: Context, Style: Style, Value: string): ()
		const Transparency: number? = tonumber(Value)
		if Transparency then MarkOf(Context, Style).Transparency = math.clamp(Transparency :: number, 0, 1) end
	end;
}

const function Load(Style: Style): Style
	const Fields: { [string]: unknown } = Sketch :: any

	table.clear(Fields)
	for Key: string, Value: unknown in (Style :: any) do Fields[Key] = Value end

	return Sketch
end

const function Same(Left: Style, Right: Style): boolean
	const LeftFields: { [string]: unknown } = Left :: any
	const RightFields: { [string]: unknown } = Right :: any

	for Key: string, Value: unknown in (LeftFields) do
		if RightFields[Key] ~= Value then return false end
	end

	for Key: string, Value: unknown in (RightFields) do
		if LeftFields[Key] ~= Value then return false end
	end

	return true
end

const function Intern(Context: Context, Draft: Style): Style
	if Draft.Container then return Clone(Draft) end

	const Interning: Types.InternData = Context.Styles
	const Index: number = Interning.Count + 1
	const Prior: Style? = Interning.Prior[Index]
	const Result: Style = if Prior and Same(Prior :: Style, Draft) then Prior :: Style else Clone(Draft)

	Interning.Count = Index
	Interning.Current[Index] = Result

	return Result
end

const function Setter(Field: string, Value: any): Handler
	return function(Context: Context, Node: XMLNode, Style: Style): ()
		if (Style :: any)[Field] == Value then Walk(Context, Node, Style); return end

		const Draft: any = Load(Style)
		Draft[Field] = Value

		Walk(Context, Node, Intern(Context, Draft))
	end
end

const function Decorator(Appliers: { [string]: Applier }, Prepare: ((Context: Context, Style: Style) -> any)?): Handler
	return function(Context: Context, Node: XMLNode, Style: Style): ()
		if not Prepare and #Node.Attributes == 0 then Walk(Context, Node, Style); return end

		const Draft: Style = Load(Style)
		if Prepare then Prepare(Context, Draft) end

		ApplyAttributes(Context, Draft, Node, Appliers)
		Walk(Context, Node, Intern(Context, Draft))
	end
end

const NativeHandlers: { [string]: Handler } = {
	["b"] = Setter("Bold", true);
	["i"] = Setter("Italic", true);
	["u"] = Setter("Underline", true);
	["s"] = Setter("Strike", true);
	["uppercase"] = Setter("Case", "Upper");
	["uc"] = Setter("Case", "Upper");
	["smallcaps"] = Setter("Case", "SmallCaps");
	["sc"] = Setter("Case", "SmallCaps");
	["font"] = Decorator(FontAppliers, nil);
	["stroke"] = Decorator(StrokeAppliers, StrokeOf);
	["mark"] = Decorator(MarkAppliers, MarkOf);
	["br"] = function(Context: Context, Node: XMLNode, Style: Style): ()
		AddBreak(Context.Emit)
		Walk(Context, Node, Style)
	end;
}

const function Bind(Walker: Handler): ()
	Walk = Walker
end

return {
	Bind = Bind;
	Reject = Reject;
	Load = Load;
	Intern = Intern;
	Handlers = NativeHandlers;
}
