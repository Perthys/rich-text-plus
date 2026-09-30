--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const Driver = require("../Packages/RichTextPlus/Renderer/Driver")
const LimitsModule = require("../Packages/RichTextPlus/Policy/Limits")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

type Case = {
	Flag: string,
	Markup: string,
	Expected: string,
}

const Library: any = RichTextPlus
const Intents: any = Library.Intents
const Presets: any = Intents.Presets

const Checked: { string } = {"Images", "Links", "Gradients", "Effects", "CustomClasses", "Markdown", "CodeBlocks"}
const RenderingNames: { string } = {"Passthrough", "Culling", "Clipping", "SyntaxHighlight"}
const PresetNames: { string } = {"Default", "Trusted", "Chat", "Plain"}

const Expected: { [string]: { [string]: boolean } } = {
	Default = {Images = true, Links = true, Gradients = true, Effects = true, CustomClasses = true, Markdown = true, CodeBlocks = true},
	Trusted = {Images = true, Links = true, Gradients = true, Effects = true, CustomClasses = true, Markdown = true, CodeBlocks = true},
	Chat = {Images = false, Links = false, Gradients = false, Effects = false, CustomClasses = false, Markdown = false, CodeBlocks = false},
	Plain = {Images = false, Links = false, Gradients = false, Effects = false, CustomClasses = false, Markdown = false, CodeBlocks = false},
}

const DeniedByPreset: { [string]: string } = {Default = "Strip", Trusted = "Escape", Chat = "Escape", Plain = "Escape"}

