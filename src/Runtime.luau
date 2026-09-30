--!strict
--!native
--!optimize 2

const Measure = require("./Text/Measure")
const Pool = require("./Render/Pool")
const Schedule = require("./Render/Schedule")
const Profiler = require("./Utility/Profiler")
const Driver = require("./Renderer/Driver")
const Rendering = require("./Policy/Rendering")

--[=[
	Engine-wide settings shared by every renderer, reached through `RichTextPlus.Runtime`.

	@class Runtime
	@since 0.2.0
]=]
--[=[
	Loads font faces in parallel and builds glyph tables so labels measure without engine calls. Defaults to the `TextLabel` default font and size.

	@within Runtime
	@function Preload
	@yields
	@param Fonts { Font }?
	@param Sizes { number }?
]=]
const function Preload(Fonts: { Font }?, Sizes: { number }?): ()
	if Fonts and Sizes then Measure.Preload(Fonts :: { Font }, Sizes :: { number }); return end

	const Probe: TextLabel = Instance.new("TextLabel")
	const Face: Font, Size: number = Probe.FontFace, Probe.TextSize
	Probe:Destroy()

	Measure.Preload(Fonts or {Face}, Sizes or {Size})
end

--[=[
	Caps how many recycled segments, link buttons and backdrops the shared pool keeps.

	@within Runtime
	@function SetPoolLimit
	@param Limit number
]=]
const function SetPoolLimit(Limit: number): ()
	Pool.SetLimit(Limit)
end

--[=[
	Sets the milliseconds per `Heartbeat` spent on queued label refreshes. Defaults to 2.

	@within Runtime
	@function SetFrameBudget
	@param Milliseconds number
]=]
const function SetFrameBudget(Milliseconds: number): ()
	Schedule.SetBudget(Milliseconds)
end

--[=[
	Adds `RTP:<Stage>` MicroProfiler labels. They cost 3 to 10% on small updates, so they are off by default.

	@within Runtime
	@function SetProfiling
	@param Enabled boolean
]=]
const function SetProfiling(Enabled: boolean): ()
	if type(Enabled) ~= "boolean" then error("RichTextPlus profiling flag must be a boolean", 2) end

	Profiler.Enabled = Enabled
end

--[=[
	Settles every renderer now. [Renderer:Flush] settles one.

	@within Runtime
	@function Flush
]=]
const function Flush(): ()
	Driver.Drain()
end

--[=[
	The rendering switch names, in order.

	@within Runtime
	@prop RenderingNames { RenderingName }
	@readonly
]=]
return {
	Preload = Preload;
	SetPoolLimit = SetPoolLimit;
	SetFrameBudget = SetFrameBudget;
	SetProfiling = SetProfiling;
	Flush = Flush;
	RenderingNames = Rendering.Names;
}
