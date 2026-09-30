--!strict
--!native
--!optimize 2

const Types = require("./Types")
const Signal = require("./Utility/Signal")
const Styles = require("./Utility/Styles")
const Selector = require("@self/Selector")

type Element = Types.Element
type ElementsData = Types.ElementsData
type Binding = Types.Binding
type BindHandlers = Types.BindHandlers
type Record = Types.Record
type Fields = Types.Fields
type Token = Types.Token

const Events: { [string]: boolean } = table.freeze({
	Activated = true;
	HoverChanged = true;
	PressChanged = true;
})

const FieldEvents: { [string]: string } = table.freeze({
	Hovered = "HoverChanged";
	Pressed = "PressChanged";
})

const Attribute = Styles.Attribute

const LOOKAHEAD: number = 16

const Wanted: { [Element]: boolean } = {}
const Parts: { string } = {}

local Painter: ((Target: Element) -> ())? = nil
local Invalidate: ((Owner: Fields) -> ())? = nil

--[=[
	One rendered tag of the markup, such as an `<a>`, a `<b>` or a custom class. Get elements with [Renderer:QueryDescendants] and [Renderer:QueryFirst], and handle input on them with [Renderer:Bind].

	Elements persist across re-renders: an element keeps its identity, state and connections while its tag is still there, matched by `id` when it has one and by its position among its siblings otherwise.

	Only interactive elements get input: `<a>`, custom classes with `Interactive = true`, tags with a `hovercolor` or `presscolor` attribute, and elements matched by a [Renderer:Bind] selector. Plain text costs nothing extra.

	```lua
	local Buy = Renderer:QueryFirst("#buy")
	Buy.Activated:Connect(function()
		print(Buy.Text, Buy:GetAttribute("price"))
	end)
	```

	@class Element
]=]
--[=[
	The tag name, lowercase.

	@within Element
	@prop Tag string
	@readonly
]=]
--[=[
	The `id` attribute, which also keeps the element's identity when siblings move.

	@within Element
	@prop Id string?
	@readonly
]=]
--[=[
	The rendered text inside the element, words joined by single spaces.

	@within Element
	@prop Text string
	@readonly
]=]
--[=[
	The enclosing element, or `nil` at the top of the document.

	@within Element
	@prop Parent Element?
	@readonly
]=]
--[=[
	Hover, press, focus and reveal state. Read it in a style class's `Apply` to restyle on interaction.

	@within Element
	@prop State ElementState
	@readonly
]=]
--[=[
	Whether the element gets input handling.

	@within Element
	@prop Interactive boolean
	@readonly
]=]
--[=[
	Fires when the element, or an interactive element inside it, is clicked or tapped.

	@within Element
	@prop Activated Signal<>
	@readonly
]=]
--[=[
	Fires with `true` when the pointer enters the element's text and `false` when it leaves.

	@within Element
	@prop HoverChanged Signal<boolean>
	@readonly
]=]
--[=[
	Fires with `true` when a press starts on the element and `false` when it ends or the pointer leaves.

	@within Element
	@prop PressChanged Signal<boolean>
	@readonly
]=]
const ElementClass = {}
const Methods = {}

const function TextOf(Target: Element): string
	if Target.Removed then return "" end

	const Tokens: { Token } = Target.Owner.Elements.Tokens
	table.clear(Parts)

	for Index = Target.First, Target.Last do
		const Token: Token? = Tokens[Index]
		if not Token then break end
		if (Token :: Token).Kind ~= "Word" then continue end

		const Previous: Token? = Tokens[Index - 1]
		if #Parts > 0 and ((Token :: Token).SpaceBefore or (Previous ~= nil and Previous.Kind == "Break")) then table.insert(Parts, " ") end

		table.insert(Parts, (Token :: Token).Text :: string)
	end

	const Joined: string = table.concat(Parts)
	table.clear(Parts)

	return Joined
end

const function SignalOf(Target: Element, Name: string): Signal.Signal<...any>
	const Signals: { [string]: Signal.Signal<...any> } = Target.Signals or {}
	Target.Signals = Signals

	const Existing: Signal.Signal<...any>? = Signals[Name]
	if Existing then return Existing :: Signal.Signal<...any> end

	const Created: Signal.Signal<...any> = Signal.new()
	if Target.Removed then Created:Destroy() end
	Signals[Name] = Created

	return Created
