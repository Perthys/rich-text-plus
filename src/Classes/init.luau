--!strict
--!native
--!optimize 2

const Types = require("./Types")
const Lifetime = require("./Utility/Lifetime")

type Definition = Types.ClassDefinition
type Registry = { [string]: Definition }

const Loaders: { [string]: () -> any } = {
	["Image"] = function(): any return require("@self/Image") end;
	["Hyperlink"] = function(): any return require("@self/Hyperlink") end;
	["Gradient"] = function(): any return require("@self/Gradient") end;
	["Effect"] = function(): any return require("@self/Effect") end;
	["CodeBlock"] = function(): any return require("@self/CodeBlock") end;
	["Code"] = function(): any return require("@self/Code") end;
	["Rule"] = function(): any return require("@self/Rule") end;
	["Indent"] = function(): any return require("@self/Indent") end;
	["Dir"] = function(): any return require("@self/Dir") end;
}

const TagModules: { [string]: string } = {
	["Img"] = "Image";
	["A"] = "Hyperlink";
	["Gradient"] = "Gradient";
	["Wave"] = "Effect";
	["Shake"] = "Effect";
	["Codeblock"] = "CodeBlock";
	["Code"] = "Code";
	["Hr"] = "Rule";
	["Indent"] = "Indent";
	["Dir"] = "Dir";
}

const Loaded: { [string]: any } = {}
const Owned = Lifetime.Own("Classes.Owned", {} :: { [Types.Fields]: Registry })

const function Load(Name: string): any
	const Cached: any = Loaded[Name]; if Cached ~= nil then return Cached end
	const Loader: (() -> any)? = Loaders[Name]; if not Loader then return nil end

	const Module: any = (Loader :: () -> any)()
	Loaded[Name] = Module

	return Module
end

const function ForTag(Tag: string): any
	const Name: string? = TagModules[Tag]; if not Name then return nil end

	return Load(Name :: string)
end

const function Has(Tag: string): boolean
	return TagModules[Tag] ~= nil
end

const function Validate(Definition: Definition): ()
	if type(Definition) ~= "table" then error("RichTextPlus class definition must be a table", 3) end

	const Kind: string = Definition.Kind
	const Valid: boolean = (Kind == "Object" and Definition.Build ~= nil)
		or (Kind == "Style" and Definition.Apply ~= nil)
		or (Kind == "Container" and Definition.Wrap ~= nil)
		or (Kind == "Effect" and type(Definition.Update) == "function")

	if not Valid then error(`RichTextPlus class Kind "{Kind}" needs Object+Build, Style+Apply, Container+Wrap or Effect+Update`, 3) end
end

const function Register(Owner: any, Name: string, Definition: Definition?): ()
	if Owner == nil then error("RichTextPlus classes belong to a renderer: use renderer:AddCustomClass(Name, Definition)", 2) end
	if Owner.Destroyed then return end

	const Key: string = string.lower(Name)
	const Target: Registry? = Owned[Owner]

	if Definition == nil then
		if Target then (Target :: Registry)[Key] = nil end

		return
	end

	const Accepted: Definition = Definition :: Definition
	Validate(Accepted)

	if Target then (Target :: Registry)[Key] = Accepted else Owned[Owner] = {[Key] = Accepted} end
end

const function Find(Owner: any, Key: string): Definition?
	const Target: Registry? = Owned[Owner]

	return if Target then Target[Key] else nil
end

const function Clear(Owner: any): ()
	Owned[Owner] = nil
end

return {
	Load = Load;
	ForTag = ForTag;
	Has = Has;
	Register = Register;
	Find = Find;
	Clear = Clear;
}
