--!strict

const XML = require("../Packages/XML")
const Trove = require("../Packages/Trove")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const Flatten = require("../Packages/RichTextPlus/Core/Flatten")
const Styles = require("../Packages/RichTextPlus/Utility/Styles")
const Presets = require("../Packages/RichTextPlus/Policy/Presets")
const Rendering = require("../Packages/RichTextPlus/Policy/Rendering")
const Markdown = require("../Packages/RichTextPlus/Markdown")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const function Flat(Text: string): ()
	const Label: TextLabel = Instance.new("TextLabel")
	Label.TextSize = 20
	Label.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.Text = Text

	const MainTrove: any = (Trove :: any).new()
	const State: any = {
		Label = Label;
		Options = {Scale = 1};
		Rendering = (Rendering :: any).Defaults;
		Intents = Presets.Default.Intents;
		Limits = Presets.Default.Limits;
		Denied = Presets.Default.Denied;
		Theme = {};
		Document = {Tokens = {}};
		Elements = ElementsModule.Create();
		Instances = {Records = {}};
		Objects = {Sizes = {}, Cache = {}};
		Troves = {Main = MainTrove, Objects = MainTrove:Extend()};
		Generation = {Refresh = 0};
		Scale = {Factor = 1};
		Animation = {};
	}

	const Ok: boolean, Problem: any = pcall((Flatten :: any).Run, State, (XML :: any).GenerateTreeFromXML(Text))

	MainTrove:Clean()
	Label:Destroy()

	if not Ok then error(Problem, 0) end
end

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}
	const Library: any = Styles
	const Converter: any = Markdown

	const function Fast(Name: string, Limit: number, Callback: () -> ()): ()
		const Started: number = os.clock()
		pcall(Callback)
		const Elapsed: number = os.clock() - Started

		table.insert(Outcome.Report :: { string }, `{Name}: {string.format("%.2f", Elapsed * 1000)} ms (limit {Limit * 1000} ms)`)

		if Elapsed < Limit then Outcome.Passed += 1; return end

		Outcome.Failed += 1
		table.insert(Outcome.Failures, `{Name} is linear: {Elapsed}`)
	end

	const Gap: string = "a" .. string.rep(" ", 20000) .. "b"
	Fast("Trim interior run", 0.05, function() Library.Trim(Gap) end)
	Fast("TrimEnd interior run", 0.05, function() Library.TrimEnd(Gap) end)
	Fast("ParseColor interior run", 0.05, function() Library.ParseColor(Gap .. "c") end)
	Fast("Truthy interior run", 0.05, function() Library.Truthy(Gap .. "d", true) end)
	Fast("markdown paragraph interior run", 0.2, function() Converter.ToMarkup(Gap) end)
	Fast("markdown heading interior run", 0.2, function() Converter.ToMarkup("# " .. Gap .. " #x") end)
	Fast("markdown heading hash run", 0.2, function() Converter.ToMarkup("# a" .. string.rep("#", 20000) .. "b") end)
	Fast("markdown fence interior run", 0.2, function() Converter.ToMarkup("```" .. string.rep(" ", 20000) .. "`") end)
	Fast("markdown fence info run", 0.2, function() Converter.ToMarkup("```a" .. string.rep(" ", 20000) .. "`b") end)
	Fast("indent size interior run", 0.05, function() Flat(`<indent by="1{string.rep(" ", 20000)}a{string.rep(" ", 20000)}!">x</indent>`) end)
	Fast("xml close tag interior run", 0.05, function() (XML :: any).GenerateTreeFromXML(`<b>x</b{string.rep(" ", 20000)}>`) end)

	const Lines: { string } = {string.rep("> ", 12) .. "a"}
	for _ = 1, 3000 do table.insert(Lines, "a") end
	const Source: string = table.concat(Lines, "\n")
	Fast("deep quote lazy lines", 0.5, function() Converter.ToMarkup(Source) end)

	const Items: { string } = {}
	for Depth = 0, 11 do table.insert(Items, string.rep("  ", Depth) .. "- a") end
	for _ = 1, 3000 do table.insert(Items, "a") end
	const Nested: string = table.concat(Items, "\n")
	Fast("deep list lazy lines", 0.5, function() Converter.ToMarkup(Nested) end)

	return Outcome
end

return {
	Run = Run,
}
