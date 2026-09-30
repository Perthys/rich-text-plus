--!strict
--!native
--!optimize 2

const Config = require("../Config")
const XML = require("../../XML")
const Trove = require("../../Trove")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Styles = require("../Utility/Styles")
const Intents = require("../Policy/Intents")
const Assets = require("../Policy/Assets")
const Bidi = require("../Text/Bidi")
const Classes = require("../Classes")
const Lifetime = require("../Utility/Lifetime")
const Elements = require("../Elements")
const Tokens = require("@self/Tokens")
const Styling = require("@self/Styling")
const Scope = require("@self/Context")

type XMLNode = Types.Node
type Style = Types.Style
type Joint = Types.Joint
type Element = Types.Element
type Context = Types.FlattenContext
type Handler = Types.FlattenHandler

const RegionTag: string = "customclass"
const LinkTag: string = "a"
const CodeBlockTag: string = "codeblock"
const MarkdownTag: string = "md"
const Verbatim: { [string]: boolean } = table.freeze({[CodeBlockTag] = true, [MarkdownTag] = true})
const Proxy: Types.Token = {Kind = "Word", Width = 0, Height = 0, SpaceBefore = false, X = 0}
const DefaultLinkColor: Color3 = Config.Renderer.LINK_COLOR

const LowerName = Styles.LowerName
const Band = bit32.band
const Btest = bit32.btest
const TagMasks: { [string]: number } = Intents.Masks
const Effects: number = Intents.Flags.Effects
const CodeBlocks: number = Intents.Flags.CodeBlocks
const Controls: number = Intents.Flags.Controls
const Colors: number = Intents.Flags.Color
const Clone = Styles.Clone
const Unescape = Styles.Unescape
const ParseColor = Styles.ParseColor
const AddText = Tokens.AddText
const Decode = Tokens.Decode
const AddObject = Tokens.AddObject
const AddSource = Tokens.AddSource
const AddBreak = Tokens.AddBreak
const Load = Styling.Load
const Intern = Styling.Intern
const Reject = Styling.Reject
const NativeHandlers: { [string]: Handler } = Styling.Handlers

local Walk: Handler
local Visit: Handler
const Contexts = Lifetime.Own("Flatten.Contexts", {} :: { [Types.Fields]: Context })
const Bases = Lifetime.Own("Flatten.Bases", {} :: { [Types.Fields]: Style })
const Interned = Lifetime.Own("Flatten.Interned", {} :: { [Types.Fields]: { Style } })
const Tokenizers = Lifetime.Own("Flatten.Tokenizers", {} :: { [Types.Fields]: Context })
const NoStyles: { Style } = Scope.NoStyles

const function Count(Context: Context): boolean
	const Flags: Types.FlagData = Context.Flags
	if Flags.Halted then return false end

	const Counts: Types.CountData = Context.Counts

	Counts.Nodes += 1
	if Counts.Nodes <= Context.Limits.Nodes then return true end

	Flags.Halted = true

	return false
end

const function AddPlainText(Context: Context, Node: XMLNode, Style: Style): ()
	const Stack: { XMLNode } = {Node}

	while #Stack > 0 do
		const Current: XMLNode = table.remove(Stack) :: XMLNode
		if Current ~= Node and not Count(Context) then return end

		const Type: string = Current.Type

		if Type == "STRING" then AddText(Context, Decode(Context, Current.Text or ""), Style); continue end
		if Type ~= "TAG" and Type ~= "SINGLE" then continue end

		const Tag: string = LowerName(Current.TagType or "")
		if Tag == "br" then AddBreak(Context.Emit) end
		if Context.Flags.Collapse and Verbatim[Tag] then AddText(Context, Styles.InnerText(Current), Style); continue end

		const Children: { XMLNode } = Current.Children
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end
end

const function IsBuiltin(Tag: string): boolean
	return NativeHandlers[Tag] ~= nil or Tag == RegionTag or Classes.Has(Styles.PascalName(Tag))
end

NativeHandlers[MarkdownTag] = function(Context: Context, Node: XMLNode, Style: Style): ()
	if Node.Type == "SINGLE" then return end

	const Markdown = require("../Markdown")
	const Tree: XMLNode = Markdown.ToTree(Styles.InnerText(Node), Context.State)

	const Flags: Types.FlagData = Context.Flags
	const Generated: boolean = Flags.Generated
	const Collapsing: boolean = Flags.Collapse
	Flags.Generated = true
	Flags.Collapse = false
	Context.Nesting.Opaque += 1
	Walk(Context, Tree, Style)
	Context.Nesting.Opaque -= 1
	Flags.Collapse = Collapsing
	Flags.Generated = Generated
