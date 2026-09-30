--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")

const LoopResolution: number = Config.Classes.GRADIENT_LOOP_RESOLUTION
const LoopFrames: number = Config.Classes.GRADIENT_LOOP_FRAMES
const MaximumColors: number = Config.Classes.MAXIMUM_GRADIENT_COLORS
const MaximumSpeed: number = Config.Classes.MAXIMUM_GRADIENT_SPEED
const OpenByte: number = string.byte("(")
const CloseByte: number = string.byte(")")
const CommaByte: number = string.byte(",")

const Sequences = setmetatable({} :: { [Types.Gradient]: { ColorSequence } }, {__mode = "k"})

const function SplitColors(List: string): { Color3 }
	const Colors: { Color3 } = {}

	local Depth: number = 0
	local Start: number = 1

	for Index = 1, #List + 1 do
		const Code: number? = string.byte(List, Index)

		if Code == OpenByte then
			Depth += 1
		elseif Code == CloseByte then
			Depth = math.max(Depth - 1, 0)
		elseif Code == nil or (Code == CommaByte and Depth == 0) then
			const Color: Color3? = Styles.ParseColor(string.sub(List, Start, Index - 1))
			if Color and #Colors < MaximumColors then table.insert(Colors, Color :: Color3) end

			Start = Index + 1
		end
	end

	return Colors
end

const function Parse(Node: Types.Node): Types.Gradient?
	const List: string? = Styles.Attribute(Node, "Colors"); if not List then return nil end

	const Colors: { Color3 } = SplitColors(List :: string)

	if #Colors == 0 then return nil end
	if #Colors == 1 then table.insert(Colors, Colors[1]) end

	const Keypoints: { ColorSequenceKeypoint } = table.create(#Colors)

	for Index: number, Color: Color3 in (Colors) do
		Keypoints[Index] = ColorSequenceKeypoint.new((Index - 1) / (#Colors - 1), Color)
	end

	return {
		Sequence = ColorSequence.new(Keypoints);
		Colors = Colors;
		Speed = math.clamp(Styles.Finite(tonumber(Styles.Attribute(Node, "Speed")), 0), -MaximumSpeed, MaximumSpeed);
		Rotation = Styles.Finite(tonumber(Styles.Attribute(Node, "Rotation")), 0) % 360;
	}
end

const function Evaluate(Colors: { Color3 }, Position: number): Color3
	const Count: number = #Colors
	const Scaled: number = (Position % 1) * Count
	const Floor: number = math.floor(Scaled)
	const Index: number = Floor % Count

	return Colors[Index + 1]:Lerp(Colors[(Index + 1) % Count + 1], Scaled - Floor)
end

const function Build(Colors: { Color3 }, Phase: number): ColorSequence
	const Keypoints: { ColorSequenceKeypoint } = table.create(LoopResolution + 1)

	for Step = 0, LoopResolution do
		const Position: number = Step / LoopResolution
		Keypoints[Step + 1] = ColorSequenceKeypoint.new(Position, Evaluate(Colors, Position - Phase))
	end

	return ColorSequence.new(Keypoints)
end

const function Loop(Data: Types.Gradient, Frame: number): ColorSequence
	const Frames: { ColorSequence } = Sequences[Data] or table.create(LoopFrames)
	Sequences[Data] = Frames

	const Cached: ColorSequence? = Frames[Frame + 1]; if Cached then return Cached end

	const Created: ColorSequence = Build(Data.Colors, Frame / LoopFrames)
	Frames[Frame + 1] = Created

	return Created
end

const function Apply(Style: Types.Style, Node: Types.Node): ()
	Style.Gradient = Parse(Node)
end

return {
	Kind = "Style";
	Apply = Apply;
	Parse = Parse;
	Frames = LoopFrames;
	Loop = Loop;
}
