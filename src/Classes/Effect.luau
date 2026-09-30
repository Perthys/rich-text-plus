--!strict
--!native
--!optimize 2

const Config = require("../Config")
const Types = require("../Types")
const Styles = require("../Utility/Styles")

type Frame = Types.EffectFrame
type Shape = { Amplitude: number, Frequency: number }

const MaximumAmplitude: number = Config.Classes.MAXIMUM_EFFECT_AMPLITUDE
const MaximumFrequency: number = Config.Classes.MAXIMUM_EFFECT_FREQUENCY

const function WaveOffset(Time: number, Shape: Shape, Seed: number): (number, number)
	return 0, math.sin(Time * Shape.Frequency + Seed) * Shape.Amplitude
end

const function ShakeOffset(Time: number, Shape: Shape, Seed: number): (number, number)
	const Moment: number = Time * Shape.Frequency

	return math.noise(Seed, Moment) * Shape.Amplitude * 2, math.noise(Moment, Seed) * Shape.Amplitude * 2
end

const function Wave(Frame: Frame): ()
	Frame.Offset = Vector2.new(WaveOffset(Frame.Time, Frame, Frame.Seed))
end

const function Shake(Frame: Frame): ()
	Frame.Offset = Vector2.new(ShakeOffset(Frame.Time, Frame, Frame.Seed))
end

const Definitions: { [string]: Types.ClassDefinition } = {
	["Wave"] = table.freeze({Kind = "Effect", Update = Wave}) :: Types.ClassDefinition;
	["Shake"] = table.freeze({Kind = "Effect", Update = Shake}) :: Types.ClassDefinition;
}

const Internal: { [Types.EffectUpdate]: Types.EffectOffset } = {
	[Wave] = WaveOffset;
	[Shake] = ShakeOffset;
}

const function Data(Name: string, Node: Types.Node, Shaking: boolean, Parent: Types.EffectData?): Types.EffectData
	return {
		Name = Name;
		Amplitude = math.clamp(Styles.Finite(tonumber(Styles.Attribute(Node, "Amplitude")), if Shaking then 1.2 else 2.5), 0, MaximumAmplitude);
		Frequency = math.clamp(Styles.Finite(tonumber(Styles.Attribute(Node, "Frequency")), if Shaking then 11 else 6), 0, MaximumFrequency);
		Node = Node;
		Parent = Parent;
	}
end

const function Apply(Style: Types.Style, Node: Types.Node, _State: Types.Fields): ()
	const Name: string = Styles.PascalName(Node.TagType or "")

	Style.Effect = Data(Name, Node, Name == "Shake", Style.Effect)
end

const function Custom(Style: Types.Style, Name: string, Node: Types.Node): ()
	Style.Effect = Data(Name, Node, false, Style.Effect)
end

return {
	Kind = "Style";
	Apply = Apply;
	Custom = Custom;
	Definitions = Definitions;
	Internal = Internal;
}
