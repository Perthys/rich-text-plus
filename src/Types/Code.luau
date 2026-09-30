--!strict

export type SizeData = {
	Width: number;
	Height: number;
}

export type PanelData = {
	Margin: number;
	Padding: number;
	Header: number;
	Gap: number;
	Body: number;
	Height: number;
	Radius: number;
}

export type CodePlan = {
	Text: string;
	Lines: number;
	Size: number;
	Outer: SizeData;
	Panel: PanelData;
}

return {}
