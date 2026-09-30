--!strict

const Trove = require("../../Trove")
const Document = require("./Document")
const Style = require("./Style")
const Text = require("./Text")
const Renderer = require("./Renderer")
const Element = require("./Element")

export type TreeData = {
	Parent: Element.Element?;
	Derived: { [Style.Style]: Style.Style };
}

export type DraftData = {
	Stroke: Style.StrokeData?;
	Mark: Style.MarkData?;
}

export type RangeData = {
	Min: number;
	Max: number;
}

export type CountData = {
	Depth: number;
	Nodes: number;
	Objects: number;
	Characters: number;
}

export type LimitData = {
	Depth: number;
	Nodes: number;
	Objects: number;
	Characters: number;
	TextSize: RangeData;
}

export type AccessData = {
	Intents: number;
	Strip: boolean;
	Assets: ((Id: string) -> boolean)?;
}

export type EmitData = {
	Tokens: { Text.Token };
	Anchor: Text.Token?;
	Recycle: boolean;
	Offset: number;
	Space: boolean;
	Code: number?;
	Joint: Text.Joint?;
	Bidi: boolean;
}

export type InternData = {
	Count: number;
	Prior: { Style.Style };
	Current: { Style.Style };
}

export type ReuseData = {
	Index: { [string]: { GuiObject } };
	Claimed: { [string]: number };
	Cache: { [GuiObject]: string };
	Trove: Trove.Trove?;
}

export type NestingData = {
	Opaque: number;
	Region: number;
}

export type FlagData = {
	Busy: boolean;
	Halted: boolean;
	Generated: boolean;
	Collapse: boolean;
	Strip: boolean;
}

export type FlattenContext = {
	State: Renderer.Fields;
	Scale: number;
	Ledger: Text.Ledger;
	Access: AccessData;
	Emit: EmitData;
	Styles: InternData;
	Draft: DraftData;
	Reuse: ReuseData;
	Tree: TreeData;
	Counts: CountData;
	Limits: LimitData;
	Nesting: NestingData;
	Flags: FlagData;
}

export type FlattenHandler = (Context: FlattenContext, Node: Document.Node, Style: Style.Style) -> ()
export type FlattenApplier = (Context: FlattenContext, Style: Style.Style, Value: string) -> ()

return {}
