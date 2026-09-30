--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")

type RenderingData = Types.RenderingData

const Names: { string } = table.freeze({
	"Passthrough";
	"Culling";
	"Clipping";
	"SyntaxHighlight";
})

const Known: { [string]: boolean } = {}
for _, Name: string in (Names) do Known[Name] = true end
table.freeze(Known)

const Defaults: RenderingData = Config.Rendering

const function Check(Name: string): ()
	if not Known[Name] then error(`Unknown RichTextPlus rendering switch "{Name}": use Passthrough, Culling, Clipping or SyntaxHighlight`, 3) end
end

const function Resolve(Provided: Types.Rendering?): RenderingData
	if not Provided then return Defaults end

	const Resolved: { [string]: boolean } = table.clone(Defaults) :: any

	for Name: string, Enabled: boolean? in (Provided :: any) do
		Check(Name)
		Resolved[Name] = Enabled ~= false
	end

	return table.freeze(Resolved) :: any
end

const function With(Current: RenderingData, Name: string, Enabled: boolean): RenderingData
	const Updated: { [string]: boolean } = table.clone(Current) :: any
	Updated[Name] = Enabled

	return table.freeze(Updated) :: any
end

return {
	Names = Names;
	Known = Known;
	Defaults = Defaults;
	Check = Check;
	Resolve = Resolve;
	With = With;
}
