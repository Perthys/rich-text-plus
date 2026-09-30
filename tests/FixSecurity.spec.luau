--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const XMLModule = require("../Packages/XML")
const TroveModule = require("../Packages/Trove")
const ElementsModule = require("../Packages/RichTextPlus/Elements")
const FlattenModule = require("../Packages/RichTextPlus/Core/Flatten")
const StylesModule = require("../Packages/RichTextPlus/Utility/Styles")
const IntentsModule = require("../Packages/RichTextPlus/Policy/Intents")
const LimitsModule = require("../Packages/RichTextPlus/Policy/Limits")
const PresetsModule = require("../Packages/RichTextPlus/Policy/Presets")
const AssetsModule = require("../Packages/RichTextPlus/Policy/Assets")
const RenderingModule = require("../Packages/RichTextPlus/Policy/Rendering")
const MarkdownModule = require("../Packages/RichTextPlus/Markdown")
const MeasureModule = require("../Packages/RichTextPlus/Text/Measure")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const AfterAll = JestGlobals.afterAll

const Library: any = RichTextPlus
const XML: any = XMLModule
const Trove: any = TroveModule
const Flatten: any = FlattenModule
const Styles: any = StylesModule
const Intents: any = IntentsModule
const Limits: any = LimitsModule
const Assets: any = AssetsModule
const Rendering: any = RenderingModule
const Markdown: any = MarkdownModule
const Measure: any = MeasureModule

const Override: string = "\u{202E}"
const Isolate: string = "\u{2066}"
const Presets: any = Intents.Presets
const Base: string = Font.fromEnum(Enum.Font.SourceSans).Family

const Cleanup: { () -> () } = {}

const API: any = setmetatable({
	new = function(Target: TextLabel): any
		return Library.new(Target):SetRendering("Passthrough", false):Flush()
	end;
}, {__index = Library})

const function MakeState(Setup: any?, Markup: string?): any
	const Config: any = Setup or {}
	const Bundle: any = PresetsModule.Resolve(Config.Preset or "Default", 1)

	const Label: TextLabel = Instance.new("TextLabel")
	Label.TextSize = 20
	Label.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.Text = Config.Text or Markup or ""

	const MainTrove: any = Trove.new()

	const State: any = {
		Label = Label;
		Options = {Scale = 1};
		Rendering = Rendering.Defaults;
		Intents = if Config.Intents ~= nil then Intents.Frozen(Intents.Resolve(Config.Intents)) else Bundle.Intents;
		Limits = if Config.Limits ~= nil then Limits.Resolve(Config.Limits, 1) else Bundle.Limits;
		Denied = Config.Denied or Bundle.Denied;
		Assets = Assets.Resolve(Config.Assets, 1);
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

	table.insert(Cleanup, function()
		MainTrove:Clean()
		Label:Destroy()
	end)

	return State
end

const function Run(Text: string, Setup: any?): any
	const State: any = MakeState(Setup, Text)
	Flatten.Run(State, XML.GenerateTreeFromXML(Text))

	return State
end

const function Render(State: any): string
	const Parts: { string } = {}

	for _, Token: any in State.Document.Tokens do
		const Space: string = if Token.SpaceBefore then " " else ""

		if Token.Kind == "Break" then
			table.insert(Parts, "\n")
		elseif Token.Kind == "Object" then
			table.insert(Parts, `{Space}[{Token.Object.Name}]`)
		else
			table.insert(Parts, Space .. Token.Text)
		end
	end

	return table.concat(Parts)
end

const function Word(State: any, Text: string): any
	for _, Token: any in State.Document.Tokens do
		if Token.Kind == "Word" and Token.Text == Text then return Token.Style end
	end

	return nil
end

const function Objects(State: any): { any }
	const Found: { any } = {}
	for _, Token: any in State.Document.Tokens do
		if Token.Kind == "Object" then table.insert(Found, Token) end
	end

	return Found
end

const function Clean(State: any): boolean
	for _, Token: any in State.Document.Tokens do
		const Text: string? = Token.Text
		if Text and (string.find(Text :: string, Override, 1, true) or string.find(Text :: string, "%c")) then return false end
	end

	return true
end

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 200)
	Created.TextSize = 20
	Created.TextWrapped = true
	Created.Text = Text

	table.insert(Cleanup, function() Created:Destroy() end)

	return Created
