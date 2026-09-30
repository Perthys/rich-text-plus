--!strict
--!native
--!optimize 2

const XML = require("../../XML")
const Types = require("../Types/Markdown")
const Config = require("../Config").Markdown
const Inline = require("./Inline")

type Writer = Types.Writer
type Context = Types.Context
type Emitter = Types.Emitter
type Block = Types.Block
type Inline = Types.Inline
type Document = Types.Document
type ResolvedTheme = Types.ResolvedTheme
type Dialect = Types.Dialect

const Escape: (Text: string) -> string = XML.Escape

const EmphasisTags: { [string]: string } = {
	["Emphasis"] = "i";
	["Strong"] = "b";
	["Strikethrough"] = "s";
}

const function Push(Out: Writer, Text: string): ()
	Out.Count += 1
	Out.Parts[Out.Count] = Text
	Out.Size += #Text

	if Out.Size > Out.Limit then Out.Halted = true end
end

const function TakeMarker(Context: Context): string?
	const Marker: string? = Context.Marker
	Context.Marker = nil

	return Marker
end

const function BeginText(Out: Writer, Context: Context): ()
	const Gap: Types.Gap = Out.Gap

	if Gap.Pending and Gap.LastText then
		if Gap.Prefix ~= "" then Push(Out, Gap.Prefix) end
		Push(Out, "<br/>")
	end

	Gap.Pending = false
	Gap.LastText = true

	const Start: string = TakeMarker(Context) or Context.Prefix
	if Start ~= "" then Push(Out, Start) end
end

const function BeginObject(Out: Writer, Context: Context): ()
	const Gap: Types.Gap = Out.Gap

	Gap.Pending = false
	Gap.LastText = false

	const Marker: string? = TakeMarker(Context)
	if Marker then Push(Out, Marker); Push(Out, "<br/>") end
end

const function MarkGap(Out: Writer, Context: Context): ()
	const Gap: Types.Gap = Out.Gap
	if Gap.LastText == nil then return end

	Gap.Pending = true
	Gap.Prefix = Context.Prefix
end

local EmitInlines: (Out: Writer, Nodes: { Inline }, Break: string) -> ()

const function EmitInline(Out: Writer, Node: Inline, Break: string): ()
	const Kind: string = Node.Type

	if Kind == "Text" then
		const Value: string = (Node :: Types.Text).Value
		if Value ~= "" then Push(Out, Escape(Value)) end
	elseif Kind == "Break" then
		Push(Out, Break)
	elseif Kind == "Code" then
		Push(Out, `<code>{Escape((Node :: Types.Code).Value)}</code>`)
	elseif Kind == "Link" then
		const Link: Types.Link = Node :: Types.Link
		Push(Out, `<a href="{Escape(Link.Destination)}">`)
		EmitInlines(Out, Link.Children, Break)
		Push(Out, "</a>")
	elseif Kind == "Image" then
		Push(Out, `<img src="{Escape((Node :: Types.Image).Source)}"/>`)
	else
		const Tag: string = EmphasisTags[Kind]
		Push(Out, `<{Tag}>`)
		EmitInlines(Out, (Node :: Types.Emphasis).Children, Break)
		Push(Out, `</{Tag}>`)
	end
end

EmitInlines = function(Out: Writer, Nodes: { Inline }, Break: string): ()
	for _, Node: Inline in (Nodes) do EmitInline(Out, Node, Break) end
end

const function EmitPieces(Out: Writer, State: Types.Scanner, Break: string): ()
	const Pieces: { Types.Piece } = State.Pieces

	for Index = 1, State.Count do
		const Piece: any = Pieces[Index]

		if Piece == false then continue end

		if type(Piece) == "string" then
			if Piece ~= "" then Push(Out, Escape(Piece)) end

			continue
		end

		if Piece == Inline.Break then Push(Out, Break); continue end

		const Kind: string? = Piece.Type

		if Kind == nil then
			if Piece.Before ~= "" then Push(Out, Piece.Before) end
			if Piece.Count > 0 then Push(Out, string.rep(Piece.Char, Piece.Count)) end
			if Piece.After ~= "" then Push(Out, Piece.After) end
		elseif Kind == "Open" then
			Push(Out, `<a href="{Escape(Piece.Destination)}">`)
		elseif Kind == "Close" then
			Push(Out, "</a>")
		else
			EmitInline(Out, Piece :: Inline, Break)
		end
	end
end

