--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Trove = require("../../Trove")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Registry = require("../Render/Registry")
const Styles = require("../Utility/Styles")
const Segment = require("../Render/Segment")
const Native = require("../Core/Native")
const Reveal = require("../Render/Reveal")
const Schedule = require("../Render/Schedule")
const Stage = require("./Stage")
const Transparency = require("./Transparency")
const Lifecycle = require("./Lifecycle")

type Fields = Types.Fields

const SIZE_TOLERANCE: number = Config.Renderer.SIZE_TOLERANCE
const NO_PADDING: UDim = UDim.new()

const PropertyStages: { [string]: number } = {
	["TextSize"] = Stage.Flatten;
	["FontFace"] = Stage.Flatten;
	["TextColor3"] = Stage.Flatten;
	["LineHeight"] = Stage.Scale;
	["TextWrapped"] = Stage.Scale;
	["TextScaled"] = Stage.Scale;
	["TextXAlignment"] = Stage.Layout;
	["TextYAlignment"] = Stage.Layout;
	["TextTruncate"] = Stage.Layout;
}

const PaddingProperties: { string } = {"PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom"}

const Join = Stage.Join
const Mirror = Transparency.Mirror

const function Restyle(State: Fields, Property: string): boolean
	const Value: any = (State.Label :: any)[Property]
	const Seen: { [string]: any } = State.Host.Seen
	if Seen[Property] == Value then return false end

	Seen[Property] = Value

	return true
end

const function Restyled(State: Fields): number?
	const Label: any = State.Label
	const Seen: { [string]: any } = State.Host.Seen

	local From: number? = nil

	for Property: string, Level: number in (PropertyStages) do
		const Value: any = Label[Property]
		if Seen[Property] == Value then continue end

		Seen[Property] = Value
		From = Join(From, Level)
	end

	return From
end

const function Repadded(State: Fields): boolean
	const Padding: UIPadding? = State.Label:FindFirstChildWhichIsA("UIPadding")
	const Seen: { [string]: any } = State.Host.Seen

	local Changed: boolean = false

	for _, Property: string in (PaddingProperties) do
		const Value: UDim = if Padding then (Padding :: any)[Property] else NO_PADDING
		if Seen[Property] == Value then continue end

		Seen[Property] = Value
		Changed = true
	end

	return Changed
end

const function Retext(State: Fields): boolean
	const Label: TextLabel = State.Label
	const Text: string = Label.Text
	const Markup: string? = State.Native.Markup
	const Shown: string? = if State.Native.Active then Markup else State.Document.Source

	if Text == Shown or Text == State.Host.Text then return false end

	Native.Churn(State)

	if State.Native.Active then
		const Source: string? = State.Native.Source

		if Markup and Source == State.Document.Source and Native.Rebase(State, Text) == Source and not Native.Volatile(State) then Label.Text = Markup :: string; return false end

		Mirror(State)
	end

	State.Host.Text = Text

	return true
end

const function Stretched(State: Fields, Size: Vector2): number?
	const Label: TextLabel = State.Label
	const WidthChanged: boolean = math.abs(Size.X - State.Host.Width) > SIZE_TOLERANCE
	const HeightChanged: boolean = math.abs(Size.Y - State.Host.Height) > SIZE_TOLERANCE

	if not (WidthChanged or HeightChanged) then return nil end
	if Label.TextScaled then return Stage.Scale end

	const AutomaticSize: Enum.AutomaticSize = Label.AutomaticSize
	const HeightFree: boolean = AutomaticSize == Enum.AutomaticSize.Y
		or AutomaticSize == Enum.AutomaticSize.XY
		or (Label.TextYAlignment == Enum.TextYAlignment.Top and not State.Rendering.Clipping)

	return if WidthChanged or not HeightFree then Stage.Layout else nil
end

const function Resized(State: Fields): number?
	if State.Native.Active then return nil end

	const Label: TextLabel = State.Label
	const Ratio: number = Styles.AncestorScale(Label)

	if Ratio ~= State.Scale.Ancestor then
		State.Scale.Ancestor = Ratio

		if State.Rendering.Culling then State.Cull.Dirty = true; Registry.Wake(State) end
	end

	return Stretched(State, Styles.LocalSize(Label, Ratio))
end

const function Poll(State: Fields): number?
	if State.Destroyed then return nil end

	local From: number? = Restyled(State)

	if Retext(State) then From = Join(From, Stage.Text) end
	if State.Native.Active then return From end

	const Label: TextLabel = State.Label

	if Repadded(State) then From = Join(From, if Label.TextScaled then Stage.Scale else Stage.Layout) end

	const Resize: number? = Stretched(State, Styles.LocalSize(Label, State.Scale.Ancestor))

	return if Resize then Join(From, Resize :: number) else From
end

const function Recull(State: Fields): ()
	State.Cull.ChainDirty = true
	State.Cull.Dirty = true
	Registry.Wake(State)
end

