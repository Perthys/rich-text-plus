--!strict

--[=[
	One capability flag of [Intents]. Each built-in tag belongs to exactly one flag; `font` is split, its `color` attribute needs `Color` and every other attribute needs `Font`.

	@type IntentFlag "Formatting" | "LineBreaks" | "Color" | "Font" | "Stroke" | "Mark" | "Casing" | "Images" | "Links" | "Gradients" | "Effects" | "Markdown" | "Code" | "CodeBlocks" | "Rules" | "Direction" | "Indent" | "CustomClasses" | "Controls"
	@within Intents
]=]
export type IntentFlag = "Formatting" | "LineBreaks" | "Color" | "Font" | "Stroke" | "Mark" | "Casing" | "Images" | "Links" | "Gradients" | "Effects" | "Markdown" | "Code" | "CodeBlocks" | "Rules" | "Direction" | "Indent" | "CustomClasses" | "Controls"

--[=[
	Anything [Intents.Resolve] accepts: a flag or preset name (any case), a bitfield number, an [Intents] object, or an array of these.

	@type IntentsValue IntentFlag | Preset | number | Intents | { IntentsValue }
	@within Intents
]=]
export type IntentsValue = IntentFlag | Preset | number | Intents | { IntentsValue }

export type Intents = {
	Bitfield: number;
	Has: (self: Intents, ...IntentsValue) -> boolean;
	Any: (self: Intents, ...IntentsValue) -> boolean;
	Add: (self: Intents, ...IntentsValue) -> Intents;
	Remove: (self: Intents, ...IntentsValue) -> Intents;
	Toggle: (self: Intents, ...IntentsValue) -> Intents;
	ToArray: (self: Intents) -> { IntentFlag };
	Serialize: (self: Intents) -> { [string]: boolean };
	Equals: (self: Intents, Other: IntentsValue) -> boolean;
	Freeze: (self: Intents) -> Intents;
	Allows: (self: Intents, Tag: string, Attribute: string?) -> boolean;
}

--[=[
	What happens to a tag the intents do not grant. `"Escape"` shows it as literal text; `"Strip"` drops the tag and keeps its content, so a denied link shows its text and a denied code block renders as plain monospace.

	@type Denied "Escape" | "Strip"
	@within RichTextPlus
]=]
export type Denied = "Escape" | "Strip"

--[=[
	Size clamp for markup text sizes, each from 1 to 100.

	@interface TextSizeLimits
	@within RichTextPlus
	.Min number?
	.Max number?
]=]
export type TextSizeLimits = {
	Min: number?;
	Max: number?;
}

--[=[
	Resource limits for one renderer. A missing field means no limit; values are floored and clamped at 0, and `math.huge`, NaN or non-numbers mean no limit.

	@interface Limits
	@within RichTextPlus
	.Depth number? -- Tag nesting, 256 at most
	.Nodes number? -- Parsed nodes rendered before rendering stops
	.Characters number? -- Text characters rendered before text is cut
	.Objects number? -- Inline objects such as images
	.TextSize TextSizeLimits?
]=]
export type Limits = {
	Depth: number?;
	Nodes: number?;
	Characters: number?;
	Objects: number?;
	TextSize: TextSizeLimits?;
}

export type LimitsData = {
	Depth: number?;
	Nodes: number?;
	Characters: number?;
	Objects: number?;
	TextSize: TextSizeLimits;
}

--[=[
	Decides which assets images and asset fonts may load: a function given the canonical `rbxassetid://` style id, or an allowlist map of ids in any accepted form.

	@type AssetFilter ((Id: string) -> boolean) | { [string]: boolean }
	@within RichTextPlus
]=]
export type AssetFilter = ((Id: string) -> boolean) | { [string]: boolean }

--[=[
	Rendering switches. All default to on.

	@interface Rendering
	@within RichTextPlus
	.Passthrough boolean? -- Let the engine draw plain labels natively
	.Culling boolean? -- Skip off-screen segments
	.Clipping boolean? -- Clip content to the label
	.SyntaxHighlight boolean? -- Color code blocks
]=]
export type Rendering = {
	Passthrough: boolean?;
	Culling: boolean?;
	Clipping: boolean?;
	SyntaxHighlight: boolean?;
}

export type RenderingData = {
	Passthrough: boolean;
	Culling: boolean;
	Clipping: boolean;
	SyntaxHighlight: boolean;
}

--[=[
	@type RenderingName "Passthrough" | "Culling" | "Clipping" | "SyntaxHighlight"
	@within RichTextPlus
]=]
export type RenderingName = "Passthrough" | "Culling" | "Clipping" | "SyntaxHighlight"

--[=[
	`"Preserve"` keeps raw text whitespace; `"Markup"` ignores indentation between tags.

	@type Whitespace "Preserve" | "Markup"
	@within RichTextPlus
]=]
export type Whitespace = "Preserve" | "Markup"

--[=[
	A built-in bundle of intents, limits and denied handling, applied with [Renderer:SetPreset]. `Default` and `Trusted` grant every flag; `Default` strips tags it does not know and has no limits, `Trusted` escapes them and is limited.

	@type Preset "Default" | "Trusted" | "Chat" | "Plain"
	@within RichTextPlus
]=]
export type Preset = "Default" | "Trusted" | "Chat" | "Plain"

return {}
