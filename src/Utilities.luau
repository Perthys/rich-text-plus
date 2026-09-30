--!strict
--!native
--!optimize 2

const XML = require("../XML")
const Types = require("./Types")
const Styles = require("./Utility/Styles")
const MarkdownTypes = require("./Types/Markdown")

type StripOptions = {
	Whitespace: Types.Whitespace?;
}

--[=[
	Escaping, attribute parsing, markdown and highlighting helpers, reached through `RichTextPlus.Utilities`.

	@class Utilities
]=]
--[=[
	Escapes `& < > " '` so text renders literally. Escape filtered player text before putting it in markup.

	@within Utilities
	@function Escape
	@param Text string
	@return string
]=]
--[=[
	Decodes XML entities. Never throws: invalid code points stay literal.

	@within Utilities
	@function Unescape
	@param Text string
	@return string
]=]
--[=[
	Reads an attribute from a node, case-insensitively and unescaped.

	@within Utilities
	@function Attribute
	@param Node Node
	@param Name string
	@return string?
]=]
--[=[
	Reads a finite number attribute, or returns `Default`.

	@within Utilities
	@function AttributeNumber
	@param Node Node
	@param Name string
	@param Default number?
	@return number?
]=]
--[=[
	Reads a boolean attribute. `false`, `0`, `no` and `off` are false, any other value is true, and a missing attribute returns `Default`.

	@within Utilities
	@function AttributeBoolean
	@param Node Node
	@param Name string
	@param Default boolean
	@return boolean
]=]
--[=[
	Returns the unescaped text content of a node, with `<br/>` as a newline.

	@within Utilities
	@function InnerText
	@param Node Node
	@return string
]=]
--[=[
	Parses a color name, `#rgb`, `#rrggbb` or `rgb(r, g, b)`.

	@within Utilities
	@function ParseColor
	@param Value string?
	@return Color3?
]=]
--[=[
	Formats a color as `rgb(r, g, b)`.

	@within Utilities
	@function FormatColor
	@param Color Color3
	@return string
]=]
--[=[
	Parses a font weight name (`bold`, `semibold`, ...) or a number from 100 to 900.

	@within Utilities
	@function ParseWeight
	@param Value string?
	@return Enum.FontWeight?
]=]
--[=[
	Removes leading and trailing whitespace.

	@within Utilities
	@function Trim
	@param Value string
	@return string
]=]
--[=[
	Returns the canonical form of an image or font asset id, or `nil` if it is not an accepted form. `123`, `rbxassetid://123` and asset URLs become `rbxassetid://123`.

	@within Utilities
	@function CanonicalId
	@param Source string
	@return string?
]=]
--[=[
	Removes all markup and returns the plain text. `Options.Whitespace` picks the whitespace mode.

	@within Utilities
	@function Strip
	@param Markup string
	@param Options { Whitespace: Whitespace? }?
	@return string
]=]
--[=[
	Returns the markup an `<md>` block with this body becomes.

	@within Utilities
	@function Markdown
	@param Source string
	@param Theme Theme?
	@param TextSize number?
	@return string
]=]
--[=[
	Parses markdown into a syntax tree. See the Markdown guide for the node types.

	@within Utilities
	@function ParseMarkdown
	@param Source string
	@return table
]=]
--[=[
	Returns Luau source as syntax highlighted markup. `Syntax` overrides token colors.

	@within Utilities
	@function Highlight
	@param Code string
	@param Syntax { [string]: Color3 }?
	@return string
]=]
return table.freeze({
	Escape = function(Text: string): string
		return XML.Escape(Text)
	end;
	Unescape = Styles.Unescape;
	Attribute = Styles.Attribute;
	AttributeNumber = Styles.AttributeNumber;
	AttributeBoolean = Styles.AttributeBoolean;
	InnerText = Styles.InnerText;
	ParseColor = Styles.ParseColor;
	FormatColor = Styles.FormatColor;
	ParseWeight = Styles.ParseWeight;
	Trim = Styles.Trim;
	CanonicalId = Styles.CanonicalId;
	Strip = function(Markup: string, Options: StripOptions?): string
		const Mode: Types.Whitespace = require("./Policy/Whitespace").Resolve(if Options then Options.Whitespace else nil)

		return require("./Core/Strip").Run(Markup, Mode == "Markup")
	end;
	Markdown = function(Source: string, Theme: Types.Theme?, TextSize: number?): string
		return require("./Markdown").ToMarkup(Source, Theme, TextSize)
	end;
	ParseMarkdown = function(Source: string): MarkdownTypes.Document
		return require("./Markdown").Parse(Source)
	end;
	Highlight = function(Code: string, Syntax: { [string]: Color3 }?): string
		return require("./Text/Highlighter").Highlight(Code, Syntax)
	end;
})