const Cases: { Case } = {
	{
		Flag = "Images",
		Markup = [[a <img src="rbxassetid://5" size="20"/> b <img src="1">cap</img> <md>![](rbxassetid://1) t</md>]],
		Expected = "a b cap t|links=0",
	},
	{
		Flag = "Links",
		Markup = [[<a href="u">click me</a> <a href="v"/> <md>[t](w) <https://x.y></md>]],
		Expected = "click me v t https://x.y|links=0",
	},
	{
		Flag = "Gradients",
		Markup = [[<gradient colors="#f00,#00f">g</gradient> h <md>*i*</md>]],
		Expected = "g h i|links=0",
	},
	{
		Flag = "Effects",
		Markup = [[<wave>w</wave> <shake amplitude="2">s</shake> <customclass><glow>e</glow></customclass>]],
		Expected = "w s e|links=0",
	},
	{
		Flag = "Markdown",
		Markup = "<md>**x** &lt;y&gt;\n- item\n---</md> after",
		Expected = "**x** &lt;y&gt;\n- item\n--- after|links=0",
	},
	{
		Flag = "CodeBlocks",
		Markup = "<codeblock lang=\"lua\">local x = 1</codeblock> <md>```lua\nlocal y\n```</md>",
		Expected = "[CodeBlock:plain] [CodeBlock:plain]|links=0",
	},
	{
		Flag = "CustomClasses",
		Markup = [[<customclass><icon/>x <warn>w</warn> <glow>e</glow></customclass> <customclass name="warn">y</customclass>]],
		Expected = "x w e y|links=0",
	},
}

const RichTextMarkup: string = "<b>x</b>\nline2 &amp; <i>y</i>"
const RichTextExpected: string = "<b>x</b>\nline2 &amp; <i>y</i>|links=0"

const Warn: any = {Kind = "Style", Apply = function(Style: any) Style.Bold = true end}
const Glow: any = {Kind = "Effect", Update = function(Frame: any): () Frame.Offset = Vector2.new(0, 1) end}
const Icon: any = {Kind = "Object", Build = function(): GuiObject
	const Created: Frame = Instance.new("Frame")
	Created.Name = "Icon"
	Created.Size = UDim2.fromOffset(10, 10)

	return Created
end}

local Screen: ScreenGui
const Renderers: { any } = {}

const function Mount(Text: string, Setup: ((any) -> ())?): (any, TextLabel)
	const Target: TextLabel = Instance.new("TextLabel")
	Target.Size = UDim2.fromOffset(600, 400)
	Target.TextSize = 20
	Target.TextWrapped = true
	Target.Parent = Screen

	const Renderer: any = Library.new(Target):AddCustomClasses({warn = Warn, icon = Icon, glow = Glow}):SetRendering("Passthrough", false)
	if Setup then Setup(Renderer) end
	Renderer.Label.Text = Text
	Renderer:Flush()

	table.insert(Renderers, Renderer)

	return Renderer, Target
end

const function Loose(): any
	const Renderer: any = Library.new(Instance.new("TextLabel"))
	table.insert(Renderers, Renderer)

	return Renderer
end

const function Marks(Style: any): string
	return (if Style.Bold then "*" else "")
		.. (if Style.Element then "@" else "")
		.. (if Style.Gradient then "~" else "")
		.. (if Style.Effect then `^{Style.Effect.Name}:` else "")
		.. (if Style.Code then "`" else "")
		.. (if Style.Container then `#{Style.Container.Name}:` else "")
end

const function Outline(Object: Instance): string
	const Panel: Instance? = Object:FindFirstChild("Panel")
	if not Panel then return Object.Name end

	const Code: Instance? = (Panel :: Instance):FindFirstChild("Code")
	const Styled: boolean = (Panel :: Frame).BackgroundTransparency < 1
	const Highlighted: boolean = Code ~= nil and (Code :: TextLabel).RichText

	return `{Object.Name}:{if Styled then "panel" else "plain"}{if Highlighted then ":lit" else ""}`
end

const function Snapshot(Renderer: any): string
	const Parts: { string } = {}

	for _, Token: any in Renderer.Document.Tokens do
		const Space: string = if Token.SpaceBefore then " " else ""

		if Token.Kind == "Break" then
			table.insert(Parts, "\n")
		elseif Token.Kind == "Object" then
			table.insert(Parts, `{Space}[{Outline(Token.Object)}]`)
		else
			table.insert(Parts, Space .. Marks(Token.Style) .. Token.Text)
		end
	end

	const Groups: number = #ElementsModule.Query(Renderer, ElementsModule.Selector.Compile("a", 1), false)

	return `{table.concat(Parts)}|links={Groups}`
end

const function Message(Callback: () -> ()): string?
	const Ok: boolean, Problem: any = pcall(Callback)
	if Ok then return nil end

	return tostring(Problem)
end

const function Release(): ()
	for _, Renderer: any in Renderers do pcall(Renderer.Destroy, Renderer) end
	table.clear(Renderers)
	for _, Child: Instance in Screen:GetChildren() do Child:Destroy() end
end

BeforeAll(function()
	Screen = Gui.new("Features")
end)

AfterAll(function()
	Release()
	Gui.Cleanup()
end)

Describe("presets", function()
	AfterAll(Release)

	for _, Preset: string in PresetNames do
		const Values: { [string]: boolean } = Expected[Preset]

		Describe(Preset, function()
			local Renderer: any

			BeforeAll(function()
				Renderer = Mount("x", function(Built: any) Built:SetPreset(Preset) end)
			end)

			It(`{Preset} applies its intents`, function()
				Expect(Renderer:GetIntents()).toBe(Presets[Preset])
			end)

			It(`{Preset} applies its limits`, function()
				Expect(Renderer:GetLimits()).toBe(LimitsModule.Presets[Preset])
			end)

			It(`{Preset} applies its denied handling`, function()
				Expect(Renderer:GetDenied()).toBe(DeniedByPreset[Preset])
			end)

			It(`{Preset} intents are frozen`, function()
				Expect(table.isfrozen(Renderer:GetIntents())).toBe(true)
			end)

			for _, Name: string in Checked do
				It(`{Preset} {Name}`, function()
					Expect(Renderer:GetIntents():Has(Name)).toBe(Values[Name])
				end)
			end
		end)
	end

	Describe("default renderer", function()
		local Default: any

		BeforeAll(function()
			Default = Mount("x")
		end)

		It("intents default to Default", function()
			Expect(Default:GetIntents()).toBe(Presets.Default)
		end)

		It("limits default to Default", function()
			Expect(Default:GetLimits()).toBe(LimitsModule.Presets.Default)
		end)

		It("denied tags strip by default", function()
			Expect(Default:GetDenied()).toBe("Strip")
		end)
	end)
end)

Describe("custom intents", function()
	AfterAll(Release)

	Describe("Trusted without CodeBlocks", function()
		local Renderer: any

		BeforeAll(function()
			Renderer = Mount("x", function(Built: any) Built:SetPreset("Trusted"):SetIntents(Presets.Trusted:Remove("CodeBlocks")) end)
		end)

		It("keeps Trusted limits", function()
			Expect(Renderer:GetLimits()).toBe(LimitsModule.Presets.Trusted)
		end)

		It("drops CodeBlocks", function()
			Expect(Renderer:GetIntents():Has("CodeBlocks")).toBe(false)
		end)

		It("keeps Markdown", function()
			Expect(Renderer:GetIntents():Has("Markdown")).toBe(true)
		end)

		It("leaves the preset untouched", function()
			Expect(Presets.Trusted:Has("CodeBlocks")).toBe(true)
		end)
	end)

	It("SetIntents keeps the limits", function()
		const Renderer: any = Mount("x", function(Built: any) Built:SetPreset("Chat"):SetIntents({"Formatting", "Links"}) end)

		Expect(Renderer:GetLimits()).toBe(LimitsModule.Presets.Chat)
	end)

	It("SetIntents with an equal bitfield keeps the stored object", function()
		const Renderer: any = Mount("x")
		const Before: any = Renderer:GetIntents()
		Renderer:SetIntents(Before.Bitfield)

		Expect(Renderer:GetIntents()).toBe(Before)
	end)

	It("SetIntents stores a frozen copy", function()
		const Mutable: any = Intents.new("Formatting")
		const Renderer: any = Mount("x", function(Built: any) Built:SetIntents(Mutable) end)
		Mutable:Add("Images")

		Expect(Renderer:GetIntents():Has("Images")).toBe(false)
	end)
end)

Describe("switching", function()
	AfterAll(Release)

	local Renderer: any
	local Target: TextLabel

	BeforeAll(function()
		Renderer, Target = Mount([[a <img src="rbxassetid://5"/> b]])
	end)

	It("images start on", function()
		Expect(Renderer:GetIntents():Has("Images")).toBe(true)
	end)

	It("GetIntents is read-only", function()
		Expect(function() Renderer:GetIntents().Bitfield = 0 end).toThrow()
	end)

	It("image renders", function()
		Expect(Snapshot(Renderer)).toBe("a [InlineImage] b|links=0")
	end)

	It("SetPreset returns the renderer", function()
		Expect(Renderer:SetPreset("Chat")).toBe(Renderer)
	end)

	It("Chat switches Images off immediately", function()
		Expect(Renderer:GetIntents():Has("Images")).toBe(false)
	end)

	It("Chat escapes the image", function()
		Expect(Snapshot(Renderer:Flush())).toBe([[a <img src="rbxassetid://5"/> b|links=0]])
	end)

	It("Chat builds no image", function()
		Expect(Target:FindFirstChild("InlineImage")).toBeNil()
	end)

	Describe("Default without Images", function()
		BeforeAll(function()
			Renderer:SetPreset("Default"):SetIntents(Presets.Default:Remove("Images")):Flush()
		end)

		It("reflects", function()
			Expect(Renderer:GetIntents():Has("Images")).toBe(false)
		end)

		It("keeps Links", function()
			Expect(Renderer:GetIntents():Has("Links")).toBe(true)
		end)

		It("drops the image", function()
			Expect(Snapshot(Renderer)).toBe("a b|links=0")
		end)
	end)

	Describe("plain", function()
		BeforeAll(function()
			Renderer:SetPreset("Plain"):Flush()
		end)

		It("Plain grants nothing", function()
			Expect(Renderer:GetIntents().Bitfield).toBe(0)
		end)

		It("Plain renders the source", function()
			Expect(Snapshot(Renderer)).toBe([[a <img src="rbxassetid://5"/> b|links=0]])
		end)
	end)

	Describe("default again", function()
		BeforeAll(function()
			Renderer:SetPreset("Default"):Flush()
		end)

		for _, Name: string in Checked do
			It(`Default switches {Name} back on`, function()
				Expect(Renderer:GetIntents():Has(Name)).toBe(true)
			end)
		end

		It("Default renders the image again", function()
			Expect(Snapshot(Renderer)).toBe("a [InlineImage] b|links=0")
		end)
	end)
end)

Describe("removed names", function()
	AfterAll(Release)

	local Renderer: any

	BeforeAll(function()
		Renderer = Mount("x")
	end)

	const Mentions: { { any } } = {
		{"SetFeature removed", function() Renderer:SetFeature("Images", false) end, "SetIntents"},
		{"SetFeature points to SetRendering", function() Renderer:SetFeature("Culling", false) end, "SetRendering"},
		{"GetFeature removed", function() Renderer:GetFeature("Images") end, "GetIntents():Has"},
		{"SetPermissions removed", function() Renderer:SetPermissions("Chat") end, "SetPreset"},
		{"SetPermissions points to SetIntents", function() Renderer:SetPermissions("Chat") end, "SetIntents"},
		{"GetPermissions removed", function() Renderer:GetPermissions() end, "GetIntents"},
		{"Permissions removed", function() return Library.Permissions end, "RichTextPlus.Intents"},
		{"Options table removed", function() Library.new(Instance.new("TextLabel"), {Features = {Images = false}}) end, "chained setters"},
		{"Full preset", function() Renderer:SetPreset("Full") end, "Default"},
		{"unknown flag", function() Renderer:SetIntents("Videos") end, "Videos"},
		{"old limit names", function() Renderer:SetLimits({MaxObjects = 1}) end, "Objects"},
		{"bad denied mode", function() Renderer:SetDenied("Hide") end, "Escape"},
	}

	for _, Row: { any } in Mentions do
		It(Row[1], function()
			Expect(Row[2]).toThrow()
		end)

		It(`{Row[1]} mentions {Row[3]}`, function()
			Expect((string.find(Message(Row[2]) or "", Row[3], 1, true))).never.toBeNil()
		end)
	end

	It("Full is not a preset", function()
		Expect(Presets.Full).toBeNil()
	end)

	It("preset names stay case-insensitive", function()
		Expect(Renderer:SetPreset("chat"):GetIntents()).toBe(Presets.Chat)
	end)
end)

Describe("rendering", function()
	AfterAll(Release)

	Describe("defaults", function()
		local Plain: any

		BeforeAll(function()
			Plain = Loose():Flush()
		end)

		for _, Name: string in RenderingNames do
			It(`{Name} defaults on`, function()
				Expect(Plain:GetRendering(Name)).toBe(true)
			end)
		end

		It("renderer.Rendering is read-only", function()
			Expect(function() Plain.Rendering.Culling = false end).toThrow()
		end)
	end)

	Describe("switches", function()
		local Renderer: any

		BeforeAll(function()
			Renderer = Mount("x", function(Built: any) Built:SetRendering("Culling", false) end)
		end)

		It("Options.Rendering switches off", function()
			Expect(Renderer:GetRendering("Culling")).toBe(false)
		end)

		It("Options.Rendering keeps the others", function()
			Expect(Renderer:GetRendering("Clipping")).toBe(true)
		end)

		It("SetRendering returns the renderer", function()
			Expect(Renderer:SetRendering("Culling", true)).toBe(Renderer)
		end)

		It("SetRendering switches on", function()
			Expect(Renderer:GetRendering("Culling")).toBe(true)
		end)

		It("SetRendering switches off", function()
			Renderer:SetRendering("Clipping", false):Flush()

			Expect(Renderer:GetRendering("Clipping")).toBe(false)
		end)

		It("SetRendering keeps renderer.Rendering frozen", function()
			Expect(table.isfrozen(Renderer.Rendering)).toBe(true)
		end)

		It("SetRendering unknown", function()
			Expect(function() Renderer:SetRendering("Nope", true) end).toThrow()
		end)

		It("SetRendering unknown mentions Nope", function()
			Expect((string.find(Message(function() Renderer:SetRendering("Nope", true) end) or "", "Nope", 1, true))).never.toBeNil()
		end)

		It("SetRendering of a feature", function()
			Expect(function() Renderer:SetRendering("Images", false) end).toThrow()
		end)

		It("SetRendering needs a boolean", function()
			Expect(function() Renderer:SetRendering("Culling", "off") end).toThrow()
		end)

		It("GetRendering unknown", function()
			Expect(function() Renderer:GetRendering("Nope") end).toThrow()
		end)

		It("GetRendering of a feature", function()
			Expect(function() Renderer:GetRendering("Markdown") end).toThrow()
		end)

		It("unknown rendering switch", function()
			Expect(function() Loose():SetRendering("Typewriter", false):Flush() end).toThrow()
		end)
	end)

	Describe("passthrough", function()
		local Passing: any

		BeforeAll(function()
			Passing = Mount("just plain words", function(Built: any) Built:SetRendering("Passthrough", true) end)
		end)

		It("Passthrough on hands plain text to the engine", function()
			Expect(Passing.Native.Active).toBeTruthy()
		end)

		It("Passthrough off renders segments", function()
			Passing:SetRendering("Passthrough", false):Flush()

			Expect(Passing.Native.Active).toBeFalsy()
		end)
	end)

	Describe("syntax highlight", function()
		local Code: any
		local CodeLabel: TextLabel

		BeforeAll(function()
			Code, CodeLabel = Mount([[<codeblock lang="lua">local x = 1</codeblock>]])
		end)

		It("SyntaxHighlight on", function()
			Expect(Outline(CodeLabel:FindFirstChild("CodeBlock") :: Instance)).toBe("CodeBlock:panel:lit")
		end)

		It("SyntaxHighlight off", function()
			Code:SetRendering("SyntaxHighlight", false):Flush()

			Expect(Outline(CodeLabel:FindFirstChild("CodeBlock") :: Instance)).toBe("CodeBlock:panel")
		end)
	end)

	It("Culling off keeps no clip chain", function()
		const Culled: any = Mount("culled", function(Built: any) Built:SetRendering("Culling", false) end)
		Driver.Tick(Culled, 0.016)

		Expect(#Culled.Cull.Clippers).toBe(0)
	end)
end)

Describe("tag owners", function()
	const Tags: { [string]: string } = Intents.Tags

	It("Tags frozen", function()
		Expect(table.isfrozen(Tags)).toBe(true)
	end)

	It("Flags frozen", function()
		Expect(table.isfrozen(Intents.Flags)).toBe(true)
	end)

	const Sorted: { string } = {}
	for Tag: string in Tags do table.insert(Sorted, Tag) end
	table.sort(Sorted)

	for _, Tag: string in Sorted do
		const Owner: string = Tags[Tag]

		It(`{Tag} is lowercase`, function()
			Expect(Tag).toBe(string.lower(Tag))
		end)

		It(`{Tag} owner {Owner} is a flag`, function()
			Expect(Intents.Flags[Owner]).never.toBeNil()
		end)
	end

	It("wave owned by Effects", function()
		Expect(Tags.wave).toBe("Effects")
	end)

	It("md owned by Markdown", function()
		Expect(Tags.md).toBe("Markdown")
	end)

	It("b owned by Formatting", function()
		Expect(Tags.b).toBe("Formatting")
	end)

	It("every flag but Controls owns a tag", function()
		const Owned: { [string]: boolean } = {}
		for _, Owner: string in Tags do Owned[Owner] = true end
		Owned.Color = true

		for Name: string in Intents.Flags do
			if Name ~= "Controls" then Expect(Owned[Name]).toBe(true) end
		end
	end)
end)

Describe("equivalence with the old feature switches", function()
	AfterAll(Release)

	for _, Case: Case in Cases do
		Describe(Case.Flag, function()
			local Off: any
			local On: any

			BeforeAll(function()
				Off = Mount(Case.Markup, function(Built: any) Built:SetIntents(Presets.Default:Remove(Case.Flag)) end)
				On = Mount(Case.Markup)
			end)

			It(`{Case.Flag} off renders like the old switch`, function()
				Expect(Snapshot(Off)).toBe(Case.Expected)
			end)

			It(`{Case.Flag} on renders differently`, function()
				Expect(Snapshot(On)).never.toBe(Case.Expected)
			end)

			It(`{Case.Flag} off under Trusted with Strip`, function()
				const Trusted: any = Mount(Case.Markup, function(Built: any)
					Built:SetPreset("Trusted"):SetIntents(Presets.Trusted:Remove(Case.Flag)):SetDenied("Strip")
				end)

				Expect(Snapshot(Trusted)).toBe(Case.Expected)
			end)
		end)
	end

	Describe("rich text", function()
		local Literal: any

		BeforeAll(function()
			Literal = Mount(RichTextMarkup, function(Built: any) Built:SetIntents({}):SetDenied("Escape") end)
		end)

		It("no intents with Escape renders the source like the old switch", function()
			Expect(Snapshot(Literal)).toBe(RichTextExpected)
		end)

		It("no intents keeps no ledger", function()
			Expect(Literal.Document.Ledger).toBeNil()
		end)

		It("Plain renders like the old RichText switch", function()
			Expect(Snapshot(Mount(RichTextMarkup, function(Built: any) Built:SetPreset("Plain") end))).toBe(RichTextExpected)
		end)

		It("no intents with Strip removes every tag", function()
			Expect(Snapshot(Mount(RichTextMarkup, function(Built: any) Built:SetIntents({}) end))).toBe("x\nline2 & y|links=0")
		end)

		It("rich text on parses", function()
			Expect(Snapshot(Mount(RichTextMarkup))).never.toBe(RichTextExpected)
		end)
	end)

	It("a denied tag stays escaped under Chat", function()
		Expect(Snapshot(Mount([[<img src="1"/>x]], function(Built: any) Built:SetPreset("Chat") end))).toBe([[<img src="1"/>x|links=0]])
	end)

	It("a denied tag strips in Strip mode, a link keeping its href", function()
		Expect(Snapshot(Mount([[<img src="1"/>x <a href="u"/>]], function(Built: any) Built:SetPreset("Chat"):SetDenied("Strip") end))).toBe("x u|links=0")
	end)

	It("Chat keeps only the color of a font tag", function()
		const Renderer: any = Mount([[<font color="#ff0000" size="40">x</font>]], function(Built: any) Built:SetPreset("Chat") end)
		const Token: any = Renderer.Document.Tokens[1]

		Expect(Token.Style.Color).toEqual(Color3.fromRGB(255, 0, 0))
		Expect(Token.Style.Size).never.toBe(40)
	end)

	It("Font without Color keeps the size but not the color", function()
		const Renderer: any = Mount([[<font color="#ff0000" size="40">x</font>]], function(Built: any) Built:SetIntents({"Font"}) end)
		const Token: any = Renderer.Document.Tokens[1]

		Expect(Token.Style.Color).never.toEqual(Color3.fromRGB(255, 0, 0))
		Expect(Token.Style.Size).toBe(40)
	end)
end)
