--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Intents = require("./Intents")
const Limits = require("./Limits")

export type Bundle = {
	Intents: Types.Intents;
	Limits: Types.LimitsData;
	Denied: Types.Denied;
}

const DeniedModes: { [string]: boolean } = table.freeze({Escape = true, Strip = true})

const Bundles: { [string]: Bundle } = {}
for Name: string, Preset: any in (Config.Presets) do
	Bundles[string.lower(Name)] = table.freeze({
		Intents = Intents.Presets[Name];
		Limits = Limits.Presets[Name];
		Denied = Preset.Denied;
	})
end
table.freeze(Bundles)

const function Resolve(Name: any, Level: number): Bundle
	const Found: Bundle? = if type(Name) == "string" then Bundles[string.lower(Name)] else nil
	if not Found then error(`Unknown RichTextPlus preset "{tostring(Name)}": use "Default", "Trusted", "Chat" or "Plain"`, Level + 1) end

	return Found :: Bundle
end

const function CheckDenied(Mode: any, Level: number): ()
	if type(Mode) ~= "string" or not DeniedModes[Mode] then error(`RichTextPlus denied handling "{tostring(Mode)}" is not "Escape" or "Strip"`, Level + 1) end
end

return {
	Default = Bundles.default;
	Resolve = Resolve;
	CheckDenied = CheckDenied;
}
