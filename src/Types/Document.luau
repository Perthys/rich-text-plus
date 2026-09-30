--!strict

const XML = require("../../XML")

--[=[
	An XML node from the markup, as given to custom classes. Read it with the [Utilities] attribute helpers.

	@interface Node
	@within RichTextPlus
	.Type string -- `"TAG"`, `"SINGLE"`, `"STRING"` or `"COMMENT"`
	.TagType string?
	.Text string?
	.Attributes { Attribute }
	.Children { Node }
]=]
export type Node = XML.Node
--[=[
	@interface Attribute
	@within RichTextPlus
	.Name string
	.Value string -- Raw, still escaped
]=]
export type Attribute = XML.Attribute

return {}
