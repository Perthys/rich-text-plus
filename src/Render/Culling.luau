--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Registry = require("./Registry")
const Styles = require("../Utility/Styles")
const Lifetime = require("../Utility/Lifetime")

type View = {
	MinX: number;
	MinY: number;
	MaxX: number;
	MaxY: number;
	Stale: boolean;
}

const Empty: { GuiObject } = table.freeze({})
const Holders = Lifetime.Own("Culling.Holders", {} :: { [Types.Fields]: { GuiObject } })
const Views = Lifetime.Own("Culling.Views", {} :: { [Types.Fields]: View })

const function ViewOf(State: Types.Fields): View
	const Existing: View? = Views[State]; if Existing then return Existing :: View end

	const Created: View = {MinX = 0, MinY = 0, MaxX = 0, MaxY = 0, Stale = true}
	Views[State] = Created

	return Created
end

const function Frame(Collector: LayerCollector, Clippers: { GuiObject }, Target: View): ()
	const CollectorPosition: Vector2 = Collector.AbsolutePosition
	const CollectorSize: Vector2 = Collector.AbsoluteSize

	local MinX: number = CollectorPosition.X
	local MinY: number = CollectorPosition.Y
	local MaxX: number = MinX + CollectorSize.X
	local MaxY: number = MinY + CollectorSize.Y

	for _, Clipper: GuiObject in (Clippers) do
		const Position: Vector2 = Clipper.AbsolutePosition
		const Size: Vector2 = Clipper.AbsoluteSize

		MinX = math.max(MinX, Position.X)
		MinY = math.max(MinY, Position.Y)
		MaxX = math.min(MaxX, Position.X + Size.X)
		MaxY = math.min(MaxY, Position.Y + Size.Y)
	end

	Target.MinX = MinX
	Target.MinY = MinY
	Target.MaxX = MaxX
	Target.MaxY = MaxY
	Target.Stale = false
end

const function Release(State: Types.Fields): ()
	const Cull: Types.CullData = State.Cull

	State.Troves.Cull:Clean()
	table.clear(Cull.Clippers)
	Holders[State] = nil

	Cull.Collector = nil
	Cull.ChainDirty = true
	Cull.Culled = false
end

const function Chain(State: Types.Fields): ()
	const Trove = State.Troves.Cull
	const Cull: Types.CullData = State.Cull
	const Clippers: { GuiObject } = Cull.Clippers
	const Label: TextLabel = State.Label

	Release(State)
	Cull.ChainDirty = false

	const Holding: { GuiObject } = {}
	const Window: View = ViewOf(State)

	Holders[State] = Holding
	Window.Stale = true

	const function Invalidate(): ()
		Cull.Dirty = true
		Registry.Wake(State)
	end

	const function Reframe(): ()
		Window.Stale = true
		Invalidate()
	end

	const function Rechain(): ()
		Cull.ChainDirty = true
		Invalidate()
	end

	const function Rescale(): ()
		State.Scale.Ancestor = Styles.AncestorScale(Label)
		Invalidate()
	end

	const function Watch(Node: Instance): ()
		const Scaler: UIScale? = Node:FindFirstChildWhichIsA("UIScale")
		if Scaler then Trove:Connect((Scaler :: UIScale):GetPropertyChangedSignal("Scale"), Rescale) end
	end

	State.Scale.Ancestor = Styles.AncestorScale(Label)

	Trove:Connect(Label:GetPropertyChangedSignal("Visible"), Invalidate)
	Watch(Label)

	local Current: Instance? = Label.Parent

	while Current do
		const Node: Instance = Current :: Instance

		if Node:IsA("LayerCollector") then
			Cull.Collector = Node
			Trove:Connect(Node:GetPropertyChangedSignal("AbsoluteSize"), Reframe)
			Trove:Connect(Node:GetPropertyChangedSignal("AbsolutePosition"), Reframe)
			Trove:Connect(Node:GetPropertyChangedSignal("Enabled"), Invalidate)
			Watch(Node)

			return
		end

		if Node:IsA("GuiObject") then
			table.insert(Holding, Node)
			Trove:Connect(Node:GetPropertyChangedSignal("Visible"), Invalidate)
			Trove:Connect(Node:GetPropertyChangedSignal("ClipsDescendants"), Rechain)
			Watch(Node)

			if Node.ClipsDescendants then
				table.insert(Clippers, Node)
				Trove:Connect(Node:GetPropertyChangedSignal("AbsoluteSize"), Reframe)
				Trove:Connect(Node:GetPropertyChangedSignal("AbsolutePosition"), Reframe)
			end
		end

		Current = Node.Parent
	end
