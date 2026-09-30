--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Segment = require("./Segment")
const Backdrop = require("./Backdrop")
const Lifetime = require("../Utility/Lifetime")

type Set = {
	Root: Frame;
	Layers: { Types.Layer };
}

type Shelves = {
	Labels: { Types.Record };
	Buttons: { Types.Record };
	Styled: { { [string]: Types.Record } };
	Chain: { [Types.Record]: Types.Record };
	Taken: { [Types.Record]: boolean };
}

type Work = {
	Assigned: { Types.Record? };
	Heads: { [Types.Style]: Types.Record };
	Tails: { [Types.Style]: Types.Record };
	Links: { [Types.Record]: Types.Record };
	Claimed: { [Types.Record]: boolean };
	Loose: { Types.Record };
	Segments: { Types.Record };
	Shelves: Shelves;
}

const SpareLimit: number = Config.Pool.SPARE_LIMIT
const DefaultLimit: number = Config.Pool.LIMIT
const HolderName: string = "RichTextPlusPool"

const Shared = {
	Limit = DefaultLimit;
	Labels = {} :: { Types.Record };
	Buttons = {} :: { Types.Record };
	Backdrops = {} :: { Set };
	Frames = 0;
	Holder = nil :: Folder?;
}

const Signatures = setmetatable({} :: { [Types.Style]: string | false }, {__mode = "k"})
const Works = Lifetime.Own("Pool.Works", {} :: { [Types.Fields]: Work })
const Fields: { string } = table.create(9, "")

const function Attach(Object: Instance, Parent: Instance): ()
	Object.Parent = Parent
end

const function Holder(): Folder
	const Existing: Folder? = Shared.Holder; if Existing then return Existing :: Folder end

	const Created: Folder = Instance.new("Folder")
	Created.Name = HolderName
	Shared.Holder = Created

	return Created
end

const function Park(Object: Instance): boolean
	return (pcall(Attach, Object, Holder()))
end

const function Shelf(Button: boolean): { Types.Record }
	return if Button then Shared.Buttons else Shared.Labels
end

const function Store(Record: Types.Record): boolean
	const Style: Types.Style? = Record.Style
	if Style and (Style :: Types.Style).Container then return false end

	const List: { Types.Record } = Shelf(Record.Button)
	if #List >= Shared.Limit or not Park(Record.Instance) then return false end

	Segment.Reset(Record)
	table.insert(List, Record)

	return true
end

const function Recycle(State: Types.Fields, Record: Types.Record): ()
	State.Instances.Records[Record.Instance] = nil

	if not Store(Record) then Record.Instance:Destroy() end
end

const function Borrow(State: Types.Fields, Button: boolean): Types.Record
	const Record: Types.Record? = table.remove(Shelf(Button))
	if Record then return Segment.Adopt(State, Record :: Types.Record) end

	return Segment.Create(State, Button)
end

const function Signature(Style: Types.Style): string?
	const Cached: (string | false)? = Signatures[Style]
	if Cached ~= nil then return if Cached then Cached :: string else nil end

	if Style.Gradient or Style.Effect or Style.Container then Signatures[Style] = false; return nil end

	const Stroke: Types.StrokeData? = Style.Stroke
	const Flags: number = (if Style.Bold then 1 else 0) + (if Style.Italic then 2 else 0) + (if Style.Underline then 4 else 0) + (if Style.Strike then 8 else 0)

	Fields[1] = Style.Family
	Fields[2] = tostring(Style.Size)
	Fields[3] = Style.Color:ToHex()
	Fields[4] = tostring(Style.Weight)
	Fields[5] = tostring(Flags)
	Fields[6] = Style.Case or ""
	Fields[7] = if Style.Element then Style.Link or "" else ""
	Fields[8] = tostring(Style.Transparency)
	Fields[9] = if Stroke then `{Stroke.Color:ToHex()}:{Stroke.Thickness}:{Stroke.Joins.Name}:{Stroke.Transparency}` else ""

	const Built: string = table.concat(Fields, "\0")

	Signatures[Style] = Built

	return Built
end

