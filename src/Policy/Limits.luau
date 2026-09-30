--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")

type Limits = Types.Limits
type LimitsData = Types.LimitsData
type TextSizeLimits = Types.TextSizeLimits

const Fields: { [string]: boolean } = table.freeze({Depth = true, Nodes = true, Characters = true, Objects = true, TextSize = true})
const SizeFields: { [string]: boolean } = table.freeze({Min = true, Max = true})

const function Count(Value: any): number?
	if type(Value) ~= "number" or Value ~= Value or Value == math.huge then return nil end

	return math.max(math.floor(Value), 0)
end

const function Size(Value: any): number?
	if type(Value) ~= "number" or Value ~= Value then return nil end

	return math.clamp(Value, 1, Styles.MaximumTextSize)
end

const function Validate(Source: any, Allowed: { [string]: boolean }, Level: number): ()
	for Key: any in (Source) do
		if not Allowed[Key] then error(`Unknown RichTextPlus limit "{tostring(Key)}": limits take Depth, Nodes, Characters, Objects and TextSize = \{Min, Max\}`, Level + 1) end
	end
end

const function NormalizeSize(Source: any, Level: number): TextSizeLimits
	if Source == nil then return table.freeze({}) end
	if type(Source) ~= "table" then error("RichTextPlus TextSize limits take a table {Min, Max}", Level + 1) end

	Validate(Source, SizeFields, Level + 1)

	const Min: number? = Size(Source.Min)
	const Max: number? = Size(Source.Max)

	return table.freeze({
		Min = if Min and Max then math.min(Min :: number, Max :: number) else Min;
		Max = Max;
	})
end

const function Normalize(Source: Limits, Level: number): LimitsData
	Validate(Source, Fields, Level + 1)

	return table.freeze({
		Depth = Count(Source.Depth);
		Nodes = Count(Source.Nodes);
		Characters = Count(Source.Characters);
		Objects = Count(Source.Objects);
		TextSize = NormalizeSize(Source.TextSize, Level + 1);
	})
end

const Presets: { [string]: LimitsData } = {}
for Name: string, Preset: any in (Config.Presets) do Presets[Name] = Normalize(Preset.Limits, 1) end
table.freeze(Presets)

const PresetNames: { [string]: LimitsData } = {}
for Name: string, Preset: LimitsData in (Presets) do PresetNames[string.lower(Name)] = Preset end

const function Resolve(Value: any, Level: number): LimitsData
	if type(Value) == "string" then
		const Preset: LimitsData? = PresetNames[string.lower(Value)]
		if not Preset then error(`Unknown RichTextPlus preset "{Value}": use "Default", "Trusted", "Chat" or "Plain"`, Level + 1) end

		return Preset :: LimitsData
	end

	if type(Value) ~= "table" then error("RichTextPlus limits take a preset name or a table of Depth, Nodes, Characters, Objects and TextSize", Level + 1) end

	return Normalize(Value, Level + 1)
end

return {
	Presets = Presets;
	Resolve = Resolve;
}
