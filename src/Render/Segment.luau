--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Classes = require("../Classes")
const Styles = require("../Utility/Styles")
const Measure = require("../Text/Measure")
const Unicode = require("../Text/Unicode")
const Backdrop = require("./Backdrop")
const Pixel = require("../Utility/Pixel")
const Characters = require("../Utility/Characters")
const Elements = require("../Elements")

type Run = Types.Run

const HoverTint: number = Config.Segment.HOVER_TINT
const EffectSeedScale: number = Config.Segment.EFFECT_SEED_SCALE
const White: Color3 = Color3.new(1, 1, 1)
const Unset: number = -math.huge
const WidePattern: string = Characters.WIDE_PATTERN

const Probe: TextLabel = Instance.new("TextLabel")
const DefaultStrokeColor: Color3 = Probe.TextStrokeColor3
const DefaultStrokeTransparency: number = Probe.TextStrokeTransparency
Probe:Destroy()

local EffectModule: any = nil

const function Builtins(): any
	if EffectModule then return EffectModule end

	EffectModule = Classes.Load("Effect")

	return EffectModule
end

const function Upper(Text: string, Case: string?): boolean
	return Case == "Upper" and not string.find(Text, WidePattern)
end

const function Rich(Style: Types.Style, Text: string): boolean
	if Style.Underline or Style.Strike then return true end

	const Case: string? = Style.Case

	return Case ~= nil and not Upper(Text, Case)
end

const function Compose(Text: string, Style: Types.Style, Hovered: boolean): string
	const Case: string? = Style.Case

	local Result: string = if Upper(Text, Case) then Measure.Cased(string.upper(Text), nil) else Measure.Cased(Text, Case)

	if Style.Strike then Result = `<s>{Result}</s>` end
	if Style.Underline or Hovered then Result = `<u>{Result}</u>` end

	return Result
end

const function Markup(Text: string, Style: Types.Style, Hovered: boolean): string
	if Hovered or Rich(Style, Text) then return Compose(Text, Style, Hovered) end

	return if Upper(Text, Style.Case) then string.upper(Text) else Text
end

const function Fade(State: Types.Fields, Record: Types.Record): ()
	const Style: Types.Style? = Record.Style
	const Label: TextLabel? = Record.Label
	if not (Style and Label) then return end

	const Developer: number = State.Developer.Transparency
	const Look: Types.LookData = Record.Look
	const Motion: Types.MotionData? = Record.Motion
	const Alpha: number? = if Motion then Motion.Alpha else nil
	const StrokeAlpha: number? = if Motion then Motion.StrokeAlpha else nil
	const Transparency: number = Styles.CombineTransparency(Developer, Alpha or (Style :: Types.Style).Transparency)

	if Look.Transparency ~= Transparency then
		Label.TextTransparency = Transparency
		Look.Transparency = Transparency
	end

	const Stroke: UIStroke? = Record.Decor.Stroke
	const Data: Types.StrokeData? = (Style :: Types.Style).Stroke
	if Stroke and Data then Stroke.Transparency = Styles.CombineTransparency(Developer, StrokeAlpha or Data.Transparency) end
end

const function Trace(State: Types.Fields, Record: Types.Record): ()
	const Label: TextLabel? = Record.Label; if not Label then return end

	const Host: TextLabel = State.Label
	const Outline: Types.OutlineData = Record.Decor.Outline
	const Color: Color3 = Host.TextStrokeColor3
	const Transparency: number = Host.TextStrokeTransparency

	if Outline.Color ~= Color then (Label :: TextLabel).TextStrokeColor3 = Color; Outline.Color = Color end
	if Outline.Transparency ~= Transparency then (Label :: TextLabel).TextStrokeTransparency = Transparency; Outline.Transparency = Transparency end
end

const function Write(Content: Types.ContentData, Label: TextLabel, Text: string, Enabled: boolean): ()
	if not Enabled and Content.Rich ~= false then Label.RichText = false; Content.Rich = false end
	if Content.Text ~= Text then Label.Text = Text; Content.Text = Text end
	if Enabled and Content.Rich ~= true then Label.RichText = true; Content.Rich = true end
end

const function Emphasis(Content: Types.ContentData, Style: Types.Style): string
	const Cached: string? = Content.HoverText; if Cached then return Cached :: string end

	const Created: string = Markup(Content.Raw, Style, true)
	Content.HoverText = Created

	return Created
