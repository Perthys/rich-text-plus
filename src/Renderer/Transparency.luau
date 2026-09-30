--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Native = require("../Core/Native")
const Segment = require("../Render/Segment")

type Fields = Types.Fields

const HIDDEN: number = 1 - 2 ^ -12

const function Expected(State: Fields): number
	return if Native.Showing(State) then State.Developer.Transparency else HIDDEN
end

const function Capture(State: Fields): (boolean, number)
	const Live: number = State.Label.TextTransparency
	if Live == HIDDEN or Live == State.Developer.Transparency then return false, Live end

	State.Developer.Transparency = Live

	return true, Live
end

const function Conceal(State: Fields, Live: number): ()
	Native.Suppress(State)
	Native.Remember(State)

	if Live ~= HIDDEN then State.Label.TextTransparency = HIDDEN end
end

const function Mirror(State: Fields): ()
	const Captured: boolean, Live: number = Capture(State)

	Conceal(State, Live)

	if Captured then Segment.ApplyTransparency(State) end
end

return {
	Expected = Expected;
	Capture = Capture;
	Conceal = Conceal;
	Mirror = Mirror;
}
