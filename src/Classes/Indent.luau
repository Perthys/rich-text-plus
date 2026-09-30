--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")

const function Size(Value: string?, TextSize: number, Scale: number): number?
	if not Value then return nil end

	const Amount: string?, Unit: string? = string.match(Styles.Trim(string.lower(Value :: string)), "^([%d%.]+)%s*(%a*)$")
	const Number: number? = if Amount then tonumber(Amount) else nil
	if not Number then return nil end

	if Unit == "em" then return (Number :: number) * TextSize end
	if Unit == "" or Unit == "px" then return (Number :: number) * Scale end

	return nil
end

const function Apply(Style: Types.Style, Node: Types.Node, State: Types.Fields?): ()
	const Scale: number = if State then Styles.EffectiveScale(State :: Types.Fields) else 1

	Style.Indent = {
		Size = Size(Styles.Attribute(Node, "By"), Style.Size, Scale);
		Repeat = Styles.Truthy(Styles.Attribute(Node, "Repeat"), false);
	}
end

return {
	Kind = "Style";
	Apply = Apply;
}
