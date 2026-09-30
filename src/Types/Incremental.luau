--!strict

const Text = require("./Text")

export type Window = {
	Starts: { number };
	Stops: { number };
	Reaches: { number };
}

export type CutData = {
	Before: number;
	Removed: number;
	After: number;
	Head: number;
	Tail: number;
	Delta: number;
}

export type Change = {
	Entry: Text.Entry;
	Slot: number;
	Raw: string;
	Tokens: { Text.Token };
	Cut: CutData;
	Closed: boolean;
	ExitCode: number?;
	Characters: number;
}

export type Workspace = {
	Window: Window;
	Changes: { Change };
	Records: { Change };
	Spare: buffer?;
	Busy: boolean;
}

return {}