end

const function Tint(Record: Types.Record): Color3?
	local Current: Types.Element? = Record.Element

	while Current do
		const Target: Types.Element = Current :: Types.Element
		const State: Types.ElementState = Target.State

		if State.Pressed and Target.PressColor then return Target.PressColor end
		if State.Hovered and Target.HoverColor then return Target.HoverColor end

		Current = Target.Parent
	end

	return nil
end

const function Paint(Record: Types.Record): ()
	const Target: Types.Element? = Record.Element
	const Style: Types.Style? = Record.Style
	const Owner: Types.Fields? = Record.Owner :: any
	if not (Target and Style and Owner and Record.Button) then return end

	const Button: TextButton = Record.Instance :: TextButton
	const Content: Types.ContentData = Record.Content
	const Look: Types.LookData = Record.Look
	const Formatted: boolean = Content.Rich == true
	const Emphasized: boolean = (Style :: Types.Style).Link ~= nil and (Target :: Types.Element).State.Hovered and Content.Revealed ~= 0

	local Color: Color3? = Tint(Record)

	if Emphasized and not Color then Color = (Owner :: Types.Fields).Theme.LinkHoverColor or (Style :: Types.Style).Color:Lerp(White, HoverTint) end

	if Emphasized then
		Button.Text = Emphasis(Content, Style :: Types.Style)
		if not Formatted then Button.RichText = true end
	elseif Button.Text ~= Content.Text then
		if not Formatted then Button.RichText = false end
		Button.Text = Content.Text
	end

	const Final: Color3 = Color or (Style :: Types.Style).Color
	if Look.Color ~= Final then Button.TextColor3 = Final; Look.Color = Final end
end

const function Active(Target: Types.Element): boolean
	local Current: Types.Element? = Target

	while Current do
		const State: Types.ElementState = (Current :: Types.Element).State
		if State.Hovered or State.Pressed then return true end

		Current = (Current :: Types.Element).Parent
	end

	return false
end

const PaintStack: { Types.Element } = {}

const function PaintTree(Target: Types.Element): ()
	const Stack: { Types.Element } = PaintStack
	const Base: number = #Stack

	table.insert(Stack, Target)

	while #Stack > Base do
		const Current: Types.Element = table.remove(Stack) :: Types.Element
		const Records: { Types.Record }? = Current.Records

		if Records then
			for _, Record: Types.Record in (Records :: { Types.Record }) do Paint(Record) end
		end

		for _, Child: Types.Element in (Current.Children) do table.insert(Stack, Child) end
	end
end

Elements.SetPainter(PaintTree)

const function Pressable(Input: InputObject): boolean
	const Kind: Enum.UserInputType = Input.UserInputType

	return Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch
end

const function Connect(Record: Types.Record, Button: TextButton): ()
	Button.MouseEnter:Connect(function() Elements.Enter(Record) end)
	Button.MouseLeave:Connect(function() Elements.Leave(Record) end)
	Button.Activated:Connect(function() Elements.Activate(Record) end)
	Button.InputBegan:Connect(function(Input: InputObject) if Pressable(Input) then Elements.Press(Record, true) end end)
	Button.InputEnded:Connect(function(Input: InputObject) if Pressable(Input) then Elements.Press(Record, false) end end)
	Button.SelectionGained:Connect(function() Elements.Focus(Record, true) end)
	Button.SelectionLost:Connect(function() Elements.Focus(Record, false) end)
end

const function NewRecord(Object: GuiObject, Label: TextLabel?, Button: boolean): Types.Record
	return {
		Instance = Object;
		Label = Label;
		Owner = nil;
		Button = Button;
		Depth = 1;
		Style = nil;
		Element = nil;
		Shown = true;
		Parented = false;
		Content = {Raw = "", Text = "", Rich = false, HoverText = nil, Graphemes = 1, Gaps = nil, Revealed = -1};
		Look = {Font = nil, Color = nil, Size = -1, Transparency = 0};
		X = Unset;
		Y = Unset;
		Left = Unset;
		Top = Unset;
		Width = -1;
		Height = -1;
		Reach = 0;
		Updates = nil;
		Layers = 0;
		Internal = false;
		Shift = nil;
		Seed = 0;
		Motion = nil;
		Decor = {
			Gradient = nil;
			Frame = -1;
			Stroke = nil;
			Wrapped = nil;
			Container = nil;
			Outline = if Label then {Color = DefaultStrokeColor, Transparency = DefaultStrokeTransparency} else {Color = nil, Transparency = nil};
		};
		Decoration = {List = {}, Sources = {}, Version = -1};
	}
