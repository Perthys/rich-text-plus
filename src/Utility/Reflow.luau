--!strict
--!native
--!optimize 2

const Types = require("../Types")
const Lifetime = require("./Lifetime")

type Resizer = Types.Resizer
type Applier = Types.Applier

type Entry = {
	Measure: Resizer;
	Apply: Applier?;
}

type Pending = {
	Tokens: { Types.Token };
	Sizes: { Vector2 };
	Busy: boolean;
}

const Entries = Lifetime.Track("Reflow.Entries", {} :: { [GuiObject]: Entry })
const Scratches = Lifetime.Own("Reflow.Scratches", {} :: { [Types.Fields]: Pending })

const function Register(Object: GuiObject, Measure: Resizer, Apply: Applier?): ()
	if not Entries[Object] then Object.Destroying:Once(function() Entries[Object] = nil end) end

	Entries[Object] = {Measure = Measure, Apply = Apply}
end

const function Measure(Object: GuiObject, Width: number, Factor: number?): Vector2?
	const Found: Entry? = Entries[Object]; if not Found then return nil end

	return (Found :: Entry).Measure(Width, Factor or 1)
end

const function Apply(Object: GuiObject, Width: number, Factor: number?): ()
	const Found: Entry? = Entries[Object]; if not Found then return end

	const Writer: Applier? = (Found :: Entry).Apply
	if Writer then (Writer :: Applier)(Width, Factor or 1) end
end

const function Height(Object: GuiObject, Width: number, Factor: number?): number?
	const Size: Vector2? = Measure(Object, Width, Factor); if not Size then return nil end

	Apply(Object, Width, Factor)

	return (Size :: Vector2).Y
end

const function Claim(State: Types.Fields): Pending
	const Existing: Pending? = Scratches[State]

	if Existing and not Existing.Busy then
		Existing.Busy = true

		return Existing
	end

	const Created: Pending = {Tokens = {}, Sizes = {}, Busy = true}
	if not Existing then Scratches[State] = Created end

	return Created
end

const function Fit(State: Types.Fields, Width: number, Factor: number): boolean
	const Generation: number = State.Generation.Refresh
	const Tokens: { Types.Token } = State.Document.Tokens

	local Pending: Pending? = nil
	local Count: number = 0

	for _, Token: Types.Token in (Tokens) do
		const Object: GuiObject? = Token.Object
		if not (Token.Block and Object) then continue end

		const Found: Entry? = Entries[Object :: GuiObject]; if not Found then continue end

		const Active: Pending = Pending or Claim(State)
		Pending = Active
		Count += 1
		Active.Tokens[Count] = Token
		Active.Sizes[Count] = (Found :: Entry).Measure(Width, Factor)
	end

	const Fresh: boolean = State.Generation.Refresh == Generation and not State.Destroyed
	if not Pending then return Fresh end

	const Active: Pending = Pending :: Pending
	const Measured: { Types.Token } = Active.Tokens
	const Sizes: { Vector2 } = Active.Sizes

	if Fresh then
		for Index = 1, Count do
			const Token: Types.Token = Measured[Index]
			const Size: Vector2 = Sizes[Index]

			Token.Width = Size.X
			Token.Height = Size.Y
		end
	end

	table.clear(Measured)
	table.clear(Sizes)
	Active.Busy = false

	return Fresh
end

const function Commit(State: Types.Fields, Width: number, Factor: number): ()
	for _, Token: Types.Token in (State.Document.Tokens) do
		const Object: GuiObject? = Token.Object
		if Token.Block and Object then Apply(Object :: GuiObject, Width, Factor) end
	end
end

return {
	Register = Register;
	Measure = Measure;
	Apply = Apply;
	Height = Height;
	Fit = Fit;
	Commit = Commit;
}
