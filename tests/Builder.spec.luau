--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Profiler = require("../Packages/RichTextPlus/Utility/Profiler")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const Markup: string = [[<b>Welcome</b> to the <font color="#FF7800">arena</font>, read <a href="rules">the rules</a> and <customclass><hot>shout</hot></customclass>]]

const Hot: any = {Kind = "Style", Apply = function(Style: any) Style.Bold = true end}
const Theme: any = {CodeBackground = Color3.fromRGB(10, 20, 30)}
const Tint: Color3 = Color3.fromRGB(255, 0, 128)

local Screen: ScreenGui
const Owned: { any } = {}

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Keep(Renderer: any): any
	table.insert(Owned, Renderer)

	return Renderer
end

const function Errors(Body: () -> ()): string
	const Ok: boolean, Problem: any = pcall(Body)

	return if Ok then "" else tostring(Problem)
end

const function Counting(Counts: { [string]: number }, Body: () -> ()): ()
	const Begin: (Name: string) -> () = (Profiler :: any).Begin
	const Profiling: boolean = (Profiler :: any).Enabled

	table.clear(Counts)
	;(Profiler :: any).Enabled = true
	;(Profiler :: any).Begin = function(Name: string): ()
		Counts[Name] = (Counts[Name] or 0) + 1
		Begin(Name)
	end

	const Ok: boolean, Problem: any = pcall(Body)

	;(Profiler :: any).Begin = Begin
	;(Profiler :: any).Enabled = Profiling

	if not Ok then error(Problem, 0) end
end

BeforeAll(function()
	Screen = Gui.new("Builder")
end)

AfterAll(function()
	for _, Renderer: any in Owned do Renderer:Destroy() end
	Gui.Cleanup()
end)

