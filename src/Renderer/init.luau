--!strict
--!native
--!optimize 2

const Types = require("./Types")
const Classes = require("./Classes")
const Rendering = require("./Policy/Rendering")
const Whitespace = require("./Policy/Whitespace")
const Intents = require("./Policy/Intents")
const Limits = require("./Policy/Limits")
const Presets = require("./Policy/Presets")
const Assets = require("./Policy/Assets")
const Culling = require("./Render/Culling")
const Schedule = require("./Render/Schedule")
const Reveal = require("./Render/Reveal")
const Elements = require("./Elements")
const Profiler = require("./Utility/Profiler")
const Stage = require("@self/Stage")
const Lifecycle = require("@self/Lifecycle")
const Watch = require("@self/Watch")
const Driver = require("@self/Driver")

type Fields = Types.Fields
type Intents = Types.Intents
type IntentsValue = Types.IntentsValue
type Limits = Types.Limits
type LimitsData = Types.LimitsData
type DeniedMode = Types.Denied
type AssetFilter = Types.AssetFilter
type Preset = Types.Preset
type RenderingName = Types.RenderingName
type WhitespaceMode = Types.Whitespace
type Theme = Types.Theme
type ClassDefinition = Types.ClassDefinition
type Element = Types.Element
type BindHandlers = Types.BindHandlers
type Binding = Types.Binding

const REMOVED_OPTIONS: string = "RichTextPlus.new takes only the label: configure the renderer with chained setters, RichTextPlus.new(Label):SetPreset(Preset):SetIntents(Flags):SetLimits(Limits):SetScale(Scale):SetTheme(Theme):SetWhitespace(Mode):SetRendering(Name, Enabled):AddCustomClass(Name, Definition), or AddCustomClasses(Map)"

const LINKS_REMOVED: string = 'RichTextPlus Renderer.Links was removed: bind the links instead, Renderer:Bind("a", {Activated = function(Element) end, HoverChanged = function(Element, Hovering) end}), and read Element:GetAttribute("href") and Element.Text'

const MOVED_LINK_SIGNALS: { [string]: string } = table.freeze({
	LinkClicked = "Activated = function(Element) end";
	LinkHovered = "HoverChanged = function(Element, Hovering) end";
	LinkLeft = "HoverChanged = function(Element, Hovering) end";
})

const SETTLE: string = "the runtime drives rendering, call Renderer:Flush() to settle pending work now"

const REMOVED: { [string]: string } = table.freeze({
	SetText = "assign Label.Text instead, it renders on the next frame and Renderer:Flush() renders it now";
	Render = SETTLE;
	Layout = SETTLE;
	SolveScale = SETTLE;
	ApplyTransparency = SETTLE;
	Flatten = "assign the markup to Label.Text instead";
	Abandon = "Renderer:Destroy() is the only teardown";
	Owns = "a renderer replaced by RichTextPlus.new on the same label stops by itself, and Renderer:Destroy() releases it";
	AddEffect = 'register an effect class with Renderer:AddCustomClass(Name, {Kind = "Effect", Update = Updater}) and use it inside <customclass>';
	GetEffectNames = "effects are custom classes, registered with Renderer:AddCustomClass";
	SetPermissions = "use Renderer:SetPreset(Name) for a preset, or Renderer:SetIntents(Flags) with SetLimits, SetDenied and SetAssetFilter";
	GetPermissions = "use Renderer:GetIntents(), GetLimits() and GetDenied()";
	GetFeature = 'use Renderer:GetIntents():Has(Flag), for example Renderer:GetIntents():Has("Images")';
	SetFeature = "use Renderer:SetIntents(Renderer:GetIntents():Remove(Flag)) for markup, and Renderer:SetRendering(Name, Enabled) for Passthrough, Culling, Clipping and SyntaxHighlight";
	SetLinkColor = "the link color is part of the theme, Renderer:SetTheme({LinkColor = Color, LinkHoverColor = Color})";
	GetLinkColor = "read Renderer:GetTheme().LinkColor";
})

