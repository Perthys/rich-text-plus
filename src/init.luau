--!strict
--!native
--!optimize 2

const Types = require("@self/Types")
const Renderer = require("@self/Renderer")
const Runtime = require("@self/Runtime")
const Intents = require("@self/Policy/Intents")
const Utilities = require("@self/Utilities")
const Signal = require("@self/Utility/Signal")

export type Renderer = Renderer.Renderer
export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection
export type Element = Types.Element
export type ElementState = Types.ElementState
export type BindHandlers = Types.BindHandlers
export type Node = Types.Node
export type Attribute = Types.Attribute
export type Gradient = Types.Gradient
export type EffectFrame = Types.EffectFrame
export type Style = Types.Style
export type Intents = Types.Intents
export type IntentFlag = Types.IntentFlag
export type IntentsValue = Types.IntentsValue
export type Limits = Types.Limits
export type TextSizeLimits = Types.TextSizeLimits
export type Denied = Types.Denied
export type AssetFilter = Types.AssetFilter
export type Rendering = Types.Rendering
export type RenderingName = Types.RenderingName
export type Whitespace = Types.Whitespace
export type Preset = Types.Preset
export type Theme = Types.Theme
export type ClassDefinition = Types.ClassDefinition

--[=[
	Rich text for Roblox `TextLabel`s: images, links, gradients, effects, markdown and code on top of Roblox RichText, with untrusted text gated by intents and limits.

	```lua
	local RichTextPlus = require(ReplicatedStorage.Packages.RichTextPlus)

	local Renderer = RichTextPlus.new(Label):SetPreset("Trusted")
	Label.Text = `<b>Hello</b> <wave>world</wave>`
	```

	The module holds only statics. Per-label operations are [Renderer] methods, engine-wide settings live on [Runtime].

	@class RichTextPlus
]=]
--[=[
	Takes over `Label` and returns its renderer. Set text with `Label.Text`; it renders on the next frame, or now with [Renderer:Flush].
	Calling it again on the same label replaces the previous renderer.

	@function new
	@within RichTextPlus
	@param Label TextLabel
	@return Renderer
]=]
--[=[
	Engine-wide settings shared by every renderer.

	@prop Runtime Runtime
	@within RichTextPlus
]=]
--[=[
	Intent flags, presets and the [Intents] bitfield class.

	@prop Intents Intents
	@within RichTextPlus
]=]
--[=[
	Escaping, attribute parsing, markdown and highlighting helpers.

	@prop Utilities Utilities
	@within RichTextPlus
]=]
const RichTextPlus = {
	new = Renderer.new;
	Runtime = Runtime;
	Intents = table.freeze({
		Flags = Intents.Flags;
		Presets = Intents.Presets;
		Tags = Intents.Tags;
		new = Intents.new;
		Resolve = Intents.Resolve;
	});
	Utilities = Utilities;
}

const function Moved(_: any, Name: any): nil
	if type(Name) ~= "string" then return nil end
	if Name == "Permissions" then error("RichTextPlus.Permissions was replaced by RichTextPlus.Intents: pass flags to Renderer:SetIntents, a preset name to Renderer:SetPreset, and limits to Renderer:SetLimits", 2) end
	if Name == "Flush" then error("RichTextPlus.Flush was split: RichTextPlus.Runtime.Flush() settles every label, Renderer:Flush() settles one", 2) end
	if (Runtime :: any)[Name] then error(`RichTextPlus.{Name} moved to RichTextPlus.Runtime.{Name}`, 2) end
	if Renderer.Removed[Name] then error(`RichTextPlus.{Name} was removed: {Renderer.Removed[Name]}`, 2) end
	if (Renderer.Class :: any)[Name] then error(`RichTextPlus.{Name} is a renderer method: call Renderer:{Name}(...) on the object RichTextPlus.new returns`, 2) end

	return nil
end

return table.freeze(setmetatable(RichTextPlus, {__index = Moved}))
