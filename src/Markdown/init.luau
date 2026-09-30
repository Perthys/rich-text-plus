--!strict
--!native
--!optimize 2

const XML = require("../XML")
const Types = require("./Types")
const Profiler = require("./Utility/Profiler")
const MarkdownTypes = require("./Types/Markdown")
const Config = require("./Config")
const Scan = require("@self/Scan")
const Blocks = require("@self/Blocks")
const Inline = require("@self/Inline")
const Emit = require("@self/Emit")
const Embed = require("@self/Embed")

export type Document = MarkdownTypes.Document
export type Block = MarkdownTypes.Block
export type Inline = MarkdownTypes.Inline
export type Dialect = MarkdownTypes.Dialect
export type Extension = MarkdownTypes.Extension
export type ResolvedTheme = MarkdownTypes.ResolvedTheme

type BlockRule = MarkdownTypes.BlockRule
type InlineRule = MarkdownTypes.InlineRule
type Emitter = MarkdownTypes.Emitter

const Defaults: ResolvedTheme = Config.Theme :: any
const Settings = Config.Markdown

const function ResolveTheme(Theme: Types.Theme?): ResolvedTheme
	if not Theme then return Defaults end

	const Source: Types.Theme = Theme :: Types.Theme

	return {
		CodeFamily = Source.CodeFamily or Defaults.CodeFamily;
		CodeTextColor = Source.CodeTextColor or Defaults.CodeTextColor;
		CodeBackground = Source.CodeBackground or Defaults.CodeBackground;
		CodeBackgroundTransparency = Source.CodeBackgroundTransparency or Defaults.CodeBackgroundTransparency;
		CodePadding = Source.CodePadding or Defaults.CodePadding;
		CodeCornerRadius = Source.CodeCornerRadius or Defaults.CodeCornerRadius;
		QuoteColor = Source.QuoteColor or Defaults.QuoteColor;
		RuleColor = Source.RuleColor or Defaults.RuleColor;
		HeadingScale = Source.HeadingScale or Defaults.HeadingScale;
		Syntax = Source.Syntax;
	}
end

const function Accepts(Rule: BlockRule, Char: string): boolean
	return Rule.Leads == nil or string.find(Char, `^[{Rule.Leads}]`) ~= nil
end

const function Route(Rules: { BlockRule }, Keep: (Rule: BlockRule) -> boolean): { [number]: { BlockRule } }
	const Routes: { [number]: { BlockRule } } = {}
	const Shared: { [string]: { BlockRule } } = {}

	for Byte = 0, 255 do
		const Char: string = string.char(Byte)
		const Chosen: { BlockRule } = {}
		const Names: { string } = {}

		for _, Rule: BlockRule in (Rules) do
			if not Keep(Rule) or not Accepts(Rule, Char) then continue end

			table.insert(Chosen, Rule)
			table.insert(Names, Rule.Name)
		end

		const Key: string = table.concat(Names, "|")
		if not Shared[Key] then Shared[Key] = table.freeze(Chosen) end

		Routes[Byte] = Shared[Key]
	end

	return table.freeze(Routes)
end

const function Tests(Routes: { [number]: { BlockRule } }): { [number]: { (Line: string) -> any } }
	const Result: { [number]: { (Line: string) -> any } } = {}
	const Shared: { [{ BlockRule }]: { (Line: string) -> any } } = {}

	for Byte: number, Rules: { BlockRule } in (Routes) do
		if not Shared[Rules] then
			const Chosen: { (Line: string) -> any } = {}
			for _, Rule: BlockRule in (Rules) do table.insert(Chosen, Rule.Test :: (Line: string) -> any) end
			Shared[Rules] = table.freeze(Chosen)
		end

		Result[Byte] = Shared[Rules]
	end

	return table.freeze(Result)
end