end

const function Keep(Renderer: any): any
	table.insert(Cleanup, function() Renderer:Destroy() end)

	return Renderer
end

AfterAll(function()
	for Index = #Cleanup, 1, -1 do pcall(Cleanup[Index]) end
	Gui.Cleanup()
end)

Describe("safe entity decoder", function()
	It("huge decimal entity stays literal", function()
		Expect(Styles.Unescape("&#99999999999999999999;")).toBe("&#99999999999999999999;")
	end)

	It("above max code point stays literal", function()
		Expect(Styles.Unescape("&#x110000;")).toBe("&#x110000;")
	end)

	It("surrogate stays literal", function()
		Expect(Styles.Unescape("&#xD800;")).toBe("&#xD800;")
	end)

	It("zero stays literal", function()
		Expect(Styles.Unescape("&#0;")).toBe("&#0;")
	end)

	It("valid numeric decodes", function()
		Expect(Styles.Unescape("&#65;&#x42;")).toBe("AB")
	end)

	It("XML.Unescape is the same decoder", function()
		Expect(XML.Unescape("&#99999999999999999999;")).toBe(Styles.Unescape("&#99999999999999999999;"))
	end)

	const Hostile: string = '<font color="&#x110000;">a &#99999999999999999999; b</font> <a href="&#xFFFFFFFFF;">l</a>'

	It("huge entities do not crash Flatten", function()
		Expect(function() Run(Hostile) end).never.toThrow()
	end)

	It("huge entity renders literally", function()
		const Ok: boolean, State: any = pcall(Run, Hostile)
		Expect(Ok and Render(State)).toBe("a &#99999999999999999999; b l")
	end)

	local Renderer: any

	It("huge entity does not crash new", function()
		Expect(function() Renderer = Keep(API.new(Label("x &#99999999999999999999;"))) end).never.toThrow()
	end)

	It("huge entity does not crash an incremental edit", function()
		Expect(function() Renderer.Label.Text = "y &#x7FFFFFFFFFFF; z"; Renderer:Flush() end).never.toThrow()
	end)

	It("incremental edit keeps literal", function()
		Expect(Render(Renderer)).toBe("y &#x7FFFFFFFFFFF; z")
	end)
end)

