--!strict
--!native
--!optimize 2

const RichTextPlus = require("./Packages/RichTextPlus")

type Node = RichTextPlus.Node
type Style = RichTextPlus.Style
type Owner = RichTextPlus.Renderer

const Utilities = RichTextPlus.Utilities

const MaximumDimension: number = 1024
const MaximumVolume: number = 1

const function Clamped(Node: Node, Name: string, Maximum: number): number?
	const Value: number? = Utilities.AttributeNumber(Node, Name)

	return if Value then math.clamp(Value :: number, 0, Maximum) else nil
end

const function Source(Node: Node, State: Owner): string?
	const Raw: string? = Utilities.Attribute(Node, "src"); if not Raw then return nil end
	const Asset: string? = Utilities.CanonicalId(Raw :: string); if not Asset then return nil end

	return if State:AllowsAsset(Asset :: string) then Asset else nil
end

const function Size(Node: Node, Style: Style, Scale: number): UDim2
	const Default: number = math.floor(Style.Size * 1.25 + 0.5)
	const Uniform: number? = Clamped(Node, "size", MaximumDimension)
	const Width: number? = Clamped(Node, "width", MaximumDimension) or Uniform
	const Height: number? = Clamped(Node, "height", MaximumDimension) or Uniform

	return UDim2.fromOffset(
		if Width then math.floor(Width :: number * Scale + 0.5) else Default,
		if Height then math.floor(Height :: number * Scale + 0.5) else Default
	)
end

const function Build(Node: Node, Style: Style, Scale: number, State: Owner): GuiObject?
	const Asset: string? = Source(Node, State); if not Asset then return nil end

	const Video: VideoFrame = Instance.new("VideoFrame")
	Video.Name = "InlineVideo"
	Video.BackgroundTransparency = 1
	Video.Video = Asset :: string
	Video.Looped = Utilities.AttributeBoolean(Node, "looped", true)
	Video.Playing = Utilities.AttributeBoolean(Node, "playing", false)
	Video.Volume = Clamped(Node, "volume", MaximumVolume) or 0
	Video.Size = Size(Node, Style, Scale)

	return Video
end

const VideoClass: RichTextPlus.ClassDefinition = {
	Kind = "Object";
	Build = Build;
}

return VideoClass
