--!strict
--!native
--!optimize 2

const Cache = require("@self/Cache")
const Build = require("@self/Build")
const Place = require("@self/Place")

return {
	Obtain = Cache.Obtain;
	Read = Cache.Read;
	Find = Cache.Find;
	Base = Cache.Base;
	Blocked = Cache.Blocked;
	Prune = Cache.Prune;
	Create = Build.Create;
	Splice = Build.Splice;
	Finalize = Place.Finalize;
	Current = Place.Current;
	Remember = Place.Remember;
	Restore = Cache.Restore;
	Apply = Cache.Apply;
	Drop = Cache.Drop;
}
