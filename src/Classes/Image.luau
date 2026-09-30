--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")

const MaximumDimension: number = Config.Classes.MAXIMUM_IMAGE_DIMENSION

const function Source(Node: Types.Node): string?
	const Value: string? = Styles.Attribute(Node, "Src"); if not Value then return nil end

	return Styles.CanonicalId(Value :: string)
end

const function Dimension(Node: Types.Node, Name: string): number?
	const Value: number? = tonumber(Styles.Attribute(Node, Name)); if not Value then return nil end

	return math.clamp(Value :: number, 0, MaximumDimension)
end

const function Build(Node: Types.Node, Style: Types.Style, Scale: number): GuiObject?
	const Asset: string? = Source(Node); if not Asset then return nil end

	const Default: number = math.floor(Style.Size * 1.25 + 0.5)
	const Uniform: number? = Dimension(Node, "Size")
	const Width: number? = Dimension(Node, "Width") or Uniform
	const Height: number? = Dimension(Node, "Height") or Uniform

	const Image: ImageLabel = Instance.new("ImageLabel")
	Image.Name = "InlineImage"
	Image.BackgroundTransparency = 1
	Image.Image = Asset :: string
	Image.ScaleType = Enum.ScaleType.Fit
	Image.Size = UDim2.fromOffset(
		if Width then math.floor(Width :: number * Scale + 0.5) else Default,
		if Height then math.floor(Height :: number * Scale + 0.5) else Default
	)

	return Image
end

return {
	Kind = "Object";
	Void = true;
	Source = Source;
	Build = Build;
}
