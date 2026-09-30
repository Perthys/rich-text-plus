--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Unicode = require("../Text/Unicode")
const Elements = require("../Elements")

const function Show(Record: Types.Record, Units: number): ()
	const Content: Types.ContentData = Record.Content
	const Previous: number = Content.Revealed
	if Previous == Units then return end

	Content.Revealed = Units

	const Label: TextLabel? = Record.Label

	if Label then Label.MaxVisibleGraphemes = Units else Record.Instance.Visible = Units ~= 0 end
	if not Record.Button or (Previous == 0) == (Units == 0) then return end

	Record.Instance.Interactable = Units ~= 0
	Record.Instance.Selectable = Units ~= 0
end

const function Portion(Record: Types.Record, Visible: number, Consumed: number, Units: number): number
	if Visible >= Consumed + Units then return -1 end
	if Visible <= Consumed then return 0 end
	if not Record.Label then return -1 end

	const Shown: number = Visible - Consumed
	const Gaps: { number }? = Record.Content.Gaps
	if not Gaps then return Shown end

	local Extra: number = 0

	for _, Offset: number in (Gaps :: { number }) do
		if Offset >= Shown then break end

		Extra += 1
	end

	return Shown + Extra
end

const function Apply(State: Types.Fields): ()
	const Limit: number = State.Label.MaxVisibleGraphemes
	const Visible: number = if Limit < 0 then math.huge else Limit

	local Consumed: number = 0

	for _, Record: Types.Record in (State.Instances.Order) do
		const Units: number = if Record.Label then Record.Content.Graphemes else 1

		Show(Record, Portion(Record, Visible, Consumed, Units))
		Consumed += Units
	end

	Elements.Reveal(State)
end

const function Count(State: Types.Fields): number
	if State.Native.Active then return Unicode.Count(State.Label.ContentText) end

	local Total: number = 0

	for _, Record: Types.Record in (State.Instances.Order) do Total += if Record.Label then Record.Content.Graphemes else 1 end

	return Total
end

return {
	Apply = Apply;
	Count = Count;
}
