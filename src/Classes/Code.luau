--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Markdown = require("../Markdown")

const InlineCornerLimit: number = Config.Classes.INLINE_CODE_CORNER_LIMIT

const function Apply(Style: Types.Style, _Node: Types.Node, State: Types.Fields?): ()
	const Theme: Markdown.ResolvedTheme = Markdown.Theme(if State then State.Theme else nil)

	Style.Code = true
	Style.Family = Styles.ResolveFamily(Theme.CodeFamily)
	Style.Color = Theme.CodeTextColor
	Style.Mark = {
		Color = Theme.CodeBackground;
		Transparency = Theme.CodeBackgroundTransparency;
		Radius = math.min(Theme.CodeCornerRadius, InlineCornerLimit);
		Parent = Style.Mark;
	}
end

return {
	Kind = "Style";
	Apply = Apply;
}