end

ElementClass.__index = function(Target: any, Key: any): any
	const Method: any = (Methods :: any)[Key]
	if Method then return Method end
	if Key == "Text" then return TextOf(Target) end

	if Key == "State" then
		const Created: Types.ElementState = {Hovered = false, Pressed = false, Focused = false, Visible = not Target.Removed}
		rawset(Target, "State", Created)

		return Created
	end

	if Events[Key] then return SignalOf(Target, Key) end

	return nil
end

ElementClass.__tostring = function(Target: any): string
	return if Target.Id then `Element<{Target.Tag}#{Target.Id}>` else `Element<{Target.Tag}>`
end

--[=[
	Returns an attribute of the tag, unescaped. Names are case-insensitive.

	@within Element
	@method GetAttribute
	@param Name string
	@return string?
]=]
function Methods.GetAttribute(self: Element, Name: string): string?
	if type(Name) ~= "string" then error("RichTextPlus Element:GetAttribute takes an attribute name", 2) end

	const Node: Types.Node? = self.Node
	if not Node then return nil end

	return Attribute(Node :: Types.Node, Name)
end

--[=[
	Returns the elements inside this one that match a selector, in document order. Same selectors as [Renderer:QueryDescendants], with this element as the root.

	@within Element
	@method QueryDescendants
	@param Selector string
	@return { Element }
]=]
function Methods.QueryDescendants(self: Element, Source: string): { Element }
	const Compiled: Selector.Compiled = Selector.Compile(Source, 2)

	return Selector.Collect(Compiled, self.Children, self, {}, false)
end

const function New(Owner: Fields, Tag: string): Element
	const Created: any = {
		Tag = Tag;
		Children = {};
		Interactive = false;
		Owner = Owner;
		First = 1;
		Last = 0;
		EntryOpen = 1;
		EntryClose = 0;
		Seen = 0;
		Cursor = 1;
		Removed = false;
		Intrinsic = false;
		Restyle = false;
	}

	return setmetatable(Created, ElementClass) :: any
end

const function Create(): ElementsData
	return {
		Roots = {};
		Ids = {};
		All = {};
		Interactive = {};
		NextRoots = {};
		NextIds = {};
		NextAll = {};
		NextInteractive = {};
		Tokens = {};
		Pass = 0;
		Cursor = 1;
		Bindings = {};
		Pointer = {Element = nil, Over = 0, Pressed = nil};
	}
end

const function Begin(Data: ElementsData): ()
	Data.Pass += 1
	Data.Cursor = 1

	table.clear(Data.NextRoots)
	table.clear(Data.NextIds)
	table.clear(Data.NextAll)
	table.clear(Data.NextInteractive)
end

