--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Unicode = require("../Text/Unicode")
const Flatten = require("./Flatten")
const Measure = require("../Text/Measure")
const Native = require("./Native")
const Characters = require("../Utility/Characters")
const Whitespace = require("../Policy/Whitespace")
const Intents = require("../Policy/Intents")
const Areas = require("../Types/Incremental")
const Scanner = require("@self/Scan")
const Elements = require("../Elements")

type XMLNode = Types.Node
type Token = Types.Token
type Entry = Types.Entry
type Ledger = Types.Ledger
type Spans = Types.Spans

type Window = Areas.Window
type Change = Areas.Change
type Cut = Areas.CutData
type Workspace = Areas.Workspace

const NewlineByte: number = Characters.NEWLINE
const Controls: number = Intents.Flags.Controls

const Byte = string.byte
const Find = string.find
const Sub = string.sub
const Unescape = Styles.Unescape
const Sanitize = Styles.Sanitize
const Collapse = Whitespace.Collapse
const Recycle: (Token: Token) -> () = Flatten.Recycle

const Crossing = Scanner.Crossing
const Scan = Scanner.Scan
const Prefix = Scanner.Prefix
const Realign = Scanner.Realign
const Bounds = Scanner.Bounds

const Workspaces = setmetatable({} :: { [Spans]: Workspace }, {__mode = "k"})

const function Equivalent(Old: Token, New: Token): boolean
	return Old.Kind == New.Kind
		and Old.Text == New.Text
		and Old.SpaceBefore == New.SpaceBefore
		and Old.Glue == New.Glue
		and (Old.Hyphen == nil) == (New.Hyphen == nil)
end

const function NewWorkspace(): Workspace
	return {Window = {Starts = {}, Stops = {}, Reaches = {}}, Changes = {}, Records = {}, Spare = nil, Busy = false}
end

const function Acquire(Spans: Spans): Workspace
	const Existing: Workspace? = Workspaces[Spans]
	if Existing and not Existing.Busy then return Existing end

	const Created: Workspace = NewWorkspace()
	if not Existing then Workspaces[Spans] = Created end

	return Created
end

const function Load(Workspace: Workspace, Text: string): buffer
	const Size: number = #Text
	const Spare: buffer? = Workspace.Spare

	local Target: buffer

	if Spare and buffer.len(Spare :: buffer) >= Size then
		Target = Spare :: buffer
	else
		Target = buffer.create(math.max(Size, if Spare then buffer.len(Spare :: buffer) * 2 else 0))
		Workspace.Spare = Target
	end

	buffer.writestring(Target, 0, Text)

	return Target
end

const function Discard(Tokens: { Token }): ()
	for _, Token: Token in (Tokens) do Recycle(Token) end

	table.clear(Tokens)
end

const function Claim(Workspace: Workspace, Entry: Entry, Slot: number, Raw: string): Change
	const Records: { Change } = Workspace.Records
	const Index: number = #Workspace.Changes + 1
	const Existing: Change? = Records[Index]

	if not Existing then
		const Created: Change = {
			Entry = Entry;
			Slot = Slot;
			Raw = Raw;
			Tokens = {};
			Cut = {Before = 0, Removed = 0, After = 0, Head = 0, Tail = 0, Delta = 0};
			Closed = false;
			ExitCode = nil;
			Characters = 0;
		}

		Records[Index] = Created

		return Created
	end

	const Change: Change = Existing :: Change
	Change.Entry = Entry
	Change.Slot = Slot
	Change.Raw = Raw
	Change.Characters = 0

	return Change
end

const function Abandon(Workspace: Workspace): ()
	const Changes: { Change } = Workspace.Changes

	for _, Change: Change in (Changes) do Discard(Change.Tokens) end

	table.clear(Changes)
end

const function Release(Workspace: Workspace): ()
	const Changes: { Change } = Workspace.Changes

	for _, Change: Change in (Changes) do
		const Fresh: { Token } = Change.Tokens
		const Cut: Cut = Change.Cut
		const Size: number = #Fresh

		for Index = 1, Cut.Head do Recycle(Fresh[Index]) end
		for Index = Size - Cut.Tail + 1, Size do Recycle(Fresh[Index]) end

		table.clear(Fresh)
	end

	table.clear(Changes)
