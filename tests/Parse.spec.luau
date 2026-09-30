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
const ClassesModule = require("../Packages/RichTextPlus/Classes")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const XML: any = XMLModule
const Trove: any = TroveModule
const Flatten: any = FlattenModule
const Styles: any = StylesModule
const Policy: any = {Intents = IntentsModule, Limits = LimitsModule, Presets = PresetsModule, Assets = AssetsModule}
const Rendering: any = RenderingModule
const Classes: any = ClassesModule
const Presets: any = IntentsModule.Presets

const MarkdownStub: string = [[
local XML = require("../XML")
local Calls = {}
return {
	Calls = Calls;
	Preprocess = function(Text) return Text end;
	ToTree = function(Raw, State)
		table.insert(Calls, Raw)
		return XML.GenerateTreeFromXML('<b>STUB</b> <codeblock lang="lua">print(1)</codeblock><hr/>')
	end;
}
]]

const BlockStub: string = [[
local Builds = {}
return {
	Kind = "Object";
	Block = true;
	Builds = Builds;
	Build = function(Node, Style, Scale, State)
		table.insert(Builds, {Node = Node, Scale = Scale, State = State})
		local Frame = Instance.new("Frame")
		Frame.Name = "StubBlock"
		Frame.Size = UDim2.fromOffset(200, 40)
		return Frame
	end;
}
]]

const Cleanup: { () -> () } = {}

const function Distance(Actual: Color3?, Expected: Color3): number
	if Actual == nil then return math.huge end

	const Color: Color3 = Actual :: Color3

	return math.max(math.abs(Color.R - Expected.R), math.abs(Color.G - Expected.G), math.abs(Color.B - Expected.B))
end

