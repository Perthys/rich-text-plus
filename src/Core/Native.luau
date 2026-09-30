--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Attributes = require("../Utility/Attributes")
const Styles = require("../Utility/Styles")
const Scale = require("./Scale")
const Pool = require("../Render/Pool")
const Culling = require("../Render/Culling")
const Profiler = require("../Utility/Profiler")
const Lifetime = require("../Utility/Lifetime")

type Style = Types.Style
type Token = Types.Token

const BoldValue: number = Enum.FontWeight.Bold.Value
const MarkupPattern: string = "[<&]"
const ChurnWindow: number = Config.Native.CHURN_WINDOW
const ChurnLimit: number = Config.Native.CHURN_LIMIT

const Parts: { string } = {}
const Remembered = Lifetime.Own("Native.Remembered", {} :: { [Types.Fields]: number })

const Find = string.find
const Sub = string.sub

const function Heft(Style: Style): Enum.FontWeight
	const Weight: Enum.FontWeight = Style.Weight or Enum.FontWeight.Regular

	return if Style.Bold and Weight.Value < BoldValue then Enum.FontWeight.Bold else Weight
end

const function Styled(Style: Style): boolean
	if Style.Link or Style.Element or Style.Gradient or Style.Effect or Style.Container then return true end
	if Style.Indent or Style.Code or Style.Direction or Style.Stroke or Style.Mark or Style.Case then return true end

	return Style.Underline or Style.Strike or Style.Transparency > 0
end

const function Plain(Style: Style, Face: Font, Size: number, Color: Color3): boolean
	if Styled(Style) or Style.Size ~= Size or Style.Color ~= Color or Style.Family ~= Face.Family then return false end

	return Style.Italic == (Face.Style == Enum.FontStyle.Italic) and Heft(Style) == Face.Weight
end

const function Eligible(Tokens: { Token }, Face: Font, Size: number, Color: Color3): boolean
	local Previous: Token? = nil
	local Checked: Style? = nil

	for _, Token: Token in (Tokens) do
		const Joined: boolean = Previous ~= nil and (Previous :: Token).Kind == "Word"

		Previous = Token

		if Token.Kind == "Break" then continue end
		if Token.Kind ~= "Word" or not Token.Text or Token.Hyphen or Token.Level or Token.Rtl then return false end
		if Find(Token.Text :: string, MarkupPattern) then return false end
		if Joined and not (Token.SpaceBefore or Token.Glue) then return false end

		const Style: Style? = Token.Style
		if not Style then return false end
		if Style == Checked then continue end
		if not Plain(Style :: Style, Face, Size, Color) then return false end

		Checked = Style
	end

	return true
end

const function Emit(Tokens: { Token }): string
	local Previous: Token? = nil

	for _, Token: Token in (Tokens) do
		const Joined: boolean = Previous ~= nil and (Previous :: Token).Kind == "Word"

		Previous = Token

		if Token.Kind == "Break" then table.insert(Parts, "\n"); continue end
		if Joined and Token.SpaceBefore then table.insert(Parts, " ") end

		table.insert(Parts, Token.Text :: string)
	end

	const Result: string = table.concat(Parts)
	table.clear(Parts)

	return Result
end

const function Volatile(State: Types.Fields): boolean
	return State.Native.Streak >= ChurnLimit
end

const function Markup(State: Types.Fields): string?
	if not State.Rendering.Passthrough then return nil end

	const Label: TextLabel = State.Label
	const Size: number = Styles.BaseSize(State)
	if Size ~= Label.TextSize then return nil end

	const Tokens: { Token } = State.Document.Tokens
	if not Eligible(Tokens, Label.FontFace, Size, Label.TextColor3) then return nil end

	return Emit(Tokens)
end

const function Churn(State: Types.Fields): ()
	const Native: Types.NativeData = State.Native
	const Now: number = os.clock()

	Native.Streak = if Now - Native.Clock < ChurnWindow then Native.Streak + 1 else 0
	Native.Clock = Now
end

const function Remember(State: Types.Fields): ()
	const Developer: number = State.Developer.Transparency
	if Remembered[State] == Developer then return end

	const Label: TextLabel = State.Label
	const Stored: number? = Label:GetAttribute(Attributes.DeveloperTransparency) :: number?

	if Stored ~= Developer and (Stored ~= nil or Developer ~= 0) then Label:SetAttribute(Attributes.DeveloperTransparency, Developer) end

	Remembered[State] = Developer
end

const function Showing(State: Types.Fields): boolean
	return State.Native.Active and State.Label.Text == State.Native.Markup
end

const function Rebase(State: Types.Fields, Text: string): string
	const Native: Types.NativeData = State.Native
	const Markup: string? = Native.Markup
	const Original: string? = Native.Source

	if not (Native.Active and Markup and Original) or Markup == Original or Text == Original then return Text end
	if Text == Markup then return Original :: string end

	const Size: number = #(Markup :: string)

	if Sub(Text, 1, Size) == Markup then return (Original :: string) .. Sub(Text, Size + 1) end
	if Size > 0 and Sub(Text, -Size) == Markup then return Sub(Text, 1, #Text - Size) .. (Original :: string) end

	return Text
end

const function Source(State: Types.Fields): string
	return Rebase(State, State.Label.Text)
end

const function Assign(State: Types.Fields, Text: string): ()
	const Label: TextLabel = State.Label
	const Markup: string = State.Native.Markup :: string

	State.Document.Source = Text
	State.Native.Source = Text

	if Label.Text ~= Markup then Label.Text = Markup end
end

const function Suppress(State: Types.Fields): ()
	const Label: TextLabel = State.Label
	if not Label.RichText then return end

	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Suppress") end

	State.Native.RichText = true
	Scale.Echo(State, "RichText")
	Label.RichText = false

	if Profiling then Profiler.End() end
end

const function Restore(State: Types.Fields): ()
	const Native: Types.NativeData = State.Native
	const Developer: boolean? = Native.RichText; if Developer == nil then return end

	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Restore") end

	Native.RichText = nil
	if State.Label.RichText ~= Developer then State.Label.RichText = Developer :: boolean end

	if Profiling then Profiler.End() end
end

const function Enter(State: Types.Fields, Text: string): ()
	const Label: TextLabel = State.Label
	const Native: Types.NativeData = State.Native

	if not Native.Active then
		Native.Active = true

		Pool.Clear(State)
		Culling.Release(State)

		table.clear(State.Instances.Order)
		table.clear(State.Animation.Animated)
		table.clear(State.Animation.Moving)
	end

	State.Scale.Measured = 0
	Native.Markup = Text
	Native.Source = State.Document.Source

	Scale.Release(State)
	Suppress(State)

	if Label.Text ~= Text then Label.Text = Text end

	Remember(State)

	const Developer: number = State.Developer.Transparency
	if Label.TextTransparency ~= Developer then Label.TextTransparency = Developer end
end

const function Release(State: Types.Fields): ()
	const Native: Types.NativeData = State.Native
	if not Native.Active then return end

	const Profiling: boolean = Profiler.Enabled
	if Profiling then Profiler.Begin("RTP:Release") end

	const Restored: string = Source(State)

	Native.Active = false
	Native.Markup = nil
	Native.Source = nil

	if State.Label.Text ~= Restored then State.Label.Text = Restored end

	if Profiling then Profiler.End() end
end

return {
	Markup = Markup;
	Churn = Churn;
	Volatile = Volatile;
	Remember = Remember;
	Showing = Showing;
	Source = Source;
	Rebase = Rebase;
	Assign = Assign;
	Suppress = Suppress;
	Restore = Restore;
	Enter = Enter;
	Release = Release;
}