--[=[
	Owns one `TextLabel` and renders its `Text` as rich text. Create one with [RichTextPlus.new].

	Setters return the renderer and only mark it dirty, so a chain renders once, on the next frame or on [Renderer:Flush].

	```lua
	local Renderer = RichTextPlus.new(Label)
		:SetPreset("Trusted")
		:SetTheme({LinkColor = Color3.fromRGB(90, 170, 255)})

	Renderer:Bind("a", {
		Activated = function(Element)
			print(Element:GetAttribute("href"), Element.Text)
		end,
	})
	```

	@class Renderer
]=]
const Renderer = {}; Renderer.__index = Renderer

const function Unknown(_: any, Name: any): nil
	if Name == "OnLinkClicked" then error(Lifecycle.RemovedOnLinkClicked, 2) end
	if type(Name) ~= "string" then return nil end
	if REMOVED[Name] then error(`RichTextPlus Renderer:{Name} was removed: {REMOVED[Name]}`, 2) end
	if Name == "Links" then error(LINKS_REMOVED, 2) end
	if MOVED_LINK_SIGNALS[Name] then error(`RichTextPlus Renderer.{Name} was removed: use Renderer:Bind("a", \{{MOVED_LINK_SIGNALS[Name]}\})`, 2) end

	return nil
end

const function Assign(Object: any, Name: any, Value: any): ()
	if Name == "OnLinkClicked" then error(Lifecycle.RemovedOnLinkClicked, 2) end

	rawset(Object, Name, Value)
end

Renderer.__newindex = Assign
setmetatable(Renderer, {__index = Unknown})

export type Renderer = typeof(setmetatable({} :: Fields, Renderer))

const Now = Driver.Now
const Mark = Schedule.Raise

Elements.SetInvalidator(function(State: Fields): ()
	Mark(State, Stage.Flatten)
end)

const function AsFields(Value: any): Fields
	return Value :: Fields
end

--[=[
	Reparses the whole document now.

	@within Renderer
	@return Renderer
]=]
function Renderer:Rebuild(): Renderer
	Now(AsFields(self), Stage.Parse)

	return self
end

--[=[
	Renders pending changes now instead of on the next frame. Settles `Label.Text` and other label writes first.

	@within Renderer
	@return Renderer
]=]
function Renderer:Flush(): Renderer
	Driver.Settle(AsFields(self))

	return self
end

--[=[
	Returns the number of rendered graphemes, the unit `MaxVisibleGraphemes` counts. An inline object counts as one. Settles pending writes first.

	```lua
	local Count = Renderer:GetGraphemeCount()
	TweenService:Create(Label, TweenInfo.new(Count / 40), {MaxVisibleGraphemes = Count}):Play()
	```

	@within Renderer
	@return number
]=]
function Renderer:GetGraphemeCount(): number
	const State: Fields = AsFields(self)

	Driver.Settle(State)

	return Reveal.Count(State)
end

--[=[
	Registers or replaces a custom class. Classes only resolve inside `<customclass>` regions; names are case-insensitive.

	@within Renderer
	@tag Builder
	@param Name string
	@param Definition ClassDefinition
	@return Renderer
]=]
function Renderer:AddCustomClass(Name: string, Definition: ClassDefinition): Renderer
	const State: Fields = AsFields(self)

	Classes.Register(State, Name, Definition)
	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Registers every entry of a `{ [Name]: Definition }` map.

	@within Renderer
	@tag Builder
	@param Definitions { [string]: ClassDefinition }
	@return Renderer
]=]
function Renderer:AddCustomClasses(Definitions: { [string]: ClassDefinition }): Renderer
	const State: Fields = AsFields(self)
	if type(Definitions) ~= "table" then error("RichTextPlus Renderer:AddCustomClasses takes a map of class names to definitions", 2) end

	for Name: string, Definition: ClassDefinition in (Definitions) do Classes.Register(State, Name, Definition) end

	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Removes a custom class.

	@within Renderer
	@tag Builder
	@param Name string
	@return Renderer
]=]
function Renderer:RemoveCustomClass(Name: string): Renderer
	const State: Fields = AsFields(self)

	Classes.Register(State, Name, nil)
	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Returns the active intents, frozen.

	@within Renderer
	@return Intents
]=]
function Renderer:GetIntents(): Intents
	return AsFields(self).Intents
