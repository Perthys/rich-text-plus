--!strict
--!native
--!optimize 2

const HttpService = game:GetService("HttpService")

const Config = require("../Config")
const Trove = require("../../Trove")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Elements = require("../Elements")
const Rendering = require("../Policy/Rendering")
const Whitespace = require("../Policy/Whitespace")
const Presets = require("../Policy/Presets")
const Registry = require("../Render/Registry")
const Scale = require("../Core/Scale")
const Native = require("../Core/Native")
const Schedule = require("../Render/Schedule")
const Transparency = require("./Transparency")

type Fields = Types.Fields
type Theme = Types.Theme

const REMOVED_ON_LINK_CLICKED: string = 'RichTextPlus OnLinkClicked was removed: bind the links instead, Renderer:Bind("a", {Activated = function(Element) print(Element:GetAttribute("href"), Element.Text) end})'
const DEFAULT_LINK_COLOR: Color3 = Config.Renderer.LINK_COLOR
const DEFAULT_THEME: Theme = table.freeze({})

const AutomaticSizeNames: { [string]: Enum.AutomaticSize } = {
	["X"] = Enum.AutomaticSize.X;
	["Y"] = Enum.AutomaticSize.Y;
	["XY"] = Enum.AutomaticSize.XY;
	["None"] = Enum.AutomaticSize.None;
}

const function Forget(Label: TextLabel, Name: string): ()
	if Label:GetAttribute(Name) ~= nil then Label:SetAttribute(Name, nil) end
end

const function Relinquish(State: Fields, Dying: boolean?): ()
	Schedule.Take(State)
	Registry.Abandon(State, Dying)
	Native.Release(State)

	if not Dying then Native.Restore(State) end
end

const function Teardown(State: Fields, Dying: boolean?): ()
	Schedule.Take(State)
	if State.Destroyed then return end

	const Label: TextLabel = State.Label

	Relinquish(State, Dying)

	if not Dying and Label:GetAttribute(Attributes.Owner) == State.Token then
		pcall(function()
			const _: boolean, Live: number = Transparency.Capture(State)
			const Developer: number = State.Developer.Transparency
			if Live ~= Developer then Label.TextTransparency = Developer end

			Scale.Release(State)

			Forget(Label, Attributes.DeveloperTransparency)
			Forget(Label, Attributes.Owner)
		end)
	end
end

const function Sweep(Label: TextLabel): ()
	for _, Child: Instance in (Label:GetChildren()) do
		if Child:GetAttribute(Attributes.Marker) then Child:Destroy() end
	end
end

const function Supersede(Label: TextLabel): boolean?
	const Found: Fields? = Registry.Get(Label); if not Found then return nil end

	const Prior: Fields = Found :: Fields
	const Inherited: boolean? = Prior.Native.RichText

	Prior.Native.RichText = nil
	Teardown(Prior)

	return Inherited
end

const function Create(Label: TextLabel): Fields
	const Inherited: boolean? = Supersede(Label)
	const Preset: Presets.Bundle = Presets.Default
	const MainTrove: Trove.Trove = Trove.new()

	const State: Fields = {
		Label = Label;
		Token = HttpService:GenerateGUID(false);
		Destroyed = false;
		Options = {
			Scale = 1;
			Whitespace = Whitespace.Default;
		};
		Elements = Elements.Create();
		Intents = Preset.Intents;
		Limits = Preset.Limits;
		Denied = Preset.Denied;
		Assets = nil;
		Rendering = Rendering.Defaults;
		Theme = DEFAULT_THEME;
		Document = {
			Source = nil;
			Origin = nil;
			Tree = nil;
			Ledger = nil;
			Tokens = {};
			SpaceWidths = {};
		};
		Instances = {
			Records = {};
			Segments = {};
			Spare = {};
			Order = {};
		};
		Backdrop = {
			Root = nil;
			Layers = {};
		};
		Objects = {
			Sizes = {};
			Cache = {};
		};
		Troves = {
			Main = MainTrove;
			Objects = MainTrove:Extend();
			Cull = MainTrove:Extend();
		};
		Generation = {
			Refresh = 0;
			Text = 0;
			Layout = 0;
			Measure = 0;
		};
		Scale = {
			Factor = 1;
			Measured = 0;
			Ancestor = 1;
		};
		Host = {
			Width = 0;
			Height = 0;
			Text = Label.Text;
			Seen = {};
			Echoes = {};
		};
		Developer = {
			Transparency = (Label:GetAttribute(Attributes.DeveloperTransparency) :: number?) or (if Label:GetAttribute(Attributes.Owner) then 0 else Label.TextTransparency);
			AutomaticSize = nil;
		};
		Native = {
			Active = false;
			Markup = nil;
			Source = nil;
			RichText = Inherited;
			Streak = 0;
			Clock = -math.huge;
		};
		Animation = {
			Clock = 0;
			Animated = {};
			Moving = {};
		};
		Decoration = {
			List = {};
			Version = 0;
			Dirty = true;
		};
		Cull = {
			Dirty = true;
			ChainDirty = true;
			Culled = false;
			Padding = 0;
			Clippers = {};
			Collector = nil;
			Bounds = {
				MinX = 0;
				MinY = 0;
				MaxX = 0;
				MaxY = 0;
			};
		};
	}

	Sweep(Label)

	Label:SetAttribute(Attributes.Owner, State.Token)

	const StoredAutomaticSize: string? = Label:GetAttribute(Attributes.DeveloperAutomaticSize) :: string?
	if StoredAutomaticSize then State.Developer.AutomaticSize = AutomaticSizeNames[StoredAutomaticSize :: string] end

	return State
end

return {
	DefaultTheme = DEFAULT_THEME;
	DefaultLinkColor = DEFAULT_LINK_COLOR;
	RemovedOnLinkClicked = REMOVED_ON_LINK_CLICKED;
	Create = Create;
	Relinquish = Relinquish;
	Teardown = Teardown;
}