end

const function Replace(State: Types.Fields, Change: Change, Text: string, Start: number, OldStop: number, NewStop: number, Closed: boolean): boolean
	const Entry: Entry = Change.Entry
	const Tokens: { Token } = State.Document.Tokens
	const First: number = Entry.First
	const Count: number = Entry.Count
	const Resumed: boolean = Start > 1

	local Before: number = 0
	if Resumed then
		while Before < Count and (Tokens[First + Before].Offset or 0) < Start do Before += 1 end
	end

	local After: number = 0
	if Closed then
		while After < Count - Before and (Tokens[First + Count - 1 - After].Offset or 0) > OldStop do After += 1 end
	end

	const Removed: number = Count - Before - After
	if Removed == 0 then return false end

	const Anchor: Token? = Tokens[First + Before - 1]
	const EntrySpace: boolean, EntryExitSpace: boolean, EntryHooked: boolean, EntryJoint: Types.Joint?, EntryExitJoint: Types.Joint? = Flatten.Unpack(Entry.Flags)
	const Space: boolean = if Resumed then Byte(Text, Start - 1) ~= NewlineByte else EntrySpace
	const Fresh: { Token } = Change.Tokens

	const Tokenized: boolean, ExitSpace: boolean, ExitCode: number?, ExitJoint: Types.Joint?, Hooked: boolean = Flatten.Tokenize(
		State,
		Entry.Style,
		Sub(Text, Start, NewStop),
		if Anchor then Anchor.Kind else nil,
		Space,
		if Resumed then nil else Entry.Code,
		if Resumed then nil else EntryJoint,
		Fresh
	)

	if not Tokenized or #Fresh == 0 or Hooked ~= (not Resumed and EntryHooked) then Discard(Fresh); return false end

	const Size: number = #Fresh

	if not Closed then
		if ExitSpace ~= EntryExitSpace or ExitJoint ~= EntryExitJoint then Discard(Fresh); return false end
		if not ExitSpace and ExitJoint == nil and Unicode.Trailing(ExitCode) ~= Unicode.Trailing(Entry.ExitCode) then Discard(Fresh); return false end

		const Last: Token = Tokens[First + Count - 1]
		const Final: Token = Fresh[Size]

		if Final.Kind ~= Last.Kind then Discard(Fresh); return false end
		if Last.Hyphen ~= nil then Final.Hyphen = 0 end
	end

	for _, Token: Token in (Fresh) do Token.Offset = (Token.Offset or 0) + Start - 1 end

	const Base: number = First + Before
	const Shared: number = math.min(Removed, Size)

	local Head: number = 0
	while Head < Shared and Equivalent(Tokens[Base + Head], Fresh[Head + 1]) do Head += 1 end

	local Tail: number = 0
	while Tail < Shared - Head and Equivalent(Tokens[Base + Removed - 1 - Tail], Fresh[Size - Tail]) do Tail += 1 end

	const Cut: Cut = Change.Cut

	Cut.Before = Before
	Cut.Removed = Removed
	Cut.After = After
	Cut.Head = Head
	Cut.Tail = Tail
	Cut.Delta = NewStop - OldStop
	Change.Closed = Closed
	Change.ExitCode = ExitCode

	return true
end

