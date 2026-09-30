--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Styles = require("../Utility/Styles")
const Pixel = require("../Utility/Pixel")

type Piece = Types.BackdropPiece
type Coverage = Types.Coverage

const SpareLimit: number = Config.Backdrop.SPARE_LIMIT

const function Outermost(Left: Piece, Right: Piece): boolean
	return Left.Depth < Right.Depth
end

const function Nesting(Mark: Types.MarkData): number
	local Depth: number = 0
	local Current: Types.MarkData? = Mark.Parent

	while Current do
		Depth += 1
		Current = (Current :: Types.MarkData).Parent
	end

	return Depth
end

const function Begin(Reuse: Coverage?): Coverage
	if not Reuse then return {Pieces = {}, Latest = {}, Spare = nil, From = 1, Y = 0, Height = 0, Nested = false} end

	const Coverage: Coverage = Reuse :: Coverage
	const Pieces: { Piece } = Coverage.Pieces
	const Spare: { Piece } = Coverage.Spare or {}

	Coverage.Spare = Spare

	for _, Piece: Piece in (Pieces) do table.insert(Spare, Piece) end

	table.clear(Pieces)
	table.clear(Coverage.Latest)

	Coverage.From = 1
	Coverage.Y = 0
	Coverage.Height = 0
	Coverage.Nested = false

	return Coverage
end

const function Row(Coverage: Coverage, Y: number, Height: number): ()
	Coverage.From = #Coverage.Pieces + 1
	Coverage.Y = Y
	Coverage.Height = Height
end

const function Extend(Coverage: Coverage, Span: Types.MarkData, Start: number, Finish: number, Pad: number): ()
	const Pieces: { Piece } = Coverage.Pieces

	for Index = Coverage.From, #Pieces do
		const Piece: Piece = Pieces[Index]
		if Piece.Mark ~= Span then continue end

		if Start < Piece.Start then Piece.Start = Start end
		if Finish > Piece.Finish then Piece.Finish = Finish end
		if Pad > Piece.Pad then Piece.Pad = Pad end

		return
	end

	const Depth: number = Nesting(Span)
	const Head: boolean = Coverage.Latest[Span] == nil
	const Spare: { Piece }? = Coverage.Spare
	const Reused: Piece? = if Spare then table.remove(Spare :: { Piece }) else nil

	local Created: Piece

	if Reused then
		Created = Reused :: Piece
		Created.Mark = Span
		Created.Start = Start
		Created.Finish = Finish
		Created.Y = Coverage.Y
		Created.Height = Coverage.Height
		Created.Pad = Pad
		Created.Head = Head
		Created.Tail = false
		Created.Depth = Depth
	else
		Created = {
			Mark = Span;
			Start = Start;
			Finish = Finish;
			Y = Coverage.Y;
			Height = Coverage.Height;
			Pad = Pad;
			Head = Head;
			Tail = false;
			Depth = Depth;
		}
	end

	if Depth > 0 then Coverage.Nested = true end

	table.insert(Pieces, Created)
	Coverage.Latest[Span] = Created
end

const function Cover(Coverage: Coverage, Style: Types.Style, Start: number, Width: number, Pad: number): ()
	local Mark: Types.MarkData? = Style.Mark
	local Padding: number = Pad

	while Mark do
		Extend(Coverage, Mark :: Types.MarkData, Start, Start + Width, Padding)

		Mark = (Mark :: Types.MarkData).Parent
		Padding = 0
	end
end

const function Stack(State: Types.Fields): ()
	const Depth: number = State.Label.ZIndex
	const Root: Frame? = State.Backdrop.Root

	if Root and (Root :: Frame).ZIndex ~= Depth then (Root :: Frame).ZIndex = Depth end

	for _, Layer: Types.Layer in (State.Backdrop.Layers) do
		if Layer.Frame.ZIndex ~= Depth then Layer.Frame.ZIndex = Depth end

		const Fill: Frame? = Layer.Fill
		if Fill and (Fill :: Frame).ZIndex ~= Depth then (Fill :: Frame).ZIndex = Depth end
	end
end

const function Mount(State: Types.Fields, Frame: Frame, Layers: { Types.Layer }?): Frame
	const Label: TextLabel = State.Label

	State.Backdrop.Root = Frame
	if Layers then State.Backdrop.Layers = Layers :: { Types.Layer } end
	Stack(State)
	Frame.Parent = Label

	for _, List: { Types.Record } in ({State.Instances.Segments, State.Instances.Spare}) do
		for _, Record: Types.Record in (List) do
			if not Record.Parented then continue end

			Record.Instance.Parent = nil
			Record.Instance.Parent = Label
		end
	end

	return Frame
end

const function Root(State: Types.Fields): Frame
	const Existing: Frame? = State.Backdrop.Root; if Existing then return Existing :: Frame end

	const Created: Frame = Instance.new("Frame")
	Created.Name = "Backdrops"
	Created.BackgroundTransparency = 1
	Created.BorderSizePixel = 0
	Created.Size = UDim2.new()
	Created:SetAttribute(Attributes.Marker, true)

	return Mount(State, Created, nil)
end

const function Create(State: Types.Fields): Types.Layer
	const Frame: Frame = Instance.new("Frame")
	Frame.Name = "Backdrop"
	Frame.BorderSizePixel = 0
	Frame.ZIndex = State.Label.ZIndex
	Frame.Parent = Root(State)

	return {
		Frame = Frame;
		Fill = nil;
		Corner = nil;
		Mark = nil;
		Shown = true;
		Rect = {X = -math.huge, Y = -math.huge, Width = -1, Height = -1};
		Round = {Radius = 0, Left = false, Right = false};
		Paint = {Target = nil, Tint = nil, Alpha = -1};
	}