end

const function Raise(Object: GuiObject, Shift: number): ()
	if Shift == 0 then return end

	Object.ZIndex += Shift

	for _, Child: Instance in (Object:GetDescendants()) do
		if Child:IsA("GuiObject") then (Child :: GuiObject).ZIndex += Shift end
	end
end

const function Stack(Record: Types.Record, Depth: number): ()
	const Current: number = Record.Depth
	if Current == Depth then return end

	Raise(Record.Instance, Depth - Current)
	Record.Depth = Depth
end

const function Adopt(State: Types.Fields, Record: Types.Record): Types.Record
	Record.Owner = State
	State.Instances.Records[Record.Instance] = Record
	Stack(Record, State.Label.ZIndex)

	return Record
end

const function Create(State: Types.Fields, Button: boolean): Types.Record
	local Object: GuiObject

	if Button then
		const Created: TextButton = Instance.new("TextButton")
		Created.AutoButtonColor = false
		Object = Created
	else
		Object = Instance.new("TextLabel")
	end

	const Label: TextLabel = Object :: TextLabel
	Label.Name = "Segment"
	Label.AutoLocalize = false
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label:SetAttribute(Attributes.Marker, true)

	const Record: Types.Record = NewRecord(Object, Label, Button)
	if Button then Connect(Record, Object :: TextButton) end

	return Adopt(State, Record)
end

const function Destroy(State: Types.Fields, Record: Types.Record): ()
	State.Instances.Records[Record.Instance] = nil
	Record.Instance:Destroy()
end

const function Unwrap(Decor: Types.DecorData): ()
	const Wrapped: GuiObject? = Decor.Wrapped
	if Wrapped then (Wrapped :: GuiObject):Destroy() end

	Decor.Wrapped = nil
	Decor.Container = nil
end

const function Strip(Copies: Types.CopyData): ()
	for _, Old: Instance in (Copies.List) do Old:Destroy() end

	table.clear(Copies.List)
	table.clear(Copies.Sources)
end

const function Still(Record: Types.Record): ()
	const Motion: Types.MotionData? = Record.Motion; if not Motion then return end

	const Label: TextLabel? = Record.Label
	if Label and Motion.Rotation ~= 0 then Label.Rotation = 0 end

	Motion.Rotation = 0
	Motion.Tinted = false
	Motion.Alpha = nil
	Motion.StrokeColor = nil
	Motion.StrokeAlpha = nil
end

const function Reset(Record: Types.Record): ()
	const Decor: Types.DecorData = Record.Decor

	Strip(Record.Decoration)
	Unwrap(Decor)

	if Record.Layers > 0 then
		Record.X = Unset
		Record.Left = Unset
	end

	Still(Record)

	Record.Owner = nil
	Record.Element = nil
	Record.Style = nil
	Record.Parented = false
	Record.Layers = 0
	Record.Motion = nil
	Record.Decoration.Version = -1

	if not Record.Button then return end

	Record.Content.Text = ""
	Record.Content.Rich = nil
	Record.Look.Color = nil
end

const function Decoration(Child: Instance): boolean
	if Child:GetAttribute(Attributes.Marker) then return false end
	if Child:IsA("UIGradient") then return true end

	return Child:IsA("UIStroke") and (Child :: UIStroke).ApplyStrokeMode ~= Enum.ApplyStrokeMode.Border
end

const function Collect(State: Types.Fields): ()
	State.Decoration.Dirty = false
	State.Decoration.Version += 1

	const Sources: { Instance } = State.Decoration.List
	table.clear(Sources)

	for _, Child: Instance in (State.Label:GetChildren()) do
		if not Decoration(Child) then continue end

		table.insert(Sources, Child)
	end
end

const function Covered(Previous: Types.Style?, Style: Types.Style): boolean
	if not Previous then return false end

	return ((Previous :: Types.Style).Stroke == nil) == (Style.Stroke == nil) and ((Previous :: Types.Style).Gradient == nil) == (Style.Gradient == nil)
end

