const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const Root = path.resolve(__dirname, "..");
const Config = JSON.parse(fs.readFileSync(path.join(__dirname, "TestKit.json"), "utf8"));
const Source = path.resolve(Root, process.argv[2] || process.env.TESTKIT_SOURCE || Config.Source);

const Files = {
	"RunJest.luau": [
		[/const PORT = \d+/, `const PORT = ${Config.Port}`],
		[/const FOLDER_NAME = "[^"]*"/, `const FOLDER_NAME = "${Config.Folder}"`],
	],
	"serve.js": [
		[/REGEX_TEST_/g, `${Config.EnvPrefix}_`],
		[/\|\| 34981\)/, `|| ${Config.Port})`],
		[/luau-regex tests/, `${Config.Name} tests`],
	],
};

function Fail(Message) {
	console.error(`VendorTestKit: ${Message}`);
	process.exit(1);
}

function Revision() {
	try {
		return execFileSync("git", ["-C", Source, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).trim();
	} catch {
		return "unknown";
	}
}

for (const [Name, Rules] of Object.entries(Files)) {
	const From = path.join(Source, "tools", Name);
	if (!fs.existsSync(From)) Fail(`no ${Name} in ${path.dirname(From)} (pass a luau-regex path or set TESTKIT_SOURCE)`);
	let Text = fs.readFileSync(From, "utf8");
	for (const [Pattern, Replacement] of Rules) {
		if (!Pattern.test(Text)) Fail(`${Name} no longer matches ${Pattern}, update tools/VendorTestKit.js`);
		Pattern.lastIndex = 0;
		Text = Text.replace(Pattern, Replacement);
	}
	fs.writeFileSync(path.join(__dirname, Name), Text);
}

console.log(`vendored test kit from luau-regex ${Revision()} (${Source}) into tools`);
