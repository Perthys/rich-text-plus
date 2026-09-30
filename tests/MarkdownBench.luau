--!strict

const Markdown = require("../Packages/RichTextPlus/Markdown")

const Converter: any = Markdown

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const Cases: { { any } } = {
	{"Stars", function(Count: number): string return string.rep("*a ", Count) end},
	{"Underscores", function(Count: number): string return string.rep("_a_b ", Count) end},
	{"Brackets", function(Count: number): string return string.rep("[", Count) .. string.rep("](", Count) end},
	{"Backticks", function(Count: number): string
		const Parts: { string } = {}
		for Index = 1, Count do table.insert(Parts, string.rep("`", Index % 50 + 1) .. "a") end

		return table.concat(Parts)
	end},
	{"Nesting", function(Count: number): string return string.rep("> ", Count) .. "x" end},
	{"Lists", function(Count: number): string
		const Parts: { string } = {}
		for Index = 1, Count do table.insert(Parts, string.rep(" ", Index % 20) .. "- item") end

		return table.concat(Parts, "\n")
	end},
}

const function Time(Source: string): number
	const Start: number = os.clock()
	Converter.ToMarkup(Source, nil, 14)

	return os.clock() - Start
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}

	for _, Case: { any } in Cases do
		const Name: string = Case[1]
		const Build: (Count: number) -> string = Case[2]

		Time(Build(500))
		const Small: number = Time(Build(4000))
		const Large: number = Time(Build(16000))
		const Detail: string = `{string.format("%.2f", Small * 1000)} ms -> {string.format("%.2f", Large * 1000)} ms`

		table.insert(Outcome.Report :: { string }, `linear {Name}: {Detail}`)

		if Large < Small * 8 + 0.01 then
			Outcome.Passed += 1
		else
			Outcome.Failed += 1
			table.insert(Outcome.Failures, `linear {Name}: {Detail}`)
		end
	end

	return Outcome
end

return {
	Run = Run,
}