const function Claim(Data: ElementsData, Owner: Fields, Parent: Element?, Tag: string, Node: Types.Node, Id: string?): Element
	const Pass: number = Data.Pass
	const Siblings: { Element } = if Parent then (Parent :: Element).Children else Data.NextRoots
	const Previous: { Element }? = if Parent then (Parent :: Element).Prior else Data.Roots

	local Found: Element? = nil

	if Id then
		const Candidate: Element? = Data.Ids[Id :: string]
		if Candidate and Candidate.Tag == Tag and Candidate.Seen ~= Pass and not Candidate.Removed then Found = Candidate end
	elseif Previous then
		const List: { Element } = Previous :: { Element }
		const Start: number = if Parent then (Parent :: Element).Cursor else Data.Cursor

		for Index = Start, math.min(#List, Start + LOOKAHEAD) do
			const Candidate: Element = List[Index]
			if Candidate.Tag ~= Tag or Candidate.Id ~= nil or Candidate.Seen == Pass or Candidate.Removed then continue end

			Found = Candidate
			if Parent then (Parent :: Element).Cursor = Index + 1 else Data.Cursor = Index + 1 end

			break
		end
	end

	const Claimed: Element = Found or New(Owner, Tag)

	if Found then
		const Kept: { Element } = Claimed.Children
		const Spare: { Element } = Claimed.Prior or {}

		table.clear(Spare)
		Claimed.Children = Spare
		Claimed.Prior = Kept
	end

	Claimed.Seen = Pass
	Claimed.Cursor = 1
	Claimed.Id = Id
	Claimed.Node = Node
	Claimed.Parent = Parent
	Claimed.Intrinsic = false
	Claimed.Restyle = false
	Claimed.HoverColor = nil
	Claimed.PressColor = nil

	table.insert(Siblings, Claimed)
	table.insert(Data.NextAll, Claimed)
	if Id and not Data.NextIds[Id :: string] then Data.NextIds[Id :: string] = Claimed end

	return Claimed
end

const function Settle(Data: ElementsData, Target: Element): boolean
	local Interactive: boolean = Target.Intrinsic

	if not Interactive then
		for _, Entry: Binding in (Data.Bindings) do
			if Selector.Matches(Entry.Selector, Target, nil, true) then Interactive = true; break end
		end
	end

	Target.Interactive = Interactive

	if not Interactive then
		const State: Types.ElementState? = rawget(Target :: any, "State")
		if State then (State :: Types.ElementState).Visible = true end

		Target.Records = nil

		return false
	end

	Target.Records = Target.Records or {}
	table.insert(Data.NextInteractive, Target)

	return true
end

const function Retire(Target: Element): ()
	if Target.Removed then return end

	const State: Types.ElementState? = rawget(Target :: any, "State")

	Target.Removed = true
	Target.Parent = nil
	Target.Node = nil
	Target.Records = nil
	Target.Interactive = false
	table.clear(Target.Children)
	if Target.Prior then table.clear(Target.Prior :: { Element }) end

	if State then
		State.Hovered = false
		State.Pressed = false
		State.Focused = false
		State.Visible = false
	end

	const Signals: { [string]: Signal.Signal<...any> }? = Target.Signals
	if not Signals then return end

	for _, Entry: Signal.Signal<...any> in (Signals :: { [string]: Signal.Signal<...any> }) do Entry:Destroy() end
end

const function Forget(Data: ElementsData, Target: Element?): ()
	const Pointer: Types.PointerData = Data.Pointer

	if Target and Pointer.Element == Target then
		Pointer.Element = nil
		Pointer.Over = 0
	end

	if Target and Pointer.Pressed == Target then Pointer.Pressed = nil end
end

const function Commit(Data: ElementsData, Tokens: { Token }): ()
	const Pass: number = Data.Pass

	for _, Target: Element in (Data.All) do
		if Target.Seen == Pass then continue end

		Forget(Data, Target)
		Retire(Target)
	end

	Data.Roots, Data.NextRoots = Data.NextRoots, Data.Roots
	Data.Ids, Data.NextIds = Data.NextIds, Data.Ids
	Data.All, Data.NextAll = Data.NextAll, Data.All
	Data.Interactive, Data.NextInteractive = Data.NextInteractive, Data.Interactive
	Data.Tokens = Tokens

	table.clear(Data.NextRoots)
	table.clear(Data.NextIds)
	table.clear(Data.NextAll)
	table.clear(Data.NextInteractive)
end

const function Shift(Data: ElementsData, Slot: number, Delta: number): ()
	if Delta == 0 then return end

	for _, Target: Element in (Data.All) do
		if Target.EntryOpen > Slot then
			Target.First += Delta
			Target.Last += Delta
		elseif Target.EntryClose >= Slot then
			Target.Last += Delta
		end
	end
end

const function ClearRecords(Data: ElementsData): ()
	for _, Target: Element in (Data.Interactive) do
		const Records: { Record }? = Target.Records
		if Records then table.clear(Records :: { Record }) end
	end
end

const function Invoke(Entry: Binding, Handler: (...any) -> (), ...: any): ()
	if not Entry.Connected then return end

	Handler(...)
end

const function Dispatch(Target: Element, Event: string, Value: boolean?): ()
	const Signals: { [string]: Signal.Signal<...any> }? = Target.Signals
	const Own: Signal.Signal<...any>? = if Signals then (Signals :: { [string]: Signal.Signal<...any> })[Event] else nil
	const Activation: boolean = Event == "Activated"

	if Own then
		if Activation then (Own :: Signal.Signal<...any>):Fire() else (Own :: Signal.Signal<...any>):Fire(Value) end
	end

	for _, Entry: Binding in (Target.Owner.Elements.Bindings) do
		const Handler: ((...any) -> ())? = (Entry.Handlers :: any)[Event]
		if not Handler or not Selector.Matches(Entry.Selector, Target, nil, false) then continue end

		if Activation then task.defer(Invoke, Entry, Handler :: (...any) -> (), Target) else task.defer(Invoke, Entry, Handler :: (...any) -> (), Target, Value) end
	end
end

const function Change(Target: Element, Field: string, Value: boolean): ()
	(Target.State :: any)[Field] = Value

	const Event: string? = FieldEvents[Field]
	if Event then Dispatch(Target, Event :: string, Value) end

	if Painter then (Painter :: (Target: Element) -> ())(Target) end

	const Owner: Fields = Target.Owner
	if Target.Restyle and not Owner.Destroyed and Invalidate then (Invalidate :: (Owner: Fields) -> ())(Owner) end
end

const function Retarget(Previous: Element?, Next: Element?): ()
	table.clear(Wanted)

	local Current: Element? = Next

	while Current do
		if (Current :: Element).Interactive then Wanted[Current :: Element] = true end
		Current = (Current :: Element).Parent
	end

	Current = Previous

	while Current do
		const Target: Element = Current :: Element

		if Target.Interactive and not Wanted[Target] then
			if Target.State.Pressed then Change(Target, "Pressed", false) end
			if Target.State.Hovered then Change(Target, "Hovered", false) end
		end

		Current = Target.Parent
	end

	Current = Next

	while Current do
		const Target: Element = Current :: Element
		if Target.Interactive and not Target.State.Hovered then Change(Target, "Hovered", true) end

		Current = Target.Parent
	end

	table.clear(Wanted)
end

const function Reachable(Record: Record): Element?
	const Target: Element? = Record.Element
	const Owner: Fields? = Record.Owner :: any
	if not (Target and Owner) or (Target :: Element).Removed or (Owner :: Fields).Destroyed or Record.Content.Revealed == 0 then return nil end

	return Target
end

const function Settled(Owner: Fields, Target: Element): ()
	const Pointer: Types.PointerData = Owner.Elements.Pointer
	if Pointer.Element ~= Target or Pointer.Over > 0 or Owner.Destroyed then return end

	Pointer.Element = nil
	Retarget(Target, nil)
end

const function Enter(Record: Record): ()
	const Target: Element? = Reachable(Record); if not Target then return end
	const Pointer: Types.PointerData = (Record.Owner :: Fields).Elements.Pointer
	const Previous: Element? = Pointer.Element

	if Previous ~= Target then
		Pointer.Element = Target
		Pointer.Over = 0
		Retarget(Previous, Target)
	end

	Pointer.Over += 1
end

const function Leave(Record: Record): ()
	const Owner: Fields? = Record.Owner :: any; if not Owner then return end
	const Pointer: Types.PointerData = (Owner :: Fields).Elements.Pointer
	const Current: Element? = Pointer.Element; if not Current then return end

	if Record.Element ~= Current and not (Current :: Element).Removed then return end

	Pointer.Over = math.max(Pointer.Over - 1, 0)
	if Pointer.Over == 0 then task.defer(Settled, Owner :: Fields, Current :: Element) end
end

const function Activate(Record: Record): ()
	local Current: Element? = Reachable(Record)

	while Current do
		const Target: Element = Current :: Element
		if Target.Interactive then Dispatch(Target, "Activated", nil) end

		Current = Target.Parent
	end
end

const function Release(Owner: Fields): ()
	const Pointer: Types.PointerData = Owner.Elements.Pointer
	local Current: Element? = Pointer.Pressed

	Pointer.Pressed = nil

	while Current do
		const Target: Element = Current :: Element
		if Target.State.Pressed then Change(Target, "Pressed", false) end

		Current = Target.Parent
	end
end

const function Press(Record: Record, Pressing: boolean): ()
	const Owner: Fields? = Record.Owner :: any; if not Owner or (Owner :: Fields).Destroyed then return end

	Release(Owner :: Fields)
	if not Pressing then return end

	const Target: Element? = Reachable(Record); if not Target then return end

	(Owner :: Fields).Elements.Pointer.Pressed = Target

	local Current: Element? = Target

	while Current do
		const Entry: Element = Current :: Element
		if Entry.Interactive and not Entry.State.Pressed then Change(Entry, "Pressed", true) end

		Current = Entry.Parent
	end
end

const function Focus(Record: Record, Focused: boolean): ()
	local Current: Element? = if Focused then Reachable(Record) else Record.Element

	while Current do
		const Target: Element = Current :: Element
		if Target.Interactive and not Target.Removed and Target.State.Focused ~= Focused then Change(Target, "Focused", Focused) end

		Current = Target.Parent
	end
end

const function Reveal(Owner: Fields): ()
	for _, Target: Element in (Owner.Elements.Interactive) do
		const Records: { Record } = Target.Records or {}
		local Visible: boolean = false

		for _, Record: Record in (Records) do
			if Record.Shown and Record.Content.Revealed ~= 0 then Visible = true; break end
		end

		Target.State.Visible = Visible
	end
end

const BindingClass = {}; BindingClass.__index = BindingClass

function BindingClass.Disconnect(self: any): ()
	const Entry: Binding = self :: Binding
	if not Entry.Connected then return end

	Entry.Connected = false

	const Owner: Fields = Entry.Owner
	const Bindings: { Binding } = Owner.Elements.Bindings
	const Index: number? = table.find(Bindings, Entry)
	if Index then table.remove(Bindings, Index :: number) end

	if not Owner.Destroyed and Invalidate then (Invalidate :: (Owner: Fields) -> ())(Owner) end
end

const function Bind(Owner: Fields, Compiled: Selector.Compiled, Handlers: BindHandlers): Binding
	const Created: Binding = setmetatable({Selector = Compiled, Handlers = Handlers, Connected = not Owner.Destroyed, Owner = Owner} :: any, BindingClass) :: any
	if not Created.Connected then return Created end

	table.insert(Owner.Elements.Bindings, Created)
	if Invalidate then (Invalidate :: (Owner: Fields) -> ())(Owner) end

	return Created
end

const function Query(Owner: Fields, Compiled: Selector.Compiled, First: boolean): { Element }
	return Selector.Collect(Compiled, Owner.Elements.Roots, nil, {}, First)
end

const function Destroy(Owner: Fields): ()
	const Data: ElementsData = Owner.Elements

	for _, Entry: Binding in (Data.Bindings) do Entry.Connected = false end
	for _, Target: Element in (Data.All) do Retire(Target) end
	for _, Target: Element in (Data.NextAll) do Retire(Target) end

	table.clear(Data.Bindings)
	table.clear(Data.Roots)
	table.clear(Data.Ids)
	table.clear(Data.All)
	table.clear(Data.Interactive)
	table.clear(Data.NextRoots)
	table.clear(Data.NextIds)
	table.clear(Data.NextAll)
	table.clear(Data.NextInteractive)

	Data.Tokens = {}
	Data.Pointer.Element = nil
	Data.Pointer.Pressed = nil
	Data.Pointer.Over = 0
end

const function SetPainter(Paint: (Target: Element) -> ()): ()
	Painter = Paint
end

const function SetInvalidator(Callback: (Owner: Fields) -> ()): ()
	Invalidate = Callback
end

return {
	Events = Events;
	Selector = Selector;
	Create = Create;
	Begin = Begin;
	Claim = Claim;
	Settle = Settle;
	Commit = Commit;
	Shift = Shift;
	ClearRecords = ClearRecords;
	Enter = Enter;
	Leave = Leave;
	Activate = Activate;
	Press = Press;
	Focus = Focus;
	Reveal = Reveal;
	Bind = Bind;
	Query = Query;
	Destroy = Destroy;
	SetPainter = SetPainter;
	SetInvalidator = SetInvalidator;
}
