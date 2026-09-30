--!strict

const Document = require("./Document")
const Style = require("./Style")
const Renderer = require("./Renderer")
const Element = require("./Element")

--[=[
	A custom class, registered with [Renderer:AddCustomClass]. `Kind` picks which callback is required.

	- `Object`: `Build` returns one inline object per tag; `Block = true` gives it its own line.
	- `Style`: `Apply` changes the style of the tag's content. It gets the tag's [Element], so it can read `Element.State`; with `Interactive = true` the content restyles whenever that state changes.
	- `Container`: `Wrap` decorates each text segment of the content.
	- `Effect`: `Update` animates each text segment every frame.

	@interface ClassDefinition
	@within RichTextPlus
	.Kind "Object" | "Style" | "Container" | "Effect"
	.Build ((Node: Node, Style: Style, Scale: number, State: table) -> GuiObject?)?
	.Apply ((Style: Style, Node: Node, Element: Element) -> ())?
	.Wrap ((Node: Node, Style: Style, Segment: GuiObject) -> GuiObject?)?
	.Update ((Frame: EffectFrame) -> ())?
	.Block boolean? -- Object classes only
	.Override boolean? -- Win over a built-in tag of the same name
	.Interactive boolean? -- Give the tag's text input handling, so its [Element] gets state and signals without a [Renderer:Bind]
]=]
export type ClassDefinition = {
	Kind: "Object" | "Style" | "Container" | "Effect";
	Build: ((Node: Document.Node, Style: Style.Style, Scale: number, State: Renderer.Fields) -> GuiObject?)?;
	Apply: ((Style: Style.Style, Node: Document.Node, Element: Element.Element) -> ())?;
	Wrap: ((Node: Document.Node, Style: Style.Style, Segment: GuiObject) -> GuiObject?)?;
	Update: Style.EffectUpdate?;
	Block: boolean?;
	Override: boolean?;
	Interactive: boolean?;
}

return {}
