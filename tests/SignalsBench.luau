--!strict

const Signal = require("../Packages/RichTextPlus/Utility/Signal")

type Summary = { Passed: number, Failed: number, Failures: { string }, Report: { string }? }

const LIMIT: number = 0.01

const function Run(): Summary
	const Subject: any = (Signal :: any).new()

	Subject:Connect(function() task.wait(0.25) end)
	Subject:Connect(function() end)

	const Started: number = os.clock()
	Subject:Fire()
	const Elapsed: number = os.clock() - Started

	Subject:Destroy()

	const Report: { string } = {string.format("fire returns without running handlers: %.3f ms", Elapsed * 1000)}

	if Elapsed < LIMIT then return {Passed = 1, Failed = 0, Failures = {}, Report = Report} end

	return {Passed = 0, Failed = 1, Failures = {string.format("fire returns without running handlers: took %.3f ms", Elapsed * 1000)}, Report = Report}
end

return {
	Run = Run,
}
