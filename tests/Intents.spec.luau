--!strict

const JestGlobals = require("../DevPackages/JestGlobals")
const RichTextPlus = require("../Packages/RichTextPlus")
const Presets = require("../Packages/RichTextPlus/Policy/Presets")

const Describe = JestGlobals.describe
const It = JestGlobals.it
const Expect = JestGlobals.expect

type OldRule = boolean | { [string]: boolean }

const Intents: any = (RichTextPlus :: any).Intents
const Flags: { [string]: number } = Intents.Flags

const NativeTags: { string } = {"b", "i", "u", "s", "br", "font", "stroke", "mark", "uppercase", "uc", "smallcaps", "sc"}
const TrustedTags: { string } = {"img", "a", "gradient", "wave", "shake", "md", "code", "codeblock", "hr", "dir", "indent", "customclass"}
const ChatTags: { string } = {"b", "i", "u", "s", "br", "mark"}
const AllTags: { string } = table.clone(NativeTags)
for _, Tag: string in TrustedTags do table.insert(AllTags, Tag) end

const Probes: { string } = {"color", "size", "face", "family", "weight", "transparency", "href", "src", "thickness"}

const function Rules(...: { string }): { [string]: OldRule }
	const Result: { [string]: OldRule } = {}

	for _, List: { string } in {...} do
		for _, Tag: string in List do Result[Tag] = true end
	end

	return Result
end

const OldChat: { [string]: OldRule } = Rules(ChatTags)
OldChat.font = {color = true}

const OldPresets: { [string]: { Tags: { [string]: OldRule }, Wildcard: boolean, Strip: boolean, Limits: { [string]: number? } } } = {
	Default = {Tags = Rules(NativeTags, TrustedTags), Wildcard = true, Strip = false, Limits = {MinTextSize = 8, MaxTextSize = 100}},
	Trusted = {Tags = Rules(NativeTags, TrustedTags), Wildcard = false, Strip = false, Limits = {MaxDepth = 32, MaxNodes = 4096, MaxTextLength = 16384, MaxObjects = 64, MinTextSize = 8, MaxTextSize = 96}},
	Chat = {Tags = OldChat, Wildcard = false, Strip = true, Limits = {MaxDepth = 8, MaxNodes = 256, MaxTextLength = 1024, MaxObjects = 0}},
	Plain = {Tags = {}, Wildcard = false, Strip = true, Limits = {}},
}

const function OldAllows(Rule: OldRule?, Attribute: string?): boolean
	if not Rule then return false end
	if Attribute == nil or Rule == true then return true end

	return (Rule :: { [string]: boolean })[Attribute :: string] == true
end

const function Message(Callback: () -> ()): string
	const Ok: boolean, Problem: any = pcall(Callback)

	return if Ok then "" else tostring(Problem)
end

Describe("flags", function()
	It("are powers of two", function()
		for _, Bit: number in Flags do
			Expect(Bit > 0 and bit32.band(Bit, Bit - 1) == 0).toBe(true)
		end
	end)

	It("are distinct", function()
		const Seen: { [number]: boolean } = {}

		for _, Bit: number in Flags do
			Expect(Seen[Bit]).toBeNil()
			Seen[Bit] = true
		end
	end)

	It("fit in 32 bits", function()
		for _, Bit: number in Flags do
			Expect(Bit <= 2 ^ 31).toBe(true)
		end
	end)

	It("every built-in tag has exactly one owner", function()
		for _, Tag: string in NativeTags do Expect(Flags[Intents.Tags[Tag]]).never.toBeNil() end
		for _, Tag: string in TrustedTags do Expect(Flags[Intents.Tags[Tag]]).never.toBeNil() end
	end)
end)

Describe("resolve", function()
	It("a flag name", function()
		Expect(Intents.Resolve("Links")).toBe(Flags.Links)
	end)

	It("a flag name in any case", function()
		Expect(Intents.Resolve("links")).toBe(Flags.Links)
	end)

	It("a number", function()
		Expect(Intents.Resolve(Flags.Links + Flags.Images)).toBe(Flags.Links + Flags.Images)
	end)

	It("zero", function()
		Expect(Intents.Resolve(0)).toBe(0)
	end)

	It("an array", function()
		Expect(Intents.Resolve({"Links", "Images"})).toBe(Flags.Links + Flags.Images)
	end)

	It("a nested array with duplicates", function()
		Expect(Intents.Resolve({"Links", {"Links", Flags.Images}})).toBe(Flags.Links + Flags.Images)
	end)

	It("an empty array", function()
		Expect(Intents.Resolve({})).toBe(0)
	end)

	It("another bitfield", function()
		Expect(Intents.Resolve(Intents.new("Code"))).toBe(Flags.Code)
	end)

	It("a preset name", function()
		Expect(Intents.Resolve("Chat")).toBe(Intents.Presets.Chat.Bitfield)
	end)

	It("a preset name in any case", function()
		Expect(Intents.Resolve("plain")).toBe(0)
	end)

	for _, Bad: any in {"Nope", -1, 0.5, 2 ^ 40, 0 / 0, true, Instance.new("Folder")} do
		It(`rejects {typeof(Bad)} {tostring(Bad)}`, function()
			Expect(function() Intents.Resolve(Bad) end).toThrow()
		end)
	end

	It("rejects a number with unknown bits", function()
		Expect(function() Intents.Resolve(2 ^ 30) end).toThrow()
	end)

	It("names the bad flag", function()
		Expect((string.find(Message(function() Intents.Resolve({"Links", "Videos"}) end), "Videos", 1, true))).never.toBeNil()
	end)

	It("rejects a list that contains itself", function()
		const Loop: { any } = {"Links"}
		table.insert(Loop, Loop)

		Expect(function() Intents.Resolve(Loop) end).toThrow()
	end)
end)

