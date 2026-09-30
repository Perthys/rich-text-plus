const http = require("http");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const Root = path.resolve(__dirname, "..");
const Port = Number(process.env.RTP_TEST_PORT || 34900);
const ProjectFile = process.env.RTP_TEST_PROJECT || "test.project.json";
const SourcePattern = /\.(luau|lua)$/;

function Sourcemap() {
	const Result = spawnSync("rojo", ["sourcemap", ProjectFile], { cwd: Root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
	if (Result.status !== 0) throw new Error(Result.stderr || "rojo sourcemap failed");
	return JSON.parse(Result.stdout);
}

function Convert(Node) {
	const SourceFile = (Node.filePaths || []).find((File) => SourcePattern.test(File));
	return {
		Name: Node.name,
		ClassName: Node.className,
		Source: SourceFile ? fs.readFileSync(path.resolve(Root, SourceFile), "utf8") : undefined,
		Children: (Node.children || []).map(Convert),
	};
}

http
	.createServer((Request, Response) => {
		try {
			const Body = JSON.stringify(Convert(Sourcemap()));
			Response.writeHead(200, { "Content-Type": "application/json" });
			Response.end(Body);
		} catch (Error) {
			Response.writeHead(500);
			Response.end(String(Error));
		}
	})
	.listen(Port, "127.0.0.1", () => console.log(`rich-text-plus tests on ${Port} serving ${ProjectFile}`));