const function Decorate(State: Types.Fields, Record: Types.Record, Style: Types.Style, Previous: Types.Style?): ()
	const Copies: Types.CopyData = Record.Decoration
	if Copies.Version == State.Decoration.Version and Covered(Previous, Style) then return end

	Strip(Copies)

	for _, Source: Instance in (State.Decoration.List) do
		if Style.Stroke and Source:IsA("UIStroke") then continue end
		if Style.Gradient and Source:IsA("UIGradient") then continue end

		const Copy: Instance = Source:Clone()
		Copy.Parent = Record.Instance
		table.insert(Copies.List, Copy)
		table.insert(Copies.Sources, Source)
	end

	Copies.Version = State.Decoration.Version
end

const function Read(Target: Instance, Property: string): any
	return (Target :: any)[Property]
end

const function Assign(Target: Instance, Property: string, Value: any): ()
	(Target :: any)[Property] = Value
end

const function Propagate(State: Types.Fields, Source: Instance, Property: string): ()
	if Property == "Parent" or Property == "Name" then return end

	const Ok: boolean, Value: any = pcall(Read, Source, Property); if not Ok then return end

	for _, Record: Types.Record in (State.Instances.Records) do
		const Copies: Types.CopyData = Record.Decoration

		for Index: number, Copy: Instance in (Copies.List) do
			if Copies.Sources[Index] == Source then pcall(Assign, Copy, Property, Value) end
		end
	end
end

const function StrokeFor(State: Types.Fields, Record: Types.Record, Style: Types.Style): ()
	const Decor: Types.DecorData = Record.Decor
	const Data: Types.StrokeData? = Style.Stroke

	if not Data then
		if Decor.Stroke then (Decor.Stroke :: UIStroke):Destroy(); Decor.Stroke = nil end

		return
	end

	const Existing: UIStroke? = Decor.Stroke
	const Stroke: UIStroke = Existing or Instance.new("UIStroke")
	Stroke.Color = (Data :: Types.StrokeData).Color
	Stroke.Thickness = (Data :: Types.StrokeData).Thickness * State.Scale.Factor
	Stroke.LineJoinMode = (Data :: Types.StrokeData).Joins
	if not Existing then Stroke.Parent = Record.Instance end
	Decor.Stroke = Stroke
end

const function GradientFor(Record: Types.Record, Style: Types.Style): ()
	const Decor: Types.DecorData = Record.Decor
	const Data: Types.Gradient? = Style.Gradient

	if not Data then
		if Decor.Gradient then (Decor.Gradient :: UIGradient):Destroy(); Decor.Gradient = nil end

		return
	end

	const Existing: UIGradient? = Decor.Gradient
	const Gradient: UIGradient = Existing or Instance.new("UIGradient")
	Gradient.Color = (Data :: Types.Gradient).Sequence
	Gradient.Rotation = (Data :: Types.Gradient).Rotation
	if not Existing then Gradient.Parent = Record.Instance end
	Decor.Gradient = Gradient
	Decor.Frame = -1
end

const function Stroked(Left: Types.StrokeData?, Right: Types.StrokeData?): boolean
	if Left == Right then return true end
	if not (Left and Right) then return false end

	return (Left :: Types.StrokeData).Color == (Right :: Types.StrokeData).Color
		and (Left :: Types.StrokeData).Thickness == (Right :: Types.StrokeData).Thickness
		and (Left :: Types.StrokeData).Joins == (Right :: Types.StrokeData).Joins
		and (Left :: Types.StrokeData).Transparency == (Right :: Types.StrokeData).Transparency
end

const function Twin(Left: Types.Style, Right: Types.Style): boolean
	return Left.Family == Right.Family
		and Left.Size == Right.Size
		and Left.Color == Right.Color
		and Left.Weight == Right.Weight
		and Left.Bold == Right.Bold
		and Left.Italic == Right.Italic
		and Left.Underline == Right.Underline
		and Left.Strike == Right.Strike
		and Left.Case == Right.Case
		and Left.Link == Right.Link
		and Left.Element == Right.Element
		and Left.Transparency == Right.Transparency
		and Left.Gradient == nil and Right.Gradient == nil
		and Left.Effect == nil and Right.Effect == nil
		and Left.Container == nil and Right.Container == nil
		and Stroked(Left.Stroke, Right.Stroke)
end