Describe("chain after new renders once on Flush", function()
	local Target: TextLabel
	local Renderer: any
	local Before: number = -1
	local After: number = -1
	const Counts: { [string]: number } = {}

	BeforeAll(function()
		Target = Label(Markup)

		Counting(Counts, function()
			Renderer = Keep(Library.new(Target)
				:SetPreset("Trusted")
				:SetIntents(Library.Intents.Presets.Trusted:Remove("Images"))
				:SetLimits({Objects = 8})
				:SetDenied("Strip")
				:SetAssetFilter({["rbxassetid://1"] = true})
				:SetScale(1.5)
				:SetTheme(Theme)
				:SetWhitespace("Markup")
				:SetRendering("Passthrough", false)
				:AddCustomClass("hot", Hot))

			Before = Renderer.Generation.Refresh
			Renderer:Flush()
		end)

		After = Renderer.Generation.Refresh
	end)

	It("nothing renders during the chain", function()
		Expect(Before).toBe(0)
	end)

	It("one refresh for new plus seven setters", function()
		Expect(After).toBe(1)
	end)

	It("one parse pass", function()
		Expect(Counts["RTP:Parse"]).toBe(1)
	end)

	It("one flatten pass", function()
		Expect(Counts["RTP:Flatten"]).toBe(1)
	end)

	It("one refresh pass", function()
		Expect(Counts["RTP:Refresh"]).toBe(1)
	end)

	It("rendered segments", function()
		Expect(#Target:GetChildren()).toBeGreaterThan(0)
	end)

	It("a second Flush has nothing to do", function()
		Renderer:Flush()
		Expect(Renderer.Generation.Refresh).toBe(1)
	end)
end)

Describe("chain after new renders once on the next frame", function()
	local Target: TextLabel
	local Renderer: any

	It("deferred until the frame", function()
		Target = Label(Markup)
		Renderer = Keep(Library.new(Target):SetPreset("Trusted"):SetScale(2):SetRendering("Passthrough", false):AddCustomClass("hot", Hot))
		Expect(Renderer.Generation.Refresh).toBe(0)
	end)

	It("rendered once by the scheduler", function()
		task.wait()
		task.wait()
		Expect(Renderer.Generation.Refresh).toBe(1)
	end)

	It("segments on the next frame", function()
		Expect(#Target:GetChildren()).toBeGreaterThan(0)
	end)
end)

Describe("setters return the renderer and getters read back", function()
	local Renderer: any

	BeforeAll(function()
		Renderer = Keep(Library.new(Label("plain")))
	end)

	It("SetPreset returns self", function()
		Expect(Renderer:SetPreset("Trusted")).toBe(Renderer)
	end)

	It("SetIntents returns self", function()
		Expect(Renderer:SetIntents({"Formatting", "Color", "Links"})).toBe(Renderer)
	end)

	It("SetLimits returns self", function()
		Expect(Renderer:SetLimits({Objects = 3, TextSize = {Min = 10}})).toBe(Renderer)
	end)

	It("SetDenied returns self", function()
		Expect(Renderer:SetDenied("Strip")).toBe(Renderer)
	end)

	It("SetAssetFilter returns self", function()
		Expect(Renderer:SetAssetFilter({["123"] = true})).toBe(Renderer)
	end)

	It("SetScale returns self", function()
		Expect(Renderer:SetScale(1.25)).toBe(Renderer)
	end)

	It("SetLinkColor is removed and names the theme", function()
		Expect(Errors(function() Renderer:SetLinkColor(Tint) end)).toContain("SetTheme({LinkColor")
	end)

	It("SetTheme returns self", function()
		Expect(Renderer:SetTheme(Theme)).toBe(Renderer)
	end)

	It("SetWhitespace returns self", function()
		Expect(Renderer:SetWhitespace("Markup")).toBe(Renderer)
	end)

	It("SetRendering returns self", function()
		Expect(Renderer:SetRendering("Culling", false)).toBe(Renderer)
	end)

	It("AddCustomClass returns self", function()
		Expect(Renderer:AddCustomClass("hot", Hot)).toBe(Renderer)
	end)

	It("AddCustomClasses returns self", function()
		Expect(Renderer:AddCustomClasses({warm = Hot})).toBe(Renderer)
	end)

	It("RemoveCustomClass returns self", function()
		Expect(Renderer:RemoveCustomClass("warm")).toBe(Renderer)
	end)

	It("Flush returns self", function()
		Expect(Renderer:Flush()).toBe(Renderer)
	end)

	It("GetIntents", function()
		Expect(Renderer:GetIntents():Equals({"Formatting", "Color", "Links"})).toBe(true)
	end)

	It("GetLimits", function()
		Expect(Renderer:GetLimits().Objects).toBe(3)
		Expect(Renderer:GetLimits().TextSize.Min).toBe(10)
		Expect(Renderer:GetLimits().Depth).toBeNil()
	end)

	It("GetDenied", function()
		Expect(Renderer:GetDenied()).toBe("Strip")
	end)

	It("AllowsAsset reads the filter", function()
		Expect(Renderer:AllowsAsset("rbxassetid://123")).toBe(true)
		Expect(Renderer:AllowsAsset("rbxassetid://124")).toBe(false)
	end)

	It("GetScale", function()
		Expect(Renderer:GetScale()).toBe(1.25)
	end)

	It("GetLinkColor is removed and names the theme", function()
		Expect(Errors(function() Renderer:GetLinkColor() end)).toContain("GetTheme().LinkColor")
	end)

	It("GetTheme", function()
		Expect(Renderer:GetTheme()).toBe(Theme)
	end)

	It("GetWhitespace", function()
		Expect(Renderer:GetWhitespace()).toBe("Markup")
	end)

	It("GetRendering", function()
		Expect(Renderer:GetRendering("Culling")).toBe(false)
	end)

	It("SetTheme nil restores the defaults", function()
		Renderer:SetTheme(nil)
		Expect(Renderer:GetTheme() ~= Theme and next(Renderer:GetTheme()) == nil).toBe(true)
	end)
end)

Describe("defaults", function()
	local Renderer: any

	BeforeAll(function()
		Renderer = Keep(Library.new(Label("plain")))
	end)

	It("default intents", function()
		Expect(Renderer:GetIntents()).toBe(Library.Intents.Presets.Default)
	end)

	It("default denied handling", function()
		Expect(Renderer:GetDenied()).toBe("Strip")
	end)

	It("default assets allow any canonical id", function()
		Expect(Renderer:AllowsAsset("555")).toBe(true)
		Expect(Renderer:AllowsAsset("http://evil")).toBe(false)
	end)

	It("default scale", function()
		Expect(Renderer:GetScale()).toBe(1)
	end)

	It("default whitespace", function()
		Expect(Renderer:GetWhitespace()).toBe("Preserve")
	end)

	It("default passthrough", function()
		Expect(Renderer:GetRendering("Passthrough")).toBe(true)
	end)

	It("default theme has no link color override", function()
		Expect(Renderer:GetTheme().LinkColor).toBeNil()
	end)
end)

Describe("setters on a live renderer mark dirty and render once", function()
	local Renderer: any
	local Settled: number

	BeforeAll(function()
		Renderer = Keep(Library.new(Label(Markup)):SetRendering("Passthrough", false):AddCustomClass("hot", Hot):Flush())
		Settled = Renderer.Generation.Refresh
	end)

	It("setters do not render", function()
		Renderer:SetScale(2):SetTheme({LinkColor = Tint}):SetWhitespace("Markup")
		Expect(Renderer.Generation.Refresh).toBe(Settled)
	end)

	It("one refresh for three setters", function()
		Renderer:Flush()
		Expect(Renderer.Generation.Refresh).toBe(Settled + 1)
	end)

	It("unchanged values queue nothing", function()
		Renderer:SetScale(2):SetWhitespace("Markup"):SetRendering("Passthrough", false):Flush()
		Expect(Renderer.Generation.Refresh).toBe(Settled + 1)
	end)
end)

Describe("scale and link color reach the render", function()
	local Word: any
	local Reference: any

	BeforeAll(function()
		const Base: any = Keep(Library.new(Label([[<a href="x">link</a>]])):SetRendering("Passthrough", false):Flush())
		const Renderer: any = Keep(Library.new(Label([[<a href="x">link</a>]])):SetRendering("Passthrough", false):SetScale(2):SetTheme({LinkColor = Tint}):Flush())

		Word = Renderer.Instances.Segments[1]
		Reference = Base.Instances.Segments[1]
	end)

	It("scaled segment is larger", function()
		Expect(Word and Reference and Word.Instance.TextSize > Reference.Instance.TextSize).toBe(true)
	end)

	It("link color applied", function()
		Expect(Word and Word.Instance.TextColor3).toBe(Tint)
	end)
end)

Describe("options table is rejected", function()
	local Message: string = ""

	BeforeAll(function()
		const Target: TextLabel = Label("x")
		Message = Errors(function() Library.new(Target, {Preset = "Trusted"}) end)
	end)

	It("second argument errors", function()
		Expect(Message).toContain("takes only the label")
	end)

	for _, Setter: string in {"SetPreset", "SetIntents", "SetLimits", "SetScale", "SetTheme", "SetWhitespace", "SetRendering", "AddCustomClass"} do
		It(`error names {Setter}`, function()
			Expect(Message).toContain(Setter)
		end)
	end
end)

Describe("setters validate", function()
	local Renderer: any

	BeforeAll(function()
		Renderer = Keep(Library.new(Label("x")))
	end)

	const Cases: { { any } } = {
		{"SetScale rejects zero", function() Renderer:SetScale(0) end},
		{"SetScale rejects NaN", function() Renderer:SetScale(0 / 0) end},
		{"SetScale rejects infinity", function() Renderer:SetScale(math.huge) end},
		{"SetScale rejects a string", function() Renderer:SetScale("2") end},
		{"SetTheme rejects a number", function() Renderer:SetTheme(5) end},
		{"SetWhitespace rejects unknown", function() Renderer:SetWhitespace("Collapse") end},
		{"SetRendering rejects unknown", function() Renderer:SetRendering("Typewriter", false) end},
		{"SetPreset rejects unknown preset", function() Renderer:SetPreset("Nope") end},
		{"SetIntents rejects an unknown flag", function() Renderer:SetIntents({"Nope"}) end},
		{"SetIntents rejects a boolean", function() Renderer:SetIntents(true) end},
		{"SetLimits rejects a number", function() Renderer:SetLimits(5) end},
		{"SetLimits rejects an unknown field", function() Renderer:SetLimits({MaxDepth = 4}) end},
		{"SetLimits rejects a bad TextSize", function() Renderer:SetLimits({TextSize = 5}) end},
		{"SetDenied rejects unknown", function() Renderer:SetDenied("Hide") end},
		{"SetAssetFilter rejects a string", function() Renderer:SetAssetFilter("123") end},
		{"AddCustomClasses rejects a list of nothing", function() Renderer:AddCustomClasses(5) end},
	}

	for _, Case: { any } in Cases do
		It(Case[1], function()
			Expect(Errors(Case[2])).never.toBe("")
		end)
	end

	It("failed setters leave the scale", function()
		Expect(Renderer:GetScale()).toBe(1)
	end)
end)

Describe("AddCustomClasses registers every entry", function()
	local Italic: boolean = false
	local Underline: boolean = false

	BeforeAll(function()
		const Renderer: any = Keep(Library.new(Label([[<customclass><one>a</one> <two>b</two></customclass>]])):SetRendering("Passthrough", false):AddCustomClasses({
			one = {Kind = "Style", Apply = function(Style: any) Style.Italic = true end};
			two = {Kind = "Style", Apply = function(Style: any) Style.Underline = true end};
		}):Flush())

		for _, Record: any in Renderer.Instances.Segments do
			const Text: string = Record.Instance.Text
			if string.find(Text, "<i>", 1, true) or Record.Instance.FontFace.Style == Enum.FontStyle.Italic then Italic = true end
			if string.find(Text, "<u>", 1, true) then Underline = true end
		end
	end)

	It("first class applied", function()
		Expect(Italic).toBe(true)
	end)

	It("second class applied", function()
		Expect(Underline).toBe(true)
	end)
end)
