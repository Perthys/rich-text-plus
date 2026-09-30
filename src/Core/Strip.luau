--!strict
--!native
--!optimize 2

const XML = require("../../XML")
const Types = require("../Types")
const Styles = require("../Utility/Styles")
const Flatten = require("./Flatten")
const Markdown = require("../Markdown")
const Classes = require("../Classes")
const Characters = require("../Utility/Characters")
const Whitespace = require("../Policy/Whitespace")

type Node = Types.Node

type Writer = {
	Parts: { string };
	Space: boolean;
	Start: boolean;
	Block: boolean;
}

const NewlineByte: number = Characters.NEWLINE
const SeparatorPattern: string = "[\t\n\v\f\r ]"
const Separators: { [number]: boolean } = Characters.Separators
const Resume: Node = XML.Node.new("ROOT")
const Collapse = Whitespace.Collapse

const function Break(Out: Writer): ()
	table.insert(Out.Parts, "\n")
	Out.Space = false
	Out.Start = true
	Out.Block = false
end

const function Word(Out: Writer, Text: string): ()
	if Out.Block then Break(Out) end
	if Out.Space and not Out.Start then table.insert(Out.Parts, " ") end

	table.insert(Out.Parts, Text)
	Out.Space = false
	Out.Start = false
end

const function Write(Out: Writer, Text: string): ()
	const Length: number = #Text
	local Index: number = 1

	while Index <= Length do
		const Code: number = string.byte(Text, Index)

		if Code == NewlineByte then
			Break(Out)
			Index += 1
		elseif Separators[Code] then
			Out.Space = true
			Index += 1
		else
			const Stop: number = string.find(Text, SeparatorPattern, Index) or Length + 1
			Word(Out, string.sub(Text, Index, Stop - 1))
			Index = Stop
		end
	end
end

const function Content(Raw: string, Collapsing: boolean): string
	return Styles.Unescape(if Collapsing then Collapse(Raw) else Raw)
end

const function Line(Out: Writer): ()
	if Out.Block or not Out.Start then Break(Out) end

	Out.Block = true
end

const function Code(Out: Writer, Node: Node): ()
	Line(Out)

	table.insert(Out.Parts, Classes.Load("CodeBlock").Body(Node))
	Out.Space = false
	Out.Start = false
end

const function Run(Markup: string, Collapsing: boolean): string
	const Out: Writer = {Parts = {}, Space = false, Start = true, Block = false}
	const Stack: { Node } = {}

	local Verbatim: number = 0

	const function Push(Children: { Node }): ()
		for Index = #Children, 1, -1 do table.insert(Stack, Children[Index]) end
	end

	Push(XML.GenerateTreeFromXML(Markdown.Preprocess(Markup)).Children)

	while #Stack > 0 do
		const Current: Node = table.remove(Stack) :: Node
		if Current == Resume then Verbatim -= 1; continue end

		const Type: string = Current.Type

		if Type == "STRING" then Write(Out, Content(Current.Text or "", Collapsing and Verbatim == 0)); continue end
		if Type ~= "TAG" and Type ~= "SINGLE" then continue end

		const Tag: string = Styles.LowerName(Current.TagType or "")

		if Tag == "codeblock" then Code(Out, Current); continue end
		if Tag == "md" then
			if Collapsing then Verbatim += 1; table.insert(Stack, Resume) end

			Push(Markdown.ToTree(Styles.InnerText(Current)).Children)

			continue
		end

		if Tag == "a" and Type == "SINGLE" then Write(Out, Styles.Attribute(Current, "Href") or ""); continue end

		if Tag == "br" then Break(Out) elseif Tag == "hr" then Line(Out) end

		Push(Current.Children)
	end

	return table.concat(Out.Parts)
end

return {
	Run = Run;
}