const function Restyle(State: Types.Fields, Record: Types.Record, Style: Types.Style, Size: number): ()
	const Label: TextLabel = Record.Label :: TextLabel
	const Face: Font = Measure.FontOf(Style)
	const Color: Color3 = Style.Color
	const Previous: Types.Style? = Record.Style
	const Look: Types.LookData = Record.Look

	if Look.Font ~= Face then Label.FontFace = Face; Look.Font = Face end
	if Look.Size ~= Size then Label.TextSize = Size; Look.Size = Size end
	if Look.Color ~= Color then Label.TextColor3 = Color; Look.Color = Color end

	Record.Style = Style
	Record.Content.HoverText = nil
	Record.X = Unset
	Record.Left = Unset

	Still(Record)
	StrokeFor(State, Record, Style)
	GradientFor(Record, Style)
	Decorate(State, Record, Style, Previous)
	Trace(State, Record)
	Fade(State, Record)

	const Decor: Types.DecorData = Record.Decor
	const Container: Types.ContainerData? = Style.Container
	if Container == Decor.Container then return end

	Unwrap(Decor)
	if not Container then return end

	const Data: Types.ContainerData = Container :: Types.ContainerData
	const Extra: GuiObject? = Data.Wrap(Data.Node, Style, Record.Instance)

	Decor.Container = Data
	if not Extra or Extra == Record.Instance then return end

	const Wrapper: GuiObject = Extra :: GuiObject

	Raise(Wrapper, Record.Depth - 1)
	Wrapper.Parent = Record.Instance
	Decor.Wrapped = Wrapper
end

const function Resolve(State: Types.Fields, Name: string): Types.EffectUpdate?
	const Builtin: Types.ClassDefinition? = Builtins().Definitions[Name]
	const Definition: Types.ClassDefinition? = Builtin or Classes.Find(State, Name)

	return if Definition and Definition.Kind == "Effect" then Definition.Update else nil
end

const function Effects(State: Types.Fields, Record: Types.Record, Style: Types.Style): ()
	Record.Reach = 0
	Record.Layers = 0
	Record.Shift = nil

	local Layer: Types.EffectData? = Style.Effect
	if not Layer then Still(Record); return end

	const Internal: { [Types.EffectUpdate]: Types.EffectOffset } = Builtins().Internal
	const Updates: { Types.EffectUpdate | false } = Record.Updates or {}
	local Count: number = 0
	local Reach: number = 0
	local Found: boolean = false
	local Trusted: boolean = true

	while Layer do
		const Current: Types.EffectData = Layer :: Types.EffectData
		const Update: Types.EffectUpdate? = Resolve(State, Current.Name)

		Count += 1
		Updates[Count] = Update or false
		Reach += Current.Amplitude * 2

		if Update then
			Found = true
			if not Internal[Update :: Types.EffectUpdate] then Trusted = false end
		end

		Layer = Current.Parent
	end

	for Index = #Updates, Count + 1, -1 do Updates[Index] = nil end

	Record.Updates = Updates
	Record.Reach = Reach
	if not Found then Still(Record); return end

	Record.Layers = Count
	Record.Internal = Trusted
	Record.Shift = if Trusted and Count == 1 then Internal[Updates[1] :: Types.EffectUpdate] else nil
	Record.Seed = Record.X * EffectSeedScale
	table.insert(State.Animation.Moving, Record)
end

const function Link(Record: Types.Record, Style: Types.Style): ()
	const Target: Types.Element? = Style.Element

	Record.Element = Target
	if not Target then return end

	const Records: { Types.Record }? = (Target :: Types.Element).Records
	if Records then table.insert(Records :: { Types.Record }, Record) end

	if Active(Target :: Types.Element) then Paint(Record) end
end

const function Move(Record: Types.Record, Object: GuiObject, X: number, Y: number): ()
	Record.X = X
	Record.Y = Y

	const Left: number = Pixel.Truncate(X)
	const Top: number = Pixel.Truncate(Y)
	if Left == Record.Left and Top == Record.Top then return end

	Object.Position = Pixel.Offset(Left, Top)
	Record.Left = Left
	Record.Top = Top
end

const function Resize(Record: Types.Record, Object: GuiObject, Width: number, Height: number): ()
	const Wide: number = Pixel.Truncate(Width)
	const Tall: number = Pixel.Truncate(Height)
	const Same: boolean = Record.Width >= 0 and Pixel.Truncate(Record.Width) == Wide and Pixel.Truncate(Record.Height) == Tall

	Record.Width = Width
	Record.Height = Height

	if not Same then Object.Size = Pixel.Offset(Wide, Tall) end