end

const function RunCustom(Context: Context, Definition: Types.ClassDefinition, Tag: string, Node: XMLNode, Style: Style): ()
	const Kind: string = Definition.Kind

	if Kind == "Object" then
		const Build = Definition.Build
		if not Build or Context.Counts.Objects >= Context.Limits.Objects then return end

		const Built: GuiObject? = Build(Node, Clone(Style), Context.Scale, Context.State)
		if Built then AddObject(Context, Built :: GuiObject, Definition.Block == true, "") end

		return
	end

	if Node.Type == "SINGLE" then return end

	const Next: Style = Clone(Style)
	const Wrap = Definition.Wrap
	if Kind == "Container" and Wrap then Next.Container = {Name = Tag, Node = Node, Wrap = Wrap} end
	if Kind == "Effect" and Btest(Context.Access.Intents, Effects) then Classes.Load("Effect").Custom(Next, Tag, Node) end

	const Apply = Definition.Apply
	const Current: Element? = Context.Tree.Parent

	if Current and Definition.Interactive then
		(Current :: Element).Intrinsic = true
		(Current :: Element).Restyle = Apply ~= nil
		Next.Element = Current
	end

	if Apply and Current then Apply(Next, Node, Current :: Element) end

	Context.Nesting.Opaque += 1
	Walk(Context, Node, Next)
	Context.Nesting.Opaque -= 1
end

const function OpenLink(Context: Context, Class: any, Node: XMLNode, Style: Style): ()
	const Draft: Style = Load(Style)
	const Current: Element? = Context.Tree.Parent

	Class.Open(Draft, Node, Context.State.Theme.LinkColor or DefaultLinkColor)

	if Current then
		(Current :: Element).Intrinsic = true
		Draft.Element = Current
	end

	const Next: Style = Intern(Context, Draft)

	if Node.Type == "SINGLE" then AddText(Context, Next.Link or "", Next) else Walk(Context, Node, Next) end
end

const function Signature(Context: Context, Class: any, Node: XMLNode, Style: Style): string
	const Parts: { string } = {
		Node.TagType or "";
		tostring(Context.Scale);
		tostring(Style.Size);
		Style.Color:ToHex();
		tostring(Style.Transparency);
		Style.Family;
		if Btest(Context.Access.Intents, CodeBlocks) then "+" else "-";
		if Context.State.Rendering.SyntaxHighlight then "+" else "-";
	}

	for _, Entry: Types.Attribute in (Node.Attributes) do
		table.insert(Parts, Entry.Name)
		table.insert(Parts, Entry.Value)
	end

	if not Class.Void then table.insert(Parts, Styles.InnerText(Node)) end

	return table.concat(Parts, "\0")
end

const function Reuse(Context: Context, Key: string): GuiObject?
	const Pool: Types.ReuseData = Context.Reuse
	const List: { GuiObject }? = Pool.Index[Key]; if not List then return nil end

	const Index: number = (Pool.Claimed[Key] or 0) + 1
	const Found: GuiObject? = (List :: { GuiObject })[Index]
	if Found then Pool.Claimed[Key] = Index end

	return Found
end

const function BuildObject(Context: Context, Class: any, Node: XMLNode, Style: Style): ()
	const Source: ((Node: XMLNode) -> string?)? = Class.Source
	const Asset: string? = if Source then (Source :: (Node: XMLNode) -> string?)(Node) else nil
	const Allowed: boolean = Context.Counts.Objects < Context.Limits.Objects
		and (Source == nil or (Asset ~= nil and Assets.Allows(Context.Access.Assets, Asset :: string)))

	if Allowed then
		const Key: string = Signature(Context, Class, Node, Style)
		const Built: GuiObject? = Reuse(Context, Key) or Class.Build(Node, Clone(Style), Context.Scale, Context.State)
		if Built then AddObject(Context, Built :: GuiObject, Class.Block == true, Key) end
	end

	if Class.Void then Walk(Context, Node, Style) end
end

