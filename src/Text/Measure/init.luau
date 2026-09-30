--!strict
--!native
--!optimize 2

const Metrics = require("@self/Metrics")
const Preload = require("@self/Preload")
const Fit = require("@self/Fit")

return {
	CacheLimit = Metrics.CacheLimit;
	FontOf = Metrics.FontOf;
	Cached = Metrics.Cached;
	Bounds = Metrics.Bounds;
	Cased = Metrics.Cased;
	Uppercased = Metrics.Uppercased;
	WidthOf = Metrics.WidthOf;
	Scaled = Metrics.Scaled;
	Pad = Metrics.Pad;
	Gather = Preload.Gather;
	Preload = Preload.Preload;
	TableOf = Preload.TableOf;
	Split = Fit.Split;
	Fill = Fit.Fill;
	Run = Fit.Run;
}
