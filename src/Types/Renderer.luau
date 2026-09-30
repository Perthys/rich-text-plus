--!strict

const Trove = require("../../Trove")
const Document = require("./Document")
const Policy = require("./Policy")
const Style = require("./Style")
const Text = require("./Text")
const Element = require("./Element")

export type OutlineData = {
	Color: Color3?;
	Transparency: number?;
}

export type CopyData = {
	List: { Instance };
	Sources: { Instance };
	Version: number;
}

export type MotionData = {
	Style: Style.Style?;
	Size: number;
	Decorated: number;
	X: number;
	Y: number;
	Left: number;
	Top: number;
	Phase: number;
	Tick: number;
	Rotation: number;
	Tinted: boolean;
	Alpha: number?;
	StrokeColor: Color3?;
	StrokeAlpha: number?;
}

export type ContentData = {
	Raw: string;
	Text: string;
	Rich: boolean?;
	HoverText: string?;
	Graphemes: number;
	Gaps: { number }?;
	Revealed: number;
}

export type LookData = {
	Font: Font?;
	Color: Color3?;
	Size: number;
	Transparency: number;
}

export type DecorData = {
	Gradient: UIGradient?;
	Frame: number;
	Stroke: UIStroke?;
	Wrapped: GuiObject?;
	Container: Style.ContainerData?;
	Outline: OutlineData;
}

export type Record = {
	Instance: GuiObject;
	Label: TextLabel?;
	Owner: Fields?;
	Button: boolean;
	Depth: number;
	Style: Style.Style?;
	Element: Element.Element?;
	Shown: boolean;
	Parented: boolean;
	X: number;
	Y: number;
	Left: number;
	Top: number;
	Width: number;
	Height: number;
	Reach: number;
	Updates: { Style.EffectUpdate | false }?;
	Layers: number;
	Internal: boolean;
	Shift: Style.EffectOffset?;
	Seed: number;
	Motion: MotionData?;
	Content: ContentData;
	Look: LookData;
	Decor: DecorData;
	Decoration: CopyData;
}

export type RectData = {
	X: number;
	Y: number;
	Width: number;
	Height: number;
}

export type RoundData = {
	Radius: number;
	Left: boolean;
	Right: boolean;
}

export type PaintData = {
	Target: Frame?;
	Tint: Color3?;
	Alpha: number;
}

export type Layer = {
	Frame: Frame;
	Fill: Frame?;
	Corner: UICorner?;
	Mark: Style.MarkData?;
	Shown: boolean;
	Rect: RectData;
	Round: RoundData;
	Paint: PaintData;
}

export type Run = {
	Style: Style.Style?;
	Object: GuiObject?;
	Text: string;
	Markup: string?;
	Gaps: { number }?;
	X: number;
	Y: number;
	Width: number;
	Height: number;
}

export type BackdropPiece = {
	Mark: Style.MarkData;
	Start: number;
	Finish: number;
	Y: number;
	Height: number;
	Pad: number;
	Head: boolean;
	Tail: boolean;
	Depth: number;
}

export type Coverage = {
	Pieces: { BackdropPiece };
	Latest: { [Style.MarkData]: BackdropPiece };
	Spare: { BackdropPiece }?;
	From: number;
	Y: number;
	Height: number;
	Nested: boolean;
}

export type RunColumns = {
	Items: { Run };
	Offsets: { number };
	Rises: { number };
	Pads: { number };
	Size: number;
}

export type RowColumns = {
	Firsts: { number };
	Heights: { number };
	Spans: { number };
	Flags: { number };
	Count: number;
}

export type BlockData = {
	Tokens: { Text.Token }?;
	Sizes: { number }?;
}

export type MetricsData = {
	Total: number;
	Widest: number;
	Extent: number;
	Rtl: boolean;
}

export type KeyData = {
	Tokens: { Text.Token }?;
	Text: number;
	Measure: number;
	Factor: number;
	Spacing: number;
	Minimum: number;
	Scaled: boolean;
	Serial: number;
}

export type WidthData = {
	Low: number;
	High: number;
	Width: number;
	Exact: boolean;
}

export type Shape = {
	Runs: RunColumns;
	Rows: RowColumns;
	Blocks: BlockData;
	Metrics: MetricsData;
	Key: KeyData;
	Widths: WidthData;
	Version: number;
	Used: number;
}