end

--[=[
	Sets which tags the renderer interprets. Takes anything [Intents.Resolve] does. Only the tags change: use [Renderer:SetPreset] for a preset's limits and denied handling too.

	```lua
	Renderer:SetIntents({"Formatting", "Color", "Links"})
	Renderer:SetIntents(RichTextPlus.Intents.Presets.Chat)
	```

	@within Renderer
	@tag Builder
	@param Value IntentsValue
	@return Renderer
]=]
function Renderer:SetIntents(Value: IntentsValue): Renderer
	const State: Fields = AsFields(self)
	const Bits: number = Intents.Check(Value, 2)
	if State.Intents.Bitfield == Bits then return self end

	State.Intents = Intents.Frozen(Bits)
	Mark(State, Stage.Parse)

	return self
end

--[=[
	Returns the active limits, normalized and frozen.

	@within Renderer
	@return Limits
]=]
function Renderer:GetLimits(): LimitsData
	return AsFields(self).Limits
end

--[=[
	Replaces the limits with a preset's or a [Limits] table. Missing fields mean no limit.

	```lua
	Renderer:SetLimits({Depth = 8, Nodes = 256, Characters = 4096, Objects = 0})
	```

	@within Renderer
	@tag Builder
	@param Value Preset | Limits
	@return Renderer
]=]
function Renderer:SetLimits(Value: Preset | Limits): Renderer
	const State: Fields = AsFields(self)
	const Resolved: LimitsData = Limits.Resolve(Value, 2)
	if State.Limits == Resolved then return self end

	State.Limits = Resolved
	Mark(State, Stage.Parse)

	return self
end

--[=[
	Returns how tags the intents do not grant are handled.

	@within Renderer
	@return Denied
]=]
function Renderer:GetDenied(): DeniedMode
	return AsFields(self).Denied
end

--[=[
	Sets how tags the intents do not grant are handled: `"Escape"` shows them as literal text, `"Strip"` drops the tag and keeps its content.

	@within Renderer
	@tag Builder
	@param Mode Denied
	@return Renderer
]=]
function Renderer:SetDenied(Mode: DeniedMode): Renderer
	const State: Fields = AsFields(self)

	Presets.CheckDenied(Mode, 2)
	if State.Denied == Mode then return self end

	State.Denied = Mode
	Mark(State, Stage.Parse)

	return self
end

--[=[
	Applies a preset's intents, limits and denied handling at once. A new renderer starts on `"Default"`, which allows every tag and is meant for markup you write.

	```lua
	RichTextPlus.new(ChatLabel):SetPreset("Chat")
	RichTextPlus.new(ChatLabel):SetPreset("Chat"):SetIntents(RichTextPlus.Intents.Presets.Chat:Add("Links"))
	```

	@within Renderer
	@tag Builder
	@param Name Preset
	@return Renderer
]=]
function Renderer:SetPreset(Name: Preset): Renderer
	const State: Fields = AsFields(self)
	const Bundle: Presets.Bundle = Presets.Resolve(Name, 2)
	if State.Intents == Bundle.Intents and State.Limits == Bundle.Limits and State.Denied == Bundle.Denied then return self end

	State.Intents = Bundle.Intents
	State.Limits = Bundle.Limits
	State.Denied = Bundle.Denied
	Mark(State, Stage.Parse)

	return self
end

--[=[
	Decides which images and asset fonts may load, given the canonical id. `nil`, the default, allows every canonical asset id.

	```lua
	Renderer:SetAssetFilter({["rbxassetid://123"] = true})
	Renderer:SetAssetFilter(function(Id) return Approved[Id] == true end)
	```

	@within Renderer
	@tag Builder
	@param Filter AssetFilter?
	@return Renderer
]=]
function Renderer:SetAssetFilter(Filter: AssetFilter?): Renderer
	const State: Fields = AsFields(self)

	State.Assets = Assets.Resolve(Filter, 2)
	Mark(State, Stage.Parse)

	return self
end

