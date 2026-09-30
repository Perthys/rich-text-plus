--!strict

const StarterGui = game:GetService("StarterGui")

const PREFIX: string = "RTPTest_"

const Gui = {}

function Gui.new(Name: string): ScreenGui
	const Full: string = PREFIX .. Name
	const Existing: Instance? = StarterGui:FindFirstChild(Full)
	if Existing then Existing:Destroy() end

	const Created: ScreenGui = Instance.new("ScreenGui")
	Created.Name = Full
	Created.Parent = StarterGui

	return Created
end

function Gui.Cleanup(): ()
	for _, Child: Instance in StarterGui:GetChildren() do
		if string.sub(Child.Name, 1, #PREFIX) == PREFIX then Child:Destroy() end
	end
end

return Gui