const Handlers: { [string]: (State: Fields) -> () } = {
	["Text"] = function(State: Fields): ()
		if Retext(State) then Schedule.Queue(State, Stage.Text) end
	end;
	["RichText"] = function(State: Fields): ()
		Native.Suppress(State)
	end;
	["TextStrokeColor3"] = function(State: Fields): ()
		if not State.Native.Active then Segment.Outline(State) end
	end;
	["TextStrokeTransparency"] = function(State: Fields): ()
		if not State.Native.Active then Segment.Outline(State) end
	end;
	["MaxVisibleGraphemes"] = function(State: Fields): ()
		if not State.Native.Active then Reveal.Apply(State) end
	end;
	["AutomaticSize"] = function(State: Fields): ()
		const Label: TextLabel = State.Label

		if Label.TextScaled and Label.AutomaticSize == Enum.AutomaticSize.None then
			State.Developer.AutomaticSize = nil
			Label:SetAttribute(Attributes.DeveloperAutomaticSize, nil)
		end

		Schedule.Queue(State, Stage.Scale)
	end;
	["TextTransparency"] = function(State: Fields): ()
		const Live: number = State.Label.TextTransparency
		if Live == Transparency.Expected(State) then return end

		State.Developer.Transparency = Live

		if Native.Showing(State) then Native.Remember(State); return end

		Mirror(State)
		Segment.ApplyTransparency(State)
	end;
	["Size"] = function(State: Fields): ()
		if State.Native.Active or not State.Developer.AutomaticSize then return end

		const Label: TextLabel = State.Label

		Label:SetAttribute(Attributes.DeveloperSize, Label.Size)
		if not Label.TextScaled then Schedule.Queue(State, Stage.Layout) end
	end;
	["AbsoluteSize"] = function(State: Fields): ()
		const From: number? = Resized(State)
		if From then Schedule.Queue(State, From :: number) end
	end;
	["ZIndex"] = function(State: Fields): ()
		Segment.Restack(State)
	end;
	["AbsolutePosition"] = function(State: Fields): ()
		if State.Native.Active or not State.Rendering.Culling then return end

		State.Cull.Dirty = true
		Registry.Wake(State)
	end;
}

const function Connect(State: Fields): ()
	const Label: TextLabel = State.Label
	const MainTrove: Trove.Trove = State.Troves.Main
	const Echoes: { [string]: number } = State.Host.Echoes

	MainTrove:Connect(Label.Changed, function(Property: string)
		if State.Destroyed then return end

		const Pending: number? = Echoes[Property]
		if Pending and Pending > 0 then Echoes[Property] = Pending - 1; return end

		const From: number? = PropertyStages[Property]
		if From then
			if Restyle(State, Property) then Schedule.Queue(State, From :: number) end

			return
		end

		const Handler: ((State: Fields) -> ())? = Handlers[Property]
		if Handler then (Handler :: (State: Fields) -> ())(State) end
	end)

	MainTrove:Connect(Label:GetAttributeChangedSignal(Attributes.Owner), function()
		if State.Destroyed then return end
		if Label:GetAttribute(Attributes.Owner) ~= State.Token then Lifecycle.Relinquish(State) end
	end)

	MainTrove:Connect(Label.AncestryChanged, function()
		if State.Destroyed or State.Native.Active or not State.Rendering.Culling then return end

		Recull(State)
	end)

	const Watched: { [Instance]: RBXScriptConnection } = {}

	const function OnPaddingChanged(): ()
		if State.Destroyed or State.Native.Active or not Repadded(State) then return end

		Schedule.Queue(State, if Label.TextScaled then Stage.Scale else Stage.Layout)
	end

	const function OnConstraintChanged(): ()
		if State.Destroyed or State.Native.Active or not Label.TextScaled then return end

		Schedule.Queue(State, Stage.Scale)
	end

	const function OnDecorationChanged(Source: Instance, Property: string): ()
		if State.Destroyed or State.Native.Active then return end
		if Property ~= "ApplyStrokeMode" then Segment.Propagate(State, Source, Property); return end

		State.Decoration.Dirty = true
		Schedule.Queue(State, Stage.Layout)
	end

	const function Watch(Child: Instance): ()
		if Watched[Child] or Child:GetAttribute(Attributes.Marker) then return end

		if Child:IsA("UIPadding") then
			Watched[Child] = MainTrove:Connect(Child.Changed, OnPaddingChanged)
		elseif Child:IsA("UITextSizeConstraint") then
			Watched[Child] = MainTrove:Connect(Child.Changed, OnConstraintChanged)
		elseif Child:IsA("UIStroke") or Child:IsA("UIGradient") then
			Watched[Child] = MainTrove:Connect(Child.Changed, function(Property: string) OnDecorationChanged(Child, Property) end)
		end
	end

	const function Unwatch(Child: Instance): ()
		const Connection: RBXScriptConnection? = Watched[Child]; if not Connection then return end

		Watched[Child] = nil
		MainTrove:Remove(Connection)
	end

	const function OnChild(Child: Instance, Added: boolean): ()
		if State.Destroyed or State.Instances.Records[Child :: GuiObject] then return end
		if Added then Watch(Child) else Unwatch(Child) end

		if Child:IsA("UIPadding") then OnPaddingChanged(); return end
		if Child:IsA("UITextSizeConstraint") then OnConstraintChanged(); return end

		if Child:IsA("UIScale") then
			if State.Native.Active or not State.Rendering.Culling then return end

			Recull(State)

			return
		end

		if not Segment.Decoration(Child) then return end

		State.Decoration.Dirty = true
		Schedule.Queue(State, Stage.Layout)
	end

	for _, Child: Instance in (Label:GetChildren()) do Watch(Child) end

	MainTrove:Connect(Label.ChildAdded, function(Child: Instance) OnChild(Child, true) end)
	MainTrove:Connect(Label.ChildRemoved, function(Child: Instance) OnChild(Child, false) end)

	MainTrove:Connect(Label.Destroying, function()
		Lifecycle.Teardown(State, true)
	end)
end

const function Adopt(State: Fields): ()
	Connect(State)
	Registry.Add(State)
	Restyled(State)
	Repadded(State)
end

return {
	Poll = Poll;
	Adopt = Adopt;
}
