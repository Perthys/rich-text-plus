--!strict
--!native
--!optimize 2

const Config = require("../../Config")
const XML = require("../../../XML")
const Types = require("../../Types")
const Styles = require("../../Utility/Styles")
const Intents = require("../../Policy/Intents")
const Presets = require("../../Policy/Presets")

type XMLNode = Types.Node
type Style = Types.Style
type Joint = Types.Joint
type Token = Types.Token
type Context = Types.FlattenContext
type CountData = Types.CountData
type EmitData = Types.EmitData

const DefaultMaxDepth: number = Config.Flatten.MAX_DEPTH
const Controls: number = Intents.Flags.Controls
const Fallback: Presets.Bundle = Presets.Default
const Detached: Types.Ledger = table.freeze({Tree = XML.Node.new("ROOT"), Entries = {}, Slots = {}, Characters = 0, Limit = math.huge, Spans = nil})
const Unused: { [string]: { GuiObject } } = table.freeze({})
const NoStyles: { Style } = table.freeze({})

const function Tally(Target: CountData, Depth: number, Nodes: number, Objects: number, Characters: number): ()
	Target.Depth = Depth
	Target.Nodes = Nodes
	Target.Objects = Objects
	Target.Characters = Characters
end

const function Aim(Emit: EmitData, Tokens: { Token }, Anchor: Token?, Recycle: boolean, Space: boolean, Code: number?, Joint: Joint?): ()
	Emit.Tokens = Tokens
	Emit.Anchor = Anchor
	Emit.Recycle = Recycle
	Emit.Offset = 0
	Emit.Space = Space
	Emit.Code = Code
	Emit.Joint = Joint
	Emit.Bidi = false
end

const function Index(Cache: { [GuiObject]: string }): { [string]: { GuiObject } }
	if next(Cache) == nil then return Unused end

	const Found: { [string]: { GuiObject } } = {}

	for Object: GuiObject, Key: string in (Cache) do
		if Key == "" then continue end

		const List: { GuiObject }? = Found[Key]
		if List then table.insert(List :: { GuiObject }, Object) else Found[Key] = {Object} end
	end

	return Found
end

const function Blank(State: Types.Fields): Context
	return {
		State = State;
		Scale = 1;
		Ledger = Detached;
		Access = {Intents = Fallback.Intents.Bitfield, Strip = Fallback.Denied == "Strip", Assets = nil};
		Emit = {Tokens = {}, Anchor = nil, Recycle = false, Offset = 0, Space = false, Code = nil, Joint = nil, Bidi = false};
		Styles = {Count = 0, Prior = NoStyles, Current = {}};
		Draft = {Stroke = nil, Mark = nil};
		Reuse = {Index = Unused, Claimed = {}, Cache = {}, Trove = nil};
		Tree = {Parent = nil, Derived = {}};
		Counts = {Depth = -1, Nodes = 0, Objects = 0, Characters = 0};
		Limits = {Depth = DefaultMaxDepth, Nodes = math.huge, Objects = math.huge, Characters = math.huge, TextSize = {Min = 1, Max = Styles.MaximumTextSize}};
		Nesting = {Opaque = 0, Region = 0};
		Flags = {Busy = false, Halted = false, Generated = false, Collapse = false, Strip = false};
	}
end

const function Reset(Context: Context, Root: XMLNode?, Prior: { Style }?): Context
	const State: Types.Fields = Context.State
	const Granted: number = (State.Intents or Fallback.Intents).Bitfield
	const Bounds: Types.LimitsData = State.Limits or Fallback.Limits
	const Limit: number = if Root then Bounds.Characters or math.huge else math.huge
	const Emit: EmitData = Context.Emit
	const Reuse: Types.ReuseData = Context.Reuse
	const Limits: Types.LimitData = Context.Limits
	const Flags: Types.FlagData = Context.Flags
	const Interned: Types.InternData = Context.Styles

	if Root then
		const Previous: Types.Ledger? = State.Document.Ledger
		const Entries: { Types.Entry } = table.create(if Previous then #(Previous :: Types.Ledger).Entries else 0)

		Context.Ledger = {Tree = Root :: XMLNode, Entries = Entries, Slots = {}, Characters = 0, Limit = Limit, Spans = nil}
		Emit.Tokens = table.create(#State.Document.Tokens)
		Reuse.Index = Index(State.Objects.Cache)
		Reuse.Cache = {}
	end

	table.clear(Reuse.Claimed)
	table.clear(Interned.Current)

	Context.Scale = Styles.EffectiveScale(State)
	Context.Access.Intents = Granted
	Context.Access.Strip = (State.Denied or Fallback.Denied) == "Strip"
	Context.Access.Assets = State.Assets
	Context.Draft.Stroke = nil
	Context.Draft.Mark = nil
	Context.Nesting.Opaque = 0
	Context.Nesting.Region = 0

	Aim(Emit, Emit.Tokens, nil, false, false, nil, nil)
	Tally(Context.Counts, -1, 0, 0, 0)
	Tally(Limits, Bounds.Depth or DefaultMaxDepth, Bounds.Nodes or math.huge, Bounds.Objects or math.huge, Limit)

	Limits.TextSize.Min = Bounds.TextSize.Min or 1
	Limits.TextSize.Max = Bounds.TextSize.Max or Styles.MaximumTextSize
	Interned.Count = 0
	Interned.Prior = Prior or NoStyles
	Reuse.Trove = nil
	Context.Tree.Parent = nil
	Flags.Generated = false
	Flags.Collapse = State.Options.Whitespace == "Markup"
	Flags.Halted = false
	Flags.Strip = not bit32.btest(Granted, Controls)

	return Context
end

const function Release(Context: Context): ()
	Context.Flags.Busy = false
	Context.Reuse.Index = Unused
end

return {
	NoStyles = NoStyles;
	Aim = Aim;
	Blank = Blank;
	Reset = Reset;
	Release = Release;
}