const function Sort(Loose: { Types.Record }, Shelves: Shelves): ()
	const Chain: { [Types.Record]: Types.Record } = Shelves.Chain

	table.clear(Shelves.Labels)
	table.clear(Shelves.Buttons)
	table.clear(Shelves.Styled[1])
	table.clear(Shelves.Styled[2])
	table.clear(Chain)
	table.clear(Shelves.Taken)

	for Index = #Loose, 1, -1 do
		const Record: Types.Record = Loose[Index]
		const Kind: number = if Record.Button then 2 else 1

		table.insert(if Record.Button then Shelves.Buttons else Shelves.Labels, Record)

		const Style: Types.Style? = Record.Style
		const Key: string? = if Style then Signature(Style :: Types.Style) else nil
		if not Key then continue end

		const Bucket: { [string]: Types.Record } = Shelves.Styled[Kind]
		const Head: Types.Record? = Bucket[Key :: string]

		if Head then Chain[Record] = Head :: Types.Record end
		Bucket[Key :: string] = Record
	end
end

const function Pop(Shelves: Shelves, List: { Types.Record }): Types.Record?
	const Taken: { [Types.Record]: boolean } = Shelves.Taken

	while true do
		const Record: Types.Record? = table.remove(List)
		if not Record then return nil end
		if Taken[Record :: Types.Record] then continue end

		Taken[Record :: Types.Record] = true

		return Record
	end
end

const function Unchain(Shelves: Shelves, Bucket: { [string]: Types.Record }, Key: string): Types.Record?
	const Taken: { [Types.Record]: boolean } = Shelves.Taken

	while true do
		const Record: Types.Record? = Bucket[Key]
		if not Record then return nil end

		Bucket[Key] = Shelves.Chain[Record :: Types.Record]
		if Taken[Record :: Types.Record] then continue end

		Taken[Record :: Types.Record] = true

		return Record
	end
end

const function Take(Shelves: Shelves, Button: boolean, Style: Types.Style?): Types.Record?
	if not Style then return Pop(Shelves, if Button then Shelves.Buttons else Shelves.Labels) end

	const Key: string? = Signature(Style :: Types.Style); if not Key then return nil end

	return Unchain(Shelves, Shelves.Styled[if Button then 2 else 1], Key :: string)
end

const function Retire(State: Types.Fields, Loose: { Types.Record }, Taken: { [Types.Record]: boolean }): ()
	const Spare: { Types.Record } = State.Instances.Spare
	table.clear(Spare)

	for _, Record: Types.Record in (Loose) do
		if Taken[Record] then continue end
		if #Spare >= SpareLimit then Recycle(State, Record); continue end

		if Record.Shown then
			Record.Instance.Visible = false
			Record.Shown = false
		end

		Record.Element = nil
		table.insert(Spare, Record)
	end
end

const function Workspace(State: Types.Fields, Size: number): Work
	const Existing: Work? = Works[State]
	if Existing then return Existing :: Work end

	const Created: Work = {
		Assigned = table.create(Size);
		Heads = {};
		Tails = {};
		Links = {};
		Claimed = {};
		Loose = {};
		Segments = {};
		Shelves = {Labels = {}, Buttons = {}, Styled = {{}, {}}, Chain = {}, Taken = {}};
	}

	Works[State] = Created

	return Created
end

const function Sequential(State: Types.Fields, Runs: { Types.Run }, Assigned: { Types.Record? }): { Types.Record? }?
	const Segments: { Types.Record } = State.Instances.Segments

	table.clear(Assigned)

	local Next: number = 0

	for Index: number, Run: Types.Run in (Runs) do
		const Style: Types.Style? = Run.Style; if not Style then continue end

		Next += 1

		const Record: Types.Record? = Segments[Next]
		if not Record or (Record :: Types.Record).Style ~= Style then return nil end

		Assigned[Index] = Record
	end

	return if Next == #Segments then Assigned else nil
end