--[=[
	Returns whether an image or font asset id is in an accepted form and passes the asset filter. Custom classes that load assets must check them with it.

	@within Renderer
	@param Source string
	@return boolean
]=]
function Renderer:AllowsAsset(Source: string): boolean
	return Assets.Allows(AsFields(self).Assets, Source)
end

--[=[
	Returns whether a rendering switch is on.

	@within Renderer
	@param Name RenderingName
	@return boolean
]=]
function Renderer:GetRendering(Name: RenderingName): boolean
	Rendering.Check(Name)

	return (AsFields(self).Rendering :: any)[Name]
end

--[=[
	Turns a rendering switch on or off. All switches default to on.

	@within Renderer
	@tag Builder
	@param Name RenderingName
	@param Enabled boolean
	@return Renderer
]=]
function Renderer:SetRendering(Name: RenderingName, Enabled: boolean): Renderer
	const State: Fields = AsFields(self)

	Rendering.Check(Name)
	if type(Enabled) ~= "boolean" then error(`RichTextPlus rendering switch "{Name}" takes a boolean`, 2) end
	if (State.Rendering :: any)[Name] == Enabled then return self end

	State.Rendering = Rendering.With(State.Rendering, Name, Enabled)

	if Name == "Culling" then Culling.Release(State) end

	Mark(State, Stage.Parse)

	return self
end

--[=[
	Returns the whitespace mode.

	@within Renderer
	@return Whitespace
]=]
function Renderer:GetWhitespace(): WhitespaceMode
	return AsFields(self).Options.Whitespace
end

--[=[
	Sets how raw text whitespace is treated. `"Preserve"` (the default) keeps it; `"Markup"` ignores indentation between tags.

	@within Renderer
	@tag Builder
	@param Mode Whitespace
	@return Renderer
]=]
function Renderer:SetWhitespace(Mode: WhitespaceMode): Renderer
	const State: Fields = AsFields(self)

	Whitespace.Check(Mode)
	if State.Options.Whitespace == Mode then return self end

	State.Options.Whitespace = Mode
	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Returns the markup size multiplier.

	@within Renderer
	@return number
]=]
function Renderer:GetScale(): number
	return AsFields(self).Options.Scale
end

--[=[
	Multiplies markup sizes. Must be positive and finite; defaults to 1.

	@within Renderer
	@tag Builder
	@param Scale number
	@return Renderer
]=]
function Renderer:SetScale(Scale: number): Renderer
	const State: Fields = AsFields(self)

	if type(Scale) ~= "number" or not (Scale > 0 and Scale < math.huge) then error("RichTextPlus Renderer:SetScale takes a positive finite number", 2) end
	if State.Options.Scale == Scale then return self end

	State.Options.Scale = Scale
	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Returns the elements that match a selector, in document order, rendering pending changes first. Selectors follow Roblox's `Instance:QueryDescendants` grammar, with tag names for classes, `class` attribute words for tags and `id` for names.

	| Selector | Matches |
	| --- | --- |
	| `a` | every `<a>` |
	| `.nav` | tags with `nav` in their `class` attribute |
	| `#buy` | the tag with `id="buy"` |
	| `[$href]`, `[$href = "x"]` | tags with the attribute, or with that value |
	| `[Text = Docs]` | element properties: `Tag`, `Id`, `Text`, `Interactive`, `Hovered`, `Pressed`, `Focused`, `Visible` |
	| `b > a`, `b >> a` | a child, or any descendant, of a `<b>` |
	| `> a` | a top-level `<a>` |
	| `a, img` | either selector |
	| `:not(.muted)`, `:has(> img)` | negation, and a descendant that matches |
	| `:Hover`, `:Press`, `:Focus`, `:Idle`, `:NonInteractable` | interaction state |

	Like Roblox, whitespace between filters does not mean descendant: `b a` means a tag that is both, so write `b >> a`. Tag and attribute names are case-insensitive; everything else is case-sensitive.

	```lua
	for _, Link in Renderer:QueryDescendants(".nav > a") do
		print(Link:GetAttribute("href"))
	end
	```

	@within Renderer
	@param Selector string
	@return { Element }
]=]
function Renderer:QueryDescendants(Selector: string): { Element }
	const State: Fields = AsFields(self)
	const Compiled: any = Elements.Selector.Compile(Selector, 2)

	Driver.Settle(State)

	return Elements.Query(State, Compiled, false)
