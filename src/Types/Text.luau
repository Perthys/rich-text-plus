--!strict

const Document = require("./Document")
const Style = require("./Style")

export type Joint = "Break" | "Glue" | "Hyphen"

export type GlyphTable = {
	Advances: { [number]: number };
	Heights: { [number]: number };
	Kerns: { [number]: number };
	Pairs: number;
}

export type Token = {
	Block: boolean?;
	Glue: boolean?;
	Hyphen: number?;
	Level: number?;
	Rtl: boolean?;
	Kind: string;
	Text: string?;
	Style: Style.Style?;
	Object: GuiObject?;
	Width: number;
	Height: number;
	SpaceBefore: boolean;
	X: number;
	Offset: number?;
}

export type Line = {
	Items: { Token };
	Leads: { Token }?;
	Height: number;
	Width: number;
}

export type Region = {
	First: number;
	Last: number;
	Resume: number;
	Previous: number;
}

export type Entry = {
	Node: Document.Node;
	Style: Style.Style;
	First: number;
	Count: number;
	Characters: number;
	Code: number?;
	ExitCode: number?;
	Flags: number;
}

export type Spans = {
	Source: buffer;
	Size: number;
	Starts: { number };
	Stops: { number };
	Reaches: { number };
	Sealed: { [number]: boolean };
	Crossing: number;
	Nodes: { Document.Node };
}

export type Ledger = {
	Tree: Document.Node;
	Entries: { Entry };
	Slots: { [Document.Node]: number };
	Characters: number;
	Limit: number;
	Spans: Spans?;
}

return {}
