--!strict

const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

type Build = {
	Name: string;
	Port: number;
	Profiling: boolean?;
}

const Port: number = 34900
const FolderName: string = "RichTextPlusBench"
const Only: { string } = {}
const Rounds: number = 5
const Scale: number = 1
const Detail: boolean = true
const Capture: boolean = false
const Prefix: string = "[RichTextPlus bench]"

const Builds: { Build } = {
	{Name = "local", Port = Port},
}

type Node = {
	Name: string;
	ClassName: string;
	Source: string?;
	Children: { Node };
}

type Timing = {
	Name: string;
	Calls: number;
	Total: number;
	Own: number;
	Max: number;
}

type Open = {
	Name: string;
	Enter: number;
	Child: number;
}

type Stage = {
	Name: string;
	Time: number;
	Calls: number;
	Share: number;
}

type Row = {
	Key: string;
	Name: string;
	Library: string;
	Samples: number;
	Median: number;
	Minimum: number;
	Normalized: number;
	Load: number;
	Controls: { number };
	Instances: number;
	Created: number;
	Stages: { Stage };
	Wrapped: number;
	Timings: { Timing };
	Captured: number;
}

type Kit = {
	API: any;
	Gui: ScreenGui;
	Label: (Text: string, Width: number, Height: number, Parent: Instance?) -> TextLabel;
	Own: (Object: Instance) -> ();
	Root: ModuleScript;
	Legacy: boolean;
	Builder: boolean;
	New: (Label: TextLabel, Classes: { [string]: any }?) -> any;
}

type Case = {
	Step: (Index: number) -> ();
	Prepare: ((Index: number) -> ())?;
	Finish: ((Index: number) -> ())?;
	Count: () -> number;
	Teardown: () -> ();
}

type Library = {
	Name: string;
	Root: ModuleScript;
	Kit: Kit;
}

type Scenario = {
	Key: string;
	Name: string;
	Iterations: number;
	Warmup: number;
	Build: (Kit: Kit) -> Case;
}

type Frame = { number }

type Tracker = {
	Totals: { [string]: number };
	Calls: { [string]: number };
	Enter: (Frame: Frame?) -> ();
	Calibrate: () -> { number };
	Install: (Overhead: { number }) -> ();
	Remove: () -> ();
}