const function WriteText(Out: Writer, Context: Context, Source: string, Open: string?, Close: string?): ()
	const Prefix: string = Context.Prefix
	const Hanging: boolean = Prefix ~= ""
	const Break: string = if Hanging then `<br/><indent>{Prefix}</indent>` else "<br/>"

	BeginText(Out, Context)

	if Hanging then Push(Out, "<indent>") end
	if Open then Push(Out, Open) end

	const State: Types.Scanner = Inline.Tokenize(Source, Out.Dialect, #Break, Out.Limit - Out.Size)

	EmitPieces(Out, State, Break)
	Inline.Release(State)

	if Close then Push(Out, Close) end
	if Hanging then Push(Out, "</indent>") end

	Push(Out, "<br/>")
end

local EmitBlocks: (Out: Writer, Children: { Block }, EndsBlank: boolean, Context: Context) -> ()

const function Emit(Out: Writer, Node: Block, Context: Context): ()
	(Out.Dialect.Emitters[Node.Type] :: Emitter)(Out, Node, Context)
end

const function Paragraph(Out: Writer, Node: Types.Paragraph, Context: Context): ()
	WriteText(Out, Context, Node.Source, nil, nil)
end

const function Heading(Out: Writer, Node: Types.Heading, Context: Context): ()
	const Look: Types.Look = Out.Look
	const Size: number = math.floor(Look.BaseSize * (Look.Theme.HeadingScale[Node.Level] or 1) + 0.5)

	WriteText(Out, Context, Node.Source, `<b><font size="{Size}">`, "</font></b>")
end

const function CodeBlock(Out: Writer, Node: Types.CodeBlock, Context: Context): ()
	BeginObject(Out, Context)
	Push(Out, if Node.Language then `<codeblock lang="{Escape(Node.Language :: string)}">` else "<codeblock>")
	if Node.Body ~= "" then Push(Out, Escape(Node.Body)) end
	Push(Out, "</codeblock>")
end

const function ThematicBreak(Out: Writer, _: Types.ThematicBreak, Context: Context): ()
	BeginObject(Out, Context)
	Push(Out, "<hr/>")
end

const function BlockQuote(Out: Writer, Node: Types.BlockQuote, Context: Context): ()
	const Marker: string? = TakeMarker(Context)
	const QuoteBar: string = Out.Look.QuoteBar

	EmitBlocks(Out, Node.Children, Node.EndsBlank, {
		Prefix = Context.Prefix .. QuoteBar;
		Marker = if Marker then (Marker :: string) .. QuoteBar else nil;
		Lists = Context.Lists;
	})
end

const function List(Out: Writer, Node: Types.List, Context: Context): ()
	const Glyphs: { string } = Config.BULLET_GLYPHS
	const Glyph: string = Glyphs[Context.Lists % #Glyphs + 1]
	local Number: number = Node.Start

	for _, Item: Types.ListItem in (Node.Items) do
		local Label: string = if Node.Ordered then `{Number}{Node.Delimiter}` else Glyph
		if Item.Checked ~= nil then Label = if Item.Checked then Config.CHECKED_GLYPH else Config.UNCHECKED_GLYPH end

		const Start: string = TakeMarker(Context) or Context.Prefix
		const Pad: string = string.rep(Config.NON_BREAKING_SPACE, 2 * (utf8.len(Label) or #Label))

		const Child: Context = {
			Prefix = `{Context.Prefix}{Config.LIST_INDENT}{Pad} `;
			Marker = `{Start}{Config.LIST_INDENT}{Escape(Label)} `;
			Lists = Context.Lists + 1;
		}

		EmitBlocks(Out, Item.Children, Item.EndsBlank, Child)

		if Child.Marker then
			BeginText(Out, Child)
			Push(Out, "<br/>")
		end

		Number += 1

		if Out.Halted then return end
	end
end

EmitBlocks = function(Out: Writer, Children: { Block }, EndsBlank: boolean, Context: Context): ()
	for _, Node: Block in (Children) do
		if Out.Halted then return end
		if (Node :: any).Spaced then MarkGap(Out, Context) end

		Emit(Out, Node, Context)
	end

	if EndsBlank and not Out.Halted then MarkGap(Out, Context) end
end

const Emitters: { [string]: Emitter } = {
	["Paragraph"] = Paragraph :: Emitter;
	["Heading"] = Heading :: Emitter;
	["CodeBlock"] = CodeBlock :: Emitter;
	["ThematicBreak"] = ThematicBreak :: Emitter;
	["BlockQuote"] = BlockQuote :: Emitter;
	["List"] = List :: Emitter;
}

const function Document(Root: Document, Theme: ResolvedTheme, BaseSize: number, Limit: number, Dialect: Dialect): string
	const Out: Writer = {
		Parts = table.create(256);
		Count = 0;
		Size = 0;
		Limit = Limit;
		Halted = false;
		Dialect = Dialect;
		Look = {
			Theme = Theme;
			BaseSize = BaseSize;
			QuoteBar = `<indent repeat="true"><font color="#{Theme.QuoteColor:ToHex()}">{Config.QUOTE_GLYPH}</font></indent> `;
		};
		Gap = {Pending = false, Prefix = "", LastText = nil};
	}

	if Root.LeadingSpace then Push(Out, " ") end

	EmitBlocks(Out, Root.Children, Root.EndsBlank, {Prefix = "", Marker = nil, Lists = 0})

	if Out.Parts[Out.Count] == "<br/>" then Out.Count -= 1 end
	if Root.TrailingSpace then Push(Out, " ") end

	return table.concat(Out.Parts, "", 1, Out.Count)
end

return {
	Emitters = Emitters;
	WriteText = WriteText;
	Blocks = function(Out: Writer, Children: { Block }, EndsBlank: boolean, Context: Context): () EmitBlocks(Out, Children, EndsBlank, Context) end;
	Document = Document;
}