const function RunBuiltin(Context: Context, Class: any, Node: XMLNode, Style: Style): ()
	const Kind: string = Class.Kind

	if Kind == "Object" then BuildObject(Context, Class, Node, Style); return end
	if Kind == "Link" then OpenLink(Context, Class, Node, Style); return end

	const Draft: Style = Load(Style)
	Class.Apply(Draft, Node, Context.State)

	Walk(Context, Node, Intern(Context, Draft))
end

const function Disable(Context: Context, Tag: string, Node: XMLNode, Style: Style): ()
	if Tag == CodeBlockTag then RunBuiltin(Context, Classes.ForTag(Styles.PascalName(Tag)), Node, Style); return end
	if Tag == LinkTag and Node.Type == "SINGLE" then AddText(Context, Styles.Attribute(Node, "Href") or "", Style); return end

	Walk(Context, Node, Style)
end

const function Deny(Context: Context, Tag: string, Node: XMLNode, Style: Style): ()
	if Context.Access.Strip then Disable(Context, Tag, Node, Style) else Reject(Context, Node, Style) end
end

const function DenyVerbatim(Context: Context, Tag: string, Node: XMLNode, Style: Style): ()
	const Flags: Types.FlagData = Context.Flags
	const Collapsing: boolean = Flags.Collapse
	Flags.Collapse = false
	Deny(Context, Tag, Node, Style)
	Flags.Collapse = Collapsing
end

const function Custom(Context: Context, Tag: string): Types.ClassDefinition?
	if Tag == RegionTag then return nil end

	const Definition: Types.ClassDefinition? = Classes.Find(Context.State, Tag)
	if not Definition or (not Definition.Override and IsBuiltin(Tag)) then return nil end

	return Definition
end

const function VisitCustom(Context: Context, Tag: string, Node: XMLNode, Style: Style): boolean
	const Definition: Types.ClassDefinition? = Custom(Context, Tag)
	if not Definition then return false end

	RunCustom(Context, Definition :: Types.ClassDefinition, Tag, Node, Style)

	return true
end

const function Alias(Node: XMLNode, Tag: string): XMLNode
	const Kept: { Types.Attribute } = {}

	for _, Entry: Types.Attribute in (Node.Attributes) do
		if LowerName(Entry.Name) ~= "name" then table.insert(Kept, Entry) end
	end

	return XML.Node.new(Node.Type, {TagType = Tag, Text = Node.Text, Attributes = Kept, Children = Node.Children})
end

const function EnterRegion(Context: Context, Node: XMLNode, Style: Style): ()
	Context.Nesting.Region += 1

	const Name: string? = Styles.Attribute(Node, "Name")
	const Tag: string? = if Name then LowerName(Name :: string) else nil

	if not (Tag and VisitCustom(Context, Tag :: string, Alias(Node, Tag :: string), Style)) then Walk(Context, Node, Style) end

	Context.Nesting.Region -= 1
end

const function Adopt(Context: Context, Derived: { [Style]: Style }, Style: Style, Target: Element): Style
	const Found: Style? = Derived[Style]
	if Found then return Found :: Style end

	const Draft: Style = Load(Style)
	Draft.Element = Target

	const Made: Style = Intern(Context, Draft)
	Derived[Style] = Made

	return Made
end

const function Outer(Owner: Element?, Target: Element): boolean
	if Owner == nil then return true end
	if Owner == Target then return false end

	local Current: Element? = Target.Parent

	while Current do
		if Current == Owner then return true end
		Current = (Current :: Element).Parent
	end

	return false
end

const function Retag(Context: Context, Target: Element): ()
	const Derived: { [Style]: Style } = Context.Tree.Derived
	const Tokens: { Types.Token } = Context.Emit.Tokens
	const Entries: { Types.Entry } = Context.Ledger.Entries

	table.clear(Derived)

	for Index = Target.First, Target.Last do
		const Token: Types.Token = Tokens[Index]
		const Current: Style? = Token.Style
		if Current and Outer((Current :: Style).Element, Target) then Token.Style = Adopt(Context, Derived, Current :: Style, Target) end
	end

	for Slot = Target.EntryOpen, Target.EntryClose do
		const Entry: Types.Entry = Entries[Slot]
		if Outer(Entry.Style.Element, Target) then Entry.Style = Adopt(Context, Derived, Entry.Style, Target) end
	end

	table.clear(Derived)
end

