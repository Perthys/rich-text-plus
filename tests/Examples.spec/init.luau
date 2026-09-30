--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Classes = require("../Packages/RichTextPlus/Classes")
const Gui = require("./Support/Gui")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect
const BeforeAll = JestGlobals.beforeAll
const AfterAll = JestGlobals.afterAll

const REGION: string = [[watch <customclass><video src="rbxassetid://123" width="160" height="90"/></customclass> now]]

const Library: any = RichTextPlus
const Presets: any = Library.Intents.Presets
const Cleanup: { () -> () } = {}
local Screen: ScreenGui
local Copy: ModuleScript? = nil
local Loaded: boolean = false
local VideoClass: any = nil

const function Label(Text: string): TextLabel
	const Created: TextLabel = Instance.new("TextLabel")
	Created.Size = UDim2.fromOffset(400, 200)
	Created.TextSize = 18
	Created.TextWrapped = true
	Created.TextXAlignment = Enum.TextXAlignment.Left
	Created.TextYAlignment = Enum.TextYAlignment.Top
	Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
	Created.TextColor3 = Color3.new(1, 1, 1)
	Created.Text = Text
	Created.Parent = Screen

	return Created
end

const function Create(Target: TextLabel, Setup: ((any) -> ())?): any
	const Renderer: any = Library.new(Target):SetRendering("Passthrough", false)
	if Setup then Setup(Renderer) end
	Renderer:Flush()
	table.insert(Cleanup, function()
		Renderer:Destroy()
		Target:Destroy()
	end)

	return Renderer
end

const function Render(Text: string, Setup: ((any) -> ())?): (TextLabel, any)
	const Target: TextLabel = Label(Text)

	return Target, Create(Target, function(Built: any)
		Built:AddCustomClass("video", VideoClass):Flush()
		if Setup then Setup(Built) end
	end)
end

const function Videos(Target: TextLabel): { VideoFrame }
	const Found: { VideoFrame } = {}
	for _, Child: Instance in Target:GetChildren() do
		if Child:IsA("VideoFrame") then table.insert(Found, Child :: VideoFrame) end
	end

	return Found
end

const function First(Text: string, Setup: ((any) -> ())?): VideoFrame?
	const Target: TextLabel = Render(Text, Setup)

	return Videos(Target)[1]
end

const function Count(Text: string, Setup: ((any) -> ())?): number
	const Target: TextLabel = Render(Text, Setup)

	return #Videos(Target)
end

const function Shown(Target: TextLabel): string
	const Parts: { string } = {}
	for _, Child: Instance in Target:GetChildren() do
		if Child.Name == "Segment" and (Child :: GuiObject).Visible then table.insert(Parts, (Child :: TextLabel).Text) end
	end

	return table.concat(Parts, " ")
end

const function Wrap(Attributes: string): string
	return `<customclass><video {Attributes}/></customclass>`
end

const function Property(Video: VideoFrame?, Name: string): any
	return if Video then (Video :: any)[Name] else nil
end

BeforeAll(function()
	Screen = Gui.new("Examples")

	const Synced: Instance? = script:FindFirstChild("Examples")
	const Source: Instance? = if Synced then Synced:FindFirstChild("VideoClass") else nil
	if not Source then return end

	const Clone: ModuleScript = (Source :: ModuleScript):Clone()
	Clone.Parent = (script.Parent :: Instance).Parent
	Copy = Clone
	Loaded, VideoClass = pcall(require :: any, Clone)
end)

AfterAll(function()
	for _, Callback: () -> () in Cleanup do pcall(Callback) end
	if Copy then Copy:Destroy() end
	Gui.Cleanup()
end)

It("example loads next to Packages", function()
	Expect(if Copy then (if Loaded then "" else tostring(VideoClass)) else "examples/VideoClass.luau is not synced into Examples.spec/Examples").toBe("")
end)

Describe("definition", function()
	It("Object kind", function()
		Expect(VideoClass.Kind).toBe("Object")
	end)

	It("Build function", function()
		Expect(type(VideoClass.Build)).toBe("function")
	end)

	It("RichTextPlus.Utilities.Attribute exported", function()
		Expect(type(Library.Utilities.Attribute)).toBe("function")
	end)

	It("built-in video class removed", function()
		Expect(Classes.Has("Video")).toBe(false)
	end)

	It("Options table removed", function()
		const Target: TextLabel = Label("x")
		table.insert(Cleanup, function() Target:Destroy() end)

		Expect((pcall(Library.new, Target, {Features = {Videos = false}}))).toBe(false)
	end)
end)