Describe("control and bidi stripping", function()
	It("Sanitize strips C0, DEL, overrides and isolates", function()
		Expect(Styles.Sanitize(`a\0b\1c\27d\127e\u{202A}f{Override}g{Isolate}h\u{2069}i`)).toBe("abcdefghi")
	end)

	It("Sanitize keeps tab and newline", function()
		Expect(Styles.Sanitize("a\tb\nc")).toBe("a\tb\nc")
	end)

	It("Sanitize keeps ellipsis and neighbours", function()
		Expect(Styles.Sanitize("a\u{2026}b\u{2029}c\u{206A}d\u{200F}")).toBe("a\u{2026}b\u{2029}c\u{206A}d\u{200F}")
	end)

	It("Chat preset strips", function()
		Expect(Presets.Chat:Has("Controls")).toBe(false)
	end)

	It("Plain preset strips", function()
		Expect(Presets.Plain:Has("Controls")).toBe(false)
	end)

	It("Default preset keeps", function()
		Expect(Presets.Default:Has("Controls")).toBe(true)
	end)

	It("Trusted preset keeps", function()
		Expect(Presets.Trusted:Has("Controls")).toBe(true)
	end)

	const Cases: { { any } } = {
		{"Chat strips entity override", "a&#8238;b", {Preset = "Chat"}, "ab"},
		{"Chat strips raw override and isolates", `a{Override}b{Isolate}c\u{2069}d`, {Preset = "Chat"}, "abcd"},
		{"Chat strips entity and raw C0", "a&#1;b\7c&#x1B;d", {Preset = "Chat"}, "abcd"},
		{"Chat keeps tab and newline", "a\tb\nc", {Preset = "Chat"}, "a b\nc"},
		{"Chat keeps ellipsis", "wait\u{2026}", {Preset = "Chat"}, "wait\u{2026}"},
		{"Chat strips inside allowed tags", "<b>x&#8238;y</b>", {Preset = "Chat"}, "xy"},
		{"Plain shows entities without decoding them", "<b>x&#8238;y</b>", {Preset = "Plain"}, "<b>x&#8238;y</b>"},
		{"Plain strips raw overrides while showing markup", `<b>x{Override}y\1</b>`, {Preset = "Plain"}, "<b>xy</b>"},
		{"Chat strips rejected tag markup", `<img src="{Override}"/>`, {Preset = "Chat"}, '<img src=""/>'},
		{"Default keeps override", "a&#8238;b", nil, `a{Override}b`},
		{"Trusted keeps override", "a&#8238;b", {Preset = "Trusted"}, `a{Override}b`},
		{"removing Controls enables stripping", "a&#8238;b", {Intents = Presets.Default:Remove("Controls")}, "ab"},
		{"adding Controls turns stripping off", "a&#8238;b", {Preset = "Chat", Intents = Presets.Chat:Add("Controls")}, `a{Override}b`},
		{"RichText off still strips", "", {Preset = "Plain", Text = "a&#8238;b\1c"}, "a&#8238;bc"},
	}

	for _, Case: { any } in Cases do
		It(Case[1], function()
			Expect(Render(Run(Case[2], Case[3]))).toBe(Case[4])
		end)
	end

	const Edits: { string } = {
		`hello <b>wor{Override}ld</b> foo`,
		`hello <b>wor{Override}ld</b> fo&#8238;o bar`,
		"hello <b>world</b> foo bar",
		"hello <b>world</b> foo bars",
		"x\1y <b>world</b> foo bars",
		"x\1y <b>world</b> foo barz",
	}

	local Renderer: any

	for Index: number, Text: string in Edits do
		It(`incremental Chat edit {Index} matches full parse`, function()
			if not Renderer then Renderer = Keep(API.new(Label("hello <b>world</b> foo")):SetPreset("Chat"):Flush()) end

			Renderer.Label.Text = Text
			Renderer:Flush()
			Expect(Render(Renderer)).toBe(Render(Run(Text, {Preset = "Chat"})))
		end)

		It(`incremental Chat edit {Index} stripped`, function()
			Expect(Clean(Renderer)).toBe(true)
		end)
	end

	local Native: TextLabel
	local Passthrough: any

	It("native passthrough label text stripped", function()
		Native = Label(`hi&#8238;there {Override}x`)
		Passthrough = Keep(Library.new(Native):SetPreset("Chat"):Flush())
		Expect(Native.Text).never.toContain(Override)
	end)

	It("native passthrough tokens stripped", function()
		Expect(Clean(Passthrough)).toBe(true)
	end)
end)

