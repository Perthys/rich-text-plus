--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const Types = require("../../Types")
const Reflow = require("../../Utility/Reflow")
const Lifetime = require("../../Utility/Lifetime")

type Shape = Types.Shape
type Memory = Types.Memory
type Token = Types.Token

const Slots: number = 6
const RunBudget: number = Config.Shape.RUN_BUDGET

const Memories = Lifetime.Own("Shape.Memories", {} :: { [Types.Fields]: Memory })

const function NewShape(): Shape
	return {
		Runs = {Items = {}, Offsets = {}, Rises = {}, Pads = {}, Size = 0};
		Rows = {Firsts = {}, Heights = {}, Spans = {}, Flags = {}, Count = 0};
		Blocks = {Tokens = nil, Sizes = nil};
		Metrics = {Total = 0, Widest = 0, Extent = 0, Rtl = false};
		Key = {Tokens = nil, Text = -1, Measure = -1, Factor = 0, Spacing = 0, Minimum = 0, Scaled = false, Serial = -1};
		Widths = {Low = 0, High = 0, Width = 0, Exact = true};
		Version = 0;
		Used = 0;
	}
end

const function Obtain(State: Types.Fields): Memory
	const Existing: Memory? = Memories[State]; if Existing then return Existing :: Memory end

	const Created: Memory = {
		Shelf = {Shapes = {}, Spare = nil, Clock = 0};
		Settings = {Spacing = 1, Scaled = false, Horizontal = Enum.TextXAlignment.Left, Vertical = Enum.TextYAlignment.Top, Cut = Enum.TextTruncate.None};
		Commit = {
			Shape = nil;
			Version = -1;
			Alignment = nil;
			Truncation = nil;
			BoxWidth = 0;
			Start = 0;
			Floor = 0;
			Factor = 0;
			Decoration = -1;
			Placed = -1;
			Ordered = -1;
		};
		Output = {};
		Coverage = nil;
		Unblocked = nil;
	}

	Memories[State] = Created

	return Created
end

const function Read(State: Types.Fields, Memory: Memory, Scaled: boolean): ()
	const Label: TextLabel = State.Label
	const Settings: Types.SettingData = Memory.Settings

	Settings.Spacing = Label.LineHeight
	Settings.Scaled = Scaled
	Settings.Horizontal = Label.TextXAlignment
	Settings.Vertical = Label.TextYAlignment
	Settings.Cut = Label.TextTruncate
end

const function Fresh(Shape: Shape, State: Types.Fields, Memory: Memory): boolean
	const Key: Types.KeyData = Shape.Key
	const Settings: Types.SettingData = Memory.Settings

	return Key.Tokens == State.Document.Tokens
		and Key.Text == State.Generation.Text
		and Key.Measure == State.Generation.Measure
		and Key.Factor == State.Scale.Measured
		and Key.Spacing == Settings.Spacing
		and Key.Scaled == Settings.Scaled
end

const function Covers(Shape: Shape, MaxWidth: number): boolean
	const Widths: Types.WidthData = Shape.Widths
	if Widths.Exact then return MaxWidth == Widths.Width end

	return MaxWidth >= Widths.Low and (MaxWidth < Widths.High or Widths.High == math.huge)
end

const function Blocked(Shape: Shape): boolean
	const Blocks: { Token }? = Shape.Blocks.Tokens

	return Blocks ~= nil and #(Blocks :: { Token }) > 0
end

const function Release(Memory: Memory, Shape: Shape): ()
	const Shelf: Types.ShelfData = Memory.Shelf

	Shape.Key.Tokens = nil
	Shape.Key.Serial = -1
	if Memory.Commit.Shape == Shape then Memory.Commit.Shape = nil end

	const Spare: Shape? = Shelf.Spare
	if not Spare or Shape.Runs.Size > (Spare :: Shape).Runs.Size then Shelf.Spare = Shape end
end

const function Prune(Memory: Memory, State: Types.Fields, Keep: Shape?): ()
	const Shapes: { Shape } = Memory.Shelf.Shapes

	for Index = #Shapes, 1, -1 do
		const Shape: Shape = Shapes[Index]
		if Shape == Keep or Fresh(Shape, State, Memory) then continue end

		table.remove(Shapes, Index)
		Release(Memory, Shape)
	end
end

const function Find(State: Types.Fields, Memory: Memory, MaxWidth: number, Minimum: number): Shape?
	const Shelf: Types.ShelfData = Memory.Shelf

	for _, Shape: Shape in (Shelf.Shapes) do
		if Shape.Key.Minimum ~= Minimum or not Covers(Shape, MaxWidth) or not Fresh(Shape, State, Memory) then continue end

		Shelf.Clock += 1
		Shape.Used = Shelf.Clock

		return Shape
	end

	return nil
end

const function Base(State: Types.Fields, Memory: Memory, Serial: number): Shape?
	for _, Shape: Shape in (Memory.Shelf.Shapes) do
		const Key: Types.KeyData = Shape.Key
		if Key.Serial == Serial and Key.Tokens == State.Document.Tokens and Key.Measure == State.Generation.Measure then return Shape end
	end

	return nil
end

const function Evict(Memory: Memory, Keep: Shape): ()
	const Shapes: { Shape } = Memory.Shelf.Shapes

	while true do
		local Total: number = 0
		local Oldest: number = 0

		for Index: number, Shape: Shape in (Shapes) do
			Total += Shape.Runs.Size
			if Shape ~= Keep and (Oldest == 0 or Shape.Used < Shapes[Oldest].Used) then Oldest = Index end
		end

		if Oldest == 0 or (#Shapes <= Slots and Total <= RunBudget) then return end

		Release(Memory, table.remove(Shapes, Oldest) :: Shape)
	end
end

const function Claim(State: Types.Fields, Memory: Memory): Shape
	Prune(Memory, State, nil)

	const Shelf: Types.ShelfData = Memory.Shelf
	const Spare: Shape? = Shelf.Spare
	const Shape: Shape = Spare or NewShape()

	Shelf.Spare = nil
	Shelf.Clock += 1
	Shape.Used = Shelf.Clock
	Shape.Version += 1

	table.insert(Shelf.Shapes, Shape)
	Evict(Memory, Shape)

	return Shape
end

const function Restore(Shape: Shape): ()
	const Blocks: { Token }? = Shape.Blocks.Tokens
	const Sizes: { number }? = Shape.Blocks.Sizes
	if not (Blocks and Sizes) then return end

	for Index: number, Token: Token in (Blocks :: { Token }) do
		Token.Width = (Sizes :: { number })[Index * 2 - 1]
		Token.Height = (Sizes :: { number })[Index * 2]
	end
end

const function Apply(Shape: Shape, MaxWidth: number, Factor: number): ()
	const Blocks: { Token }? = Shape.Blocks.Tokens
	if not Blocks then return end

	Restore(Shape)

	for _, Token: Token in (Blocks :: { Token }) do
		const Object: GuiObject? = Token.Object
		if Object then Reflow.Apply(Object :: GuiObject, MaxWidth, Factor) end
	end
end

const function Drop(Memory: Memory, Shape: Shape): ()
	const Shapes: { Shape } = Memory.Shelf.Shapes
	const Index: number? = table.find(Shapes, Shape)
	if not Index then return end

	table.remove(Shapes, Index :: number)
	Release(Memory, Shape)
end

return {
	New = NewShape;
	Obtain = Obtain;
	Read = Read;
	Find = Find;
	Base = Base;
	Blocked = Blocked;
	Prune = Prune;
	Claim = Claim;
	Restore = Restore;
	Apply = Apply;
	Drop = Drop;
}
