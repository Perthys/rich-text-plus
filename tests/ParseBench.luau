--!strict

const XML = require("../Packages/XML")
const Trove = require("../Packages/Trove")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const Flatten = require("../Packages/RichTextPlus/Core/Flatten")
const Presets = require("../Packages/RichTextPlus/Policy/Presets")
const Rendering = require("../Packages/RichTextPlus/Policy/Rendering")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const function Run(): Summary
	const Outcome: Summary = {Passed = 0, Failed = 0, Failures = {}, Report = {}}

	const Words: { string } = {}
	for Index = 1, 3000 do table.insert(Words, `w{Index}`) end
	const Text: string = `<a href="big">{table.concat(Words, " ")}</a>`

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

	const Started: number = os.clock()
	const Tree: any = (XML :: any).GenerateTreeFromXML(Text)
	const Walker: any = Flatten
	Walker.Run(State, Tree)
	const Elapsed: number = os.clock() - Started

	MainTrove:Clean()
	Label:Destroy()

	table.insert(Outcome.Report :: { string }, `long link text: {string.format("%.2f", Elapsed * 1000)} ms (limit 250 ms)`)

	if Elapsed < 0.25 then
		Outcome.Passed += 1
	else
		Outcome.Failed += 1
		table.insert(Outcome.Failures, `long link text is linear: {Elapsed}`)
	end

	return Outcome
end

return {
	Run = Run,
}