const Mixed: string = [[<b>Welcome back</b>, <font color="#FF7800">traveler</font>! The <i>northern gate</i> opens at dawn and the <u>market square</u> fills with merchants selling <mark color="#FFD000">rare gems</mark>, old maps and <s>cheap</s> fair goods. Read the <a href="https://example.com/rules">event rules</a> before joining. The quick brown fox jumps over the lazy dog while the <b>arena</b> crowd cheers loudly for every brave challenger today. Stay safe out there, friend, and good luck tonight.]]
const Paragraph: string = [[<b>Welcome back</b>, <font color="#FF7800">traveler</font>! The <i>northern gate</i> opens at dawn and the <u>market square</u> fills with merchants selling <mark color="#FFD000">rare gems</mark>, old maps and <s>cheap</s> fair goods. Read the <a href="https://example.com/rules">event rules</a> before joining. The quick brown fox jumps over the lazy dog while the <b>arena</b> crowd cheers loudly for challenger {N} today. Stay safe out there, friend, and good luck tonight.]]
const Hud: string = [[Coins: <font color="#FFD000">{N}</font>]]
const Linked: string = string.rep([[See <a href="https://example.com/{N}">page {N}</a> and <b>bold <a href="x">nested link</a></b>, ]], 20)
const Plain: string = "Score: {N} points and some more words here"
const Burst: string = [[<b>Quest</b> update: gather <font color="#FFD000">twelve golden feathers</font> near the old mill, then read the <a href="https://example.com/quest">quest notes</a> before dusk falls #{N}]]

const Chat: { string } = {
	[[<b>[Player{N}]</b>: hello there, anyone want to trade?]],
	[[<b>[Player{N}]</b>: selling <font color="#FFCC00">gold</font> for 20 each]],
	[[<b>[Player{N}]</b>: <i>gg</i> that was a close round]],
	[[<b>[Player{N}]</b>: check the <a href="rules">rules</a> before joining]],
	[[<b>[Player{N}]</b>: lol no way you got the <mark>rare drop</mark> again]],
	[[<b>[Player{N}]</b>: meet at the arena in five minutes please]],
}

const Markdown: string = [[<md>
# Patch notes

Welcome to **season two**. This update brings *new maps*, balance changes and a `/trade` command for every player.

## Changes

- Faster matchmaking for **squads** and parties
- New weapon: *Arc Rifle* with a charged shot
- Fixed a crash when opening the `inventory` twice

> Tip: press **F** to open the quick menu at any time.

```lua
local Players = game:GetService("Players")

local function OnJoin(Player: Player)
	print(`Welcome {Player.Name}!`)
	for Index = 1, 10 do
		task.wait(0.5)
	end
end

Players.PlayerAdded:Connect(OnJoin)
```

---

1. Read the [rules](https://example.com/rules) first
2. Join a **squad** of up to four players
3. Have fun and report bugs
</md>]]

const Vocabulary: { string } = string.split("the of and to in is you that it he was for on are as with his they at be this have from or one had by word but not what all were we when your can said there use an each which she do how their if will up other about out many then them these so some her would make like him into time has look two more write go see number no way could people my than first water been call who its now find long down day did get come made may part over new sound take only little work know place year live me back give most very after thing our just name good man think say great where help through much before line right too mean old any same tell boy follow came want show also around form three small set put end does another well large must big even such because turn here why ask went men read need land different home us move try kind hand picture again change off play spell air away animal house point page letter mother answer found study still learn should world", " ")

const Wraps: { { string } } = {
	{"@XML", "GenerateTreeFromXML", "xml parse"},
	{"Markdown/Embed", "Preprocess", "markdown preprocess"},
	{"Markdown", "ToTree", "markdown tree"},
	{"Markdown/Blocks", "Parse", "markdown blocks"},
	{"Markdown/Emit", "Document", "markdown emit"},
	{"Text/Highlighter", "Highlight", "syntax highlight"},
	{"Core/Flatten", "Run", "flatten"},
	{"Core/Flatten", "Tokenize", "flatten tokenize"},
	{"Core/Incremental", "Patch", "incremental patch"},
	{"Core/Native", "Markup", "native markup"},
	{"Core/Native", "Enter", "native enter"},
	{"Core/Native", "Release", "native release"},
	{"Core/Native", "Suppress", "native host rich text"},
	{"Core/Native", "Restore", "native host rich text"},
	{"Core/Scale", "Solve", "scale solve"},
	{"Core/Scale", "Enforce", "scale enforce"},
	{"Core/Scale", "Fit", "scale fit"},
	{"Text/Measure", "Run", "measure run"},
	{"Text/Measure", "Fill", "measure fill"},
	{"Text/Measure", "Split", "measure split"},
	{"Text/Measure", "Bounds", "measure bounds"},
	{"Text/Glyphs", "Estimate", "glyph estimate"},
	{"Text/Glyphs", "Record", "glyph record"},
	{"Core/Lines", "Compute", "lines compute"},
	{"Core/Layout", "Run", "layout run"},
	{"Utility/Reflow", "Fit", "reflow"},
	{"Utility/Reflow", "Commit", "reflow"},
	{"Render/Pool", "Assign", "pool assign"},
	{"Render/Pool", "Clear", "pool clear"},
	{"Render/Pool", "Root", "backdrop root"},
	{"Render/Segment", "Apply", "segment apply"},
	{"Render/Segment", "Place", "segment place"},
	{"Render/Segment", "Create", "segment create"},
	{"Render/Segment", "Adopt", "segment adopt"},
	{"Render/Segment", "Reset", "segment reset"},
	{"Render/Segment", "Collect", "decoration collect"},
	{"Render/Segment", "ApplyTransparency", "segment transparency"},
	{"Render/Backdrop", "Assign", "backdrop assign"},
	{"Render/Reveal", "Apply", "reveal"},
	{"Text/Unicode", "Count", "unicode count"},
	{"Utility/Styles", "AncestorScale", "styles geometry"},
	{"Utility/Styles", "LocalSize", "styles geometry"},
	{"Utility/Styles", "ContentSize", "styles geometry"},
	{"Utility/Styles", "Base", "styles base"},
	{"Render/Registry", "Add", "registry"},
	{"Render/Registry", "Abandon", "registry"},
	{"Render/Registry", "Wake", "registry"},
	{"Render/Schedule", "Queue", "schedule"},
	{"Render/Schedule", "Take", "schedule"},
	{"Render/Schedule", "Drain", "schedule"},
	{"Render/Culling", "Step", "culling"},
	{"Render/Culling", "Release", "culling"},
	{"Render/Animate", "Step", "animate"},
	{"Policy/Rendering", "Resolve", "options resolve"},
	{"Policy/Intents", "Check", "options resolve"},
	{"Policy/Limits", "Resolve", "options resolve"},
	{"Classes", "Clear", "classes"},
	{"Classes", "Register", "classes"},
}

local Sink: number = 0

const function Fill(Template: string, Index: number): string
	return (string.gsub(Template, "{N}", tostring(Index)))
end

const function Median(List: { number }): number
	const Copy: { number } = table.clone(List)
	table.sort(Copy)

	const Count: number = #Copy
	if Count == 0 then return 0 end
	if Count % 2 == 1 then return Copy[(Count + 1) // 2] end

	return (Copy[Count // 2] + Copy[Count // 2 + 1]) / 2
end

const function Minimum(List: { number }): number
	local Best: number = math.huge

	for _, Value: number in (List) do
		if Value < Best then Best = Value end
	end

	return Best
end

const function Control(): number
	const Start: number = os.clock()
	const List: { number } = table.create(256, 0)

	local Sum: number = 0

	for Round = 1, 24 do
		for Index = 1, 256 do List[Index] = (Index * 7919 + Round * 104729) % 1009 end

		table.sort(List)
		Sum += List[128]
	end

	Sink = Sum

	return os.clock() - Start
end

const function Probe(): number
	local Best: number = math.huge

	for _ = 1, 3 do Best = math.min(Best, Control()) end

	return Best
end

const function Engine(Gui: ScreenGui): { number }
	const Rich: { number } = {}
	const Plain: { number } = {}
	const Churn: { number } = {}
	const Salt: string = string.format("%.6f", os.clock())

	const Target: TextLabel = Instance.new("TextLabel")
	Target.AutoLocalize = false
	Target.RichText = true
	Target.Parent = Gui

	for Index = 1, 12 do
		local Start: number = os.clock()
		Target.Text = `<b>probe</b> {Salt} {Index}`
		table.insert(Rich, os.clock() - Start)

		Start = os.clock()
		Target.Text = `probe {Salt} {Index}`
		table.insert(Plain, os.clock() - Start)

		Start = os.clock()
		const Created: TextLabel = Instance.new("TextLabel")
		Created.Parent = Gui
		Created:Destroy()
		table.insert(Churn, os.clock() - Start)
	end

	Target:Destroy()

	return {Median(Rich), Median(Plain), Median(Churn)}
end

const function BigDocument(Size: number): string
	const Generator: Random = Random.new(20260926)
	const Parts: { string } = {}

	local Length: number = 0
	local Count: number = 0

	while Length < Size do
		Count += 1

		const Words: { string } = table.create(60)

		for Index = 1, 60 do
			const Word: string = Vocabulary[Generator:NextInteger(1, #Vocabulary)]
			const Roll: number = Generator:NextNumber()

			Words[Index] = if Roll < 0.04 then `<b>{Word}</b>` elseif Roll < 0.08 then `<i>{Word}</i>` elseif Roll < 0.1 then `<font color="#7FD4FF">{Word}</font>` else Word
		end

		if Count % 4 == 0 then Words[30] = `<a href="https://example.com/{Count}">{Words[30]}</a>` end
		if Count % 5 == 0 then Words[12] = `<mark color="#FFD000">{Words[12]}</mark>` end

		const Text: string = table.concat(Words, " ")
		table.insert(Parts, Text)
		Length += #Text + 2
	end

	return table.concat(Parts, "\n\n")
end

const function Descendants(Targets: { Instance }): number
	local Total: number = 0

	for _, Target: Instance in (Targets) do Total += #Target:GetDescendants() end

	return Total
end

const function Creation(Kit: Kit, Make: (Index: number) -> TextLabel): Case
	local Label: TextLabel? = nil
	local Renderer: any = nil

	return {
		Prepare = function(Index: number): ()
			Label = Make(Index)
		end;
		Step = function(_Index: number): ()
			Renderer = Kit.New(Label)
		end;
		Finish = function(_Index: number): ()
			if Renderer then Renderer:Destroy() end
			if Label then (Label :: TextLabel):Destroy() end

			Renderer = nil
			Label = nil
		end;
		Count = function(): number
			const Probe: TextLabel = Make(0)
			const Built: any = Kit.New(Probe)
			const Total: number = #Probe:GetDescendants()

			Built:Destroy()
			Probe:Destroy()

			return Total
		end;
		Teardown = function(): () end;
	}
end

const function Churn(Kit: Kit, Make: (Index: number) -> TextLabel): Case
	local Label: TextLabel? = nil

	return {
		Prepare = function(Index: number): ()
			Label = Make(Index)
		end;
		Step = function(_Index: number): ()
			Kit.New(Label):Destroy()
		end;
		Finish = function(_Index: number): ()
			if Label then (Label :: TextLabel):Destroy() end

			Label = nil
		end;
		Count = function(): number
			const Probe: TextLabel = Make(0)
			const Built: any = Kit.New(Probe)
			const Total: number = #Probe:GetDescendants()

			Built:Destroy()
			Probe:Destroy()

			return Total
		end;
		Teardown = function(): () end;
	}
end

const Hot: any = {Kind = "Style", Apply = function(Style: any) Style.Bold = true end}
const Tint: Color3 = Color3.fromRGB(255, 120, 0)
const Palette: any = {CodeBackground = Color3.fromRGB(20, 22, 28)}

const function Configure(Kit: Kit, Label: TextLabel): any
	if not Kit.Builder then
		const Legacy: any = Kit.API.new(Label, {
			Permissions = "Trusted";
			Scale = 1.25;
			LinkColor = Tint;
			Theme = Palette;
			Whitespace = "Markup";
			Rendering = {Culling = false};
			CustomClasses = {hot = Hot};
		})
		Legacy:Flush()

		return Legacy
	end

	const Created: any = Kit.API.new(Label)
	const Class: any = getmetatable(Created)
	if rawget(Class, "SetPreset") then Created:SetPreset("Trusted") else Created:SetPermissions("Trusted") end

	if rawget(Class, "Bind") then Created:SetTheme({CodeBackground = Palette.CodeBackground, LinkColor = Tint}) else Created:SetLinkColor(Tint):SetTheme(Palette) end

	return Created
		:SetScale(1.25)
		:SetWhitespace("Markup")
		:SetRendering("Culling", false)
		:AddCustomClass("hot", Hot)
		:Flush()
end

const function Configured(Kit: Kit, Make: (Index: number) -> TextLabel): Case
	local Label: TextLabel? = nil

	return {
		Prepare = function(Index: number): ()
			Label = Make(Index)
		end;
		Step = function(_Index: number): ()
			Configure(Kit, Label :: TextLabel):Destroy()
		end;
		Finish = function(_Index: number): ()
			if Label then (Label :: TextLabel):Destroy() end

			Label = nil
		end;
		Count = function(): number
			const Probe: TextLabel = Make(0)
			const Built: any = Configure(Kit, Probe)
			const Total: number = #Probe:GetDescendants()

			Built:Destroy()
			Probe:Destroy()

			return Total
		end;
		Teardown = function(): () end;
	}
end

const function Updating(Kit: Kit, Label: TextLabel, Template: string): Case
	const Renderer: any = Kit.New(Label)

	return {
		Step = function(Index: number): ()
			Label.Text = Fill(Template, Index)
			Renderer:Flush()
		end;
		Count = function(): number
			return Descendants({Label})
		end;
		Teardown = function(): ()
			Renderer:Destroy()
			Label:Destroy()
		end;
	}
end

const function Frames(Kit: Kit, Width: number, Height: number): ScrollingFrame
	const Holder: ScrollingFrame = Instance.new("ScrollingFrame")
	Holder.Size = UDim2.fromOffset(Width, Height)
	Holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Holder.CanvasSize = UDim2.new()
	Holder.BackgroundTransparency = 1

	const List: UIListLayout = Instance.new("UIListLayout")
	List.SortOrder = Enum.SortOrder.LayoutOrder
	List.Parent = Holder

	Holder.Parent = Kit.Gui
	Kit.Own(Holder)
	Kit.Own(List)

	return Holder
end

const Big: string = BigDocument(50000)
const AnimatedCount: number = 200

const function Tagged(Open: string, Close: string): string
	const Parts: { string } = {}

	for Index = 1, AnimatedCount do Parts[Index] = `{Open}w{Index}{Close}` end

	return table.concat(Parts, " ")
end

const function Animated(Kit: Kit, Markup: string, Classes: { [string]: any }?): Case
	const Label: TextLabel = Kit.Label(Markup, 900, 700)
	const Renderer: any = Kit.New(Label, Classes)
	const Driver: any = require((Kit.Root :: any).Renderer.Driver)

	Renderer:Flush()

	return {
		Step = function(_Index: number): ()
			Driver.Tick(Renderer, 1 / 60)
		end;
		Count = function(): number
			return #Renderer.Animation.Moving
		end;
		Teardown = function(): ()
			Renderer:Destroy()
			Label:Destroy()
		end;
	}
end

const function Bounce(Kit: Kit): any
	if Kit.Legacy then
		return {Kind = "Effect", Update = function(Time: number, Effect: any, Seed: number): Vector2
			return Vector2.new(0, -math.abs(math.sin(Time * Effect.Frequency + Seed)) * Effect.Amplitude)
		end}
	end

	return {Kind = "Effect", Update = function(Frame: any): ()
		Frame.Offset = Vector2.new(0, -math.abs(math.sin(Frame.Time * Frame.Frequency + Frame.Seed)) * Frame.Amplitude)
	end}
end

const function Rainbow(Kit: Kit): any
	if Kit.Legacy then
		return {Kind = "Effect", Update = function(): Vector2 return Vector2.zero end}
	end

	return {Kind = "Effect", Update = function(Frame: any): ()
		Frame.Color = Color3.fromHSV((Frame.Time * 0.5 + Frame.Seed) % 1, 0.8, 1)
	end}
end

const Scenarios: { Scenario } = {
	{
		Key = "effectswave";
		Name = "effects: 200 wave segments";
		Iterations = 120;
		Warmup = 20;
		Build = function(Kit: Kit): Case
			return Animated(Kit, Tagged("<wave>", "</wave>"), nil)
		end;
	},
	{
		Key = "effectsbounce";
		Name = "effects: 200 custom offset";
		Iterations = 120;
		Warmup = 20;
		Build = function(Kit: Kit): Case
			return Animated(Kit, `<customclass>{Tagged("<bounce>", "</bounce>")}</customclass>`, {bounce = Bounce(Kit)})
		end;
	},
	{
		Key = "effectscolor";
		Name = "effects: 200 custom color";
		Iterations = 120;
		Warmup = 20;
		Build = function(Kit: Kit): Case
			return Animated(Kit, `<customclass>{Tagged("<rainbow>", "</rainbow>")}</customclass>`, {rainbow = Rainbow(Kit)})
		end;
	},
	{
		Key = "links";
		Name = "40 links Text+Flush";
		Iterations = 60;
		Warmup = 10;
		Build = function(Kit: Kit): Case
			return Updating(Kit, Kit.Label(Fill(Linked, 0), 600, 400), Linked)
		end;
	},
	{
		Key = "hud";
		Name = "HUD counter Text+Flush";
		Iterations = 200;
		Warmup = 40;
		Build = function(Kit: Kit): Case
			return Updating(Kit, Kit.Label(Fill(Hud, 0), 220, 32), Hud)
		end;
	},
	{
		Key = "paragraph";
		Name = "paragraph edit Text+Flush";
		Iterations = 120;
		Warmup = 20;
		Build = function(Kit: Kit): Case
			return Updating(Kit, Kit.Label(Fill(Paragraph, 0), 400, 300), Paragraph)
		end;
	},
	{
		Key = "rebuild";
		Name = "rebuild 60-word mixed";
		Iterations = 80;
		Warmup = 15;
		Build = function(Kit: Kit): Case
			const Label: TextLabel = Kit.Label(Mixed, 400, 300)
			const Renderer: any = Kit.New(Label)

			return {
				Step = function(_Index: number): ()
					Renderer:Rebuild()
				end;
				Count = function(): number
					return Descendants({Label})
				end;
				Teardown = function(): ()
					Renderer:Destroy()
					Label:Destroy()
				end;
			}
		end;
	},
	{
		Key = "relayout";
		Name = "relayout on resize";
		Iterations = 120;
		Warmup = 20;
		Build = function(Kit: Kit): Case
			const Label: TextLabel = Kit.Label(Mixed, 400, 300)
			const Renderer: any = Kit.New(Label)

			return {
				Prepare = function(Index: number): ()
					Label.Size = UDim2.fromOffset(if Index % 2 == 0 then 400 else 330, 300)

					const _Size: Vector2 = Label.AbsoluteSize
				end;
				Step = function(_Index: number): ()
					Renderer:Flush()
				end;
				Count = function(): number
					return Descendants({Label})
				end;
				Teardown = function(): ()
					Renderer:Destroy()
					Label:Destroy()
				end;
			}
		end;
	},
	{
		Key = "scaled";
		Name = "TextScaled resize";
		Iterations = 60;
		Warmup = 10;
		Build = function(Kit: Kit): Case
			const Label: TextLabel = Kit.Label(Mixed, 300, 120)
			Label.TextScaled = true

			const Renderer: any = Kit.New(Label)

			return {
				Prepare = function(Index: number): ()
					Label.Size = UDim2.fromOffset(if Index % 2 == 0 then 300 else 262, 120)

					const _Size: Vector2 = Label.AbsoluteSize
				end;
				Step = function(_Index: number): ()
					Renderer:Flush()
				end;
				Count = function(): number
					return Descendants({Label})
				end;
				Teardown = function(): ()
					Renderer:Destroy()
					Label:Destroy()
				end;
			}
		end;
	},
	{
		Key = "burst";
		Name = "150-label resize burst";
		Iterations = 12;
		Warmup = 3;
		Build = function(Kit: Kit): Case
			const Holder: ScrollingFrame = Frames(Kit, 560, 480)
			const Labels: { TextLabel } = {}
			const Renderers: { any } = {}

			for Index = 1, 150 do
				const Label: TextLabel = Kit.Label(Fill(Burst, Index), 0, 0, Holder)
				Label.Size = UDim2.new(1, -12, 0, 64)
				Label.TextSize = 16
				Label.LayoutOrder = Index
				Labels[Index] = Label
			end

			const _Size: Vector2 = Holder.AbsoluteSize

			for Index: number, Label: TextLabel in (Labels) do Renderers[Index] = Kit.New(Label) end

			return {
				Prepare = function(Index: number): ()
					Holder.Size = UDim2.fromOffset(if Index % 2 == 0 then 560 else 420, 480)

					for _, Label: TextLabel in (Labels) do const _Width: Vector2 = Label.AbsoluteSize end
				end;
				Step = function(_Index: number): ()
					for _, Renderer: any in (Renderers) do Renderer:Flush() end
				end;
				Count = function(): number
					return Descendants(Labels :: { any })
				end;
				Teardown = function(): ()
					for _, Renderer: any in (Renderers) do Renderer:Destroy() end

					Holder:Destroy()
				end;
			}
		end;
	},
	{
		Key = "churn";
		Name = "create/destroy churn (chat)";
		Iterations = 150;
		Warmup = 30;
		Build = function(Kit: Kit): Case
			return Churn(Kit, function(Index: number): TextLabel
				return Kit.Label(Fill(Chat[Index % #Chat + 1], Index), 420, 40)
			end)
		end;
	},
	{
		Key = "configured";
		Name = "new + 7 settings + render (chat)";
		Iterations = 150;
		Warmup = 30;
		Build = function(Kit: Kit): Case
			return Configured(Kit, function(Index: number): TextLabel
				return Kit.Label(`<customclass><hot>hey</hot></customclass> {Fill(Chat[Index % #Chat + 1], Index)}`, 420, 40)
			end)
		end;
	},
	{
		Key = "markdown";
		Name = "markdown doc with code (new)";
		Iterations = 24;
		Warmup = 6;
		Build = function(Kit: Kit): Case
			return Creation(Kit, function(_Index: number): TextLabel
				const Label: TextLabel = Kit.Label(Markdown, 480, 0)
				Label.AutomaticSize = Enum.AutomaticSize.Y

				return Label
			end)
		end;
	},
	{
		Key = "native";
		Name = "native plain Text+Flush";
		Iterations = 200;
		Warmup = 40;
		Build = function(Kit: Kit): Case
			return Updating(Kit, Kit.Label(Fill(Plain, 0), 360, 40), Plain)
		end;
	},
	{
		Key = "nativenew";
		Name = "native plain new+Destroy";
		Iterations = 150;
		Warmup = 30;
		Build = function(Kit: Kit): Case
			return Churn(Kit, function(Index: number): TextLabel
				return Kit.Label(Fill(Plain, Index), 360, 40)
			end)
		end;
	},
	{
		Key = "big";
		Name = "50KB document (new)";
		Iterations = 2;
		Warmup = 1;
		Build = function(Kit: Kit): Case
			const Holder: ScrollingFrame = Frames(Kit, 600, 500)

			return Creation(Kit, function(_Index: number): TextLabel
				const Label: TextLabel = Kit.Label(Big, 588, 0, Holder)
				Label.AutomaticSize = Enum.AutomaticSize.Y

				return Label
			end)
		end;
	},
	{
		Key = "bigrelayout";
		Name = "50KB document relayout";
		Iterations = 4;
		Warmup = 1;
		Build = function(Kit: Kit): Case
			const Holder: ScrollingFrame = Frames(Kit, 600, 500)
			const Label: TextLabel = Kit.Label(Big, 0, 0, Holder)
			Label.Size = UDim2.new(1, -12, 0, 0)
			Label.AutomaticSize = Enum.AutomaticSize.Y

			const Renderer: any = Kit.New(Label)

			return {
				Prepare = function(Index: number): ()
					Holder.Size = UDim2.fromOffset(if Index % 2 == 0 then 600 else 520, 500)

					const _Size: Vector2 = Label.AbsoluteSize
				end;
				Step = function(_Index: number): ()
					Renderer:Flush()
				end;
				Count = function(): number
					return Descendants({Label})
				end;
				Teardown = function(): ()
					Renderer:Destroy()
					Holder:Destroy()
				end;
			}
		end;
	},
}

const function Construct(API: any, Builder: boolean, Label: TextLabel, Classes: { [string]: any }?): any
	if not Builder then
		const Legacy: any = API.new(Label, if Classes then {CustomClasses = Classes} else nil)
		Legacy:Flush()

		return Legacy
	end

	const Renderer: any = API.new(Label)
	if Classes then Renderer:AddCustomClasses(Classes) end
	Renderer:Flush()

	return Renderer
end

const function Resolve(Root: Instance, Path: string): any
	if Path == "@XML" then
		const Found: Instance? = if Root.Parent then (Root.Parent :: Instance):FindFirstChild("XML") else nil
		return if Found and Found:IsA("ModuleScript") then require(Found :: any) else nil
	end

	local Current: Instance? = Root

	for _, Part: string in (string.split(Path, "/")) do
		Current = if Current then (Current :: Instance):FindFirstChild(Part) else nil
	end

	return if Current and Current:IsA("ModuleScript") then require(Current :: any) else nil
end

const function Drain(Library: Library): ()
	const Pool: any = Resolve(Library.Root, "Render/Pool")
	const Runtime: any = Library.Kit.API.Runtime or Library.Kit.API
	if type(Pool) ~= "table" or type(Pool.Limit) ~= "function" or type(Runtime.SetPoolLimit) ~= "function" then return end

	const Limit: number = Pool.Limit()

	Runtime.SetPoolLimit(0)
	Runtime.SetPoolLimit(Limit)
end

const function Tracker(Root: Instance?): Tracker
	const Totals: { [string]: number } = {}
	const Calls: { [string]: number } = {}
	const Frames: { Frame } = {}
	const Restores: { () -> () } = {}

	local Depth: number = 0
	local Active: boolean = false
	local Inside: number = 0
	local Outside: number = 0

	const function Enter(Frame: Frame?): ()
		Active = Frame ~= nil
		Depth = if Frame then 1 else 0

		if Frame then Frames[1] = Frame :: Frame end
	end

	const function Push(): Frame
		Depth += 1

		const Opened: Frame = Frames[Depth] or {0, 0}
		Frames[Depth] = Opened
		Opened[2] = 0
		Opened[1] = os.clock()

		return Opened
	end

	const function Pop(Frame: Frame, Name: string): ()
		const Elapsed: number = os.clock() - Frame[1]

		Depth -= 1

		Totals[Name] = (Totals[Name] or 0) + Elapsed - Frame[2] - Inside
		Calls[Name] = (Calls[Name] or 0) + 1

		if Depth > 0 then Frames[Depth][2] += Elapsed + Outside end
	end

	const function Close(Frame: Frame, Name: string, ...: any): ...any
		Pop(Frame, Name)

		return ...
	end

	const function Wrap(Module: any, Key: string, Name: string): ()
		const Original: any = Module[Key]
		if type(Original) ~= "function" then return end

		const Wrapped = function(...: any): ...any
			if not Active then return Original(...) end

			const Frame: Frame = Push()

			return Close(Frame, Name, Original(...))
		end

		if not pcall(function() Module[Key] = Wrapped end) then return end

		table.insert(Restores, function() Module[Key] = Original end)
	end

	const function Label(Module: any): ()
		if type(Module) ~= "table" or type(Module.Begin) ~= "function" then return end

		const Saved: { [string]: any } = {}
		const Opened: { { any } } = {}

		for _, Key: string in ({"Begin", "End", "Depth", "Unwind", "Suspend", "Resume", "Enabled"}) do Saved[Key] = Module[Key] end

		const function Finish(): ()
			const Entry: { any }? = table.remove(Opened)
			if Entry and Entry[1] then Pop(Entry[1], Entry[2]) end
		end

		Module.Begin = function(Name: string): ()
			const Entry: { any } = {if Active then Push() else false, Name}
			table.insert(Opened, Entry)
		end
		Module.End = Finish
		Module.Depth = function(): number return #Opened end
		Module.Unwind = function(Level: number): ()
			while #Opened > Level do Finish() end
		end
		Module.Suspend = function(): () end
		Module.Resume = function(): () end
		Module.Enabled = true

		table.insert(Restores, function()
			for Key: string, Value: any in (Saved) do Module[Key] = Value end
		end)
	end

	const function Calibrate(): { number }
		const Target = {Noop = function(): () end}
		const Raw: () -> () = Target.Noop
		const Count: number = 4000

		Wrap(Target, "Noop", "(calibration)")

		const Wrapped: () -> () = Target.Noop

		local BestRaw: number, BestWrapped: number, BestInside: number = math.huge, math.huge, math.huge

		for _ = 1, 15 do
			local Start: number = os.clock()
			for _ = 1, Count do Raw() end
			BestRaw = math.min(BestRaw, os.clock() - Start)

			Totals["(calibration)"] = 0
			Enter({0, 0})

			Start = os.clock()
			for _ = 1, Count do Wrapped() end
			BestWrapped = math.min(BestWrapped, os.clock() - Start)
			BestInside = math.min(BestInside, Totals["(calibration)"])

			Enter(nil)
		end

		for Index = #Restores, 1, -1 do Restores[Index]() end

		table.clear(Restores)
		Totals["(calibration)"] = nil
		Calls["(calibration)"] = nil

		const Measured: number = BestInside / Count

		return {Measured, math.max((BestWrapped - BestRaw) / Count - Measured, 0)}
	end

	const function Install(Overhead: { number }): ()
		Inside = Overhead[1]
		Outside = Overhead[2]

		if not Root then return end

		const Target: Instance = Root :: Instance

		for _, Entry: { string } in (Wraps) do
			const Module: any = Resolve(Target, Entry[1])
			if type(Module) == "table" then Wrap(Module, Entry[2], Entry[3]) end
		end

		Label(Resolve(Target, "Utility/Profiler"))

		const Classes: Instance? = Target:FindFirstChild("Classes")
		const Children: { Instance } = if Classes then (Classes :: Instance):GetChildren() else {}

		for _, Child: Instance in (Children) do
			if not Child:IsA("ModuleScript") then continue end

			const Ok: boolean, Module: any = pcall(require, Child)
			if Ok and type(Module) == "table" then Wrap(Module, "Build", `class build {string.lower(Child.Name)}`) end
		end
	end

	const function Remove(): ()
		for Index = #Restores, 1, -1 do Restores[Index]() end

		table.clear(Restores)
	end

	return {
		Totals = Totals;
		Calls = Calls;
		Enter = Enter;
		Calibrate = Calibrate;
		Install = Install;
		Remove = Remove;
	}
end

const function Breakdown(Root: Instance, Case: Case, Iterations: number, Counter: { number }, Overhead: { number }): ({ Stage }, number)
	const Probe: Tracker = Tracker(Root)
	const Totals: { [string]: number } = Probe.Totals
	const Calls: { [string]: number } = Probe.Calls
	const Enter: (Frame: Frame?) -> () = Probe.Enter

	const Elapsed: { number } = {}
	const Deltas: { { [string]: number } } = {}
	const Counts: { { [string]: number } } = {}
	const Previous: { [string]: number } = {}
	const Called: { [string]: number } = {}

	Probe.Install(Overhead)

	const Ok: boolean, Problem: any = pcall(function()
		for Iteration = 1, Iterations do
			Counter[1] += 1

			const Index: number = Counter[1]
			if Case.Prepare then (Case.Prepare :: (number) -> ())(Index) end

			const Frame: Frame = {os.clock(), 0}
			Enter(Frame)
			Case.Step(Index)

			const Spent: number = os.clock() - Frame[1]
			Enter(nil)

			Elapsed[Iteration] = Spent
			Totals["(unattributed)"] = (Totals["(unattributed)"] or 0) + Spent - Frame[2]
			Calls["(unattributed)"] = (Calls["(unattributed)"] or 0) + 1

			const Delta: { [string]: number } = {}
			const Count: { [string]: number } = {}

			for Name: string, Time: number in (Totals) do
				Delta[Name] = Time - (Previous[Name] or 0)
				Count[Name] = Calls[Name] - (Called[Name] or 0)
				Previous[Name] = Time
				Called[Name] = Calls[Name]
			end

			Deltas[Iteration] = Delta
			Counts[Iteration] = Count

			if Case.Finish then (Case.Finish :: (number) -> ())(Index) end
		end
	end)

	Probe.Remove()

	if not Ok then error(Problem, 0) end

	const Sorted: { number } = table.clone(Elapsed)
	table.sort(Sorted)

	const Ceiling: number = Sorted[math.max(math.ceil(#Sorted * 0.9), 1)]
	const Kept: { [string]: number } = {}
	const Made: { [string]: number } = {}

	local Total: number = 0
	local Used: number = 0

	for Iteration: number, Spent: number in (Elapsed) do
		if Spent > Ceiling then continue end

		Used += 1
		Total += Spent

		for Name: string, Time: number in (Deltas[Iteration]) do
			Kept[Name] = (Kept[Name] or 0) + math.max(Time, 0)
			Made[Name] = (Made[Name] or 0) + Counts[Iteration][Name]
		end
	end

	const Stages: { Stage } = {}
	local Attributed: number = 0

	for _, Time: number in (Kept) do Attributed += Time end

	for Name: string, Time: number in (Kept) do
		table.insert(Stages, {
			Name = Name;
			Time = Time / Used;
			Calls = Made[Name] / Used;
			Share = if Attributed > 0 then Time / Attributed else 0;
		})
	end

	table.sort(Stages, function(Left: Stage, Right: Stage): boolean return Left.Time > Right.Time end)

	return Stages, Total / math.max(Used, 1)
end

type Harvest = {
	Marker: string;
	Last: number;
	Markers: number;
	Found: { [string]: Timing };
}

const function Collect(LibMP: any, Into: Harvest): ()
	const Session: any = LibMP.Session.OpenFromBuffer(LibMP.Control:CaptureToBufferSync())
	if not Session then return end

	local Last: number = Session:GetFrameIdMax()
	const First: number = math.max(Session:GetFrameIdMin(), Into.Last + 1)

	if Last > 0 and Session:FetchFrameDesc(Last).IsIncomplete then Last -= 1 end
	if First <= 0 or First > Last then Session:Dispose(); return end

	Into.Last = Last

	const Ids: { number } = Session:FindTimerIds("::RTP*", false)
	const Names: { [number]: string } = {}

	for _, Id: number in (Ids) do Names[Id] = string.sub(Session:FetchTimerDesc(Id).TimerName, 3) end

	const Ticks: number = Session:FetchGlobalDesc().TickToMsCpu
	const Iterator: any = Session:CreateLogIterator()
	Iterator:Configure({SkipGpuThreads = true, SkipEvents = true, TimerIds = Ids, StartFrameId = First, EndFrameId = Last})

	const State: any = Iterator:GetState()
	const Stacks: { [number]: { Open } } = {}
	const Depths: { [number]: number } = {}
	const Found: { [string]: Timing } = Into.Found
	const Marker: string = Into.Marker

	while Iterator:Step() do
		const Thread: number = State:ThreadId()
		const Stack: { Open } = Stacks[Thread] or {}
		Stacks[Thread] = Stack

		if State:IsEnter() then
			const Name: string = Names[State:TimerId()] or ""

			table.insert(Stack, {Name = Name, Enter = State:Timestamp(), Child = 0})
			if Name == Marker then Depths[Thread] = (Depths[Thread] or 0) + 1 end

			continue
		end

		if not State:IsExit() then continue end

		const Closed: Open? = table.remove(Stack)
		if not Closed then continue end

		const Duration: number = (State:Timestamp() - (Closed :: Open).Enter) * Ticks
		const Name: string = (Closed :: Open).Name
		const Parent: Open? = Stack[#Stack]

		if Parent then (Parent :: Open).Child += Duration end

		if Name == Marker then
			Depths[Thread] = (Depths[Thread] or 1) - 1
			Into.Markers += 1

			continue
		end

		if (Depths[Thread] or 0) <= 0 or string.sub(Name, 1, 4) ~= "RTP:" then continue end

		const Entry: Timing = Found[Name] or {Name = Name, Calls = 0, Total = 0, Own = 0, Max = 0}
		Found[Name] = Entry

		Entry.Calls += 1
		Entry.Total += Duration
		Entry.Own += Duration - (Closed :: Open).Child
		if Duration > Entry.Max then Entry.Max = Duration end
	end

	Iterator:Dispose()
	Session:Dispose()
end

const function Sample(Library: Library, Case: Case, Iterations: number, Counter: { number }, Key: string): ({ Timing }, number)
	const Toggle: any = (Library.Kit.API.Runtime or Library.Kit.API).SetProfiling
	const Loaded: boolean, LibMP: any = pcall(require, "@rbx/LibMP")
	if type(Toggle) ~= "function" or not Loaded then return {}, 0 end

	const Control: any = LibMP.Control
	const Chunk: number = math.max(Iterations // 16, 1)
	const Into: Harvest = {Marker = `RTPBench:{Key}`, Last = 0, Markers = 0, Found = {}}

	Control:SetFrameLimit(128)
	Control:EnableProfiler(true)
	Control:EnableCapture(true)
	task.wait(0.25)
	Collect(LibMP, Into)

	Toggle(true)

	const Ok: boolean, Problem: any = pcall(function()
		for Iteration = 1, Iterations do
			Counter[1] += 1

			const Index: number = Counter[1]
			if Case.Prepare then (Case.Prepare :: (number) -> ())(Index) end

			debug.profilebegin(Into.Marker)
			Case.Step(Index)
			debug.profileend()

			if Case.Finish then (Case.Finish :: (number) -> ())(Index) end
			if Iteration % Chunk ~= 0 then continue end

			task.wait()
			Collect(LibMP, Into)
		end
	end)

	Toggle(false)

	if not Ok then error(Problem, 0) end

	for _ = 1, 3 do
		task.wait()
		Collect(LibMP, Into)
	end

	const Timings: { Timing } = {}
	for _, Entry: Timing in (Into.Found) do table.insert(Timings, Entry) end

	table.sort(Timings, function(Left: Timing, Right: Timing): boolean return Left.Own > Right.Own end)

	return Timings, Into.Markers
end

const function Release(): ()
	const Loaded: boolean, LibMP: any = pcall(require, "@rbx/LibMP")
	if not Loaded then return end

	LibMP.Control:EnableCapture(false)
	LibMP.Control:EnableProfiler(false)
end

const function Created(Gui: ScreenGui, Owned: { [Instance]: boolean }, Case: Case, Iterations: number, Counter: { number }): number
	const Seen: { [Instance]: boolean } = setmetatable({}, {__mode = "k"}) :: any

	for _, Existing: Instance in (Gui:GetDescendants()) do Seen[Existing] = true end

	local Fresh: number = 0

	const Connection: RBXScriptConnection = Gui.DescendantAdded:Connect(function(Added: Instance)
		if Seen[Added] or Owned[Added] then return end

		Seen[Added] = true
		Fresh += 1
	end)

	for _ = 1, Iterations do
		Counter[1] += 1

		const Index: number = Counter[1]
		if Case.Prepare then (Case.Prepare :: (number) -> ())(Index) end
		Case.Step(Index)
		if Case.Finish then (Case.Finish :: (number) -> ())(Index) end
	end

	task.wait()
	Connection:Disconnect()

	return Fresh / Iterations
end

const function Measure(Libraries: { Library }, Owned: { [Instance]: boolean }, Scenario: Scenario, Rounds: number, Scale: number, Overhead: { number }?): { Row }
	const Iterations: number = math.max(math.floor(Scenario.Iterations * Scale + 0.5), 1)
	const Warmup: number = math.max(math.floor(Scenario.Warmup * Scale + 0.5), 1)
	const Count: number = #Libraries
	const Cases: { Case } = {}
	const Samples: { { number } } = {}
	const Controls: { { number } } = {}
	const Counters: { { number } } = {}

	const function Once(Index: number, Timed: boolean): ()
		const Case: Case = Cases[Index]
		const Counter: { number } = Counters[Index]

		Counter[1] += 1

		const Step: number = Counter[1]
		if Case.Prepare then (Case.Prepare :: (number) -> ())(Step) end

		const Start: number = os.clock()
		Case.Step(Step)
		const Spent: number = os.clock() - Start

		if Case.Finish then (Case.Finish :: (number) -> ())(Step) end
		if Timed then table.insert(Samples[Index], Spent) end
	end

	const Ok: boolean, Problem: any = pcall(function()
		for Index: number, Library: Library in (Libraries) do
			Samples[Index] = {}
			Controls[Index] = {}
			Counters[Index] = {0}

			Drain(Library)
			Cases[Index] = Scenario.Build(Library.Kit)
		end

		for Index = 1, Count do
			for _ = 1, Warmup do Once(Index, false) end
		end

		task.wait()

		for Round = 1, Rounds do
			for Offset = 0, Count - 1 do
				const Index: number = (Round + Offset - 1) % Count + 1

				table.insert(Controls[Index], Probe())

				for _ = 1, Iterations do Once(Index, true) end
			end

			task.wait()
		end
	end)

	if not Ok then
		for _, Case: Case in (Cases) do pcall(Case.Teardown) end

		error(`{Scenario.Name}: {tostring(Problem)}`, 0)
	end

	const Rows: { Row } = {}

	for Index: number, Library: Library in (Libraries) do
		const Case: Case = Cases[Index]
		const Instances: number = Case.Count()
		const Fresh: number = Created(Library.Kit.Gui, Owned, Case, math.min(Iterations, 20), Counters[Index])

		local Stages: { Stage } = {}
		local Wrapped: number = 0
		local Timings: { Timing } = {}
		local Captured: number = 0

		if Capture then Timings, Captured = Sample(Library, Case, Iterations, Counters[Index], Scenario.Key) end
		if Overhead then Stages, Wrapped = Breakdown(Library.Root, Case, Iterations, Counters[Index], Overhead :: { number }) end

		Case.Teardown()

		table.insert(Rows, {
			Key = Scenario.Key;
			Name = Scenario.Name;
			Library = Library.Name;
			Samples = #Samples[Index];
			Median = Median(Samples[Index]);
			Minimum = Minimum(Samples[Index]);
			Normalized = 0;
			Load = 1;
			Controls = Controls[Index];
			Instances = Instances;
			Created = Fresh;
			Stages = Stages;
			Wrapped = Wrapped;
			Timings = Timings;
			Captured = Captured;
		})
	end

	task.wait()

	return Rows
end

const function Wanted(Key: string): boolean
	return #Only == 0 or table.find(Only, Key) ~= nil
end

const function Pad(Text: string, Width: number): string
	return Text .. string.rep(" ", math.max(Width - #Text, 0))
end

const function Number(Value: number, Width: number, Digits: number): string
	const Text: string = string.format(`%.{Digits}f`, Value)

	return string.rep(" ", math.max(Width - #Text, 0)) .. Text
end

const function Report(Rows: { Row }, Reference: number, Compare: boolean, Costs: { number }, Overhead: { number }?): string
	const Lines: { string } = {}
	const First: { [string]: Row } = {}

	table.insert(Lines, `{Prefix} control {string.format("%.1f", Reference * 1e6)} us | rounds {Rounds} | scale {Scale}`)
	table.insert(Lines, `engine | new rich Text set {string.format("%.1f", Costs[1] * 1e6)} us | new plain Text set {string.format("%.1f", Costs[2] * 1e6)} us | TextLabel create+destroy {string.format("%.1f", Costs[3] * 1e6)} us`)
	table.insert(Lines, `{Pad("scenario", 30)}{if Compare then Pad("lib", 8) else ""}{Pad("iters", 7)}{Pad("median us", 12)}{Pad("min us", 12)}{Pad("norm us", 12)}{Pad("load", 7)}{Pad("inst", 7)}{Pad("new/iter", 10)}{if Compare then "norm vs first" else ""}`)

	for _, Row: Row in (Rows) do
		const Base: Row? = First[Row.Key]
		if not Base then First[Row.Key] = Row end

		const Ratio: string = if Compare and Base then string.format("%.3f", Row.Normalized / math.max((Base :: Row).Normalized, 1e-9)) else ""

		table.insert(Lines, `{Pad(Row.Name, 30)}{if Compare then Pad(Row.Library, 8) else ""}{Pad(tostring(Row.Samples), 7)}{Number(Row.Median * 1e6, 9, 1)}   {Number(Row.Minimum * 1e6, 9, 1)}   {Number(Row.Normalized * 1e6, 9, 1)}   {Number(Row.Load, 4, 2)}   {Number(Row.Instances, 4, 0)}   {Number(Row.Created, 6, 2)}    {Ratio}`)
	end

	for _, Row: Row in (Rows) do
		if not Capture then break end

		table.insert(Lines, "")

		if #Row.Timings == 0 then
			table.insert(Lines, `{Row.Name}{if Compare then ` [{Row.Library}]` else ""}: MicroProfiler captured no complete iteration`)

			continue
		end

		table.insert(Lines, `{Row.Name}{if Compare then ` [{Row.Library}]` else ""}: MicroProfiler RTP labels ({Row.Captured} captured iterations, self excludes nested RTP labels)`)
		table.insert(Lines, `  {Pad("label", 16)}{Pad("calls/iter", 12)}{Pad("avg ms", 10)}{Pad("max ms", 10)}{Pad("total ms/iter", 15)}self ms/iter`)

		for Index: number, Entry: Timing in (Row.Timings) do
			if Index > 12 then break end

			const Count: number = math.max(Row.Captured, 1)

			table.insert(Lines, `  {Pad(Entry.Name, 16)}{Number(Entry.Calls / Count, 10, 2)}  {Number(Entry.Total / Entry.Calls, 8, 4)}  {Number(Entry.Max, 8, 4)}  {Number(Entry.Total / Count, 13, 4)}  {Number(Entry.Own / Count, 10, 4)}`)
		end
	end

	const Shares: { [string]: number } = {}
	local Counted: number = 0

	for _, Row: Row in (Rows) do
		if #Row.Stages == 0 then continue end

		Counted += 1

		table.insert(Lines, "")
		table.insert(Lines, `{Row.Name}{if Compare then ` [{Row.Library}]` else ""}: stage breakdown (exclusive us per iteration, {string.format("%.1f", Row.Wrapped * 1e6)} us wrapped total)`)

		for Index: number, Stage: Stage in (Row.Stages) do
			Shares[Stage.Name] = (Shares[Stage.Name] or 0) + Stage.Share

			if Index > 10 or Stage.Share < 0.01 then continue end

			table.insert(Lines, `  {Pad(Stage.Name, 26)}{Number(Stage.Time * 1e6, 10, 1)} us {Number(Stage.Share * 100, 5, 1)}%  {string.format("%.1f", Stage.Calls)} calls`)
		end
	end

	if Counted == 0 then return table.concat(Lines, "\n") end

	if Overhead then
		table.insert(Lines, "")
		table.insert(Lines, `breakdown wrapper overhead removed per call: {string.format("%.0f", (Overhead :: { number })[1] * 1e9)} ns inside, {string.format("%.0f", (Overhead :: { number })[2] * 1e9)} ns outside`)
	end

	const Names: { string } = {}
	for Name: string in (Shares) do table.insert(Names, Name) end

	table.sort(Names, function(Left: string, Right: string): boolean return Shares[Left] > Shares[Right] end)

	table.insert(Lines, "")
	table.insert(Lines, `top hotspots (mean share of exclusive time across {Counted} scenarios)`)

	for Index = 1, math.min(12, #Names) do
		const Name: string = Names[Index]
		table.insert(Lines, `{Number(Index, 3, 0)}. {Pad(Name, 26)}{Number(Shares[Name] / Counted * 100, 5, 1)}%`)
	end

	return table.concat(Lines, "\n")
end

const function Run(Roots: { ModuleScript }, Names: { string }): string
	const Compare: boolean = #Roots > 1
	const Detailed: boolean = Detail and not Compare
	const Owned: { [Instance]: boolean } = setmetatable({}, {__mode = "k"}) :: any
	const Gui: ScreenGui = Instance.new("ScreenGui")

	const function Label(Text: string, Width: number, Height: number, Parent: Instance?): TextLabel
		const Created: TextLabel = Instance.new("TextLabel")
		Created.Size = UDim2.fromOffset(Width, Height)
		Created.TextSize = 18
		Created.TextWrapped = true
		Created.TextXAlignment = Enum.TextXAlignment.Left
		Created.TextYAlignment = Enum.TextYAlignment.Top
		Created.FontFace = Font.fromEnum(Enum.Font.Gotham)
		Created.TextColor3 = Color3.new(1, 1, 1)
		Created.BackgroundTransparency = 1
		Created.Text = Text
		Created.Parent = Parent or Gui
		Owned[Created] = true

		return Created
	end

	const function Own(Object: Instance): ()
		Owned[Object] = true
	end

	const Libraries: { Library } = {}

	for Index: number, Root: ModuleScript in (Roots) do
		const API: any = require(Root :: any)
		const Renderer: any = Resolve(Root, "Renderer")
		const Builder: boolean = type(Renderer) == "table" and type(Renderer.Class) == "table" and Renderer.Class.SetScale ~= nil

		table.insert(Libraries, {
			Name = Names[Index];
			Root = Root;
			Kit = {
				API = API;
				Gui = Gui;
				Label = Label;
				Own = Own;
				Root = Root;
				Legacy = Resolve(Root, "Classes/Effect").Updaters ~= nil;
				Builder = Builder;
				New = function(Target: TextLabel, Classes: { [string]: any }?): any
					return Construct(API, Builder, Target, Classes)
				end;
			};
		})
	end

	const Rows: { Row } = {}
	const Costs: { number } = Engine(Gui)
	const Overhead: { number }? = if Detailed then Tracker(nil).Calibrate() else nil

	local Reference: number = math.huge

	const Ok: boolean, Problem: any = pcall(function()
		for _, Scenario: Scenario in (Scenarios) do
			if not Wanted(Scenario.Key) then continue end

			for _, Row: Row in (Measure(Libraries, Owned, Scenario, Rounds, Scale, Overhead)) do
				for _, Value: number in (Row.Controls) do Reference = math.min(Reference, Value) end

				table.insert(Rows, Row)
			end
		end
	end)

	Gui:Destroy()

	if Capture then Release() end
	if not Ok then error(Problem, 0) end

	for _, Row: Row in (Rows) do
		Row.Load = math.max(Median(Row.Controls) / Reference, 1)
		Row.Normalized = Row.Median / Row.Load
	end

	if Sink ~= Sink then Reference = 0 end

	return Report(Rows, Reference, Compare, Costs, Overhead)
end

const function Find(Source: Node, Name: string): Node?
	if Source.Name == Name then return Source end

	for _, Child: Node in (Source.Children) do
		const Found: Node? = Find(Child, Name)
		if Found then return Found end
	end

	return nil
end

const function Fetch(Target: Build): Node
	const Tree: Node = HttpService:JSONDecode(HttpService:GetAsync(`http://127.0.0.1:{Target.Port}/`, true))
	const Packages: Node? = Find(Tree, "Packages")
	if not Packages then error(`no Packages served on port {Target.Port}`) end

	return Packages
end

const function Create(Source: Node, Parent: Instance): Instance
	const Created: Instance = Instance.new(Source.ClassName :: any)
	Created.Name = Source.Name
	if Source.Source then (Created :: any).Source = Source.Source end

	for _, Child: Node in (Source.Children) do Create(Child, Created) end

	Created.Parent = Parent

	return Created
end

const function Main(Folder: Folder): string
	const Roots: { ModuleScript } = {}
	const Names: { string } = {}

	for _, Target: Build in (Builds) do
		const Holder: Folder = Instance.new("Folder")
		Holder.Name = Target.Name
		Holder.Parent = Folder

		const Packages: Instance = Create(Fetch(Target), Holder)
		const Root: ModuleScript = Packages:FindFirstChild("RichTextPlus") :: ModuleScript
		const Loaded: any = require(Root :: any)
		const Toggle: any = (Loaded.Runtime or Loaded).SetProfiling

		if Target.Profiling and type(Toggle) == "function" then Toggle(true) end

		table.insert(Roots, Root)
		table.insert(Names, Target.Name)
	end

	print(`{Prefix} running {if #Only == 0 then "every scenario" else table.concat(Only, ", ")} on {table.concat(Names, ", ")}`)

	const Text: string = Run(Roots, Names)

	print(Text)

	return Text
end

const Existing: Instance? = ReplicatedStorage:FindFirstChild(FolderName); if Existing then Existing:Destroy() end

const Folder: Folder = Instance.new("Folder")
Folder.Name = FolderName
Folder.Parent = ReplicatedStorage

const Ok: boolean, Result: any = pcall(Main, Folder)

Folder:Destroy()

if not Ok then warn(`{Prefix} run aborted: {tostring(Result)}`) end

return if Ok then Result else `{Prefix} run aborted: {tostring(Result)}`
