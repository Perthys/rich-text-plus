--!strict
--!native
--!optimize 2

const XML = require("../../XML")
const Types = require("../Types")
const Flatten = require("../Core/Flatten")
const Incremental = require("../Core/Incremental")
const Scale = require("../Core/Scale")
const Layout = require("../Core/Layout")
const Segment = require("../Render/Segment")
const Native = require("../Core/Native")
const Schedule = require("../Render/Schedule")
const Profiler = require("../Utility/Profiler")
const Embed = require("../Markdown/Embed")
const Intents = require("../Policy/Intents")
const Stage = require("./Stage")
const Transparency = require("./Transparency")

type XMLNode = Types.Node
type Fields = Types.Fields

const Capture = Transparency.Capture
const Conceal = Transparency.Conceal
const Mirror = Transparency.Mirror

const function Parse(State: Fields): XMLNode
	const Source: string = Native.Source(State)

	State.Document.Source = Source
	State.Document.Origin = nil

	if not Intents.Interprets(State.Intents.Bitfield, State.Denied == "Strip") then return XML.Node.new("ROOT") end

	if not string.find(Source, Embed.Pattern) then
		State.Document.Origin = Source

		return XML.GenerateTreeFromXML(Source)
	end

	return XML.GenerateTreeFromXML(Embed.Preprocess(Source))
end

const function Reflatten(State: Fields): ()
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Flatten") end

	if Flatten.Run(State, State.Document.Tree or XML.Node.new("ROOT")) then State.Scale.Measured = 0 end

	if Profiling then Profiler.End() end
end

const function Present(State: Fields): boolean
	const Captured: boolean, Live: number = Capture(State)
	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Native") end

	const Markup: string? = Native.Markup(State)
	if Markup then Native.Enter(State, Markup :: string) end

	if Profiling then Profiler.End() end
	if Markup then return true end

	if not Native.Showing(State) then Conceal(State, Live) end
	if Captured then Segment.ApplyTransparency(State) end

	return false
end

const function Settle(State: Fields): ()
	if not State.Native.Active then return end

	Native.Release(State)
	Mirror(State)
end

const function Resume(State: Fields, From: number, Generation: number, Patched: boolean): ()
	if State.Destroyed or From < Stage.Flatten or State.Generation.Text ~= Generation then return end
	if Patched and Native.Source(State) == State.Document.Source then return end

	Schedule.Queue(State, if Patched then Stage.Text else math.min(From, Stage.Parse))
end

const function Patch(State: Fields, Profiling: boolean): boolean
	if Profiling then Profiler.Begin("RTP:Patch") end

	const Patched: boolean = Incremental.Patch(State)

	if Profiling then Profiler.End() end

	return Patched
end

const function Update(State: Fields, From: number): ()
	if State.Destroyed then return end

	if From < Stage.Scale then
		if not State.Native.Active and State.Scale.Measured ~= 0 then Layout.Run(State) end

		return
	end

	State.Generation.Refresh += 1

	const Generation: number = State.Generation.Refresh
	const Profiling: boolean = Profiler.Enabled
	if From >= Stage.Flatten then State.Generation.Text = Generation end
	if From >= Stage.Parse then State.Host.Text = nil end

	const Patched: boolean = From == Stage.Text and Patch(State, Profiling)

	if not Patched then
		if From >= Stage.Parse then
			if Profiling then Profiler.Begin("RTP:Parse") end
			State.Document.Tree = Parse(State)
			if Profiling then Profiler.End() end
		end

		if From >= Stage.Flatten then Reflatten(State) end
	end

	if State.Generation.Refresh ~= Generation or State.Destroyed then Resume(State, From, Generation, Patched); return end

	if Present(State) then return end

	Scale.Enforce(State)

	if not Scale.Solve(State) then return end

	Settle(State)
	Layout.Run(State)
end

const function Refresh(State: Fields, From: number): ()
	if not Profiler.Enabled then Update(State, From); return end

	Profiler.Begin("RTP:Refresh")
	Update(State, From)
	Profiler.End()
end

return {
	Refresh = Refresh;
}
