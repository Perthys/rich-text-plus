--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Markdown = require("../Markdown")

const function Build(Node: Types.Node, Style: Types.Style, Scale: number, State: Types.Fields?): GuiObject?
	const Theme: Markdown.ResolvedTheme = Markdown.Theme(if State then State.Theme else nil)

	const Height: number = math.max(math.floor(Style.Size + 0.5), 1)
	const Requested: number = tonumber(Styles.Attribute(Node, "Thickness")) or 1
	const Thickness: number = math.clamp(math.floor(Requested * Scale + 0.5), 1, Height)

	const Frame: Frame = Instance.new("Frame")
	Frame.Name = "Rule"
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Size = UDim2.fromOffset(0, Height)

	const Line: Frame = Instance.new("Frame")
	Line.Name = "Line"
	Line.AnchorPoint = Vector2.new(0, 0.5)
	Line.BackgroundColor3 = Styles.ParseColor(Styles.Attribute(Node, "Color")) or Theme.RuleColor
	Line.BackgroundTransparency = Style.Transparency
	Line.BorderSizePixel = 0
	Line.Position = UDim2.fromScale(0, 0.5)
	Line.Size = UDim2.new(1, 0, 0, Thickness)
	Line.Parent = Frame

	return Frame
end

return {
	Kind = "Object";
	Block = true;
	Void = true;
	Build = Build;
}
