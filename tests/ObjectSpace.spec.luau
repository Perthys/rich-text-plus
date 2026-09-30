--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

local Screen: ScreenGui
const Renderers: { any } = {}

const function Mount(Text: string): TextLabel
	const Label: TextLabel = Instance.new("TextLabel")
	Label.Size = UDim2.fromOffset(600, 200)
	Label.TextSize = 20
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Top
	Label.Text = Text
	Label.Parent = Screen

	const Renderer: any = RichTextPlus.new(Label):SetRendering("Passthrough", false)
	Renderer:AddCustomClasses({
		badge = {
			Kind = "Object";
			Build = function(_Node: any, _Style: any): GuiObject?
				const Frame: Frame = Instance.new("Frame")
				Frame.Name = "Badge"
				Frame.Size = UDim2.fromOffset(30, 16)

				return Frame
			end;
		},
	})
	Renderer:Flush()
	Renderer:Flush()
	table.insert(Renderers, Renderer)

	return Label
end

const function Objects(Label: TextLabel): { GuiObject }
	const Found: { GuiObject } = {}

	for _, Child: Instance in Label:GetChildren() do
		if Child.Name == "Badge" and Child:IsA("GuiObject") and Child.Visible then table.insert(Found, Child) end
	end

	table.sort(Found, function(A: GuiObject, B: GuiObject): boolean return A.Position.X.Offset < B.Position.X.Offset end)

	return Found
end

const function Gap(Pair: { GuiObject }): number
	return Pair[2].Position.X.Offset - (Pair[1].Position.X.Offset + Pair[1].Size.X.Offset)
end

BeforeAll(function()
	Screen = Gui.new("ObjectSpace")
end)

AfterAll(function()
	for _, Renderer: any in Renderers do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("object spacing", function()
	local Badges: { GuiObject }
	local Touching: { GuiObject }
	local Spaced: GuiObject?
	local Tight: GuiObject?

	BeforeAll(function()
		Badges = Objects(Mount("Status: <customclass><badge/> <badge/></customclass> end"))
		Touching = Objects(Mount("Status: <customclass><badge/><badge/></customclass> end"))
		Spaced = Objects(Mount("word <customclass><badge/></customclass>"))[1]
		Tight = Objects(Mount("word<customclass><badge/></customclass>"))[1]
	end)

	It("two badges placed", function()
		Expect(#Badges).toBe(2)
	end)

	It("space between spaced objects", function()
		Expect(Gap(Badges)).toBeGreaterThanOrEqual(3)
	end)

	It("no space between glued objects", function()
		Expect(#Touching == 2 and Gap(Touching)).toBe(0)
	end)

	It("object after word keeps its space", function()
		Expect(if Spaced and Tight then Spaced.Position.X.Offset - Tight.Position.X.Offset else nil).toBeGreaterThan(2)
	end)
end)
