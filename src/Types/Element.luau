--!strict

const Signal = require("../Utility/Signal")
const Document = require("./Document")

--[=[
	The interaction state of an [Element]. Only interactive elements get input, so the other fields stay `false` on the rest.

	@interface ElementState
	@within Element
	.Hovered boolean -- The pointer is over the element's text
	.Pressed boolean -- A mouse button or touch is held on it
	.Focused boolean -- A gamepad selection is on it
	.Visible boolean -- Some of its text is revealed; always `true` on elements that are not interactive
]=]
export type ElementState = {
	Hovered: boolean;
	Pressed: boolean;
	Focused: boolean;
	Visible: boolean;
}

--[=[
	Handlers for [Renderer:Bind]. Each receives the element first.

	@interface BindHandlers
	@within Renderer
	.Activated ((Element: Element) -> ())?
	.HoverChanged ((Element: Element, Hovering: boolean) -> ())?
	.PressChanged ((Element: Element, Pressing: boolean) -> ())?
]=]
export type BindHandlers = {
	Activated: ((Element: Element) -> ())?;
	HoverChanged: ((Element: Element, Hovering: boolean) -> ())?;
	PressChanged: ((Element: Element, Pressing: boolean) -> ())?;
}

export type Element = {
	Tag: string;
	Id: string?;
	Text: string;
	Parent: Element?;
	Children: { Element };
	State: ElementState;
	Interactive: boolean;
	Activated: Signal.Signal<>;
	HoverChanged: Signal.Signal<boolean>;
	PressChanged: Signal.Signal<boolean>;
	GetAttribute: (self: Element, Name: string) -> string?;
	QueryDescendants: (self: Element, Selector: string) -> { Element };

	Node: Document.Node?;
	Owner: any;
	Prior: { Element }?;
	First: number;
	Last: number;
	EntryOpen: number;
	EntryClose: number;
	Seen: number;
	Cursor: number;
	Removed: boolean;
	Intrinsic: boolean;
	Restyle: boolean;
	HoverColor: Color3?;
	PressColor: Color3?;
	Records: { any }?;
	ClassText: string?;
	ClassSet: { [string]: boolean }?;
	Signals: { [string]: Signal.Signal<...any> }?;
}

export type Binding = {
	Selector: any;
	Handlers: BindHandlers;
	Connected: boolean;
	Owner: any;
	Disconnect: (self: Binding) -> ();
}

export type PointerData = {
	Element: Element?;
	Over: number;
	Pressed: Element?;
}

export type ElementsData = {
	Roots: { Element };
	Ids: { [string]: Element };
	All: { Element };
	Interactive: { Element };
	NextRoots: { Element };
	NextIds: { [string]: Element };
	NextAll: { Element };
	NextInteractive: { Element };
	Tokens: { any };
	Pass: number;
	Cursor: number;
	Bindings: { Binding };
	Pointer: PointerData;
}

return {}
