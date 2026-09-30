--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")

const function Open(Style: Types.Style, Node: Types.Node, LinkColor: Color3): ()
	Style.Link = Styles.Attribute(Node, "Href") or ""
	Style.Color = LinkColor
end

return {
	Kind = "Link";
	Open = Open;
}
