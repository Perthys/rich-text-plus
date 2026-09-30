--!strict

const Style = require("./Style")
const Text = require("./Text")
const Renderer = require("./Renderer")

export type BreakData = {
	Need: number;
	Limit: number;
	Longest: number;
	Exact: boolean;
}

export type Paragraph = {
	Start: number;
	Before: number;
	Open: Style.MarkData?;
	After: boolean;
	Breaks: BreakData;
}

export type PassData = {
	Source: { Text.Token }?;
	Spaces: { [Style.Style]: number }?;
	Width: number;
	Ratio: number;
	Factor: number;
	Spacing: number;
	Minimum: number;
	Measure: number;
}

export type TotalData = {
	Count: number;
	Total: number;
	Widest: number;
	Serial: number;
}

export type RetainData = {
	Retained: boolean;
	Leveled: boolean;
	Snapshot: { Text.Token };
	Size: number;
}

export type Sheet = {
	Lines: { Text.Line };
	Heights: { number };
	Spare: { Text.Token };
	Paragraphs: { Paragraph };
	Pass: PassData;
	Totals: TotalData;
	Breaks: BreakData;
	Retain: RetainData;
}

export type Model = {
	Anchor: number;
	Widest: number;
	Merge: number;
	Count: number;
	Paragraphs: number;
	Rows: { number };
	Content: { number };
	Waste: { number };
	Spans: { number };
	Units: { number };
}

export type ProblemData = {
	MaxWidth: number;
	Width: number;
	Height: number;
	Floor: number;
	High: number;
	Base: number;
	Spacing: number;
}

export type MeasuredData = {
	Current: number;
	Minimum: number;
	Longest: number;
	Monotone: boolean;
}

export type KnownData = {
	Yes: number;
	No: number;
}

export type GoalData = {
	Target: number;
	Size: number;
}

export type CrawlData = {
	Rising: boolean;
	Anchor: number;
	Limit: number;
	Model: Model;
}

export type ModelData = {
	Below: Model;
	Above: Model;
	Last: Model;
}

export type EndData = {
	Tokens: { [Text.Token]: boolean };
	Ready: boolean;
}

export type Bracket = {
	State: Renderer.Fields;
	Problem: ProblemData;
	Measured: MeasuredData;
	Known: KnownData;
	Goal: GoalData;
	Crawl: CrawlData;
	Models: ModelData;
	Ends: EndData;
}

export type Solution = {
	Problem: ProblemData;
	Factor: number;
	Used: number;
}

export type Memo = {
	Tokens: { Text.Token }?;
	Text: number;
	Clock: number;
	Solutions: { Solution };
}

return {}