end

const function Visible(State: Types.Fields): boolean
	if not State.Label.Visible then return false end

	for _, Holder: GuiObject in (Holders[State] or Empty) do
		if not Holder.Visible then return false end
	end

	return true
end

const function Show(State: Types.Fields, Shown: boolean): ()
	for _, Record: Types.Record in (State.Instances.Segments) do
		if Record.Shown == Shown then continue end

		Record.Shown = Shown
		Record.Instance.Visible = Shown
	end
end

const function Apparent(State: Types.Fields): number
	const Ratio: number = State.Scale.Ancestor
	const Collector: LayerCollector? = State.Cull.Collector
	if not (Collector and Collector:IsA("SurfaceGui")) then return Ratio end

	const Surface: SurfaceGui = Collector :: SurfaceGui
	const Target: Instance? = Surface.Adornee or Surface.Parent
	const Camera: Camera? = workspace.CurrentCamera
	if not (Target and Target:IsA("BasePart") and Camera) then return Ratio end

	const Part: BasePart = Target :: BasePart
	const Size: Vector3 = Part.Size
	const Face: Enum.NormalId = Surface.Face
	const Across: number = if Face == Enum.NormalId.Left or Face == Enum.NormalId.Right then Size.Z else Size.X
	const Pixels: number = Surface.AbsoluteSize.X
	if Across <= 0 or Pixels <= 0 then return Ratio end

	const View: CFrame = (Camera :: Camera).CFrame
	const Offset: Vector3 = Part.Position - View.Position
	if Offset:Dot(View.LookVector) < -Size.Magnitude then return 0 end

	const Distance: number = math.max(Offset.Magnitude, 0.1)
	const PerStud: number = (Camera :: Camera).ViewportSize.Y / (2 * Distance * math.tan(math.rad((Camera :: Camera).FieldOfView) / 2))

	return Ratio * PerStud * Across / Pixels
end

const function Step(State: Types.Fields): boolean
	const Cull: Types.CullData = State.Cull

	if not State.Rendering.Culling then Cull.Dirty = false; return true end
	if Cull.ChainDirty then Chain(State) end
	if not Cull.Dirty then return not Cull.Culled end

	Cull.Dirty = false

	const Collector: LayerCollector? = Cull.Collector

	if not (Collector and (Collector :: LayerCollector).Enabled and Visible(State)) then
		Cull.Culled = true

		return false
	end

	const Window: View = ViewOf(State)
	if Window.Stale then Frame(Collector :: LayerCollector, Cull.Clippers, Window) end

	const MinX: number = Window.MinX
	const MinY: number = Window.MinY
	const MaxX: number = Window.MaxX
	const MaxY: number = Window.MaxY
	const Label: TextLabel = State.Label
	const Origin: Vector2 = Label.AbsolutePosition
	const LabelSize: Vector2 = Label.AbsoluteSize
	const Ratio: number = State.Scale.Ancestor
	const Padding: number = Cull.Padding * Ratio
	const Bounds: Types.BoundsData = Cull.Bounds

	const InView: boolean = Origin.X + math.max(LabelSize.X, Bounds.MaxX * Ratio) + Padding > MinX
		and Origin.Y + math.max(LabelSize.Y, Bounds.MaxY * Ratio) + Padding > MinY
		and Origin.X + math.min(0, Bounds.MinX * Ratio) - Padding < MaxX
		and Origin.Y + math.min(0, Bounds.MinY * Ratio) - Padding < MaxY

	Cull.Culled = not InView

	if not InView then
		Show(State, false)

		return false
	end

	for _, Record: Types.Record in (State.Instances.Segments) do
		const X: number = Origin.X + Record.X * Ratio
		const Y: number = Origin.Y + Record.Y * Ratio
		const Reach: number = Record.Reach * Ratio

		const Shown: boolean = X + Record.Width * Ratio + Reach > MinX
			and Y + Record.Height * Ratio + Reach > MinY
			and X - Reach < MaxX
			and Y - Reach < MaxY

		if Record.Shown == Shown then continue end

		Record.Shown = Shown
		Record.Instance.Visible = Shown
	end

	return true
end

return {
	Release = Release;
	Chain = Chain;
	Step = Step;
	Apparent = Apparent;
}