Describe("BitField", function()
	It("new with nothing is empty", function()
		Expect(Intents.new().Bitfield).toBe(0)
	end)

	It("new combines every argument", function()
		Expect(Intents.new("Links", {"Images"}, Flags.Code).Bitfield).toBe(Flags.Links + Flags.Images + Flags.Code)
	end)

	It("Has needs every flag", function()
		const Value: any = Intents.new("Links", "Images")

		Expect(Value:Has("Links")).toBe(true)
		Expect(Value:Has("Links", "Images")).toBe(true)
		Expect(Value:Has({"Links", "Code"})).toBe(false)
	end)

	It("Has of nothing is true", function()
		Expect(Intents.new():Has()).toBe(true)
	end)

	It("Any needs one flag", function()
		const Value: any = Intents.new("Links")

		Expect(Value:Any("Code", "Links")).toBe(true)
		Expect(Value:Any("Code")).toBe(false)
	end)

	It("Add mutates and returns self", function()
		const Value: any = Intents.new("Links")

		Expect(Value:Add("Images")).toBe(Value)
		Expect(Value.Bitfield).toBe(Flags.Links + Flags.Images)
	end)

	It("Remove mutates and returns self", function()
		const Value: any = Intents.new("Links", "Images")

		Expect(Value:Remove("Links", "Code")).toBe(Value)
		Expect(Value.Bitfield).toBe(Flags.Images)
	end)

	It("Toggle flips", function()
		const Value: any = Intents.new("Links")
		Value:Toggle("Links", "Code")

		Expect(Value.Bitfield).toBe(Flags.Code)
	end)

	It("ToArray lists set flags in bit order", function()
		Expect(Intents.new("Links", "Formatting"):ToArray()).toEqual({"Formatting", "Links"})
	end)

	It("Serialize maps every flag", function()
		const Serialized: { [string]: boolean } = Intents.new("Links"):Serialize()
		local Count: number = 0

		for Name: string, Set: boolean in Serialized do
			Count += 1
			Expect(Set).toBe(Name == "Links")
		end

		local Total: number = 0
		for _ in Flags do Total += 1 end

		Expect(Count).toBe(Total)
	end)

	It("Equals compares resolved bitfields", function()
		const Value: any = Intents.new("Links", "Images")

		Expect(Value:Equals({"Images", "Links"})).toBe(true)
		Expect(Value:Equals(Flags.Links + Flags.Images)).toBe(true)
		Expect(Value:Equals("Links")).toBe(false)
	end)

	It("Freeze returns self and freezes", function()
		const Value: any = Intents.new("Links")

		Expect(Value:Freeze()).toBe(Value)
		Expect(table.isfrozen(Value)).toBe(true)
	end)

	It("a frozen Add returns a changed copy", function()
		const Value: any = Intents.new("Links"):Freeze()
		const Changed: any = Value:Add("Images")

		Expect(Changed).never.toBe(Value)
		Expect(Value.Bitfield).toBe(Flags.Links)
		Expect(Changed.Bitfield).toBe(Flags.Links + Flags.Images)
		Expect(table.isfrozen(Changed)).toBe(false)
	end)

	It("a frozen Remove and Toggle return copies", function()
		const Value: any = Intents.Presets.Chat

		Expect(Value:Remove("Mark")).never.toBe(Value)
		Expect(Value:Toggle("Mark")).never.toBe(Value)
		Expect(Value:Has("Mark")).toBe(true)
	end)

	It("tostring names the flags", function()
		Expect(tostring(Intents.new("Links", "Code"))).toBe("Intents(Links, Code)")
	end)

	It("Allows a font color with Color only", function()
		const Value: any = Intents.new("Color")

		Expect(Value:Allows("font")).toBe(true)
		Expect(Value:Allows("FONT", "Color")).toBe(true)
		Expect(Value:Allows("font", "size")).toBe(false)
	end)

	It("Allows no custom tag names", function()
		Expect(Intents.Presets.Default:Allows("video")).toBe(false)
	end)
end)

Describe("preset parity with the old policies", function()
	for Name: string, Old in OldPresets do
		const New: any = Intents.Presets[Name]
		const Bundle: any = Presets.Resolve(Name, 1)

		Describe(Name, function()
			It("is frozen", function()
				Expect(table.isfrozen(New)).toBe(true)
			end)

			for _, Tag: string in AllTags do
				It(`{Tag}`, function()
					Expect(New:Allows(Tag)).toBe(OldAllows(Old.Tags[Tag]))

					for _, Attribute: string in Probes do
						Expect(New:Allows(Tag, Attribute)).toBe(OldAllows(Old.Tags[Tag], Attribute))
					end
				end)
			end

			It("unknown tags", function()
				Expect(Bundle.Denied == "Strip").toBe(Old.Wildcard)
			end)

			It("control characters", function()
				Expect(New:Has("Controls")).toBe(not Old.Strip)
			end)

			It("limits", function()
				const Limits: any = Bundle.Limits

				Expect(Limits.Depth).toBe(Old.Limits.MaxDepth)
				Expect(Limits.Nodes).toBe(Old.Limits.MaxNodes)
				Expect(Limits.Characters).toBe(Old.Limits.MaxTextLength)
				Expect(Limits.Objects).toBe(Old.Limits.MaxObjects)
				Expect(Limits.TextSize.Min).toBe(Old.Limits.MinTextSize)
				Expect(Limits.TextSize.Max).toBe(Old.Limits.MaxTextSize)
			end)
		end)
	end
end)