end

const function Show(State: Types.Fields, Record: Types.Record, Object: GuiObject): ()
	if Record.Shown or State.Cull.Culled then return end

	Object.Visible = true
	Record.Shown = true
end

const function Apply(State: Types.Fields, Record: Types.Record, Run: Run): ()
	const Style: Types.Style = Run.Style :: Types.Style
	const Label: TextLabel = Record.Label :: TextLabel
	const Size: number = Measure.Scaled(Style.Size, State.Scale.Factor)
	const Decorated: boolean = Record.Decoration.Version == State.Decoration.Version
	const Previous: Types.Style? = Record.Style
	const Look: Types.LookData = Record.Look

	if Previous ~= Style or Look.Size ~= Size or not Decorated then
		const Kept: boolean = Previous ~= nil and Look.Size == Size and Decorated and Twin(Previous :: Types.Style, Style)

		if Kept then Record.Style = Style else Restyle(State, Record, Style, Size) end
	end

	const Content: Types.ContentData = Record.Content
	const Raw: string = Run.Text
	const Joined: string? = Run.Markup

	if Content.Raw ~= Raw or Previous ~= Style or Joined then
		if Content.Raw ~= Raw then
			Content.Raw = Raw
			Content.HoverText = nil
			Content.Graphemes = Unicode.Count(Raw)
		end

		if Joined then Write(Content, Label, Joined :: string, true) else Write(Content, Label, Markup(Raw, Style, false), Rich(Style, Raw)) end
	end

	Content.Gaps = Run.Gaps

	const Width: number = math.ceil(Run.Width)

	if Run.X ~= Record.X or Run.Y ~= Record.Y then Move(Record, Label, Run.X, Run.Y) end
	if Width ~= Record.Width or Run.Height ~= Record.Height then Resize(Record, Label, Width, Run.Height) end

	Show(State, Record, Label)

	if not Record.Parented then Label.Parent = State.Label; Record.Parented = true end

	Effects(State, Record, Style)
	Link(Record, Style)

	const Gradient: Types.Gradient? = Style.Gradient
	if Gradient and (Gradient :: Types.Gradient).Speed ~= 0 then table.insert(State.Animation.Animated, Record) end
end

const function Place(State: Types.Fields, Run: Run): Types.Record
	const Object: GuiObject = Run.Object :: GuiObject
	const Placed: Types.Record = State.Instances.Records[Object] or NewRecord(Object, nil, false)

	State.Instances.Records[Object] = Placed

	if Run.X ~= Placed.X or Run.Y ~= Placed.Y then Move(Placed, Object, Run.X, Run.Y) end
	if Run.Width ~= Placed.Width or Run.Height ~= Placed.Height then Resize(Placed, Object, Run.Width, Run.Height) end

	Stack(Placed, State.Label.ZIndex)

	if not Placed.Parented then Object.Parent = State.Label; Placed.Parented = true end

	Show(State, Placed, Object)

	return Placed
end

const function Outline(State: Types.Fields): ()
	for _, Record: Types.Record in (State.Instances.Segments) do Trace(State, Record) end
	for _, Record: Types.Record in (State.Instances.Spare) do Trace(State, Record) end
end

const function ApplyTransparency(State: Types.Fields): ()
	for _, Record: Types.Record in (State.Instances.Segments) do Fade(State, Record) end

	Backdrop.Fade(State)
end

const function Restack(State: Types.Fields): ()
	const Depth: number = State.Label.ZIndex

	for _, Record: Types.Record in (State.Instances.Records) do Stack(Record, Depth) end

	Backdrop.Stack(State)
end

return {
	Rich = Rich;
	Compose = Compose;
	Stroked = Stroked;
	Adopt = Adopt;
	Create = Create;
	Destroy = Destroy;
	Reset = Reset;
	Collect = Collect;
	Decoration = Decoration;
	Propagate = Propagate;
	Apply = Apply;
	Place = Place;
	Outline = Outline;
	ApplyTransparency = ApplyTransparency;
	Restack = Restack;
	Activate = Elements.Activate;
	Enter = Elements.Enter;
	Leave = Elements.Leave;
	Press = Elements.Press;
	Focus = Elements.Focus;
	Paint = Paint;
}