end

const function Partial(Round: Types.RoundData): boolean
	return Round.Radius > 0 and Round.Left ~= Round.Right
end

const function Paint(State: Types.Fields, Layer: Types.Layer): ()
	const Mark: Types.MarkData? = Layer.Mark; if not Mark then return end

	const Transparency: number = if (Mark :: Types.MarkData).Transparency >= 1 then 1
		else Styles.CombineTransparency(State.Developer.Transparency, (Mark :: Types.MarkData).Transparency)

	const Paint: Types.PaintData = Layer.Paint
	const Clipped: boolean = Partial(Layer.Round)
	const Target: Frame = if Clipped then Layer.Fill :: Frame else Layer.Frame
	const Color: Color3 = (Mark :: Types.MarkData).Color

	if Paint.Target ~= Target then
		if Clipped then Layer.Frame.BackgroundTransparency = 1 end

		Paint.Target = Target
		Paint.Tint = nil
		Paint.Alpha = -1
	end

	if Paint.Tint ~= Color then Target.BackgroundColor3 = Color; Paint.Tint = Color end
	if Paint.Alpha ~= Transparency then Target.BackgroundTransparency = Transparency; Paint.Alpha = Transparency end
end

const function Shape(Layer: Types.Layer, Radius: number, Left: boolean, Right: boolean): ()
	const Round: Types.RoundData = Layer.Round

	Round.Radius = Radius
	Round.Left = Left
	Round.Right = Right

	const Frame: Frame = Layer.Frame
	const Clipped: boolean = Partial(Round)

	Frame.ClipsDescendants = Clipped

	local Target: Frame = Frame

	if Clipped then
		const Existing: Frame? = Layer.Fill
		const Fill: Frame = Existing or Instance.new("Frame")

		Fill.Position = UDim2.fromOffset(if Left then 0 else -Radius, 0)
		Fill.Size = UDim2.new(1, Radius, 1, 0)

		if Existing then
			Fill.Visible = true
		else
			Fill.Name = "Fill"
			Fill.BorderSizePixel = 0
			Fill.ZIndex = Frame.ZIndex
			Fill.Parent = Frame
		end

		Layer.Fill = Fill
		Target = Fill
	elseif Layer.Fill then
		(Layer.Fill :: Frame).Visible = false
	end

	if Radius > 0 and (Left or Right) then
		const Corner: UICorner = Layer.Corner or Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, Radius)
		Corner.Parent = Target
		Layer.Corner = Corner
	elseif Layer.Corner then
		(Layer.Corner :: UICorner).Parent = nil
	end
end

const function Apply(State: Types.Fields, Layer: Types.Layer, Piece: Piece): ()
	const Mark: Types.MarkData = Piece.Mark
	const Frame: Frame = Layer.Frame
	const Radius: number = Mark.Radius or 0
	const X: number = math.floor(Piece.Start - (if Piece.Head then Piece.Pad else 0))
	const Width: number = math.ceil(Piece.Finish + (if Piece.Tail then Piece.Pad else 0)) - X
	const Rect: Types.RectData = Layer.Rect
	const Round: Types.RoundData = Layer.Round

	if X ~= Rect.X or Piece.Y ~= Rect.Y then
		Frame.Position = Pixel.Offset(X, Pixel.Truncate(Piece.Y))
		Rect.X = X
		Rect.Y = Piece.Y
	end

	if Width ~= Rect.Width or Piece.Height ~= Rect.Height then
		Frame.Size = Pixel.Offset(Width, Pixel.Truncate(Piece.Height))
		Rect.Width = Width
		Rect.Height = Piece.Height
	end

	const Reshaped: boolean = Radius ~= Round.Radius or Piece.Head ~= Round.Left or Piece.Tail ~= Round.Right
	if Reshaped then Shape(Layer, Radius, Piece.Head, Piece.Tail) end

	if Reshaped or Mark ~= Layer.Mark then
		Layer.Mark = Mark
		Paint(State, Layer)
	end

	if not Layer.Shown then Frame.Visible = true; Layer.Shown = true end
end

const function Assign(State: Types.Fields, Coverage: Coverage): ()
	const Layers: { Types.Layer } = State.Backdrop.Layers
	const Pieces: { Piece } = Coverage.Pieces
	const Count: number = #Pieces

	for _, Piece: Piece in (Coverage.Latest) do Piece.Tail = true end
	if Coverage.Nested then table.sort(Pieces, Outermost) end

	for Index: number, Piece: Piece in (Pieces) do
		const Layer: Types.Layer = Layers[Index] or Create(State)
		Layers[Index] = Layer

		Apply(State, Layer, Piece)
	end

	for Index = #Layers, Count + 1, -1 do
		const Layer: Types.Layer = Layers[Index]

		if Index > Count + SpareLimit then
			Layer.Frame:Destroy()
			Layers[Index] = nil
		elseif Layer.Shown then
			Layer.Frame.Visible = false
			Layer.Shown = false
		end
	end
end

const function Fade(State: Types.Fields): ()
	for _, Layer: Types.Layer in (State.Backdrop.Layers) do Paint(State, Layer) end
end

return {
	Begin = Begin;
	Row = Row;
	Cover = Cover;
	Root = Root;
	Mount = Mount;
	Stack = Stack;
	Assign = Assign;
	Fade = Fade;
}
