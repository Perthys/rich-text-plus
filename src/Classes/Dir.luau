--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")

const Directions: { [string]: "Ltr" | "Rtl" } = {
	["ltr"] = "Ltr";
	["rtl"] = "Rtl";
}

const function Apply(Style: Types.Style, Node: Types.Node): ()
	const Value: string? = Styles.Attribute(Node, "Value")
	const Direction: ("Ltr" | "Rtl")? = if Value then Directions[Styles.LowerName(Value :: string)] else nil

	if Direction then Style.Direction = Direction end
end

return {
	Kind = "Style";
	Apply = Apply;
}
