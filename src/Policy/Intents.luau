--!strict
--!native
--!optimize 2

const Config = require("../Config")
const XML = require("../../XML")
const Types = require("../Types")

type Intents = Types.Intents
type IntentFlag = Types.IntentFlag
type IntentsValue = Types.IntentsValue

const Band = bit32.band
const Bor = bit32.bor
const Bxor = bit32.bxor
const Bnot = bit32.bnot
const Btest = bit32.btest
const Lower = string.lower

const FlagNames: { IntentFlag } = table.freeze({
	"Formatting";
	"LineBreaks";
	"Color";
	"Font";
	"Stroke";
	"Mark";
	"Casing";
	"Images";
	"Links";
	"Gradients";
	"Effects";
	"Markdown";
	"Code";
	"CodeBlocks";
	"Rules";
	"Direction";
	"Indent";
	"CustomClasses";
	"Controls";
} :: { IntentFlag })

const Flags: { [string]: number } = {}
for Index: number, Name: string in (FlagNames) do Flags[Name] = bit32.lshift(1, Index - 1) end
table.freeze(Flags)

const All: number = bit32.lshift(1, #FlagNames) - 1

const TagOwners: { [string]: IntentFlag } = table.freeze({
	["b"] = "Formatting";
	["i"] = "Formatting";
	["u"] = "Formatting";
	["s"] = "Formatting";
	["br"] = "LineBreaks";
	["font"] = "Font";
	["stroke"] = "Stroke";
	["mark"] = "Mark";
	["uppercase"] = "Casing";
	["uc"] = "Casing";
	["smallcaps"] = "Casing";
	["sc"] = "Casing";
	["img"] = "Images";
	["a"] = "Links";
	["gradient"] = "Gradients";
	["wave"] = "Effects";
	["shake"] = "Effects";
	["md"] = "Markdown";
	["code"] = "Code";
	["codeblock"] = "CodeBlocks";
	["hr"] = "Rules";
	["dir"] = "Direction";
	["indent"] = "Indent";
	["customclass"] = "CustomClasses";
} :: { [string]: IntentFlag })

const FontAttributes: { [string]: number } = table.freeze({["color"] = Flags.Color})
const FontFallback: number = Flags.Font

const TagMasks: { [string]: number } = {}
for Tag: string, Owner: IntentFlag in (TagOwners) do TagMasks[Tag] = Flags[Owner] end
TagMasks["font"] = Bor(Flags.Color, Flags.Font)
table.freeze(TagMasks)

const Markup: number = Band(All, Bnot(Flags.Controls))

const Names: { [string]: number } = {}
for Name: string, Bit: number in (Flags) do Names[Lower(Name)] = Bit end

const PresetNames: { string } = table.freeze({"Default", "Trusted", "Chat", "Plain"})
const PresetBitfields: { [string]: number } = {}

const function Describe(): string
	return `flags {table.concat(FlagNames, ", ")} or presets {table.concat(PresetNames, ", ")}`
end

local Parse: (Value: any, Seen: { [any]: boolean }?) -> (number?, string?)

--[=[
	Discord.js style bitfields of the tags a renderer interprets, reached through `RichTextPlus.Intents`. Build one with [Intents.new] and pass it to [Renderer:SetIntents].

	```lua
	local Intents = RichTextPlus.Intents

	local Chat = Intents.new("Formatting", "LineBreaks", "Color", "Links")
	Chat:Has("Links") -- true
	Chat:Add(Intents.Flags.Images):Remove("Links")
	```

	`Add`, `Remove` and `Toggle` change the object and return it. A frozen object, like every preset and every [Renderer:GetIntents] result, is left alone and a changed copy is returned instead.

	@class Intents
]=]
--[=[
	The bit of every flag, a power of two.

	@within Intents
	@prop Flags { [IntentFlag]: number }
	@readonly
]=]
--[=[
	The frozen tag sets of the built-in presets. `Default` and `Trusted` grant every flag and differ only in limits and denied handling, which [Renderer:SetPreset] applies.

	@within Intents
	@prop Presets { [Preset]: Intents }
	@readonly
]=]
--[=[
	The flag that owns each built-in tag. `font` is listed as `Font`; its `color` attribute needs `Color`.

	@within Intents
	@prop Tags { [string]: IntentFlag }
	@readonly
]=]
--[=[
	The bitfield number.

	@within Intents
	@prop Bitfield number
	@readonly
]=]
const BitField = {}
BitField.__index = BitField

const function IsBitField(Value: any): boolean
	return type(Value) == "table" and getmetatable(Value) == BitField
end

const function ParseList(List: { any }, Seen: { [any]: boolean }?): (number?, string?)
	const Visited: { [any]: boolean } = Seen or {}
	if Visited[List] then return nil, "RichTextPlus intents cannot contain themselves" end
	Visited[List] = true

	local Bits: number = 0

	for _, Entry: any in (List) do
		const Resolved: number?, Problem: string? = Parse(Entry, Visited); if not Resolved then return nil, Problem end
		Bits = Bor(Bits, Resolved :: number)
	end

	return Bits, nil
end

const function ParseNumber(Value: number): (number?, string?)
	if Value ~= Value or Value < 0 or Value > All or Value % 1 ~= 0 then
		return nil, `RichTextPlus intents bitfield {Value} is not a whole number made of known flags (0 to {All})`
	end

	return Value, nil
end

const function ParseName(Value: string): (number?, string?)
	const Key: string = Lower(Value)
	const Bit: number? = Names[Key] or PresetBitfields[Key]; if Bit then return Bit, nil end

	return nil, `Unknown RichTextPlus intent "{Value}": use {Describe()}`
end

Parse = function(Value: any, Seen: { [any]: boolean }?): (number?, string?)
	const Kind: string = type(Value)

	if Kind == "number" then return ParseNumber(Value) end
	if Kind == "string" then return ParseName(Value) end
	if IsBitField(Value) then return Value.Bitfield, nil end
	if Kind == "table" then return ParseList(Value, Seen) end

	return nil, `RichTextPlus intents take {Describe()}, a bitfield number, an Intents object or an array of these, got {typeof(Value)}`
end

const function Collect(Level: number, ...: any): number
	local Bits: number = 0

	for Index = 1, select("#", ...) do
		const Resolved: number?, Problem: string? = Parse((select(Index, ...)))
		if not Resolved then error(Problem, Level + 1) end

		Bits = Bor(Bits, Resolved :: number)
	end

	return Bits
end

const function Create(Bits: number): Intents
	return setmetatable({Bitfield = Bits}, BitField) :: any
end

const function Frozen(Bits: number): Intents
	return table.freeze(Create(Bits))
end

const function Rewrite(Target: Intents, Bits: number): Intents
	if table.isfrozen(Target) then return Create(Bits) end

	(Target :: any).Bitfield = Bits

	return Target
end

--[=[
	Creates intents from any number of flags, preset names, bitfields, [Intents] objects or arrays, combined. No arguments gives no intents.

	```lua
	Intents.new("Formatting", "Color")
	Intents.new({"Formatting", "Links"}, Intents.Flags.Images)
	Intents.new("Chat")
	```

	@within Intents
	@function new
	@param ... IntentsValue
	@return Intents
]=]
const function New(...: IntentsValue): Intents
	return Create(Collect(2, ...))
end

--[=[
	Returns the bitfield number of any [IntentsValue]. Errors on an unknown name or a number with unknown bits.

	@within Intents
	@function Resolve
	@param Value IntentsValue
	@return number
]=]
const function Resolve(Value: IntentsValue): number
	return Collect(2, Value)
end

--[=[
	Returns whether every flag given is set.

	@within Intents
	@method Has
	@param ... IntentsValue
	@return boolean
]=]
function BitField.Has(self: Intents, ...: IntentsValue): boolean
	const Bits: number = Collect(2, ...)

	return Band(self.Bitfield, Bits) == Bits
end

--[=[
	Returns whether any flag given is set.

	@within Intents
	@method Any
	@param ... IntentsValue
	@return boolean
]=]
function BitField.Any(self: Intents, ...: IntentsValue): boolean
	return Btest(self.Bitfield, Collect(2, ...))
end

--[=[
	Sets the flags given.

	@within Intents
	@method Add
	@param ... IntentsValue
	@return Intents
]=]
function BitField.Add(self: Intents, ...: IntentsValue): Intents
	return Rewrite(self, Bor(self.Bitfield, Collect(2, ...)))
end

--[=[
	Clears the flags given.

	@within Intents
	@method Remove
	@param ... IntentsValue
	@return Intents
]=]
function BitField.Remove(self: Intents, ...: IntentsValue): Intents
	return Rewrite(self, Band(self.Bitfield, Bnot(Collect(2, ...))))
end

--[=[
	Flips the flags given.

	@within Intents
	@method Toggle
	@param ... IntentsValue
	@return Intents
]=]
function BitField.Toggle(self: Intents, ...: IntentsValue): Intents
	return Rewrite(self, Bxor(self.Bitfield, Collect(2, ...)))
end

--[=[
	Returns the names of the set flags, in bit order.

	@within Intents
	@method ToArray
	@return { IntentFlag }
]=]
function BitField.ToArray(self: Intents): { IntentFlag }
	const Result: { IntentFlag } = {}

	for _, Name: IntentFlag in (FlagNames) do
		if Btest(self.Bitfield, Flags[Name]) then table.insert(Result, Name) end
	end

	return Result
end

--[=[
	Returns every flag name mapped to whether it is set.

	@within Intents
	@method Serialize
	@return { [IntentFlag]: boolean }
]=]
function BitField.Serialize(self: Intents): { [string]: boolean }
	const Result: { [string]: boolean } = {}

	for _, Name: string in (FlagNames) do Result[Name] = Btest(self.Bitfield, Flags[Name]) end

	return Result
end

--[=[
	Returns whether `Other` resolves to the same bitfield.

	@within Intents
	@method Equals
	@param Other IntentsValue
	@return boolean
]=]
function BitField.Equals(self: Intents, Other: IntentsValue): boolean
	return self.Bitfield == Collect(2, Other)
end

--[=[
	Freezes the object so `Add`, `Remove` and `Toggle` return changed copies, and returns it.

	@within Intents
	@method Freeze
	@return Intents
]=]
function BitField.Freeze(self: Intents): Intents
	if not table.isfrozen(self) then table.freeze(self) end

	return self
end

--[=[
	Returns whether the intents allow a built-in tag, and with `Attribute` given, that attribute on it. Tags without a flag, such as custom class names, are never allowed directly.

	@within Intents
	@method Allows
	@param Tag string
	@param Attribute string?
	@return boolean
]=]
function BitField.Allows(self: Intents, Tag: string, Attribute: string?): boolean
	const Key: string = Lower(Tag)
	const Mask: number? = TagMasks[Key]
	if not Mask or not Btest(self.Bitfield, Mask :: number) then return false end
	if Attribute == nil or Key ~= "font" then return true end

	return Btest(self.Bitfield, FontAttributes[Lower(Attribute :: string)] or FontFallback)
end

function BitField.__tostring(self: Intents): string
	return `Intents({table.concat(self:ToArray(), ", ")})`
end

const function PresetBits(Name: string): number
	const Listed: { string }? = (Config.Presets :: any)[Name].Intents; if not Listed then return All end

	return Collect(2, Listed)
end

const Presets: { [string]: Intents } = {}
for _, Name: string in (PresetNames) do Presets[Name] = Frozen(PresetBits(Name)) end
for Name: string, Preset: Intents in (Presets) do PresetBitfields[Lower(Name)] = Preset.Bitfield end
table.freeze(Presets)
table.freeze(PresetBitfields)

const function Filter(Node: Types.Node, Granted: number): Types.Node
	const Source: { Types.Attribute } = Node.Attributes
	if #Source == 0 then return Node end

	const Kept: { Types.Attribute } = {}

	for _, Entry: Types.Attribute in (Source) do
		if Btest(Granted, FontAttributes[Lower(Entry.Name)] or FontFallback) then table.insert(Kept, Entry) end
	end

	if #Kept == #Source then return Node end

	return XML.Node.new(Node.Type, {TagType = Node.TagType, Text = Node.Text, Attributes = Kept, Children = Node.Children})
end

const function Interprets(Granted: number, Strip: boolean): boolean
	return Strip or Btest(Granted, Markup)
end

const function Check(Value: any, Level: number): number
	return Collect(Level + 1, Value)
end

return {
	Flags = Flags;
	Presets = Presets;
	Tags = TagOwners;
	new = New;
	Resolve = Resolve;
	Class = BitField;
	All = All;
	Masks = TagMasks;
	Is = IsBitField;
	Frozen = Frozen;
	Check = Check;
	Filter = Filter;
	Interprets = Interprets;
}
