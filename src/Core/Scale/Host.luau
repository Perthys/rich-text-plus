--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Attributes = require("../../Utility/Attributes")
const Styles = require("../../Utility/Styles")

const FrozenMinimumHeight: number = Config.Scale.FROZEN_MINIMUM_HEIGHT

const function Echo(State: Types.Fields, Property: string): ()
	const Echoes: { [string]: number } = State.Host.Echoes

	Echoes[Property] = (Echoes[Property] or 0) + 1
end

const function Resize(State: Types.Fields, AutomaticSize: Enum.AutomaticSize, Size: UDim2?): ()
	const Label: TextLabel = State.Label

	if Label.AutomaticSize ~= AutomaticSize then
		Echo(State, "AutomaticSize")
		Label.AutomaticSize = AutomaticSize
	end

	if Size and Label.Size ~= Size then
		Echo(State, "Size")
		Label.Size = Size :: UDim2
	end
end

const function Release(State: Types.Fields): ()
	const Label: TextLabel = State.Label
	const Stored: Enum.AutomaticSize? = State.Developer.AutomaticSize

	if not Stored then
		if Label:GetAttribute(Attributes.DeveloperSize) ~= nil then Label:SetAttribute(Attributes.DeveloperSize, nil) end

		return
	end

	Resize(State, Stored :: Enum.AutomaticSize, Label:GetAttribute(Attributes.DeveloperSize) :: UDim2?)

	Label:SetAttribute(Attributes.DeveloperAutomaticSize, nil)
	Label:SetAttribute(Attributes.DeveloperSize, nil)

	State.Developer.AutomaticSize = nil
end

const function Claim(State: Types.Fields): ()
	const Label: TextLabel = State.Label
	const Automatic: Enum.AutomaticSize = Label.AutomaticSize
	if Automatic == Enum.AutomaticSize.None then return end

	if not State.Developer.AutomaticSize then Label:SetAttribute(Attributes.DeveloperSize, Label.Size) end

	State.Developer.AutomaticSize = Automatic
	Label:SetAttribute(Attributes.DeveloperAutomaticSize, Automatic.Name)

	Resize(State, Enum.AutomaticSize.None, nil)
end

const function Grow(Axis: UDim, Content: number, Inset: number, Share: number, Parent: number): UDim
	return UDim.new(Axis.Scale, math.max(Axis.Offset, math.ceil((math.ceil(Content) + Inset) / Share - Parent * Axis.Scale)))
end

const function Inner(Outer: number, Inset: number, Share: number): number
	return math.max(math.floor(Outer * Share - Inset), 0)
end

const function Fit(State: Types.Fields, AutomaticX: boolean, AutomaticY: boolean, Width: number, Height: number, Content: Vector2): Vector2
	const Label: TextLabel = State.Label
	const Developer: UDim2 = (Label:GetAttribute(Attributes.DeveloperSize) :: UDim2?) or Label.Size
	const Parent: Instance? = Label.Parent
	const Frame: Vector2 = if Parent and Parent:IsA("GuiBase2d") then Styles.LocalSize(Parent :: any) else Vector2.zero
	const Padding: UIPadding? = Label:FindFirstChildWhichIsA("UIPadding")

	local Horizontal: number, HorizontalShare: number = 0, 1
	local Vertical: number, VerticalShare: number = 0, 1

	if Padding then
		const Left: UDim, Right: UDim = (Padding :: UIPadding).PaddingLeft, (Padding :: UIPadding).PaddingRight
		const Top: UDim, Bottom: UDim = (Padding :: UIPadding).PaddingTop, (Padding :: UIPadding).PaddingBottom

		Horizontal, HorizontalShare = Left.Offset + Right.Offset, math.max(1 - Left.Scale - Right.Scale, 0.01)
		Vertical, VerticalShare = Top.Offset + Bottom.Offset, math.max(1 - Top.Scale - Bottom.Scale, 0.01)
	end

	const X: UDim = if AutomaticX then Grow(Developer.X, Width, Horizontal, HorizontalShare, Frame.X) else Developer.X
	const Y: UDim = if AutomaticY then Grow(Developer.Y, Height, Vertical, VerticalShare, Frame.Y) else Developer.Y
	const Outer: Vector2 = Vector2.new(Frame.X * X.Scale + X.Offset, Frame.Y * Y.Scale + Y.Offset)

	Resize(State, Enum.AutomaticSize.None, UDim2.new(X, Y))

	State.Host.Width = Outer.X
	State.Host.Height = Outer.Y

	return Vector2.new(
		if AutomaticX then Inner(Outer.X, Horizontal, HorizontalShare) else Content.X,
		if AutomaticY then Inner(Outer.Y, Vertical, VerticalShare) else Content.Y
	)
end

const function Enforce(State: Types.Fields): ()
	const Label: TextLabel = State.Label

	if not Label.TextScaled then Claim(State); return end

	const Automatic: Enum.AutomaticSize = Label.AutomaticSize
	const Frozen: Vector2 = Styles.LocalSize(Label)
	if Automatic == Enum.AutomaticSize.None or Frozen.X <= 0 or Frozen.Y <= 0 then return end

	if not State.Developer.AutomaticSize then Label:SetAttribute(Attributes.DeveloperSize, Label.Size) end

	State.Developer.AutomaticSize = Automatic
	Label:SetAttribute(Attributes.DeveloperAutomaticSize, Automatic.Name)

	const Size: UDim2 = (Label:GetAttribute(Attributes.DeveloperSize) :: UDim2?) or Label.Size
	const Wide: boolean = Automatic ~= Enum.AutomaticSize.Y
	const Tall: boolean = Automatic ~= Enum.AutomaticSize.X
	const Width: UDim = if Wide then UDim.new(0, math.max(Frozen.X, Styles.MinimumBoxWidth)) else Size.X
	const Height: UDim = if Tall then UDim.new(0, math.max(Frozen.Y, FrozenMinimumHeight)) else Size.Y

	Resize(State, Enum.AutomaticSize.None, UDim2.new(Width, Height))
end

return {
	Echo = Echo;
	Release = Release;
	Fit = Fit;
	Enforce = Enforce;
}