export type PendingData = {
	Words: { string };
	Size: number;
	Style: Style.Style?;
	Level: number?;
	Spaced: boolean;
	Left: number;
	Right: number;
}

export type StagedData = {
	Count: number;
	Styles: { Style.Style };
	Texts: { string };
	Lefts: { number };
	Rights: { number };
	Spaces: { boolean };
	Pieces: { string };
}

export type CursorData = {
	Height: number;
	Factor: number;
	Pending: PendingData;
	Staged: StagedData;
}

export type ShelfData = {
	Shapes: { Shape };
	Spare: Shape?;
	Clock: number;
}

export type SettingData = {
	Spacing: number;
	Scaled: boolean;
	Horizontal: Enum.TextXAlignment;
	Vertical: Enum.TextYAlignment;
	Cut: Enum.TextTruncate;
}

export type CommitData = {
	Shape: Shape?;
	Version: number;
	Alignment: Enum.TextXAlignment?;
	Truncation: Enum.TextTruncate?;
	BoxWidth: number;
	Start: number;
	Floor: number;
	Factor: number;
	Decoration: number;
	Placed: number;
	Ordered: number;
}

export type Memory = {
	Shelf: ShelfData;
	Settings: SettingData;
	Commit: CommitData;
	Output: { Run };
	Coverage: Coverage?;
	Unblocked: { Text.Token }?;
}

export type Resizer = (Width: number, Factor: number) -> Vector2

export type Applier = (Width: number, Factor: number) -> ()

export type OptionData = {
	Scale: number;
	Whitespace: Policy.Whitespace;
}

export type DocumentData = {
	Source: string?;
	Origin: string?;
	Tree: Document.Node?;
	Ledger: Text.Ledger?;
	Tokens: { Text.Token };
	SpaceWidths: { [Style.Style]: number };
}

export type InstanceData = {
	Records: { [GuiObject]: Record };
	Segments: { Record };
	Spare: { Record };
	Order: { Record };
}

export type BackdropData = {
	Root: Frame?;
	Layers: { Layer };
}

export type ObjectData = {
	Sizes: { [GuiObject]: Vector2 };
	Cache: { [GuiObject]: string };
}

export type TroveData = {
	Main: Trove.Trove;
	Objects: Trove.Trove;
	Cull: Trove.Trove;
}

export type GenerationData = {
	Refresh: number;
	Text: number;
	Layout: number;
	Measure: number;
}

export type ScaleData = {
	Factor: number;
	Measured: number;
	Ancestor: number;
}

export type HostData = {
	Width: number;
	Height: number;
	Text: string?;
	Seen: { [string]: any };
	Echoes: { [string]: number };
}

export type DeveloperData = {
	Transparency: number;
	AutomaticSize: Enum.AutomaticSize?;
}

export type NativeData = {
	Active: boolean;
	Markup: string?;
	Source: string?;
	RichText: boolean?;
	Streak: number;
	Clock: number;
}

export type AnimationData = {
	Clock: number;
	Animated: { Record };
	Moving: { Record };
}

export type DecorationData = {
	List: { Instance };
	Version: number;
	Dirty: boolean;
}

export type BoundsData = {
	MinX: number;
	MinY: number;
	MaxX: number;
	MaxY: number;
}

export type CullData = {
	Dirty: boolean;
	ChainDirty: boolean;
	Culled: boolean;
	Padding: number;
	Clippers: { GuiObject };
	Collector: LayerCollector?;
	Bounds: BoundsData;
}

export type Fields = {
	Label: TextLabel;
	Token: string;
	Destroyed: boolean;
	Options: OptionData;
	Elements: Element.ElementsData;
	Intents: Policy.Intents;
	Limits: Policy.LimitsData;
	Denied: Policy.Denied;
	Assets: ((Id: string) -> boolean)?;
	Rendering: Policy.RenderingData;
	Theme: Style.Theme;
	Document: DocumentData;
	Instances: InstanceData;
	Backdrop: BackdropData;
	Objects: ObjectData;
	Troves: TroveData;
	Generation: GenerationData;
	Scale: ScaleData;
	Host: HostData;
	Developer: DeveloperData;
	Native: NativeData;
	Animation: AnimationData;
	Decoration: DecorationData;
	Cull: CullData;
}

return {}