end

--[=[
	Returns the first element that matches a selector, or `nil`. See [Renderer:QueryDescendants] for the grammar.

	@within Renderer
	@param Selector string
	@return Element?
]=]
function Renderer:QueryFirst(Selector: string): Element?
	const State: Fields = AsFields(self)
	const Compiled: any = Elements.Selector.Compile(Selector, 2)

	Driver.Settle(State)

	return Elements.Query(State, Compiled, true)[1]
end

--[=[
	Handles input on every element that matches a selector, now and after later renders. Matched elements become interactive; the rest of the text stays plain labels. Handlers run deferred, like signal handlers, and bubble: activating an element inside a matched one also fires the outer handler. State selectors such as `:Hover` are checked when the event fires.

	Returns a connection; disconnect it to stop. [Renderer:Destroy] disconnects every binding.

	```lua
	Renderer:Bind("a", {
		Activated = function(Link)
			print("open", Link:GetAttribute("href"))
		end,
		HoverChanged = function(Link, Hovering)
			Tooltip.Visible = Hovering
		end,
	})
	```

	@within Renderer
	@param Selector string
	@param Handlers BindHandlers
	@return Connection
]=]
function Renderer:Bind(Selector: string, Handlers: BindHandlers): Binding
	const State: Fields = AsFields(self)
	const Compiled: any = Elements.Selector.Compile(Selector, 2)

	if type(Handlers) ~= "table" then error("RichTextPlus Renderer:Bind takes a selector and a table of handlers: {Activated = fn, HoverChanged = fn, PressChanged = fn}", 2) end

	const Copied: { [string]: any } = {}

	for Name: any, Handler: any in (Handlers :: any) do
		if not Elements.Events[Name] then error(`RichTextPlus Renderer:Bind has no event "{tostring(Name)}": use Activated, HoverChanged or PressChanged`, 2) end
		if type(Handler) ~= "function" then error(`RichTextPlus Renderer:Bind handler {Name} must be a function`, 2) end

		Copied[Name] = Handler
	end

	return Elements.Bind(State, Compiled, Copied :: any)
end

--[=[
	Returns the theme: markdown, code and link colors.

	@within Renderer
	@return Theme
]=]
function Renderer:GetTheme(): Theme
	return AsFields(self).Theme
end

--[=[
	Sets the markdown, code and link theme, or restores the defaults with `nil`.

	```lua
	Renderer:SetTheme({LinkColor = Color3.fromRGB(90, 170, 255), LinkHoverColor = Color3.new(1, 1, 1)})
	```

	@within Renderer
	@tag Builder
	@param Value Theme?
	@return Renderer
]=]
function Renderer:SetTheme(Value: Theme?): Renderer
	const State: Fields = AsFields(self)

	if Value ~= nil and type(Value) ~= "table" then error("RichTextPlus Renderer:SetTheme takes a theme table, or nil for the defaults", 2) end

	State.Theme = Value or Lifecycle.DefaultTheme
	Mark(State, Stage.Flatten)

	return self
end

--[=[
	Stops rendering and hands the label back with its properties restored. Call it before `Label:Destroy()` so segments return to the shared pool.

	@within Renderer
]=]
function Renderer:Destroy(): ()
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Destroy") end

	Lifecycle.Teardown(AsFields(self))

	if Profiling then Profiler.End() end
end

const function New(Label: TextLabel, Removed: nil): Renderer
	if Removed ~= nil then error(REMOVED_OPTIONS, 2) end

	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:New") end

	const State: Fields = Lifecycle.Create(Label)
	const Created: Renderer = setmetatable(State, Renderer)

	Watch.Adopt(State)
	Schedule.Queue(State, Stage.Parse)

	if Profiling then Profiler.End() end

	return Created
end

return {
	Class = Renderer;
	Removed = REMOVED;
	new = New;
}
