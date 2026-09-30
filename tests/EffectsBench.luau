--!strict

const RichTextPlus = require("../Packages/RichTextPlus")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const Gui = require("./Support/Gui")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const LIMIT_KB: number = 64

const function Run(): Summary
	const Screen: ScreenGui = Gui.new("EffectsBench")
	const Numeric: any = {Kind = "Effect", Update = function(Frame: any): ()
		Frame.Rotation = math.sin(Frame.Time + Frame.Seed)
		Frame.Transparency = 0.5 + 0.5 * math.sin(Frame.Time * Frame.Frequency)
	end}
	const Words: { string } = {}
	for Index = 1, 40 do Words[Index] = `w{Index}` end

	const Target: TextLabel = Instance.new("TextLabel")
	Target.Size = UDim2.fromOffset(900, 400)
	Target.TextSize = 18
	Target.TextWrapped = true
	Target.TextXAlignment = Enum.TextXAlignment.Left
	Target.TextYAlignment = Enum.TextYAlignment.Top
	Target.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Target.TextColor3 = Color3.new(1, 1, 1)
	Target.Text = `<customclass><numeric>{table.concat(Words, " ")}</numeric></customclass>`
	Target.Parent = Screen

	const Renderer: any = (RichTextPlus :: any).new(Target):SetRendering("Passthrough", false):AddCustomClasses({numeric = Numeric}):Flush()
	for _ = 1, 30 do Driver.Tick(Renderer, 1 / 60) end

	const Before: number = gcinfo()
	for _ = 1, 300 do Driver.Tick(Renderer, 1 / 60) end
	const Delta: number = gcinfo() - Before

	Renderer:Destroy()
	Screen:Destroy()

	const Report: { string } = {`12000 evaluations allocate under {LIMIT_KB} KB: {Delta} KB`}

	if Delta < LIMIT_KB then return {Passed = 1, Failed = 0, Failures = {}, Report = Report} end

	return {Passed = 0, Failed = 1, Failures = {`12000 evaluations allocate under {LIMIT_KB} KB: {Delta} KB`}, Report = Report}
end

return {
	Run = Run,
}