const function MakeState(Setup: any?, Markup: string?): any
	const Config: any = Setup or {}
	const Modules: any = Config.Modules or Policy
	const Bundle: any = Modules.Presets.Resolve(Config.Preset or "Default", 1)

	const Label: TextLabel = Instance.new("TextLabel")
	Label.TextSize = 20
	Label.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.Text = Config.Text or Markup or ""

	const MainTrove: any = Trove.new()

	const State: any = {
		Label = Label;
		Options = {Scale = Config.Scale or 1};
		Rendering = Config.Rendering or Rendering.Defaults;
		Intents = if Config.Intents ~= nil then Modules.Intents.Frozen(Modules.Intents.Resolve(Config.Intents)) else Bundle.Intents;
		Limits = if Config.Limits ~= nil then Modules.Limits.Resolve(Config.Limits, 1) else Bundle.Limits;
		Denied = Config.Denied or Bundle.Denied;
		Assets = Modules.Assets.Resolve(Config.Assets, 1);
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
	const Config: any = Setup or {}
	const State: any = MakeState(Setup, Text)

	if Config.Before then Config.Before(State) end

	;(Config.Flatten or Flatten).Run(State, XML.GenerateTreeFromXML(Text))

	return State
end

const function Render(State: any): string
	const Parts: { string } = {}

	for _, Token: any in State.Document.Tokens do
		const Space: string = if Token.SpaceBefore then " " else ""

		if Token.Kind == "Break" then
			table.insert(Parts, "\n")
		elseif Token.Kind == "Object" then
			table.insert(Parts, `{Space}[{Token.Object.Name}{if Token.Block then "!" else ""}]`)
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

const function Sandbox(Stubs: { [string]: string }): any
	const Copy: Instance = (script.Parent :: Instance).Parent:FindFirstChild("Packages"):Clone()
	Copy.Name = "ParseSandbox"

	for Path: string, Source: string in Stubs do
		const Segments: { string } = string.split(Path, "/")

		local Parent: any = Copy:FindFirstChild("RichTextPlus")
		for Index = 1, #Segments - 1 do Parent = Parent:FindFirstChild(Segments[Index]) end

		const Module: ModuleScript = Instance.new("ModuleScript")
		Module.Name = Segments[#Segments]
		;(Module :: any).Source = Source

		const Existing: Instance? = Parent:FindFirstChild(Segments[#Segments])
		if Existing then (Existing :: Instance):Destroy() end

		Module.Parent = Parent
	end

	Copy.Parent = (script.Parent :: Instance).Parent
	table.insert(Cleanup, function() Copy:Destroy() end)

	return Copy:FindFirstChild("RichTextPlus")
end

AfterAll(function()
	for _, Callback: () -> () in Cleanup do pcall(Callback) end
end)

Describe("attribute helpers", function()
	local Node: any
	BeforeAll(function() Node = XML.GenerateTreeFromXML('<font COLOR="#FF7800" Size="30" face="Arial">x</font>').Children[1] end)
	It("Attribute upper-case name", function()
		Expect(Styles.Attribute(Node, "color")).toBe("#FF7800")
	end)

	It("Attribute mixed-case name", function()
		Expect(Styles.Attribute(Node, "SIZE")).toBe("30")
	end)

	It("Attribute missing", function()
		Expect(Styles.Attribute(Node, "weight")).toBeNil()
	end)

	local Escaped: any
	BeforeAll(function() Escaped = XML.GenerateTreeFromXML('<a href="a&amp;b">x</a>').Children[1] end)
	It("Attribute unescapes entities", function()
		Expect(Styles.Attribute(Escaped, "HREF")).toBe("a&b")
	end)

	local Nested: any
	BeforeAll(function() Nested = XML.GenerateTreeFromXML("<x>a<b>b</b><br/>c &lt;d&gt;</x>").Children[1] end)
	It("InnerText concatenates and unescapes", function()
		Expect(Styles.InnerText(Nested)).toBe("ab\nc <d>")
	end)

	It("PascalName", function()
		Expect(Styles.PascalName("hYPERlink")).toBe("Hyperlink")
	end)

	It("LowerName", function()
		Expect(Styles.LowerName("FoNt")).toBe("font")
	end)
end)

Describe("colors", function()
	It("ParseColor #RRGGBB", function()
		Expect(Distance(Styles.ParseColor("#FF7800"), Color3.fromRGB(255, 120, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor lower hex", function()
		Expect(Distance(Styles.ParseColor("#ff7800"), Color3.fromRGB(255, 120, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor #RGB", function()
		Expect(Distance(Styles.ParseColor("#f80"), Color3.fromRGB(255, 136, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor bare hex", function()
		Expect(Distance(Styles.ParseColor("00FF00"), Color3.fromRGB(0, 255, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor rgb()", function()
		Expect(Distance(Styles.ParseColor("rgb(255, 125, 0)"), Color3.fromRGB(255, 125, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor RGB spaces", function()
		Expect(Distance(Styles.ParseColor(" RGB(1 2 3) "), Color3.fromRGB(1, 2, 3))).toBeLessThan(0.002)
	end)

	It("ParseColor clamps channels", function()
		Expect(Distance(Styles.ParseColor("rgb(999,0,0)"), Color3.fromRGB(255, 0, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor named", function()
		Expect(Distance(Styles.ParseColor("Red"), Color3.fromRGB(255, 0, 0))).toBeLessThan(0.002)
	end)

	It("ParseColor gray", function()
		Expect(Distance(Styles.ParseColor("gray"), Color3.fromRGB(128, 128, 128))).toBeLessThan(0.002)
	end)

	It("ParseColor grey spelling removed", function()
		Expect(Styles.ParseColor("grey")).toBeNil()
	end)

	It("ParseColor rejects junk", function()
		Expect(Styles.ParseColor("bogus")).toBeNil()
	end)

	It("ParseColor rejects short hex", function()
		Expect(Styles.ParseColor("#12")).toBeNil()
	end)

	It("ParseColor rejects junk twice (cached)", function()
		Expect(Styles.ParseColor("bogus")).toBeNil()
	end)

	It("ParseColor nil", function()
		Expect(Styles.ParseColor(nil)).toBeNil()
	end)
end)

Describe("weights and faces", function()
	It("ParseWeight name", function()
		Expect(Styles.ParseWeight("bold")).toBe(Enum.FontWeight.Bold)
	end)

	It("ParseWeight mixed case", function()
		Expect(Styles.ParseWeight("SemiBold")).toBe(Enum.FontWeight.SemiBold)
	end)

	It("ParseWeight hyphen", function()
		Expect(Styles.ParseWeight("Extra-Bold")).toBe(Enum.FontWeight.ExtraBold)
	end)

	for _, Weight: Enum.FontWeight in Enum.FontWeight:GetEnumItems() :: { Enum.FontWeight } do
		It(`ParseWeight engine name {Weight.Name}`, function()
			Expect(Styles.ParseWeight(string.lower(Weight.Name))).toBe(Weight)
		end)
	end
	for _, Synonym: string in {"black", "normal", "ultralight", "demibold", "ultrabold"} do
		It(`ParseWeight synonym {Synonym} removed`, function()
			Expect(Styles.ParseWeight(Synonym)).toBeNil()
		end)
	end
	It("ParseWeight 600", function()
		Expect(Styles.ParseWeight("600")).toBe(Enum.FontWeight.SemiBold)
	end)

	It("ParseWeight 740 rounds", function()
		Expect(Styles.ParseWeight("740")).toBe(Enum.FontWeight.Bold)
	end)

	It("ParseWeight clamps", function()
		Expect(Styles.ParseWeight("5000")).toBe(Enum.FontWeight.Heavy)
	end)

	It("ParseWeight junk", function()
		Expect(Styles.ParseWeight("chunky")).toBeNil()
	end)

	local Gotham: any
	BeforeAll(function() Gotham = Styles.ResolveFace("GothamBold") end)
	It("ResolveFace enum family", function()
		Expect(Gotham.Family).toBe("rbxasset://fonts/families/GothamSSm.json")
	end)

	It("ResolveFace enum weight", function()
		Expect(Gotham.Weight).toBe(Enum.FontWeight.Bold)
	end)

	It("ResolveFace enum italic", function()
		Expect(Styles.ResolveFace("SourceSansItalic").Italic).toBe(true)
	end)

	It("ResolveFace case-insensitive enum", function()
		Expect(Styles.ResolveFace("michroma").Family).toBe(Font.fromEnum(Enum.Font.Michroma).Family)
	end)

	It("ResolveFace path", function()
		Expect(Styles.ResolveFamily("rbxasset://fonts/families/Arial.json")).toBe("rbxasset://fonts/families/Arial.json")
	end)

	It("ResolveFace asset id", function()
		Expect(Styles.ResolveFamily("12345")).toBe("rbxassetid://12345")
	end)

	It("ResolveFace family name with spaces", function()
		Expect(Styles.ResolveFamily("Source Sans Pro")).toBe("rbxasset://fonts/families/SourceSansPro.json")
	end)
end)

Describe("font attributes", function()
	local State: any
	BeforeAll(function() State = Run('<font color="#FF7800" size="30" transparency="0.5">x</font> <FONT COLOR="rgb(0,0,255)">y</FONT>') end)
	local X: any
	BeforeAll(function() X = Word(State, "x") end)
	It("font color lowercase attr", function()
		Expect(Distance(X.Color, Color3.fromRGB(255, 120, 0))).toBeLessThan(0.002)
	end)

	It("font size lowercase attr", function()
		Expect(X.Size).toBe(30)
	end)

	It("font transparency", function()
		Expect(X.Transparency).toBe(0.5)
	end)

	It("font upper-case tag and attr", function()
		Expect(Distance(Word(State, "y").Color, Color3.fromRGB(0, 0, 255))).toBeLessThan(0.002)
	end)

	It("font text", function()
		Expect(Render(State)).toBe("x y")
	end)
end)

Describe("font faces and weights", function()
	local State: any
	BeforeAll(function() State = Run('<font face="GothamBold">a</font><font family="rbxasset://fonts/families/Arial.json">b</font><font face="Michroma" weight="light">c</font>') end)
	It("font face enum family", function()
		Expect(Word(State, "a").Family).toBe("rbxasset://fonts/families/GothamSSm.json")
	end)

	It("font face enum weight", function()
		Expect(Word(State, "a").Weight).toBe(Enum.FontWeight.Bold)
	end)

	It("font family path", function()
		Expect(Word(State, "b").Family).toBe("rbxasset://fonts/families/Arial.json")
	end)

	It("font weight name", function()
		Expect(Word(State, "c").Weight).toBe(Enum.FontWeight.Light)
	end)

	local Weights: any
	BeforeAll(function() Weights = Run('<font weight="900">a</font><b><font weight="light">b</font></b><font weight="light"><b>c</b></font>') end)
	It("font weight number", function()
		Expect(Weights.Document.Tokens[1].Style.Weight).toBe(Enum.FontWeight.Heavy)
	end)

	It("inner weight overrides outer bold", function()
		Expect(Styles.FontFor(Word(Weights, "b")).Weight).toBe(Enum.FontWeight.Light)
	end)

	It("inner bold overrides outer weight", function()
		Expect(Styles.FontFor(Word(Weights, "c")).Weight).toBe(Enum.FontWeight.Bold)
	end)
end)

Describe("basic style tags", function()
	local State: any
	BeforeAll(function() State = Run("<b>b</b><strong>st</strong><i>i</i><em>em</em><u>u</u><s>s</s><strike>sk</strike><uppercase>up</uppercase><uc>uc</uc><smallcaps>sm</smallcaps><sc>sc</sc>") end)
	It("b", function()
		Expect(Word(State, "b").Bold).toBe(true)
	end)

	It("strong is not a b alias", function()
		Expect(Word(State, "st").Bold).toBe(false)
	end)

	It("i", function()
		Expect(Word(State, "i").Italic).toBe(true)
	end)

	It("em is not an i alias", function()
		Expect(Word(State, "em").Italic).toBe(false)
	end)

	It("u", function()
		Expect(Word(State, "u").Underline).toBe(true)
	end)

	It("s", function()
		Expect(Word(State, "s").Strike).toBe(true)
	end)

	It("strike is not an s alias", function()
		Expect(Word(State, "sk").Strike).toBe(false)
	end)

	It("uppercase", function()
		Expect(Word(State, "up").Case).toBe("Upper")
	end)

	It("uc", function()
		Expect(Word(State, "uc").Case).toBe("Upper")
	end)

	It("smallcaps", function()
		Expect(Word(State, "sm").Case).toBe("SmallCaps")
	end)

	It("sc", function()
		Expect(Word(State, "sc").Case).toBe("SmallCaps")
	end)

	It("uppercase keeps original text", function()
		Expect(Word(State, "up") ~= nil).toBe(true)
	end)

	It("plain base not bold", function()
		Expect(Run("x").Document.Tokens[1].Style.Bold).toBe(false)
	end)
end)

Describe("stroke", function()
	local State: any
	BeforeAll(function() State = Run('<stroke color="#00A2FF" joins="miter" thickness="2" transparency="0.25">s</stroke><stroke>d</stroke><STROKE Color="#fff">e</STROKE>', {Scale = 2}) end)
	local Stroke: any
	BeforeAll(function() Stroke = Word(State, "s").Stroke end)
	It("stroke color", function()
		Expect(Distance(Stroke.Color, Color3.fromRGB(0, 162, 255))).toBeLessThan(0.002)
	end)

	It("stroke joins", function()
		Expect(Stroke.Joins).toBe(Enum.LineJoinMode.Miter)
	end)

	It("stroke thickness scaled", function()
		Expect(Stroke.Thickness).toBe(4)
	end)

	It("stroke transparency", function()
		Expect(Stroke.Transparency).toBe(0.25)
	end)

	local Default: any
	BeforeAll(function() Default = Word(State, "d").Stroke end)
	It("stroke default color", function()
		Expect(Distance(Default.Color, Color3.new(0, 0, 0))).toBeLessThan(0.002)
	end)

	It("stroke default thickness scaled", function()
		Expect(Default.Thickness).toBe(2)
	end)

	It("stroke default joins", function()
		Expect(Default.Joins).toBe(Enum.LineJoinMode.Round)
	end)

	It("stroke case-insensitive attr", function()
		Expect(Distance(Word(State, "e").Stroke.Color, Color3.new(1, 1, 1))).toBeLessThan(0.002)
	end)

	It("stroke tables not shared", function()
		Expect(Word(State, "e").Stroke ~= Default).toBeTruthy()
	end)

	It("stroke thickness capped", function()
		Expect(Word(Run('<stroke thickness="999">z</stroke>'), "z").Stroke.Thickness).toBe(16)
	end)
end)

Describe("mark", function()
	local State: any
	BeforeAll(function() State = Run('<mark color="#FFFF00" transparency="0.5">m</mark><mark>n</mark>') end)
	It("mark color", function()
		Expect(Distance(Word(State, "m").Mark.Color, Color3.fromRGB(255, 255, 0))).toBeLessThan(0.002)
	end)

	It("mark transparency", function()
		Expect(Word(State, "m").Mark.Transparency).toBe(0.5)
	end)

	It("mark default transparency", function()
		Expect(Word(State, "n").Mark.Transparency).toBe(0)
	end)
end)

Describe("text structure", function()
	It("br self-closing", function()
		Expect(Render(Run("a<br/>b"))).toBe("a\nb")
	end)

	It("br unclosed keeps following text", function()
		Expect(Render(Run("a<br>b c"))).toBe("a\nb c")
	end)

	It("newline in text breaks", function()
		Expect(Render(Run("a\nb"))).toBe("a\nb")
	end)

	It("comment ignored", function()
		Expect(Render(Run("a<!-- <b>hidden</b> -->b"))).toBe("ab")
	end)

	It("prolog ignored", function()
		Expect(Render(Run('<?xml version="1.0"?>a'))).toBe("a")
	end)

	It("whitespace collapse", function()
		Expect(Render(Run("  a   b  "))).toBe("a b")
	end)

	It("entities decoded", function()
		Expect(Render(Run("&lt;b&gt; &amp;"))).toBe("<b> &")
	end)

	It("unknown tag stripped under Default", function()
		Expect(Render(Run("<foo>x</foo>"))).toBe("x")
	end)

	It("style change mid word glued", function()
		Expect(Render(Run("he<b>llo</b> there"))).toBe("hello there")
	end)
end)

Describe("style reuse", function()
	local Reused: any
	BeforeAll(function() Reused = Run("<font>y</font>z") end)
	It("font without attributes reuses parent style", function()
		Expect(Word(Reused, "y") == Word(Reused, "z")).toBeTruthy()
	end)

	local Nested: any
	BeforeAll(function() Nested = Run("<b>a<b>b</b></b>") end)
	It("redundant b keeps identical Style table", function()
		Expect(Word(Nested, "a") == Word(Nested, "b")).toBeTruthy()
	end)
end)

Describe("gradient and dir", function()
	local State: any
	BeforeAll(function() State = Run('<gradient colors="#f00,rgb(0,255,0),blue" speed="1" rotation="45">g</gradient>') end)
	local Gradient: any
	BeforeAll(function() Gradient = Word(State, "g").Gradient end)
	It("gradient lowercase colors attr", function()
		Expect(Gradient ~= nil).toBeTruthy()
	end)

	It("gradient color count", function()
		Expect(Gradient and #Gradient.Colors).toBe(3)
	end)

	It("gradient rgb() with commas", function()
		Expect(Distance(Gradient and Gradient.Colors[2], Color3.fromRGB(0, 255, 0))).toBeLessThan(0.002)
	end)

	It("gradient speed", function()
		Expect(Gradient and Gradient.Speed).toBe(1)
	end)

	It("gradient rotation", function()
		Expect(Gradient and Gradient.Rotation).toBe(45)
	end)

	const Many: { string } = {}
	for Index = 1, 40 do table.insert(Many, "#fff") end
	It("gradient caps keypoints", function()
		Expect(#Word(Run(`<gradient colors="{table.concat(Many, ",")}">g</gradient>`), "g").Gradient.Colors).toBe(20)
	end)

	It("gradient color attribute is not a colors alias", function()
		Expect(Word(Run('<gradient color="#f00,#00f">g</gradient>'), "g").Gradient).toBeNil()
	end)

	It("dir value", function()
		Expect(Word(Run('<dir value="rtl">x</dir>'), "x").Direction).toBe("Rtl")
	end)

	It("dir attribute is not a value alias", function()
		Expect(Word(Run('<dir dir="rtl">x</dir>'), "x").Direction).toBeNil()
	end)
end)

Describe("effects", function()
	local State: any
	BeforeAll(function() State = Run('<wave amplitude="4">w</wave><SHAKE Frequency="3">s</SHAKE><effect name="wave">e</effect><effect name="glow">x</effect>') end)
	It("wave amplitude", function()
		Expect(Word(State, "w").Effect.Amplitude).toBe(4)
	end)

	It("shake case-insensitive", function()
		Expect(Word(State, "s").Effect.Frequency).toBe(3)
	end)

	It("the effect tag is gone", function()
		Expect(Word(State, "e").Effect).toBeNil()
	end)

	It("the effect tag reaches no class", function()
		Expect(Word(State, "x").Effect).toBeNil()
	end)

	const Glow = {Kind = "Effect", Update = function(): () end}
	const Register = {Before = function(Target: any) Classes.Register(Target, "glow", Glow) end}

	local Custom: any
	BeforeAll(function() Custom = Run('<customclass><GLOW amplitude="3" frequency="2">x</GLOW></customclass>', Register) end)
	It("effect class applies", function()
		Expect(Word(Custom, "x").Effect and Word(Custom, "x").Effect.Name).toBe("glow")
	end)

	It("effect class amplitude", function()
		Expect(Word(Custom, "x").Effect and Word(Custom, "x").Effect.Amplitude).toBe(3)
	end)

	It("effect class frequency", function()
		Expect(Word(Custom, "x").Effect and Word(Custom, "x").Effect.Frequency).toBe(2)
	end)

	It("effect class default amplitude", function()
		Expect(Word(Run('<customclass><glow>x</glow></customclass>', Register), "x").Effect.Amplitude).toBe(2.5)
	end)

	It("effect class amplitude clamped", function()
		Expect(Word(Run('<customclass><glow amplitude="9999">x</glow></customclass>', Register), "x").Effect.Amplitude).toBe(50)
	end)

	It("effect class shorthand", function()
		Expect(Word(Run('<customclass name="glow">x</customclass>', Register), "x").Effect.Name).toBe("glow")
	end)

	It("effect class outside a region ignored", function()
		Expect((Word(Run('<glow>x</glow>', Register), "x") or {}).Effect).toBeNil()
	end)

	local Override: any
	BeforeAll(function() Override = Run('<customclass><wave>x</wave></customclass>', {Before = function(Target: any) Classes.Register(Target, "wave", {Kind = "Effect", Override = true, Update = Glow.Update}) end}) end)
	It("override effect class replaces wave", function()
		Expect(Word(Override, "x").Effect and Word(Override, "x").Effect.Name).toBe("wave")
	end)

	It("effect amplitude clamped", function()
		Expect(Word(Run('<wave amplitude="9999">w</wave>'), "w").Effect.Amplitude).toBe(50)
	end)
end)

Describe("images", function()
	local State: any
	BeforeAll(function() State = Run('<img SRC="123" Width="10" HEIGHT="20"/>after<img src="rbxassetid://5" size="8">cap</img>') end)
	local Found: { any }
	BeforeAll(function() Found = Objects(State) end)
	It("image count", function()
		Expect(#Found).toBe(2)
	end)

	It("image src numeric normalized", function()
		Expect(Found[1] and Found[1].Object.Image).toBe("rbxassetid://123")
	end)

	It("image width", function()
		Expect(Found[1] and Found[1].Width).toBe(10)
	end)

	It("image height", function()
		Expect(Found[1] and Found[1].Height).toBe(20)
	end)

	It("image uniform size", function()
		Expect(Found[2] and Found[2].Width).toBe(8)
	end)

	It("image object not block", function()
		Expect(Found[1] and Found[1].Block).toBeNil()
	end)

	It("image then text", function()
		Expect(Render(State)).toBe("[InlineImage]after[InlineImage]cap")
	end)

	It("image scaled by the renderer scale", function()
		Expect(Objects(Run('<img src="1" size="10"/>', {Scale = 2}))[1].Width).toBe(20)
	end)

	It("image dimension clamp", function()
		Expect(Objects(Run('<img src="1" size="99999"/>'))[1].Width).toBe(1024)
	end)

	It("image without source dropped", function()
		Expect(#Objects(Run("<img/>"))).toBe(0)
	end)

	It("object marker attribute", function()
		Expect(Found[1] and Found[1].Object:GetAttribute("RichTextPlus") == true).toBeTruthy()
	end)

	It("video is not built in", function()
		Expect(Render(Run('<video src="7"/>after'))).toBe("after")
	end)

	It("image source aliases removed", function()
		Expect(#Objects(Run('<img source="1"/><img image="2"/><img imageid="3"/>'))).toBe(0)
	end)

	local Legacy: any
	BeforeAll(function() Legacy = Run('<image src="1">kept</image>') end)
	It("image tag is not an img alias", function()
		Expect(#Objects(Legacy)).toBe(0)
	end)

	It("image tag renders content", function()
		Expect(Render(Legacy)).toBe("kept")
	end)
end)

const function Anchors(State: any): { any }
	return ElementsModule.Query(State, ElementsModule.Selector.Compile("a", 1), false)
end

const function Href(Element: any): string?
	return if Element then Element:GetAttribute("href") or "" else nil
end

Describe("links", function()
	local State: any
	BeforeAll(function() State = Run('<a href="u1">hello <b>big</b> world</a> <A HREF="u2">hel<b>lo</b></A> <a href="u3"/> <a href="u4" text="label"/> <a text="t5"/>') end)
	local Groups: any
	BeforeAll(function() Groups = Anchors(State) end)
	It("link group count", function()
		Expect(#Groups).toBe(5)
	end)

	It("link text with nested style", function()
		Expect(Groups[1] and Groups[1].Text).toBe("hello big world")
	end)

	It("link href", function()
		Expect(Href(Groups[1])).toBe("u1")
	end)

	It("link glued text", function()
		Expect(Groups[2] and Groups[2].Text).toBe("hello")
	end)

	It("link upper-case attr", function()
		Expect(Href(Groups[2])).toBe("u2")
	end)

	It("self-closing link shows href", function()
		Expect(Groups[3] and Groups[3].Text).toBe("u3")
	end)

	It("text attribute is not display text", function()
		Expect(Groups[4] and Groups[4].Text).toBe("u4")
	end)

	It("text attribute is not an href alias", function()
		Expect(Href(Groups[5])).toBe("")
	end)

	It("hyperlink tag is not an a alias", function()
		Expect(#Anchors(Run('<hyperlink href="h">x</hyperlink>'))).toBe(0)
	end)

	It("link words carry their element", function()
		Expect(Word(State, "big").Element).toBe(Groups[1])
	end)

	It("link color applied", function()
		Expect(Word(State, "hello").Color).toBe(Color3.fromRGB(92, 170, 255))
	end)

	It("link break joins with space", function()
		Expect(Anchors(Run('<a href="x">a<br/>b</a>'))[1].Text).toBe("a b")
	end)

	const Words: { string } = {}
	for Index = 1, 3000 do table.insert(Words, `w{Index}`) end
	local Long: any
	BeforeAll(function() Long = Run(`<a href="big">{table.concat(Words, " ")}</a>`) end)
	It("long link text", function()
		Expect(#Anchors(Long)[1].Text).toBe(#table.concat(Words, " "))
	end)
end)

Describe("presets", function()
	It("Presets frozen", function()
		Expect(table.isfrozen(Presets)).toBeTruthy()
	end)

	It("Chat preset frozen", function()
		Expect(table.isfrozen(Presets.Chat)).toBeTruthy()
	end)

	It("Presets are Default, Trusted, Chat and Plain", function()
		const Names: { string } = {}
		for Name: string in Presets do table.insert(Names, Name) end
		table.sort(Names)

		Expect(table.concat(Names, " ")).toBe("Chat Default Plain Trusted")
	end)

	It("Resolve has no Full alias", function()
		Expect(function() PresetsModule.Resolve("Full", 1) end).toThrow()
	end)

	It("Resolve name case-insensitive", function()
		Expect(PresetsModule.Resolve("chat", 1).Intents).toBe(Presets.Chat)
	end)

	It("Resolve unknown preset errors", function()
		Expect(function() PresetsModule.Resolve("Nope", 1) end).toThrow()
	end)

	It("flag names are case-insensitive", function()
		Expect(IntentsModule.Resolve({"formatting", "FONT"})).toBe(IntentsModule.Resolve({"Formatting", "Font"}))
	end)

	It("Allows Chat font color", function()
		Expect(Presets.Chat:Allows("font", "color")).toBe(true)
	end)

	It("Allows Chat FONT Size", function()
		Expect(Presets.Chat:Allows("FONT", "Size")).toBe(false)
	end)

	It("Allows Chat b", function()
		Expect(Presets.Chat:Allows("B")).toBe(true)
	end)

	It("Allows Chat img", function()
		Expect(Presets.Chat:Allows("img")).toBe(false)
	end)

	It("Allows Plain b", function()
		Expect(Presets.Plain:Allows("b")).toBe(false)
	end)

	It("Default strips unknown tags", function()
		Expect(PresetsModule.Resolve("Default", 1).Denied).toBe("Strip")
	end)

	It("Allows Trusted IMG", function()
		Expect(Presets.Trusted:Allows("IMG")).toBe(true)
	end)

	It("Allows Trusted md", function()
		Expect(Presets.Trusted:Allows("md")).toBe(true)
	end)

	It("Allows Trusted hr", function()
		Expect(Presets.Trusted:Allows("hr")).toBe(true)
	end)

	for _, Removed: string in {"image", "hyperlink", "rule", "strong", "em", "strike"} do
		It(`Trusted no longer lists {Removed}`, function()
			Expect(Presets.Trusted:Allows(Removed)).toBe(false)
		end)
	end

	It("a removed flag denies its tag", function()
		Expect(Presets.Default:Remove("Images"):Allows("img")).toBe(false)
	end)
end)

Describe("preset behaviour", function()
	local Everything: any
	BeforeAll(function() Everything = Run('<b>x</b> <img src="1"/> <custom>m</custom>', {Preset = "Default"}) end)
	It("Default renders everything", function()
		Expect(Render(Everything)).toBe("x [InlineImage] m")
	end)

	local Trusted: any
	BeforeAll(function() Trusted = Run('<font size="200">a</font><font size="2">b</font><img src="1"/><foo src="2"/> <icon/>', {Preset = "Trusted"}) end)
	It("Trusted size clamp max", function()
		Expect(Word(Trusted, "a").Size).toBe(96)
	end)

	It("Trusted size clamp min", function()
		Expect(Word(Trusted, "b").Size).toBe(8)
	end)

	It("Trusted keeps image, escapes unknown tags", function()
		Expect(Render(Trusted)).toBe('ab[InlineImage]<foo src="2"/> <icon/>')
	end)

	local Chat: any
	BeforeAll(function() Chat = Run('<b>x</b> <font color="#f00" size="50">y</font> <img src="1"/> <mark>m</mark> <md>z</md>', {Preset = "Chat"}) end)
	It("Chat bold", function()
		Expect(Word(Chat, "x").Bold).toBe(true)
	end)

	It("Chat font color allowed", function()
		Expect(Distance(Word(Chat, "y").Color, Color3.new(1, 0, 0))).toBeLessThan(0.002)
	end)

	It("Chat font size filtered", function()
		Expect(Word(Chat, "y").Size).toBe(20)
	end)

	It("Chat mark allowed", function()
		Expect(Word(Chat, "m").Mark ~= nil).toBeTruthy()
	end)

	It("Chat escapes img and md", function()
		Expect(Render(Chat)).toBe('x y <img src="1"/> m <md>z</md>')
	end)

	It("Chat no objects", function()
		Expect(#Objects(Chat)).toBe(0)
	end)

	local Plain: any
	BeforeAll(function() Plain = Run('<b>x</b> <font color="#f00">y</font><br/> &amp;', {Preset = "Plain"}) end)
	It("Plain shows markup literally", function()
		Expect(Render(Plain)).toBe('<b>x</b> <font color="#f00">y</font><br/> &amp;')
	end)

	It("Plain literal is not bold", function()
		Expect(Word(Plain, "<b>x</b>").Bold).toBe(false)
	end)

	It("Plain renders without a ledger", function()
		Expect(Plain.Document.Ledger).toBeNil()
	end)

	local PlainStrip: any
	BeforeAll(function() PlainStrip = Run('<b>x</b> <font color="#f00">y</font> &amp;', {Preset = "Plain", Denied = "Strip"}) end)
	It("Plain Strip still parses and strips every tag", function()
		Expect(Render(PlainStrip)).toBe("x y &")
	end)

	local Quoted: any
	BeforeAll(function() Quoted = Run([[<x a='say "hi"'>t</x>]], {Preset = "Chat"}) end)
	It("Escape re-quotes attribute with inner double quote", function()
		Expect(Render(Quoted)).toBe([[<x a='say "hi"'>t</x>]])
	end)

	local Strip: any
	BeforeAll(function() Strip = Run('<img src="1"/>hello <foo>x</foo> <i>i</i>', {Preset = "Chat", Denied = "Strip"}) end)
	It("Strip mode keeps content", function()
		Expect(Render(Strip)).toBe("hello x i")
	end)

	It("Strip mode keeps allowed", function()
		Expect(Word(Strip, "i").Italic).toBe(true)
	end)
end)

Describe("limits", function()
	It("Depth nests once", function()
		Expect(Render(Run("<b><i>x</i></b>", {Limits = {Depth = 1}}))).toBe("x")
	end)

	local Depth: any
	BeforeAll(function() Depth = Run("<b><i>x</i><br/>y</b>", {Limits = {Depth = 1}}) end)
	It("Depth flattens deeper tags", function()
		Expect(Word(Depth, "x").Italic).toBe(false)
	end)

	It("Depth keeps outer styling", function()
		Expect(Word(Depth, "x").Bold).toBe(true)
	end)

	It("Depth keeps breaks", function()
		Expect(Render(Depth)).toBe("x\ny")
	end)

	It("Depth 0 is text only", function()
		Expect(Word(Run("<b>x</b>", {Limits = {Depth = 0}}), "x").Bold).toBe(false)
	end)

	const Deep: string = string.rep("<b>", 5000) .. "deep" .. string.rep("</b>", 5000)
	local Ok: boolean = false
	local State: any
	BeforeAll(function() Ok, State = pcall(Run, Deep) end)
	It("default depth cap prevents stack overflow", function()
		Expect(Ok).toBeTruthy()
	end)

	It("default depth cap renders text", function()
		Expect(Ok and Render(State)).toBe("deep")
	end)

	It("Nodes halts", function()
		Expect(Render(Run("a <b>b</b> c <i>d</i>", {Limits = {Nodes = 3}}))).toBe("a b")
	end)

	It("Characters truncates", function()
		Expect(Render(Run("hello world", {Limits = {Characters = 5}}))).toBe("hello")
	end)

	It("Characters utf8", function()
		Expect(Render(Run("h\u{e9}llo w\u{f6}rld", {Limits = {Characters = 7}}))).toBe("h\u{e9}llo w")
	end)

	It("Characters across nodes", function()
		Expect(Render(Run("ab<b>cd</b>ef", {Limits = {Characters = 3}}))).toBe("abc")
	end)

	It("Objects", function()
		Expect(#Objects(Run('<img src="1"/><img src="2"/><img src="3"/>', {Limits = {Objects = 1}}))).toBe(1)
	end)

	local Assets: any
	BeforeAll(function() Assets = Run('<img src="111"/><img src="rbxassetid://222"/><img src="http://www.roblox.com/asset/?id=111"/>', {Assets = {["rbxassetid://111"] = true}}) end)
	It("asset allowlist filters", function()
		Expect(#Objects(Assets)).toBe(2)
	end)

	It("asset filter function", function()
		Expect(#Objects(Run('<img src="111"/><img src="222"/>', {Assets = function(Id: string): boolean return Id == "rbxassetid://222" end}))).toBe(1)
	end)
end)

Describe("feature toggles", function()
	const function Without(Flag: string): any
		return {Intents = Presets.Default:Remove(Flag)}
	end

	It("Images off", function()
		Expect(Render(Run('<img src="1"/>x', Without("Images")))).toBe("x")
	end)

	It("Images off keeps unclosed content", function()
		Expect(Render(Run('<img src="1">cap', Without("Images")))).toBe("cap")
	end)

	local Links: any
	BeforeAll(function() Links = Run('<a href="u">click me</a> <a href="v" text="t"/>', Without("Links")) end)
	It("Links off text", function()
		Expect(Render(Links)).toBe("click me v")
	end)

	It("Links off no element on the words", function()
		Expect(Word(Links, "click").Element).toBeNil()
	end)

	It("Links off no groups", function()
		Expect(#Anchors(Links)).toBe(0)
	end)

	It("Gradients off", function()
		Expect(Word(Run('<gradient colors="#f00,#00f">g</gradient>', Without("Gradients")), "g").Gradient).toBeNil()
	end)

	It("Effects off", function()
		Expect(Word(Run("<wave>w</wave>", Without("Effects")), "w").Effect).toBeNil()
	end)

	const function Glowing(Removed: string?): any
		return Word(Run('<customclass><glow>x</glow></customclass>', {Intents = if Removed then Presets.Default:Remove(Removed) else nil, Before = function(Target: any) Classes.Register(Target, "glow", {Kind = "Effect", Update = function(): () end}) end}), "x")
	end

	It("effect classes apply with regions and effects allowed", function()
		Expect(Glowing().Effect.Name).toBe("glow")
	end)

	It("Effects off ignores effect classes", function()
		Expect(Glowing("Effects").Effect).toBeNil()
	end)

	It("Effects off keeps effect class content", function()
		Expect(Glowing("Effects") ~= nil).toBe(true)
	end)

	It("CustomClasses off ignores effect classes", function()
		Expect((Glowing("CustomClasses") or {}).Effect).toBeNil()
	end)

	local RichOff: any
	BeforeAll(function() RichOff = Run("<i>ignored</i>", {Text = "<b>x</b>\nline2", Intents = {}, Denied = "Escape"}) end)
	It("RichText off renders Label.Text literally", function()
		Expect(Render(RichOff)).toBe("<b>x</b>\nline2")
	end)

	It("Markdown off renders body literally", function()
		Expect(Render(Run("<md>**x** &lt;y&gt;</md>", Without("Markdown")))).toBe("**x** <y>")
	end)

	It("an unlisted feature tag is rejected, not switched off", function()
		Expect(Render(Run('<img src="1"/>x', {Intents = {"Formatting"}, Denied = "Escape"}))).toBe('<img src="1"/>x')
	end)
end)

Describe("markdown and block dispatch", function()
	local StubFlatten: any
	local StubModules: any
	local Markdown: any
	local CodeBlock: any
	local Setup: any

	BeforeAll(function()
		const Stubbed: any = Sandbox({
			["Markdown"] = MarkdownStub;
			["Classes/CodeBlock"] = BlockStub;
			["Classes/Rule"] = BlockStub;
		})

		StubFlatten = (require :: any)(Stubbed.Core.Flatten)
		StubModules = {Intents = (require :: any)(Stubbed.Policy.Intents), Limits = (require :: any)(Stubbed.Policy.Limits), Presets = (require :: any)(Stubbed.Policy.Presets), Assets = (require :: any)(Stubbed.Policy.Assets)}
		Markdown = (require :: any)(Stubbed.Markdown)
		CodeBlock = (require :: any)(Stubbed.Classes.CodeBlock)
		Setup = {Flatten = StubFlatten, Modules = StubModules}
	end)

	local State: any
	BeforeAll(function() State = Run("<md>raw &lt;text&gt; **x**</md>", Setup) end)
	It("md hands raw unescaped text to ToTree", function()
		Expect(Markdown.Calls[1]).toBe("raw <text> **x**")
	end)

	It("md walks generated tree", function()
		Expect(Render(State)).toBe("STUB [StubBlock!][StubBlock!]")
	end)

	It("md generated styles apply", function()
		Expect(Word(State, "STUB").Bold).toBe(true)
	end)

	It("codeblock Block token", function()
		Expect(Objects(State)[1] and Objects(State)[1].Block).toBe(true)
	end)

	It("codeblock gets State", function()
		Expect(CodeBlock.Builds[1] and CodeBlock.Builds[1].State).toBe(State)
	end)

	It("codeblock gets code child", function()
		Expect(CodeBlock.Builds[1] and Styles.InnerText(CodeBlock.Builds[1].Node)).toBe("print(1)")
	end)

	local Direct: any
	BeforeAll(function() Direct = Run('<codeblock lang="lua">x = 1</codeblock>', Setup) end)
	It("codeblock direct dispatch", function()
		Expect(Render(Direct)).toBe("[StubBlock!]")
	end)

	local Off: any
	BeforeAll(function() Off = Run("<codeblock>x</codeblock>", {Flatten = StubFlatten, Modules = StubModules, Intents = StubModules.Intents.Presets.Default:Remove("CodeBlocks"), Rendering = {SyntaxHighlight = false}}) end)
	It("codeblock still dispatched with CodeBlocks off", function()
		Expect(Render(Off)).toBe("[StubBlock!]")
	end)

	local Generated: any
	BeforeAll(function() Generated = Run("<md>q</md>", {Flatten = StubFlatten, Modules = StubModules, Preset = "Chat", Intents = StubModules.Intents.Presets.Chat:Add("Markdown")}) end)
	It("generated tree strips disallowed tags", function()
		Expect(Render(Generated)).toBe("STUB print(1)")
	end)
end)

Describe("custom classes", function()
	const Frame = function(Name: string): GuiObject
		const Object: Frame = Instance.new("Frame")
		Object.Name = Name
		Object.Size = UDim2.fromOffset(12, 12)
		return Object
	end

	const Seen: { any } = {}
	const Red: Color3 = Color3.new(1, 0, 0)

	const Register = function(State: any): ()
		Classes.Register(State, "Icon", {
			Kind = "Object";
			Build = function(Node: any, Style: any, Scale: number, Owner: any): GuiObject
				table.insert(Seen, {Node = Node, Style = Style, Scale = Scale, Owner = Owner, Text = Styles.InnerText(Node)})
				return Frame("Icon")
			end;
		})
		Classes.Register(State, "warn", {
			Kind = "Style";
			Apply = function(Style: any, Node: any): ()
				Style.Color = Styles.ParseColor(Styles.Attribute(Node, "color")) or Red
			end;
		})
		Classes.Register(State, "BOX", {
			Kind = "Container";
			Wrap = function(_Node: any, _Style: any, _Segment: GuiObject): GuiObject? return nil end;
			Apply = function(Style: any): () Style.Italic = true end;
		})
	end

	const Source: string = '<icon/> <icon name="x"/> <ICON>label</ICON> <warn>w</warn> <warn color="#00f">v</warn> <warn/> <box>a b</box> <box/> <Box pad="2">c</Box>'

	local State: any
	BeforeAll(function() State = Run(`<customclass>{Source}</customclass>`, {Before = Register}) end)
	It("object forms build", function()
		Expect(#Objects(State)).toBe(3)
	end)

	It("object TAG form consumes children", function()
		Expect(Word(State, "label")).toBeNil()
	end)

	It("object TAG form InnerText", function()
		Expect(Seen[3] and Seen[3].Text).toBe("label")
	end)

	It("object attribute form sees attribute", function()
		Expect(Seen[2] and Styles.Attribute(Seen[2].Node, "NAME")).toBe("x")
	end)

	It("object Build receives State", function()
		Expect(Seen[1] and Seen[1].Owner).toBe(State)
	end)

	It("object Build receives Scale", function()
		Expect(Seen[1] and Seen[1].Scale).toBe(1)
	end)

	It("style container form", function()
		Expect(Distance(Word(State, "w").Color, Red)).toBeLessThan(0.002)
	end)

	It("style attribute form", function()
		Expect(Distance(Word(State, "v").Color, Color3.new(0, 0, 1))).toBeLessThan(0.002)
	end)

	It("container marks style", function()
		Expect(Word(State, "a").Container and Word(State, "a").Container.Name).toBe("box")
	end)

	It("container shares one style across words", function()
		Expect(Word(State, "a") == Word(State, "b")).toBeTruthy()
	end)

	It("container Apply runs", function()
		Expect(Word(State, "a").Italic).toBe(true)
	end)

	It("container attribute form node", function()
		Expect(Word(State, "c").Container and Styles.Attribute(Word(State, "c").Container.Node, "pad")).toBe("2")
	end)

	It("region renders nothing itself, self-closing style/container no-ops", function()
		Expect(Render(State)).toBe("[Icon] [Icon] [Icon] w v a b c")
	end)

	local Outside: any
	BeforeAll(function() Outside = Run(Source, {Before = Register}) end)
	It("classes do not resolve outside a region", function()
		Expect(Render(Outside)).toBe("label w v a b c")
	end)

	It("no custom objects outside a region", function()
		Expect(#Objects(Outside)).toBe(0)
	end)

	It("no container outside a region", function()
		Expect(Word(Outside, "a").Container).toBeNil()
	end)

	local Nested: any
	BeforeAll(function() Nested = Run("<customclass><b><customclass><warn>n</warn></customclass></b> <warn>m</warn></customclass> <warn>o</warn>", {Before = Register}) end)
	It("nested region resolves", function()
		Expect(Distance(Word(Nested, "n").Color, Red)).toBeLessThan(0.002)
	end)

	It("nested region keeps outer styling", function()
		Expect(Word(Nested, "n").Bold).toBe(true)
	end)

	It("outer region still active after nested one closes", function()
		Expect(Distance(Word(Nested, "m").Color, Red)).toBeLessThan(0.002)
	end)

	It("after region closes classes stop resolving", function()
		Expect(Word(Nested, "o").Color).toBe(Color3.new(1, 1, 1))
	end)

	local Count: number
	BeforeAll(function() Count = #Seen end)
	local Shorthand: any
	BeforeAll(function() Shorthand = Run('<customclass name="warn" color="#00f">s1</customclass> <customclass name="Icon" size="3"/> <customclass name="box">bx</customclass> <customclass name="nosuch">plain</customclass>', {Before = Register}) end)
	It("shorthand style class with attributes", function()
		Expect(Distance(Word(Shorthand, "s1").Color, Color3.new(0, 0, 1))).toBeLessThan(0.002)
	end)

	It("shorthand self-closing object", function()
		Expect(#Objects(Shorthand)).toBe(1)
	end)

	It("shorthand drops name attribute", function()
		Expect(Seen[Count + 1] and Styles.Attribute(Seen[Count + 1].Node, "name")).toBeNil()
	end)

	It("shorthand keeps other attributes", function()
		Expect(Seen[Count + 1] and Styles.Attribute(Seen[Count + 1].Node, "size")).toBe("3")
	end)

	It("shorthand node takes class tag name", function()
		Expect(Seen[Count + 1] and Seen[Count + 1].Node.TagType).toBe("icon")
	end)

	It("shorthand container", function()
		Expect(Word(Shorthand, "bx").Container and Word(Shorthand, "bx").Container.Name).toBe("box")
	end)

	It("shorthand unknown name renders content", function()
		Expect(Render(Shorthand)).toBe("s1 [Icon] bx plain")
	end)

	It("built-ins work inside a region", function()
		Expect(Word(Run("<customclass><b>x</b></customclass>"), "x").Bold).toBe(true)
	end)

	local Builtin: any
	BeforeAll(function()
		Builtin = Run("<customclass><b>t</b></customclass>", {Before = function(Owner: any)
			Classes.Register(Owner, "b", {Kind = "Style", Apply = function(Style: any) Style.Underline = true end})
		end})
	end)
	It("built-in not overridden without Override", function()
		Expect(Word(Builtin, "t").Bold).toBe(true)
	end)

	It("built-in custom ignored without Override", function()
		Expect(Word(Builtin, "t").Underline).toBe(false)
	end)

	local Forced: any
	BeforeAll(function()
		Forced = Run("<customclass><b>t</b></customclass> <b>u</b>", {Before = function(Owner: any)
			Classes.Register(Owner, "b", {Kind = "Style", Override = true, Apply = function(Style: any) Style.Underline = true end})
		end})
	end)
	It("Override replaces built-in inside region", function()
		Expect(Word(Forced, "t").Underline).toBe(true)
	end)

	It("Override drops built-in behaviour inside region", function()
		Expect(Word(Forced, "t").Bold).toBe(false)
	end)

	It("built-in untouched outside region", function()
		Expect(Word(Forced, "u").Bold).toBe(true)
	end)

	It("Override not applied outside region", function()
		Expect(Word(Forced, "u").Underline).toBe(false)
	end)

	const Owner: any = {}
	It("function definition rejected", function()
		Expect(function() Classes.Register(Owner, "bad", function() end) end).toThrow()
	end)

	It("Style without Apply rejected", function()
		Expect(function() Classes.Register(Owner, "bad", {Kind = "Style"}) end).toThrow()
	end)

	It("unknown Kind rejected", function()
		Expect(function() Classes.Register(Owner, "bad", {Kind = "Nope", Build = function() end}) end).toThrow()
	end)

	It("non-table rejected", function()
		Expect(function() Classes.Register(Owner, "bad", 5) end).toThrow()
	end)

	It("no global registry (nil owner rejected)", function()
		Expect(function() Classes.Register(nil, "bad", {Kind = "Style", Apply = function() end}) end).toThrow()
	end)

	It("case-insensitive registration", function()
		Classes.Register(Owner, "Tier", {Kind = "Style", Apply = function() end})
		Expect(Classes.Find(Owner, "tier") ~= nil).toBeTruthy()
	end)

	It("remove by any case", function()
		Classes.Register(Owner, "TIER", nil)
		Expect(Classes.Find(Owner, "tier")).toBeNil()
	end)

	It("CustomClasses off makes regions transparent", function()
		Expect(Render(Run("<customclass><icon/>x <warn>w</warn></customclass>", {Before = Register, Intents = Presets.Default:Remove("CustomClasses")}))).toBe("x w")
	end)

	It("Objects limit applies to custom objects", function()
		Expect(#Objects(Run("<customclass><icon/><icon/></customclass>", {Before = Register, Limits = {Objects = 1}}))).toBe(1)
	end)

	It("Chat escapes regions", function()
		Expect(Render(Run("<customclass><icon/></customclass>", {Before = Register, Preset = "Chat"}))).toBe("<customclass><icon/></customclass>")
	end)

	local Stripped: any
	BeforeAll(function() Stripped = Run("<customclass><icon/><warn>w</warn></customclass>", {Before = Register, Preset = "Chat", Denied = "Strip"}) end)
	It("Chat Strip keeps content without classes", function()
		Expect(Render(Stripped)).toBe("w")
	end)

	It("Chat Strip does not resolve classes", function()
		Expect(Word(Stripped, "w").Color).toBe(Color3.new(1, 1, 1))
	end)

	It("Trusted region admits classes not listed as tags", function()
		Expect(#Objects(Run("<customclass><icon/></customclass>", {Before = Register, Preset = "Trusted"}))).toBe(1)
	end)

	It("stripped regions drop unknown class tags", function()
		Expect(Render(Run("<customclass><icon/>x</customclass>", {Before = Register, Preset = "Trusted", Intents = Presets.Trusted:Remove("CustomClasses"), Denied = "Strip"}))).toBe("x")
	end)

	It("intents without regions escape them", function()
		Expect(Render(Run("<customclass><icon/></customclass>", {Before = Register, Preset = "Trusted", Intents = Presets.Trusted:Remove("CustomClasses")}))).toBe("<customclass><icon/></customclass>")
	end)

	It("region shorthand resolves under Plain plus CustomClasses", function()
		Expect(Distance(Word(Run('<customclass name="warn">x</customclass>', {Before = Register, Preset = "Plain", Intents = {"CustomClasses"}}), "x").Color, Red)).toBeLessThan(0.002)
	end)

	It("Clear removes the renderer registry", function()
		Classes.Clear(State)
		Expect(Classes.Find(State, "icon")).toBeNil()
	end)
end)

Describe("class tag", function()
	const Markup: string = '<customclass><class name="w" bold="true" size="18"/><w>x</w> <WARNING>y</WARNING></customclass>'
	local Everything: any
	BeforeAll(function() Everything = Run(Markup) end)
	It("class tag declares nothing", function()
		Expect(Word(Everything, "x").Bold).toBe(false)
	end)

	It("class tag applies no attributes", function()
		Expect(Word(Everything, "x").Size).toBe(20)
	end)

	It("class tag is an unknown tag under Default", function()
		Expect(Render(Everything)).toBe("x y")
	end)

	It("class tag outside a region walks its content", function()
		Expect(Word(Run('<class name="w" bold="true">z</class>'), "z").Bold).toBe(false)
	end)

	It("Trusted escapes the class tag", function()
		Expect(Render(Run(Markup, {Preset = "Trusted"}))).toBe('<class name="w" bold="true" size="18"/><w>x</w> <WARNING>y</WARNING>')
	end)

	It("Trusted Strip drops the class tag", function()
		Expect(Render(Run(Markup, {Preset = "Trusted", Denied = "Strip"}))).toBe("x y")
	end)

	It("Chat escapes the class tag", function()
		Expect(Render(Run(Markup, {Preset = "Chat"}))).toBe(Markup)
	end)

	It("Allows Trusted class", function()
		Expect(Presets.Trusted:Allows("class")).toBe(false)
	end)

	local Registered: any
	BeforeAll(function()
		Registered = Run('<customclass><class>x</class> <customclass name="class">y</customclass></customclass> <class>z</class>', {Before = function(Owner: any)
			Classes.Register(Owner, "class", {Kind = "Style", Apply = function(Style: any) Style.Bold = true end})
		end})
	end)
	It("renderer class named class resolves", function()
		Expect(Word(Registered, "x").Bold).toBe(true)
	end)

	It("shorthand renderer class named class resolves", function()
		Expect(Word(Registered, "y").Bold).toBe(true)
	end)

	It("renderer class named class stays inside regions", function()
		Expect(Word(Registered, "z").Bold).toBe(false)
	end)
end)

Describe("integration", function()
	const Green: Color3 = Color3.new(0, 1, 0)
	const Blue: Color3 = Color3.new(0, 0, 1)
	const Escaped: string = '<customclass><tone>t</tone> <legacy/> <styled>s</styled></customclass> <tone>out</tone> <img src="1"/>'

	const function Tone(Color: Color3): any
		return {Kind = "Style", Apply = function(Style: any) Style.Color = Color end}
	end

	local Loaded: boolean = false
	local Api: any
	local Label: TextLabel
	local Renderer: any
	local Removed: boolean = false

	BeforeAll(function()
		Loaded, Api = pcall(function(): any return RichTextPlus end)

		Label = Instance.new("TextLabel")
		Label.Size = UDim2.fromOffset(600, 100)
		Label.TextSize = 20
		Label.Text = Escaped

		Renderer = Api.new(Label):AddCustomClass("Tone", Tone(Green)):Flush()
	end)

	AfterAll(function()
		if Renderer then Renderer:Destroy() end
		if Label then Label:Destroy() end
	end)

	It("integration: RichTextPlus loads", function()
		Expect(Loaded).toBeTruthy()
	end)

	It("integration: no global RegisterClass", function()
		Expect(Api.RegisterClass).toBeNil()
	end)

	for _, Name: string in {"AddCustomTag", "AddStyleTag", "SetLinkHandler", "Classes"} do
		It(`integration: {Name} removed`, function()
			Expect(Api[Name]).toBeNil()
		end)
	end

	It("integration: chained AddCustomClass", function()
		Expect(Distance(Word(Renderer, "t") and Word(Renderer, "t").Color, Green)).toBeLessThan(0.002)
	end)

	It("integration: legacy tag not rendered", function()
		Expect(Render(Renderer)).never.toContain("[Legacy]")
	end)

	It("integration: class outside region unresolved", function()
		Expect(Word(Renderer, "out") and Word(Renderer, "out").Color ~= Green).toBeTruthy()
	end)

	It("integration: AddCustomClass replaces a class", function()
		Renderer:AddCustomClass("TONE", Tone(Blue)):Flush()
		Expect(Distance(Word(Renderer, "t") and Word(Renderer, "t").Color, Blue)).toBeLessThan(0.002)
	end)

	It("integration: AddCustomClass Style kind", function()
		Renderer:AddCustomClass("Styled", {Kind = "Style", Apply = function(Style: any) Style.Underline = true end}):Flush()
		Expect(Word(Renderer, "s") and Word(Renderer, "s").Underline).toBe(true)
	end)

	It("integration: AddCustomClass rejects a bare function", function()
		Expect(function() Renderer:AddCustomClass("fn", function() end) end).toThrow()
	end)

	It("integration: RemoveCustomClass exists", function()
		Removed = pcall(function() Renderer:RemoveCustomClass("tone"):Flush() end)
		Expect(Removed).toBe(true)
	end)

	It("integration: RemoveCustomClass unresolves", function()
		Expect(Removed and Word(Renderer, "t") and Word(Renderer, "t").Color ~= Blue).toBeTruthy()
	end)

	It("integration: SetPreset escapes", function()
		Renderer:SetPreset("Chat"):Flush()
		Expect(Render(Renderer)).toBe(Escaped)
	end)

	It("integration: SetFeature removed", function()
		Renderer:SetPreset("Default"):Flush()
		Expect(function() Renderer:SetFeature("CustomClasses", false) end).toThrow()
	end)

	It("integration: intents without CustomClasses", function()
		Renderer:SetIntents(Api.Intents.Presets.Default:Remove("CustomClasses")):Flush()
		Expect(Render(Renderer)).toBe("t s out [InlineImage]")
	end)

	It("integration: GetIntents follows SetIntents", function()
		Expect(Renderer:GetIntents():Has("CustomClasses")).toBe(false)
	end)
end)
