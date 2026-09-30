--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")

type Filter = (Id: string) -> boolean

const CanonicalId = Styles.CanonicalId

const function FromAllowlist(Allowlist: { [string]: boolean }, Level: number): Filter
	const Allowed: { [string]: boolean } = {}

	for Id: any, Enabled: any in (Allowlist) do
		if type(Id) ~= "string" then error("RichTextPlus asset allowlists map asset id strings to booleans", Level + 1) end

		const Canonical: string? = CanonicalId(Id)
		if Canonical and Enabled == true then Allowed[Canonical :: string] = true end
	end

	table.freeze(Allowed)

	return function(Id: string): boolean
		return Allowed[Id] == true
	end
end

const function Resolve(Value: Types.AssetFilter?, Level: number): Filter?
	if Value == nil then return nil end
	if type(Value) == "function" then return Value :: Filter end
	if type(Value) == "table" then return FromAllowlist(Value :: { [string]: boolean }, Level + 1) end

	error("RichTextPlus Renderer:SetAssetFilter takes a function of the canonical id, an allowlist map, or nil to allow every asset", Level + 1)
end

const function Allows(Filter: Filter?, Source: string): boolean
	const Canonical: string? = CanonicalId(Source); if not Canonical then return false end
	if not Filter then return true end

	return (Filter :: Filter)(Canonical :: string) == true
end

return {
	CanonicalId = CanonicalId;
	Resolve = Resolve;
	Allows = Allows;
}