const function Rewrite(State: Types.Fields, Ledger: Ledger, Spans: Spans, Index: number, New: buffer, Raw: string, NewStart: number, Workspace: Workspace): Change?
	const Node: XMLNode = Spans.Nodes[Index]
	const Slot: number? = Ledger.Slots[Node]; if not Slot then return nil end

	const Entry: Entry = Ledger.Entries[Slot :: number]
	if Entry.Count == 0 then return nil end

	const Previous: string = Node.Text :: string
	const Folded: boolean = State.Options.Whitespace == "Markup" and (Find(Previous, "\n", 1, true) ~= nil or Find(Raw, "\n", 1, true) ~= nil)
	const Content: string = if Folded then Collapse(Raw) else Raw
	const Escaped: boolean = Find(Previous, "&", 1, true) ~= nil or Find(Raw, "&", 1, true) ~= nil
	const Decoded: string = if Escaped then Unescape(Content) else Content
	const Strip: boolean = not bit32.btest(State.Intents.Bitfield, Controls)
	const Text: string = if Strip then Sanitize(Decoded) else Decoded
	const Shifted: boolean = Folded or Escaped or (Strip and (Text ~= Decoded or Sanitize(Previous) ~= Previous))
	const Change: Change = Claim(Workspace, Entry, Slot :: number, Raw)

	local Replaced: boolean = false

	if not Shifted then
		const Start: number, OldStop: number, NewStop: number, Closed: boolean = Bounds(Spans.Source, Spans.Starts[Index], #Previous, New, NewStart, #Raw)
		if Start > 1 or Closed then Replaced = Replace(State, Change, Text, Start, OldStop, NewStop, Closed) end
	end

	if not Replaced and not Replace(State, Change, Text, 1, #Previous, #Text, false) then return nil end
	if Ledger.Limit < math.huge then Change.Characters = utf8.len(Text) or #Text end

	return Change
end

const function Plan(State: Types.Fields, Ledger: Ledger, Spans: Spans, New: buffer, Source: string, Workspace: Workspace, From: number): boolean
	const Old: buffer = Spans.Source
	const Changes: { Change } = Workspace.Changes
	const Window: Window = Workspace.Window
	const Stops: { number } = Window.Stops

	for Offset: number, Start: number in (Window.Starts) do
		const Index: number = From + Offset - 1
		const Stop: number = Stops[Offset]
		const OldStart: number = Spans.Starts[Index]
		const Length: number = Stop - Start + 1

		if Length == Spans.Stops[Index] - OldStart + 1 and Prefix(Old, OldStart - 1, New, Start - 1, Length) == Length then continue end

		const Change: Change? = Rewrite(State, Ledger, Spans, Index, New, Sub(Source, Start, Stop), Start, Workspace)
		if not Change then return false end

		const Previous: Change? = Changes[#Changes]
		if Previous and Previous.Slot >= (Change :: Change).Slot then Discard((Change :: Change).Tokens); return false end

		table.insert(Changes, Change :: Change)
	end

	return true
end

const function Splice(List: { Token }, From: number, Removed: number, Source: { Token }, First: number, Last: number): ()
	const Added: number = Last - First + 1

	if Added ~= Removed then
		const Size: number = #List

		table.move(List, From + Removed, Size, From + Added)
		for Index = Size + Added - Removed + 1, Size do List[Index] = nil end
	end

	table.move(Source, First, Last, From, List)
end

const function Apply(Tokens: { Token }, Change: Change): ()
	const Entry: Entry = Change.Entry
	const Cut: Cut = Change.Cut
	const Fresh: { Token } = Change.Tokens
	const Size: number = #Fresh
	const Base: number = Entry.First + Cut.Before
	const Removed: number = Cut.Removed
	const Head: number = Cut.Head
	const Tail: number = Cut.Tail
	const Delta: number = Cut.Delta

	for Offset = 0, Head - 1 do Tokens[Base + Offset].Offset = Fresh[Offset + 1].Offset end
	for Offset = 0, Tail - 1 do Tokens[Base + Removed - 1 - Offset].Offset = Fresh[Size - Offset].Offset end

	for Index = Base + Removed, Base + Removed + Cut.After - 1 do
		const Kept: Token = Tokens[Index]
		Kept.Offset = (Kept.Offset or 0) + Delta
	end

	Splice(Tokens, Base + Head, Removed - Head - Tail, Fresh, Head + 1, Size - Tail)

	Entry.Count += Size - Removed
	Entry.Node.Text = Change.Raw

	if not Change.Closed then Entry.ExitCode = Change.ExitCode end
end

const function Commit(State: Types.Fields, Ledger: Ledger, Changes: { Change }): ()
	const Tokens: { Token } = State.Document.Tokens
	const Entries: { Entry } = Ledger.Entries

	local Shift: number = 0
	local Next: number = 1

	for Slot = Changes[1].Slot, #Entries do
		const Entry: Entry = Entries[Slot]
		Entry.First += Shift

		const Change: Change? = Changes[Next]
		if not Change or (Change :: Change).Slot ~= Slot then continue end

		Next += 1

		const Count: number = Entry.Count

		Apply(Tokens, Change :: Change)
		Elements.Shift(State.Elements, Slot, Entry.Count - Count)

		Shift += Entry.Count - Count
		Ledger.Characters += (Change :: Change).Characters - Entry.Characters
		Entry.Characters = (Change :: Change).Characters
	end
end

const function Resize(Spans: Spans, First: number, Window: Window, Delta: number): ()
	const SpanStarts: { number } = Spans.Starts
	const SpanStops: { number } = Spans.Stops
	const SpanReaches: { number } = Spans.Reaches
	const Reaches: { number } = Window.Reaches
	const Count: number = #Reaches

	for Offset = 1, Count do
		if SpanReaches[First + Offset - 1] > 0 then Spans.Crossing -= 1 end
		if Reaches[Offset] > 0 then Spans.Crossing += 1 end
	end

	table.move(Window.Starts, 1, Count, First, SpanStarts)
	table.move(Window.Stops, 1, Count, First, SpanStops)
	table.move(Reaches, 1, Count, First, SpanReaches)

	if Delta == 0 then return end

	for Index = First + Count, #SpanStarts do
		SpanStarts[Index] += Delta
		SpanStops[Index] += Delta
		if SpanReaches[Index] > 0 then SpanReaches[Index] += Delta end
	end
end

const function Budget(Ledger: Ledger, Changes: { Change }): boolean
	if Ledger.Limit == math.huge then return true end

	local Total: number = Ledger.Characters

	for _, Change: Change in (Changes) do Total += Change.Characters - Change.Entry.Characters end

	return Total <= Ledger.Limit
end

const function Prepare(State: Types.Fields, Ledger: Ledger, Source: string): Spans?
	const Existing: Spans? = Ledger.Spans; if Existing then return Existing end

	const Built: Spans? = Scan(Source, Ledger.Tree)
	if not Built then State.Document.Ledger = nil; return nil end

	Ledger.Spans = Built

	return Built
end

const function Step(State: Types.Fields, Ledger: Ledger, Spans: Spans, Old: string, New: string, Workspace: Workspace): boolean
	const Current: buffer = Load(Workspace, New)

	const First: number, Aligned: boolean = Realign(Spans, Current, New, Workspace.Window)
	if not Aligned then return false end

	const Changes: { Change } = Workspace.Changes
	if not Plan(State, Ledger, Spans, Current, New, Workspace, First) or #Changes == 0 or not Budget(Ledger, Changes) then Abandon(Workspace); return false end

	for _, Change: Change in (Changes) do
		if not Measure.Fill(State, Change.Tokens, Change.Cut.Head + 1, #Change.Tokens - Change.Cut.Tail) then Abandon(Workspace); return true end
	end

	Commit(State, Ledger, Changes)
	Resize(Spans, First, Workspace.Window, #New - #Old)
	Release(Workspace)

	Workspace.Spare = Spans.Source
	Spans.Source = Current
	Spans.Size = #New
	State.Document.Source = New
	State.Document.Origin = New

	return true
end

const function Advance(State: Types.Fields, Ledger: Ledger, Spans: Spans, Old: string, New: string): boolean
	const Workspace: Workspace = Acquire(Spans)

	Workspace.Busy = true

	const Advanced: boolean = Step(State, Ledger, Spans, Old, New, Workspace)

	Workspace.Busy = false

	return Advanced
end

const function Patch(State: Types.Fields): boolean
	const Document: Types.DocumentData = State.Document
	const Ledger: Ledger? = Document.Ledger
	const Old: string? = Document.Source

	if not (Ledger and Old) or Document.Origin ~= Old or (Ledger :: Ledger).Tree ~= Document.Tree then return false end
	if State.Scale.Measured == 0 or State.Scale.Measured ~= State.Scale.Factor then return false end

	const Spans: Spans? = Prepare(State, Ledger :: Ledger, Old :: string); if not Spans then return false end

	return Advance(State, Ledger :: Ledger, Spans :: Spans, Old :: string, Native.Source(State))
end

return {
	Patch = Patch;
}