Describe("region render", function()
	local Target: TextLabel
	local Found: { VideoFrame }
	local Video: VideoFrame

	BeforeAll(function()
		Target = Render(REGION)
		Found = Videos(Target)
		Video = Found[1]
	end)

	It("one video mounted", function()
		Expect(#Found).toBe(1)
	end)

	It("object name", function()
		Expect(Video.Name).toBe("InlineVideo")
	end)

	It("canonical asset id", function()
		Expect(Video.Video).toBe("rbxassetid://123")
	end)

	It("width attribute", function()
		Expect(Video.Size.X.Offset).toBe(160)
	end)

	It("height attribute", function()
		Expect(Video.Size.Y.Offset).toBe(90)
	end)

	It("paused by default", function()
		Expect(Video.Playing).toBe(false)
	end)

	It("silent by default", function()
		Expect(Video.Volume).toBe(0)
	end)

	It("loops by default", function()
		Expect(Video.Looped).toBe(true)
	end)

	It("laid out after the first word", function()
		Expect(Video.Position.X.Offset).toBeGreaterThan(0)
	end)

	It("marked as renderer object", function()
		Expect(Video:GetAttribute("RichTextPlus")).toBe(true)
	end)

	It("text around the video", function()
		Expect(Shown(Target)).toBe("watch now")
	end)
end)

Describe("renderer registration", function()
	local Target: TextLabel
	local Renderer: any
	local Built: VideoFrame?
	local Current: VideoFrame?

	BeforeAll(function()
		Target = Label(REGION)
		Renderer = Create(Target)
	end)

	It("unregistered class builds nothing", function()
		Expect(#Videos(Target)).toBe(0)
	end)

	It("AddCustomClass builds the video", function()
		Renderer:AddCustomClass("video", VideoClass):Flush()
		Built = Videos(Target)[1]

		Expect(Built).never.toBeNil()
	end)

	It("plain text edit keeps the video", function()
		Renderer.Label.Text = (string.gsub(REGION, "watch", "see"))
		Renderer:Flush()

		Expect(Videos(Target)[1]).toBe(Built)
	end)

	It("markup edit keeps exactly one video", function()
		Renderer.Label.Text = `<b>edited</b> {REGION}`
		Renderer:Flush()

		Expect(#Videos(Target)).toBe(1)
	end)

	It("markup edit rebuilds the video", function()
		Expect(Built ~= nil and (Built :: VideoFrame).Parent == nil).toBe(true)
	end)

	It("RemoveCustomClass drops the video", function()
		Current = Videos(Target)[1]
		Renderer:RemoveCustomClass("video"):Flush()

		Expect(#Videos(Target)).toBe(0)
	end)

	It("dropped video destroyed", function()
		Expect(Current ~= nil and (Current :: VideoFrame).Parent == nil).toBe(true)
	end)
end)

Describe("tag forms", function()
	local Shorthand: VideoFrame?
	local Upper: VideoFrame?
	local Outside: TextLabel

	BeforeAll(function()
		Shorthand = First('<customclass name="video" src="123" size="40"/>')
		Upper = First('<customclass><VIDEO SRC="7" Volume="0.25" PLAYING="yes"/></customclass>')
		Outside = Render('<video src="5"/> plain')
	end)

	It("shorthand builds", function()
		Expect(Property(Shorthand, "Video")).toBe("rbxassetid://123")
	end)

	It("uniform size", function()
		Expect(Property(Shorthand, "Size")).toBe(UDim2.fromOffset(40, 40))
	end)

	It("tag and attribute names case-insensitive", function()
		Expect(Property(Upper, "Volume")).toBe(0.25)
	end)

	It("any non-false flag enables", function()
		Expect(Property(Upper, "Playing")).toBe(true)
	end)

	It("default size from text size", function()
		Expect((First(Wrap('src="5"')) :: VideoFrame).Size).toBe(UDim2.fromOffset(23, 23))
	end)

	It("size follows SetScale", function()
		Expect((First(Wrap('src="5" size="40"'), function(Built: any) Built:SetScale(2) end) :: VideoFrame).Size.X.Offset).toBe(80)
	end)

	It("dimensions clamped", function()
		Expect((First(Wrap('src="5" width="99999" height="-3"')) :: VideoFrame).Size).toBe(UDim2.fromOffset(1024, 0))
	end)

	It("outside a region video is an unknown tag", function()
		Expect(#Videos(Outside)).toBe(0)
	end)

	It("outside a region content still renders", function()
		Expect(Shown(Outside)).toBe("plain")
	end)
end)

Describe("attributes", function()
	local Loud: VideoFrame?

	BeforeAll(function()
		Loud = First(Wrap('src="7" volume="10" playing="true" looped="false"'))
	end)

	It("volume capped at 1", function()
		Expect(Property(Loud, "Volume")).toBe(1)
	end)

	It("playing opt-in", function()
		Expect(Property(Loud, "Playing")).toBe(true)
	end)

	It("looped opt-out", function()
		Expect(Property(Loud, "Looped")).toBe(false)
	end)

	It("negative volume", function()
		Expect((First(Wrap('src="7" volume="-4"')) :: VideoFrame).Volume).toBe(0)
	end)

	It("junk volume", function()
		Expect((First(Wrap('src="7" volume="loud"')) :: VideoFrame).Volume).toBe(0)
	end)

	It("fractional volume", function()
		Expect((First(Wrap('src="7" volume="0.5"')) :: VideoFrame).Volume).toBe(0.5)
	end)

	It("playing off", function()
		Expect((First(Wrap('src="7" playing="off"')) :: VideoFrame).Playing).toBe(false)
	end)
end)

Describe("asset ids", function()
	local Allow: any

	BeforeAll(function()
		Allow = {["rbxassetid://111"] = true}
	end)

	It("asset url canonicalized", function()
		Expect(Property(First(Wrap('src="http://www.roblox.com/asset/?id=0111"')), "Video")).toBe("rbxassetid://111")
	end)

	It("script url rejected", function()
		Expect(First(Wrap('src="javascript:1"'))).toBeNil()
	end)

	It("foreign host rejected", function()
		Expect(First(Wrap('src="https://evil.example/x.mp4"'))).toBeNil()
	end)

	It("missing src builds nothing", function()
		Expect(First(Wrap(""))).toBeNil()
	end)

	It("allowlisted id built", function()
		Expect(Property(First(Wrap('src="111"'), function(Built: any) Built:SetAssetFilter(Allow) end), "Video")).toBe("rbxassetid://111")
	end)

	It("id outside the allowlist dropped", function()
		Expect(First(Wrap('src="222"'), function(Built: any) Built:SetAssetFilter(Allow) end)).toBeNil()
	end)
end)

Describe("policy", function()
	const Markup: string = Wrap('src="7"')
	local Chat: TextLabel

	BeforeAll(function()
		Chat = Render(Markup, function(Built: any) Built:SetPreset("Chat") end)
	end)

	It("Chat builds no video", function()
		Expect(#Videos(Chat)).toBe(0)
	end)

	It("Chat shows the markup literally", function()
		Expect(Shown(Chat)).toBe(Markup)
	end)

	It("Trusted admits registered classes", function()
		Expect(Count(Markup, function(Built: any) Built:SetPreset("Trusted") end)).toBe(1)
	end)

	It("CustomClasses missing denies the region", function()
		Expect(Count(Markup, function(Built: any) Built:SetPreset("Trusted"):SetIntents(Presets.Trusted:Remove("CustomClasses")) end)).toBe(0)
	end)

	It("Objects limit caps videos", function()
		Expect(Count(`<customclass><video src="7"/><video src="8"/></customclass>`, function(Built: any) Built:SetLimits({Objects = 1}) end)).toBe(1)
	end)

	It("customclass switched off builds no video", function()
		Expect(Count(Markup, function(Built: any) Built:SetIntents(Presets.Default:Remove("CustomClasses")) end)).toBe(0)
	end)
end)

Describe("teardown", function()
	It("destroy removes the video", function()
		const Target: TextLabel, Renderer: any = Render(REGION)
		const Video: VideoFrame? = Videos(Target)[1]
		Renderer:Destroy()

		Expect(Video ~= nil and (Video :: VideoFrame).Parent == nil).toBe(true)
	end)
end)
