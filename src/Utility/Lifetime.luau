--!strict
--!native
--!optimize 2

const Types = require("../Types")

type Keyed = { [any]: any }

type Entry = {
	Name: string;
	Table: Keyed;
}

const Owned: { { [Types.Fields]: any } } = {}
const Tracked: { Entry } = {}

const function Track<Key, Value>(Name: string, Table: { [Key]: Value }): { [Key]: Value }
	table.insert(Tracked, {Name = Name, Table = Table})

	return Table
end

const function Own<Value>(Name: string, Table: { [Types.Fields]: Value }): { [Types.Fields]: Value }
	table.insert(Owned, Table)

	return Track(Name, Table)
end

const function Forget(State: Types.Fields): ()
	for _, Table: { [Types.Fields]: any } in (Owned) do Table[State] = nil end
end

const function Counts(): { [string]: number }
	const Result: { [string]: number } = {}

	for _, Entry: Entry in (Tracked) do
		local Count: number = Result[Entry.Name] or 0
		for _ in (Entry.Table) do Count += 1 end

		Result[Entry.Name] = Count
	end

	return Result
end

const function Holding(Key: any): { string }
	const Result: { string } = {}

	for _, Entry: Entry in (Tracked) do
		if Entry.Table[Key] ~= nil and not table.find(Result, Entry.Name) then table.insert(Result, Entry.Name) end
	end

	table.sort(Result)

	return Result
end

return {
	Own = Own;
	Track = Track;
	Forget = Forget;
	Counts = Counts;
	Holding = Holding;
}