Describe("canonical asset ids", function()
	const Canonical: any = Library.Utilities.CanonicalId

	It("Utilities and Styles share CanonicalId", function()
		Expect(Canonical).toBe(Styles.CanonicalId)
	end)

	const Cases: { { any } } = {
		{"digits", "123", "rbxassetid://123"},
		{"scheme case and padding", "  RBXASSETID://0042 ", "rbxassetid://42"},
		{"asset url", "http://www.roblox.com/asset/?id=5", "rbxassetid://5"},
		{"asset url without slash or www", "HTTPS://roblox.com/asset?id=5", "rbxassetid://5"},
		{"rejects unanchored id query", "evil?id=5", nil},
		{"rejects foreign host", "https://evil.example/asset/?id=5", nil},
		{"rejects trailing junk", "rbxassetid://5?x=1", nil},
		{"rejects two ids", "rbxassetid://5 rbxassetid://6", nil},
		{"rejects id zero", "000", nil},
		{"rejects overlong id", string.rep("9", 25), nil},
		{"rejects empty", "", nil},
		{"engine path", "rbxasset://textures/face.png", "rbxasset://textures/face.png"},
		{"rejects engine traversal", "rbxasset://textures/../../x.png", nil},
		{"thumbnail", "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150"},
		{"thumbnail filter", "rbxthumb://type=Avatar&id=1&w=48&h=48&filters=circular", "rbxthumb://type=Avatar&id=1&w=48&h=48&filters=circular"},
		{"rejects thumbnail extras", "rbxthumb://type=Avatar&id=1&w=48&h=48&x=1", nil},
	}

	for _, Case: { any } in Cases do
		It(Case[1], function()
			Expect(Canonical(Case[2])).toBe(Case[3])
		end)
	end

	const Allow: any = {Assets = {["rbxassetid://111"] = true, ["0222"] = true, ["garbage?id=333"] = true}}
	const Filter: any = Assets.Resolve(Allow.Assets, 1)

	It("allowlist keys canonical", function()
		Expect(Assets.Allows(Filter, "222")).toBe(true)
	end)

	It("allowlist drops non-canonical keys", function()
		Expect(Assets.Allows(Filter, "333")).toBe(false)
	end)

	It("a filter function sees the canonical id", function()
		local Seen: string? = nil
		Assets.Allows(function(Id: string): boolean Seen = Id; return true end, "http://www.roblox.com/asset/?id=42")

		Expect(Seen).toBe("rbxassetid://42")
	end)

	It("a filter never sees a rejected id", function()
		local Called: boolean = false

		Expect(Assets.Allows(function(): boolean Called = true; return true end, "https://evil.example/a.png")).toBe(false)
		Expect(Called).toBe(false)
	end)

	It("allowlist bypass closed", function()
		Expect(#Objects(Run('<img src="evil?id=111"/>', Allow))).toBe(0)
	end)

	It("allowlist bypass closed with host", function()
		Expect(#Objects(Run('<img src="https://evil.example/asset/?id=111"/>', Allow))).toBe(0)
	end)

	const function Listed(): { any }
		return Objects(Run('<img src="http://www.roblox.com/asset/?id=111"/><img src="222"/>', Allow))
	end

	It("allowlisted objects built", function()
		Expect(#Listed()).toBe(2)
	end)

	It("image loads canonical id, not raw source", function()
		const Found: { any } = Listed()
		Expect(Found[1] and Found[1].Object.Image).toBe("rbxassetid://111")
	end)

	It("zero-padded key matches", function()
		const Found: { any } = Listed()
		Expect(Found[2] and Found[2].Object.Image).toBe("rbxassetid://222")
	end)

	It("non-canonical source rejected under Default", function()
		Expect(#Objects(Run('<img src="https://evil.example/x.png"/><img src="javascript:1"/>'))).toBe(0)
	end)

	It("padded digits accepted under Default", function()
		Expect(Objects(Run('<img src=" 123 "/>'))[1].Object.Image).toBe("rbxassetid://123")
	end)

	It("thumbnail accepted under Default", function()
		Expect(Objects(Run('<img src="rbxthumb://type=Avatar&amp;id=1&amp;w=48&amp;h=48"/>'))[1].Object.Image).toBe("rbxthumb://type=Avatar&id=1&w=48&h=48")
	end)

	It("markdown image goes through CanonicalId", function()
		Expect(#Objects(Run("<md>![x](https://evil.example/a.png) ![y](rbxassetid://111)</md>", Allow))).toBe(1)
	end)
end)

Describe("font faces", function()
	const Allow: any = {Assets = {["rbxassetid://111"] = true}}
	const Markup: string = '<font face="rbxassetid://222">a</font> <font face="rbxassetid://111">b</font> <font face="Arial">c</font> <font face="https://evil.example/f.json">d</font> <font face="rbxasset://fonts/../x.json">e</font> <font face="Foo/../x">f</font> <font face="rbxasset://textures/x.png">g</font> <font face="rbxasset://fonts/families/Arial.json">h</font>'

	const Faces: { { string } } = {
		{"face asset outside allowlist ignored", "a", Base},
		{"face asset in allowlist applied", "b", "rbxassetid://111"},
		{"face enum name ignores allowlist", "c", Font.fromEnum(Enum.Font.Arial).Family},
		{"face url rejected", "d", Base},
		{"face traversal rejected", "e", Base},
		{"face family name with path rejected", "f", Base},
		{"face non-font engine path rejected", "g", Base},
		{"face engine font path accepted", "h", "rbxasset://fonts/families/Arial.json"},
	}

	for _, Case: { string } in Faces do
		It(Case[1], function()
			Expect(Word(Run(Markup, Allow), Case[2]).Family).toBe(Case[3])
		end)
	end

	It("face digits without allowlist", function()
		Expect(Word(Run('<font face="12345">x</font>'), "x").Family).toBe("rbxassetid://12345")
	end)

	It("ResolveFace rejects junk", function()
		Expect(Styles.ResolveFace("https://evil.example/f.json")).toBeNil()
	end)

	It("ResolveFamily keeps developer input", function()
		Expect(Styles.ResolveFamily("https://evil.example/f.json")).toBe("https://evil.example/f.json")
	end)

	It("class tag face is not applied", function()
		Expect(Word(Run('<customclass><class name="w" face="rbxassetid://111"/><w>x</w></customclass>', Allow), "x").Family).toBe(Base)
	end)

	const Styled: { any } = {}
	for Index = 1, 150 do
		table.insert(Styled, {Bold = false, Italic = false, Underline = false, Strike = false, Color = Color3.new(1, 1, 1), Size = 20, Family = `rbxasset://fonts/families/SecuritySpam{Index}.json`, Weight = Enum.FontWeight.Regular, Transparency = 0})
	end

	It("Measure faces keep resolving past the family cap", function()
		local Matches: number = 0
		for _, Style: any in Styled do
			if Measure.FontOf(Style).Family == Style.Family then Matches += 1 end
		end

		Expect(Matches).toBe(#Styled)
	end)

	It("early style re-resolves after the cap resets", function()
		Expect(Measure.FontOf(Styled[1]).Family).toBe(Styled[1].Family)
	end)
end)

Describe("class tag", function()
	const Markup: string = '<customclass><class name="w" bold="true" color="#ff0000"/><w>x</w></customclass>'
	const Escaped: string = '<class name="w" bold="true" color="#ff0000"/><w>x</w>'

	It("Default declares nothing", function()
		Expect(Word(Run(Markup), "x").Bold).toBe(false)
	end)

	It("Default applies no declared color", function()
		Expect(Word(Run(Markup), "x").Color).toBe(Color3.new(1, 1, 1))
	end)

	It("Trusted does not list class", function()
		Expect(Presets.Trusted:Allows("class")).toBe(false)
	end)

	It("Chat does not list class", function()
		Expect(Presets.Chat:Allows("class")).toBe(false)
	end)

	It("Trusted escapes class like any unlisted tag", function()
		Expect(Render(Run(Markup, {Preset = "Trusted"}))).toBe(Escaped)
	end)

	It("Trusted class tag no style", function()
		Expect(Word(Run(Markup, {Preset = "Trusted"}), "x").Bold).toBe(false)
	end)

	It("Strip mode drops class tag", function()
		Expect(Render(Run(Markup, {Preset = "Trusted", Denied = "Strip"}))).toBe("x")
	end)

	It("Strip mode class tag no style", function()
		Expect(Word(Run(Markup, {Preset = "Trusted", Denied = "Strip"}), "x").Bold).toBe(false)
	end)

	It("Plain with regions escapes class", function()
		Expect(Render(Run(Markup, {Preset = "Plain", Intents = {"CustomClasses"}}))).toBe(Escaped)
	end)

	It("shorthand naming class is inert", function()
		Expect(Word(Run('<customclass name="class" bold="true">x</customclass>'), "x").Bold).toBe(false)
	end)
end)

Describe("preset caps and escape helper", function()
	const Capped: any = Limits.Presets

	It("Default stays unlimited nodes", function()
		Expect(Capped.Default.Nodes).toBeNil()
	end)

	It("Default stays unlimited text", function()
		Expect(Capped.Default.Characters).toBeNil()
	end)

	It("Chat finite nodes", function()
		Expect(Capped.Chat.Nodes and Capped.Chat.Nodes < math.huge).toBe(true)
	end)

	It("Chat finite text", function()
		Expect(Capped.Chat.Characters and Capped.Chat.Characters < math.huge).toBe(true)
	end)

	It("Chat no objects", function()
		Expect(Capped.Chat.Objects).toBe(0)
	end)

	It("Trusted finite nodes", function()
		Expect(Capped.Trusted.Nodes and Capped.Trusted.Nodes < math.huge).toBe(true)
	end)

	It("Trusted finite objects", function()
		Expect(Capped.Trusted.Objects and Capped.Trusted.Objects < math.huge).toBe(true)
	end)

	It("Trusted finite text", function()
		Expect(Capped.Trusted.Characters and Capped.Trusted.Characters < math.huge).toBe(true)
	end)

	It("Chat truncates long text", function()
		Expect(#Render(Run(string.rep("a", 5000), {Preset = "Chat"}))).toBe(Capped.Chat.Characters)
	end)

	It("Trusted caps objects", function()
		const Images: { string } = {}
		for Index = 1, Capped.Trusted.Objects + 6 do table.insert(Images, `<img src="{Index}"/>`) end

		Expect(#Objects(Run(table.concat(Images), {Preset = "Trusted"}))).toBe(Capped.Trusted.Objects)
	end)

	It("Escape exported", function()
		Expect(type(Library.Utilities.Escape)).toBe("function")
	end)

	It("Escape only under Utilities", function()
		Expect(rawget(Library, "Escape")).toBeNil()
	end)

	It("Attribute only under Utilities", function()
		Expect(rawget(Library, "Attribute") == nil and type(Library.Utilities.Attribute) == "function").toBe(true)
	end)

	It("Utilities frozen", function()
		Expect(table.isfrozen(Library.Utilities)).toBe(true)
	end)

	It("Escape escapes markup", function()
		Expect(Library.Utilities.Escape([[<b a="1">&'</b>]])).toBe("&lt;b a=&quot;1&quot;&gt;&amp;&apos;&lt;/b&gt;")
	end)

	const Hostile: string = "<font color='red'>hi</font> &amp; &#8238;"
	local Renderer: any

	It("escaped text renders literally", function()
		Renderer = Keep(API.new(Label(`<b>{Library.Utilities.Escape(Hostile)}</b>`)):SetPreset("Chat"):Flush())
		Expect(Render(Renderer)).toBe(Hostile)
	end)

	It("escaped text keeps outer styling", function()
		Expect(Word(Renderer, "<font") and Word(Renderer, "<font").Bold).toBe(true)
	end)
end)

Describe("limit normalization", function()
	const Odd: any = Limits.Resolve({TextSize = {Min = 50, Max = 20}, Characters = 5.5, Nodes = -3, Depth = 2.7, Objects = 0 / 0}, 1)
	const Wide: any = Limits.Resolve({TextSize = {Min = 0, Max = 500}, Characters = math.huge, Nodes = "10"}, 1)

	const Cases: { { any } } = {
		{"Min capped at Max", Odd.TextSize.Min, 20},
		{"Max kept", Odd.TextSize.Max, 20},
		{"fractional Characters floored", Odd.Characters, 5},
		{"negative Nodes floored at zero", Odd.Nodes, 0},
		{"fractional Depth floored", Odd.Depth, 2},
		{"NaN limit dropped", Odd.Objects, nil},
		{"Min floor", Wide.TextSize.Min, 1},
		{"Max ceiling", Wide.TextSize.Max, Styles.MaximumTextSize},
		{"infinite limit dropped", Wide.Characters, nil},
		{"non-number limit dropped", Wide.Nodes, nil},
	}

	for _, Case: { any } in Cases do
		It(Case[1], function()
			Expect(Case[2]).toBe(Case[3])
		end)
	end

	It("normalized limits are frozen", function()
		Expect(table.isfrozen(Odd) and table.isfrozen(Odd.TextSize)).toBe(true)
	end)

	It("preset names are case-insensitive", function()
		Expect(Limits.Resolve("chat", 1)).toBe(Limits.Presets.Chat)
	end)

	It("unknown fields are rejected", function()
		Expect(function() Limits.Resolve({MaxTextLength = 5}, 1) end).toThrow()
	end)

	const Inverted: any = {TextSize = {Min = 50, Max = 20}, Characters = 5.5}
	const Source: string = '<font size="30">hello</font> world'

	It("inverted size range does not crash", function()
		Expect(function() Run(Source, {Limits = Inverted}) end).never.toThrow()
	end)

	It("fractional Characters truncates", function()
		const Ok: boolean, State: any = pcall(Run, Source, {Limits = Inverted})
		Expect(Ok and Render(State)).toBe("hello")
	end)

	It("size clamped to normalized range", function()
		const Ok: boolean, State: any = pcall(Run, Source, {Limits = Inverted})
		Expect(Ok and Word(State, "hello").Size).toBe(20)
	end)

	It("Min above the ceiling does not crash", function()
		Expect(function() Run('<font size="9">x</font>', {Preset = "Trusted", Limits = {TextSize = {Min = 200, Max = 96}}}) end).never.toThrow()
	end)
end)

Describe("linear trims", function()
	It("Trim both sides", function()
		Expect(Styles.Trim(" \t a b \n")).toBe("a b")
	end)

	It("Trim blank", function()
		Expect(Styles.Trim("   ")).toBe("")
	end)

	It("Trim empty", function()
		Expect(Styles.Trim("")).toBe("")
	end)

	It("Trim untouched", function()
		Expect(Styles.Trim("ab")).toBe("ab")
	end)

	It("TrimEnd", function()
		Expect(Styles.TrimEnd("a b \t\n ")).toBe("a b")
	end)

	It("TrimEnd keeps leading", function()
		Expect(Styles.TrimEnd("  a")).toBe("  a")
	end)

	const Gap: string = "a" .. string.rep(" ", 20000) .. "b"
	const Runs: { { any } } = {
		{"Trim interior run", function() Styles.Trim(Gap) end},
		{"TrimEnd interior run", function() Styles.TrimEnd(Gap) end},
		{"ParseColor interior run", function() Styles.ParseColor(Gap .. "c") end},
		{"Truthy interior run", function() Styles.Truthy(Gap .. "d", true) end},
		{"markdown paragraph interior run", function() Markdown.ToMarkup(Gap) end},
		{"markdown heading interior run", function() Markdown.ToMarkup("# " .. Gap .. " #x") end},
		{"markdown heading hash run", function() Markdown.ToMarkup("# a" .. string.rep("#", 20000) .. "b") end},
		{"markdown fence interior run", function() Markdown.ToMarkup("```" .. string.rep(" ", 20000) .. "`") end},
		{"markdown fence info run", function() Markdown.ToMarkup("```a" .. string.rep(" ", 20000) .. "`b") end},
		{"indent size interior run", function() Run(`<indent by="1{string.rep(" ", 20000)}a{string.rep(" ", 20000)}!">x</indent>`) end},
		{"xml close tag interior run", function() XML.GenerateTreeFromXML(`<b>x</b{string.rep(" ", 20000)}>`) end},
	}

	for _, Case: { any } in Runs do
		It(`{Case[1]} runs`, function()
			Expect(Case[2]).never.toThrow()
		end)
	end

	It("indent em size", function()
		Expect(Word(Run('<indent by="2em">x</indent>'), "x").Indent.Size).toBe(40)
	end)

	It("indent padded px size", function()
		Expect(Word(Run('<indent by=" 12 PX ">x</indent>'), "x").Indent.Size).toBe(12)
	end)

	It("indent junk size", function()
		Expect(Word(Run('<indent by="1 a !">x</indent>'), "x").Indent.Size).toBeNil()
	end)

	It("heading closing hashes stripped", function()
		Expect(Markdown.ToMarkup("# Title ##")).toBe('<b><font size="28">Title</font></b>')
	end)

	It("heading glued hash kept", function()
		Expect(Markdown.ToMarkup("# Title#")).toBe('<b><font size="28">Title#</font></b>')
	end)

	It("heading only hashes", function()
		Expect(Markdown.ToMarkup("# ###")).toBe('<b><font size="28"></font></b>')
	end)

	It("fence with info", function()
		Expect(Markdown.ToMarkup("```lua extra\nx\n```")).toBe('<codeblock lang="lua">x</codeblock>')
	end)

	It("backtick in info is not a fence", function()
		Expect(Markdown.ToMarkup("``` a`b\nx")).never.toContain("codeblock")
	end)

	It("tilde fence", function()
		Expect(Markdown.ToMarkup("~~~ a`b\nx\n~~~")).toBe('<codeblock lang="a`b">x</codeblock>')
	end)
end)

Describe("markdown entities and breakout", function()
	It("md decodes entities in text", function()
		Expect(Markdown.ToMarkup("&lt;b&gt; &amp; &#65;")).toBe("&lt;b&gt; &amp; A")
	end)

	It("md code span keeps entity", function()
		Expect(Markdown.ToMarkup("`&amp;`")).toBe("<code>&amp;amp;</code>")
	end)

	It("md huge entity literal", function()
		Expect(Markdown.ToMarkup("&#99999999999;")).toBe("&amp;#99999999999;")
	end)

	It("md link destination decoded", function()
		Expect(Markdown.ToMarkup("[a](x&amp;y)")).toBe('<a href="x&amp;y">a</a>')
	end)

	It("md decoded entity is not syntax", function()
		Expect(Markdown.ToMarkup("&#42;x&#42;")).toBe("*x*")
	end)

	local Safe: any

	It("escaped md body cannot close the block", function()
		Safe = Keep(API.new(Label(`<md>{Library.Utilities.Escape("</md><b>x</b> **y**")}</md>`)))
		Expect(Render(Safe)).toBe("</md><b>x</b> y")
	end)

	It("escaped md body keeps markdown", function()
		Expect(Word(Safe, "y") and Word(Safe, "y").Bold).toBe(true)
	end)

	It("escaped md body does not style x", function()
		Expect(Word(Safe, "x")).toBeNil()
	end)

	It("escaped entity text round-trips", function()
		const Literal: any = Keep(API.new(Label(`<md>{Library.Utilities.Escape("a &amp; b")}</md>`)):SetPreset("Trusted"):Flush())
		Expect(Render(Literal)).toBe("a &amp; b")
	end)
end)

Describe("markdown amplification", function()
	const Lines: { string } = {string.rep("> ", 12) .. "a"}
	for _ = 1, 3000 do table.insert(Lines, "a") end
	const Source: string = table.concat(Lines, "\n")

	const Items: { string } = {}
	for Depth = 0, 11 do table.insert(Items, string.rep("  ", Depth) .. "- a") end
	for _ = 1, 3000 do table.insert(Items, "a") end
	const Nested: string = table.concat(Items, "\n")

	local Output: string = ""
	local Listed: string = ""

	It("deep quote lazy lines runs", function()
		Expect(function() Output = Markdown.ToMarkup(Source) end).never.toThrow()
	end)

	It("quote prefix output bounded", function()
		Expect(#Output).toBeLessThan(#Source * 33 + 16384 + 4096)
	end)

	It("deep list lazy lines runs", function()
		Expect(function() Listed = Markdown.ToMarkup(Nested) end).never.toThrow()
	end)

	It("list prefix output bounded", function()
		Expect(#Listed).toBeLessThan(#Nested * 33 + 16384 + 4096)
	end)

	It("normal document keeps its tail", function()
		Expect(Markdown.ToMarkup("> quote line\n> - item one\n> - item two\n\n1. first\n2. second\n\nfinal line")).toContain("final line")
	end)
end)
