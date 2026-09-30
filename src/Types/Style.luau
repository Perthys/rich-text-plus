--!strict

const Document = require("./Document")
const Element = require("./Element")

--[=[
	A resolved `<gradient>`.

	@interface Gradient
	@within RichTextPlus
	.Sequence ColorSequence
	.Colors { Color3 }
	.Speed number
	.Rotation number
]=]
export type Gradient = {
	Sequence: ColorSequence;
	Colors: { Color3 };
	Speed: number;
	Rotation: number;
}

export type EffectData = {
	Name: string;
	Amplitude: number;
	Frequency: number;
	Node: Document.Node;
	Parent: EffectData?;
}

--[=[
	The table an Effect class's `Update` receives every frame for each visible segment. It is reused between calls: read it, write the fields you animate, return nothing, and never keep it.
	Write fields start `nil` on each call; a field left `nil` shows the segment's own style.

	@interface EffectFrame
	@within RichTextPlus
	@since 0.2.0
	.Time number -- Animation clock in seconds
	.Seed number -- Differs per segment, add it to your phase
	.Amplitude number -- The tag's `amplitude` (default 2.5, 0 to 50)
	.Frequency number -- The tag's `frequency` (default 6, 0 to 60)
	.Name string -- The class name
	.Node Node -- The tag's XML node
	.Offset Vector2? -- Write: position in pixels
	.Rotation number? -- Write: degrees around the segment's center
	.Color Color3? -- Write: text color
	.Transparency number? -- Write: text transparency, combined with the label's
	.StrokeColor Color3? -- Write: `<stroke>` color
	.StrokeTransparency number? -- Write: `<stroke>` transparency
]=]
export type EffectFrame = {
	Time: number;
	Seed: number;
	Amplitude: number;
	Frequency: number;
	Name: string;
	Node: Document.Node;
	Offset: Vector2?;
	Rotation: number?;
	Color: Color3?;
	Transparency: number?;
	StrokeColor: Color3?;
	StrokeTransparency: number?;
}

export type EffectUpdate = (Frame: EffectFrame) -> ()

export type EffectOffset = (Time: number, Effect: EffectData, Seed: number) -> (number, number)

export type StrokeData = {
	Color: Color3;
	Thickness: number;
	Transparency: number;
	Joins: Enum.LineJoinMode;
}

export type MarkData = {
	Color: Color3;
	Transparency: number;
	Radius: number?;
	Parent: MarkData?;
}

export type IndentData = {
	Size: number?;
	Repeat: boolean?;
}

export type ContainerData = {
	Name: string;
	Node: Document.Node;
	Wrap: (Node: Document.Node, Style: Style, Segment: GuiObject) -> GuiObject?;
}

--[=[
	The style of a run of text, as seen by Style, Object and Container classes. `Size` is already scaled.

	@interface Style
	@within RichTextPlus
	.Bold boolean
	.Italic boolean
	.Underline boolean
	.Strike boolean
	.Color Color3
	.Size number
	.Family string -- Font family asset or name
	.Weight Enum.FontWeight?
	.Transparency number
	.Case ("Upper" | "SmallCaps")?
	.Code boolean?
	.Direction ("Ltr" | "Rtl")?
	.Link string? -- The `href` of an enclosing link
	.Element Element? -- The innermost interactive element around the text
	.Gradient Gradient?
	.Container table?
	.Stroke table?
	.Mark table?
	.Indent table?
	.Effect table?
]=]
export type Style = {
	Container: ContainerData?;
	Stroke: StrokeData?;
	Mark: MarkData?;
	Indent: IndentData?;
	Case: ("Upper" | "SmallCaps")?;
	Code: boolean?;
	Direction: ("Ltr" | "Rtl")?;
	Bold: boolean;
	Italic: boolean;
	Underline: boolean;
	Strike: boolean;
	Color: Color3;
	Size: number;
	Family: string;
	Link: string?;
	Element: Element.Element?;
	Gradient: Gradient?;
	Effect: EffectData?;
	Weight: Enum.FontWeight?;
	Transparency: number;
}

--[=[
	Markdown, code and link colors, set with [Renderer:SetTheme]. Every field is optional and falls back to the default theme.

	@interface Theme
	@within RichTextPlus
	.CodeFamily string?
	.CodeTextColor Color3?
	.CodeBackground Color3?
	.CodeBackgroundTransparency number?
	.CodePadding number?
	.CodeCornerRadius number?
	.QuoteColor Color3?
	.RuleColor Color3?
	.HeadingScale { number }? -- Size multipliers for heading levels 1 to 6
	.Syntax { [string]: Color3 }? -- Token colors for highlighting
	.CodeLanguage string?
	.LinkColor Color3? -- Color of `<a>` text
	.LinkHoverColor Color3? -- Color of hovered `<a>` text; defaults to a lighter link color
]=]
export type Theme = {
	CodeFamily: string?;
	CodeTextColor: Color3?;
	CodeBackground: Color3?;
	CodeBackgroundTransparency: number?;
	CodePadding: number?;
	CodeCornerRadius: number?;
	QuoteColor: Color3?;
	RuleColor: Color3?;
	HeadingScale: { number }?;
	Syntax: { [string]: Color3 }?;
	CodeLanguage: string?;
	LinkColor: Color3?;
	LinkHoverColor: Color3?;
}

export type Syntax = { [string]: Color3 }

return {}