const function Compose(Rules: { BlockRule }, Inlines: { [number]: InlineRule }, Emitters: { [string]: Emitter }): Dialect
	return table.freeze({
		Blocks = table.freeze(Rules);
		Routes = Route(Rules, function(): boolean return true end);
		Shallow = Route(Rules, function(Rule: BlockRule): boolean return not Rule.Nested end);
		Interrupters = Tests(Route(Rules, function(Rule: BlockRule): boolean return Rule.Interrupts and Rule.Test ~= nil end));
		Inlines = table.freeze(Inlines);
		Emitters = table.freeze(Emitters);
		Specials = Inline.Specials(Inlines);
	})
end

const Standard: Dialect = Compose(table.clone(Blocks.Rules), table.clone(Inline.Rules), table.clone(Emit.Emitters))

const function Extend(Base: Dialect, Changes: Extension): Dialect
	const Rules: { BlockRule } = {}
	const Replaced: { [string]: BlockRule } = {}
	const Added: { BlockRule } = {}

	for _, Rule: BlockRule in (Changes.Blocks or {}) do
		if table.find(Base.Blocks, Rule) then continue end

		local Known: boolean = false
		for _, Existing: BlockRule in (Base.Blocks) do
			if Existing.Name == Rule.Name then Known = true; break end
		end

		if Known then Replaced[Rule.Name] = Rule else table.insert(Added, Rule) end
	end

	for _, Rule: BlockRule in (Base.Blocks) do
		if Rule.Name == "Paragraph" then
			for _, Extra: BlockRule in (Added) do table.insert(Rules, Extra) end
		end

		table.insert(Rules, Replaced[Rule.Name] or Rule)
	end

	const Inlines: { [number]: InlineRule } = table.clone(Base.Inlines)
	for Byte: number, Rule: InlineRule in (Changes.Inlines or {}) do Inlines[Byte] = Rule end

	const Emitters: { [string]: Emitter } = table.clone(Base.Emitters)
	for Name: string, Handler: Emitter in (Changes.Emitters or {}) do Emitters[Name] = Handler end

	return Compose(Rules, Inlines, Emitters)
end

const function Structure(Source: string, Dialect: Dialect): Document
	const Children: { Block }, EndsBlank: boolean = Blocks.Parse({Dialect = Dialect, Depth = 0}, Scan.SplitLines(Source))

	return {
		Type = "Document";
		Children = Children;
		EndsBlank = EndsBlank;
		LeadingSpace = string.find(Source, "^%s") ~= nil;
		TrailingSpace = string.find(Source, "%s$") ~= nil;
	}
end

const function Annotate(Nodes: { any }, Dialect: Dialect): ()
	for _, Node: any in (Nodes) do
		if Node.Source then Node.Children = Inline.Parse(Node.Source, Dialect) end
		if Node.Type == "BlockQuote" then Annotate(Node.Children, Dialect) end
		if Node.Type == "List" then
			for _, Item: any in (Node.Items) do Annotate(Item.Children, Dialect) end
		end
	end
end

const function Parse(Source: string, Dialect: Dialect?): Document
	const Chosen: Dialect = Dialect or Standard
	const Root: Document = Structure(Source, Chosen)

	Annotate(Root.Children, Chosen)

	return Root
end

const function ToMarkup(Source: string, Theme: Types.Theme?, BaseSize: number?, Dialect: Dialect?): string
	if Scan.IsBlank(Source) then return "" end

	const Chosen: Dialect = Dialect or Standard
	const Limit: number = #Source * Settings.AMPLIFICATION_LIMIT + Settings.OUTPUT_SLACK

	return Emit.Document(Structure(Source, Chosen), ResolveTheme(Theme), BaseSize or Settings.BASE_SIZE, Limit, Chosen)
end

const function ToTree(Source: string, State: Types.Fields?): Types.Node
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Markdown") end

	const Theme: Types.Theme? = if State then State.Theme else nil
	const BaseSize: number? = if State then State.Label.TextSize else nil
	const Tree: Types.Node = XML.GenerateTreeFromXML(ToMarkup(Source, Theme, BaseSize))

	if Profiling then Profiler.End() end

	return Tree
end

return {
	Defaults = Defaults;
	Standard = Standard;
	Theme = ResolveTheme;
	Extend = Extend;
	Parse = Parse;
	ToMarkup = ToMarkup;
	ToTree = ToTree;
	Preprocess = Embed.Preprocess;
}