const function Open(Context: Context, Tag: string, Node: XMLNode): Element
	local Id: string? = nil
	local Hover: string? = nil
	local Press: string? = nil

	for _, Entry: Types.Attribute in (Node.Attributes) do
		const Name: string = LowerName(Entry.Name)

		if Name == "id" then
			Id = Id or Unescape(Entry.Value)
		elseif Name == "hovercolor" then
			Hover = Hover or Entry.Value
		elseif Name == "presscolor" then
			Press = Press or Entry.Value
		end
	end

	const Tree: Types.TreeData = Context.Tree
	const State: Types.Fields = Context.State
	const Created: Element = Elements.Claim(State.Elements, State, Tree.Parent, Tag, Node, Id)

	Created.First = #Context.Emit.Tokens + 1
	Created.EntryOpen = #Context.Ledger.Entries + 1

	if (Hover or Press) and Btest(Context.Access.Intents, Colors) then
		Created.HoverColor = if Hover then ParseColor(Unescape(Hover :: string)) else nil
		Created.PressColor = if Press then ParseColor(Unescape(Press :: string)) else nil
		Created.Intrinsic = Created.HoverColor ~= nil or Created.PressColor ~= nil
	end

	Tree.Parent = Created

	return Created
end

const function Close(Context: Context, Created: Element, Outer: Element?): ()
	Created.Last = #Context.Emit.Tokens
	Created.EntryClose = #Context.Ledger.Entries
	Context.Tree.Parent = Outer

	if Elements.Settle(Context.State.Elements, Created) then Retag(Context, Created) end
end

const function RegionName(Node: XMLNode): string
	const Name: string? = Styles.Attribute(Node, "Name")

	return if Name then LowerName(Name :: string) else RegionTag
end

const function Dispatch(Context: Context, Tag: string, Target: XMLNode, Style: Style): ()
	if Tag == RegionTag then EnterRegion(Context, Target, Style); return end

	const Native: Handler? = NativeHandlers[Tag]
	if Native then Native(Context, Target, Style); return end

	const Class: any = Classes.ForTag(Styles.PascalName(Tag))
	if Class then RunBuiltin(Context, Class, Target, Style); return end

	Walk(Context, Target, Style)
end

Visit = function(Context: Context, Node: XMLNode, Style: Style): ()
	const Tag: string = LowerName(Node.TagType or "")

	if Context.Nesting.Region > 0 then
		const Definition: Types.ClassDefinition? = Custom(Context, Tag)

		if Definition then
			const Outer: Element? = Context.Tree.Parent
			const Created: Element = Open(Context, Tag, Node)

			RunCustom(Context, Definition :: Types.ClassDefinition, Tag, Node, Style)
			Close(Context, Created, Outer)

			return
		end
	end

	const Mask: number? = TagMasks[Tag]
	const Granted: number = Context.Access.Intents

	if not Mask or not Btest(Granted, Mask :: number) then
		if Context.Flags.Collapse and Verbatim[Tag] then DenyVerbatim(Context, Tag, Node, Style) else Deny(Context, Tag, Node, Style) end

		return
	end

	const Target: XMLNode = if Band(Granted, Mask :: number) == Mask then Node else Intents.Filter(Node, Granted)
	const Outer: Element? = Context.Tree.Parent
	const Created: Element = Open(Context, if Tag == RegionTag then RegionName(Target) else Tag, Target)

	Dispatch(Context, Tag, Target, Style)
	Close(Context, Created, Outer)
end

Walk = function(Context: Context, Node: XMLNode, Style: Style): ()
	const Children: { XMLNode } = Node.Children
	if #Children == 0 then return end

	const Counts: Types.CountData = Context.Counts
	const Nesting: Types.NestingData = Context.Nesting

	Counts.Depth += 1

	const Nested: boolean = Counts.Depth < Context.Limits.Depth

	for _, Child: XMLNode in (Children) do
		if not Count(Context) then break end

		const Type: string = Child.Type

		if Type == "STRING" then
			if Nesting.Opaque == 0 then AddSource(Context, Child, Style) else AddText(Context, Decode(Context, Child.Text :: string), Style) end
		elseif Type == "TAG" or Type == "SINGLE" then
			if Nested then Visit(Context, Child, Style) else AddPlainText(Context, Child, Style) end
		end
	end

	Counts.Depth -= 1
end

const function Create(State: Types.Fields, Root: XMLNode?): Context
	return Scope.Reset(Scope.Blank(State), Root, Interned[State])
end

