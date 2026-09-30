--!strict

const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const PORT = 34900
const FOLDER_NAME = "JEST_RichTextPlus"

type Node = { Name: string, ClassName: string, Source: string?, Children: { Node } }

const function Build(Data: Node, Parent: Instance?): Instance
	const Made = Instance.new(Data.ClassName)
	Made.Name = Data.Name
	if Data.Source then (Made :: any).Source = Data.Source end
	for _, Child in Data.Children do Build(Child, Made) end
	Made.Parent = Parent
	return Made
end

const Existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
if Existing then Existing:Destroy() end

_G.NOCOLOR = true

const Tree: Node = HttpService:JSONDecode(HttpService:GetAsync(`http://127.0.0.1:{PORT}/`, true))
Tree.Name = FOLDER_NAME
const Root = Build(Tree, ReplicatedStorage)

const Jest = (require :: any)(Root:FindFirstChild("DevPackages"):FindFirstChild("Jest"))
const Tests = Root:FindFirstChild("tests") :: Instance
const Status, Result = Jest.runCLI(Root, {verbose = false, ci = true}, {Tests}):awaitStatus()
const Bench = (require :: any)(Tests:FindFirstChild("Bench")).Run()

Root:Destroy()

if Status == "Rejected" then
	error(tostring(Result))
end

for _, Failure in Bench.Failures do print(`[Bench]     {Failure}`) end
print(`[Bench] {Bench.Passed} passed, {Bench.Failed} failed`)

const Totals = Result.results
print(`[Jest] {Totals.numPassedTests} passed, {Totals.numFailedTests} failed, {Totals.numTotalTests} total`)
return Totals.success and Bench.Failed == 0
