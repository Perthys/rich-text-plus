--!strict

export type Text = { Type: "Text", Value: string }
export type Code = { Type: "Code", Value: string }
export type Break = { Type: "Break" }
export type Emphasis = { Type: "Emphasis" | "Strong" | "Strikethrough", Children: { Inline } }
export type Link = { Type: "Link", Destination: string, Children: { Inline } }
export type Image = { Type: "Image", Source: string }

export type Inline = Text | Code | Break | Emphasis | Link | Image

export type Heading = {
	Type: "Heading";
	Level: number;
	Source: string;
	Children: { Inline }?;
	Spaced: boolean;
}

export type Paragraph = {
	Type: "Paragraph";
	Source: string;
	Children: { Inline }?;
	Spaced: boolean;
}

export type CodeBlock = {
	Type: "CodeBlock";
	Language: string?;
	Body: string;
	Spaced: boolean;
}

export type ThematicBreak = {
	Type: "ThematicBreak";
	Spaced: boolean;
}

export type BlockQuote = {
	Type: "BlockQuote";
	Children: { Block };
	EndsBlank: boolean;
	Spaced: boolean;
}

export type ListItem = {
	Type: "ListItem";
	Checked: boolean?;
	Children: { Block };
	EndsBlank: boolean;
}

export type List = {
	Type: "List";
	Ordered: boolean;
	Start: number;
	Delimiter: string;
	Items: { ListItem };
	Spaced: boolean;
}

export type Block = Heading | Paragraph | CodeBlock | ThematicBreak | BlockQuote | List

export type Document = {
	Type: "Document";
	Children: { Block };
	EndsBlank: boolean;
	LeadingSpace: boolean;
	TrailingSpace: boolean;
}

export type Node = Document | Block | ListItem | Inline

export type ResolvedTheme = {
	CodeFamily: string;
	CodeTextColor: Color3;
	CodeBackground: Color3;
	CodeBackgroundTransparency: number;
	CodePadding: number;
	CodeCornerRadius: number;
	QuoteColor: Color3;
	RuleColor: Color3;
	HeadingScale: { number };
	Syntax: { [string]: Color3 }?;
}

export type Parser = {
	Dialect: Dialect;
	Depth: number;
}

export type BlockRule = {
	Name: string;
	Leads: string?;
	Interrupts: boolean;
	Nested: boolean;
	Test: ((Line: string) -> any)?;
	Parse: (Parser: Parser, Lines: { string }, Index: number) -> (Block?, number);
}

export type Delimiter = {
	Byte: number;
	Char: string;
	Count: number;
	Length: number;
	CanOpen: boolean;
	CanClose: boolean;
	Before: string;
	After: string;
	Previous: Delimiter?;
	Next: Delimiter?;
}

export type Bracket = {
	Index: number;
	Image: boolean;
	Bottom: Delimiter?;
	Sequence: number;
	Previous: Bracket?;
}

export type Marker = { Type: "Open", Destination: string } | { Type: "Close" }

export type Piece = string | Inline | Delimiter | Marker | false

export type Scanner = {
	Pieces: { Piece };
	Count: number;
	Head: Delimiter?;
	Tail: Delimiter?;
	Bracket: Bracket?;
	Sequence: number;
	ActiveFloor: number;
	NoCloser: { [number]: boolean };
	BreakCost: number;
	Allowance: number;
}

export type InlineRule = (Scanner: Scanner, Text: string, At: number) -> number

export type Look = {
	Theme: ResolvedTheme;
	BaseSize: number;
	QuoteBar: string;
}

export type Gap = {
	Pending: boolean;
	Prefix: string;
	LastText: boolean?;
}

export type Writer = {
	Parts: { string };
	Count: number;
	Size: number;
	Limit: number;
	Halted: boolean;
	Dialect: Dialect;
	Look: Look;
	Gap: Gap;
}

export type Context = {
	Prefix: string;
	Marker: string?;
	Lists: number;
}

export type Emitter = (Out: Writer, Node: any, Context: Context) -> ()

export type Dialect = {
	Blocks: { BlockRule };
	Routes: { [number]: { BlockRule } };
	Shallow: { [number]: { BlockRule } };
	Interrupters: { [number]: { (Line: string) -> any } };
	Inlines: { [number]: InlineRule };
	Emitters: { [string]: Emitter };
	Specials: string;
}

export type Extension = {
	Blocks: { BlockRule }?;
	Inlines: { [number]: InlineRule }?;
	Emitters: { [string]: Emitter }?;
}

export type ListMatch = {
	Indent: number;
	Ordered: boolean;
	Delimiter: string;
	Number: number;
	Width: number;
	Content: string;
}

return {}