const function Assign(State: Types.Fields, Runs: { Types.Run }): { Types.Record? }
	const Work: Work = Workspace(State, #Runs)
	const Assigned: { Types.Record? } = Work.Assigned
	const Direct: { Types.Record? }? = Sequential(State, Runs, Assigned); if Direct then return Direct :: { Types.Record? } end

	const Instances: Types.InstanceData = State.Instances
	const Heads: { [Types.Style]: Types.Record } = Work.Heads
	const Tails: { [Types.Style]: Types.Record } = Work.Tails
	const Links: { [Types.Record]: Types.Record } = Work.Links
	const Claimed: { [Types.Record]: boolean } = Work.Claimed
	const Segments: { Types.Record } = Work.Segments
	const Loose: { Types.Record } = Work.Loose
	const Shelves: Shelves = Work.Shelves

	table.clear(Heads)
	table.clear(Tails)
	table.clear(Links)
	table.clear(Claimed)
	table.clear(Segments)
	table.clear(Loose)
	table.clear(Assigned)

	for _, Record: Types.Record in (Instances.Segments) do
		const Style: Types.Style = Record.Style :: Types.Style
		const Tail: Types.Record? = Tails[Style]

		if Tail then Links[Tail :: Types.Record] = Record else Heads[Style] = Record end
		Tails[Style] = Record
	end

	for Index: number, Run: Types.Run in (Runs) do
		const Style: Types.Style? = Run.Style; if not Style then continue end
		const Record: Types.Record? = Heads[Style :: Types.Style]; if not Record then continue end

		Heads[Style :: Types.Style] = Links[Record :: Types.Record]
		Assigned[Index] = Record
		Claimed[Record :: Types.Record] = true
	end

	const Spare: { Types.Record } = Instances.Spare

	for _, Record: Types.Record in (Instances.Segments) do
		if Claimed[Record] then continue end

		if (Record.Style :: Types.Style).Container then Segment.Destroy(State, Record) else table.insert(Loose, Record) end
	end

	table.move(Spare, 1, #Spare, #Loose + 1, Loose)

	Sort(Loose, Shelves)

	for Index: number, Run: Types.Run in (Runs) do
		const Style: Types.Style? = Run.Style
		if Style and not Assigned[Index] then Assigned[Index] = Take(Shelves, (Style :: Types.Style).Element ~= nil, Style) end
	end

	for Index: number, Run: Types.Run in (Runs) do
		const Style: Types.Style? = Run.Style; if not Style then continue end

		local Record: Types.Record? = Assigned[Index]

		if not Record then
			const Button: boolean = (Style :: Types.Style).Element ~= nil
			Record = Take(Shelves, Button, nil) or Borrow(State, Button)
			Assigned[Index] = Record
		end

		table.insert(Segments, Record :: Types.Record)
	end

	Retire(State, Loose, Shelves.Taken)

	Work.Segments = Instances.Segments
	Instances.Segments = Segments

	return Assigned
end

const function Root(State: Types.Fields): ()
	if State.Backdrop.Root then return end

	const Set: Set? = table.remove(Shared.Backdrops)
	if not Set then Backdrop.Root(State); return end

	Shared.Frames -= 1 + #(Set :: Set).Layers
	Backdrop.Mount(State, (Set :: Set).Root, (Set :: Set).Layers)
end

const function Shelve(State: Types.Fields, Alive: boolean): ()
	const Root: Frame? = State.Backdrop.Root
	const Layers: { Types.Layer } = State.Backdrop.Layers

	State.Backdrop.Root = nil
	State.Backdrop.Layers = {}

	if not (Root and Alive) then return end

	const Frames: number = 1 + #Layers

	if Shared.Frames + Frames > Shared.Limit or not Park(Root :: Frame) then (Root :: Frame):Destroy(); return end

	for _, Layer: Types.Layer in (Layers) do Layer.Mark = nil end

	table.insert(Shared.Backdrops, {Root = Root :: Frame, Layers = Layers})
	Shared.Frames += Frames
end

const function Clear(State: Types.Fields, Dying: boolean?): ()
	const Instances: Types.InstanceData = State.Instances
	const Alive: boolean = not Dying

	for _, List: { Types.Record } in ({Instances.Segments, Instances.Spare}) do
		for _, Record: Types.Record in (List) do
			if Alive then Recycle(State, Record) elseif not Record.Parented then Record.Instance:Destroy() end
		end
	end

	table.clear(Instances.Segments)
	table.clear(Instances.Spare)
	table.clear(Instances.Records)

	Works[State] = nil

	Shelve(State, Alive)
end

const function Trim(List: { Types.Record }, Count: number): ()
	for Index = #List, Count + 1, -1 do
		List[Index].Instance:Destroy()
		List[Index] = nil
	end
end

const function Limit(): number
	return Shared.Limit
end

const function SetLimit(Value: number): ()
	if type(Value) ~= "number" or Value ~= Value or Value < 0 then error("RichTextPlus pool limit must be a non-negative number", 3) end

	Shared.Limit = math.floor(Value)

	Trim(Shared.Labels, Shared.Limit)
	Trim(Shared.Buttons, Shared.Limit)

	while Shared.Frames > Shared.Limit do
		const Set: Set = table.remove(Shared.Backdrops) :: Set

		Shared.Frames -= 1 + #Set.Layers
		Set.Root:Destroy()
	end
end

const function Spares(): (number, number, number)
	return #Shared.Labels, #Shared.Buttons, Shared.Frames
end

return {
	Limit = Limit;
	Assign = Assign;
	Root = Root;
	Clear = Clear;
	SetLimit = SetLimit;
	Spares = Spares;
}
