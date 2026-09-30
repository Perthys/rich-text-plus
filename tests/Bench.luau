--!strict

export type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

type Bench = { Run: () -> Summary }

const function Benches(): { ModuleScript }
	const Found: { ModuleScript } = {}

	for _, Child: Instance in script.Parent:GetChildren() do
		if Child == script or not Child:IsA("ModuleScript") or string.sub(Child.Name, -5) ~= "Bench" then continue end
		table.insert(Found, Child)
	end

	table.sort(Found, function(Left: ModuleScript, Right: ModuleScript): boolean
		return Left.Name < Right.Name
	end)

	return Found
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}}

	for _, Module: ModuleScript in Benches() do
		const Name: string = Module.Name
		const Ok: boolean, Result: any = pcall(function(): Summary
			return ((require :: any)(Module) :: Bench).Run()
		end)

		if not Ok then
			Outcome.Failed += 1
			table.insert(Outcome.Failures, `{Name}: errored: {Result}`)
			continue
		end

		Outcome.Passed += Result.Passed
		Outcome.Failed += Result.Failed
		for _, Failure: string in Result.Failures do table.insert(Outcome.Failures, `{Name}: {Failure}`) end
		for _, Line: string in Result.Report or {} do print(`[{Name}] {Line}`) end
	end

	return Outcome
end

return {
	Run = Run,
}