const function Acquire(State: Types.Fields, Root: XMLNode): Context
	const Existing: Context? = Contexts[State]
	if Existing and not Existing.Flags.Busy then return Scope.Reset(Existing :: Context, Root, Interned[State]) end

	const Created: Context = Create(State, Root)
	if not Existing then Contexts[State] = Created end

	return Created
end

const function Commit(Context: Context): ()
	const State: Types.Fields = Context.State
	const Objects: Types.ObjectData = State.Objects
	const Troves: Types.TroveData = State.Troves
	const Previous: { [GuiObject]: string } = Objects.Cache
	const Reuse: Types.ReuseData = Context.Reuse
	const Cache: { [GuiObject]: string } = Reuse.Cache

	Objects.Cache = Cache
	if next(Previous) == nil and not Reuse.Trove then return end

	const Owner: Trove.Trove = Reuse.Trove or Troves.Main:Extend()
	const Records: { [GuiObject]: Types.Record } = State.Instances.Records

	for Object: GuiObject in (Previous) do
		if Cache[Object] then Owner:Add(Object); continue end

		Records[Object] = nil
		Objects.Sizes[Object] = nil
		Object:Destroy()
	end

	Troves.Main:Pop(Troves.Objects)
	Troves.Objects = Owner
end

const function Discard(Context: Context): ()
	const Owner: Trove.Trove? = Context.Reuse.Trove; if not Owner then return end
	const State: Types.Fields = Context.State

	if State.Destroyed then (Owner :: Trove.Trove):Clean() else State.Troves.Main:Remove(Owner :: Trove.Trove) end
end

const function Build(State: Types.Fields, Root: XMLNode, Context: Context): boolean
	const Generation: number = State.Generation.Refresh
	const Base: Style = Styles.Base(State, Bases[State])
	const Access: Types.AccessData = Context.Access
	const Plain: boolean = not Intents.Interprets(Access.Intents, Access.Strip)

	Bases[State] = Base
	Context.Tree.Parent = nil
	Elements.Begin(State.Elements)

	if Plain then AddText(Context, State.Document.Source or State.Label.Text, Base) else Walk(Context, Root, Base) end

	if State.Generation.Refresh ~= Generation or State.Destroyed then Discard(Context); return false end

	const Emit: Types.EmitData = Context.Emit
	const Flags: Types.FlagData = Context.Flags

	const Logical: { Types.Token } = Emit.Tokens

	if Emit.Bidi then Emit.Tokens = Bidi.Apply(Emit.Tokens) end

	const Ledger: Types.Ledger = Context.Ledger
	Ledger.Characters = Context.Counts.Characters

	Commit(Context)
	Elements.Commit(State.Elements, Logical)

	const Document: Types.DocumentData = State.Document
	Document.Tokens = Emit.Tokens
	Document.Ledger = if Plain or Emit.Bidi or Flags.Halted then nil else Ledger

	const Interning: Types.InternData = Context.Styles
	const Created: { Style } = Interning.Current
	const Retired: { Style } = Interning.Prior

	Interned[State] = Created
	Interning.Prior = Created
	Interning.Current = if Retired == NoStyles then {} else Retired

	return true
end

const function Run(State: Types.Fields, Root: XMLNode): boolean
	if State.Destroyed then return false end

	const Context: Context = Acquire(State, Root)

	Context.Flags.Busy = true

	const Built: boolean = Build(State, Root, Context)

	Scope.Release(Context)

	return Built
end

const function Tokenize(State: Types.Fields, Style: Style, Text: string, Previous: string?, Space: boolean, Code: number?, Entered: Joint?, Into: { Types.Token }): (boolean, boolean, number?, Joint?, boolean)
	const Context: Context = Tokenizers[State] or Create(State, nil)
	Tokenizers[State] = Context

	Proxy.Kind = Previous or "Word"
	Proxy.Hyphen = nil

	const Emit: Types.EmitData = Context.Emit

	Context.Flags.Strip = State.Intents ~= nil and not Btest(State.Intents.Bitfield, Controls)
	Scope.Aim(Emit, Into, if Previous then Proxy else nil, true, Space, Code, Entered)

	AddText(Context, Text, Style)

	if Emit.Bidi then return false, false, nil, nil, false end

	return true, Emit.Space, Emit.Code, Emit.Joint, Previous ~= nil and Proxy.Hyphen ~= nil
end

Styling.Bind(Walk)

return {
	Run = Run;
	Tokenize = Tokenize;
	Recycle = Tokens.Recycle;
	Unpack = Tokens.Unpack;
}
