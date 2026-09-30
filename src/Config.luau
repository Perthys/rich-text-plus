--!strict

const NON_BREAKING_SPACE: string = "\u{A0}"
const MAXIMUM_TEXT_SIZE: number = 100

return table.freeze({
	Renderer = table.freeze({
		LINK_COLOR = Color3.fromRGB(92, 170, 255);
		MAXIMUM_FRAME_DELTA = 1 / 15;
		SIZE_TOLERANCE = 0.01;
	});

	Rendering = table.freeze({
		Passthrough = true;
		Culling = true;
		Clipping = true;
		SyntaxHighlight = true;
	});

	Presets = table.freeze({
		Default = table.freeze({
			Denied = "Strip";
			Limits = table.freeze({TextSize = table.freeze({Min = 8; Max = MAXIMUM_TEXT_SIZE})});
		});
		Trusted = table.freeze({
			Denied = "Escape";
			Limits = table.freeze({Depth = 32; Nodes = 4096; Characters = 16384; Objects = 64; TextSize = table.freeze({Min = 8; Max = 96})});
		});
		Chat = table.freeze({
			Intents = table.freeze({"Formatting", "LineBreaks", "Color", "Mark"});
			Denied = "Escape";
			Limits = table.freeze({Depth = 8; Nodes = 256; Characters = 1024; Objects = 0});
		});
		Plain = table.freeze({
			Intents = table.freeze({});
			Denied = "Escape";
			Limits = table.freeze({});
		});
	});

	Styles = table.freeze({
		MINIMUM_BOX_WIDTH = 40;
		MAXIMUM_TEXT_SIZE = MAXIMUM_TEXT_SIZE;
		CACHE_LIMIT = 512;
		SNAP_STEPS = 1000;
		MAXIMUM_ID_DIGITS = 20;
		MAXIMUM_THUMB_SIZE = 4;
		NamedColors = table.freeze({
			["white"] = Color3.fromRGB(255, 255, 255);
			["black"] = Color3.fromRGB(0, 0, 0);
			["red"] = Color3.fromRGB(255, 0, 0);
			["green"] = Color3.fromRGB(0, 128, 0);
			["lime"] = Color3.fromRGB(0, 255, 0);
			["blue"] = Color3.fromRGB(0, 0, 255);
			["yellow"] = Color3.fromRGB(255, 255, 0);
			["orange"] = Color3.fromRGB(255, 165, 0);
			["purple"] = Color3.fromRGB(128, 0, 128);
			["pink"] = Color3.fromRGB(255, 192, 203);
			["cyan"] = Color3.fromRGB(0, 255, 255);
			["magenta"] = Color3.fromRGB(255, 0, 255);
			["gray"] = Color3.fromRGB(128, 128, 128);
			["silver"] = Color3.fromRGB(192, 192, 192);
			["brown"] = Color3.fromRGB(165, 42, 42);
			["gold"] = Color3.fromRGB(255, 215, 0);
		});
	});

	Flatten = table.freeze({
		MAX_DEPTH = 256;
		MAXIMUM_STROKE = 16;
		STROKE_COLOR = Color3.new(0, 0, 0);
		MARK_COLOR = Color3.fromRGB(255, 255, 0);
		RECYCLE_LIMIT = 256;
	});

	Measure = table.freeze({
		CACHE_LIMIT = 16384;
		CASED_LIMIT = 4096;
		FAMILY_LIMIT = 64;
		TABLE_LIMIT = 256;
		LESSON_LIMIT = 256;
		CHECK_LIMIT = 8;
		TOLERANCE = 1;
		TEACH_BUDGET = 0.001;
		PRELOAD_BUDGET = 0.004;
		BLOCK_SIZE = 256;
		CODE_PAD_RATIO = 0.25;
		MEASURE_WIDTH = 100000;
		MINIMUM_ADVANCE = 0.01;
		GUESS_RATIO = 0.5;
	});

	Glyphs = table.freeze({
		ID_LIMIT = 32768;
		PAIR_LIMIT = 16384;
	});

	Scale = table.freeze({
		MINIMUM_FACTOR = 0.05;
		HEIGHT_TOLERANCE = 0.01;
		MINIMUM_BOX_HEIGHT = 8;
		FROZEN_MINIMUM_HEIGHT = 20;
		SEARCH_STEPS = 14;
		GUESS_STEPS = 2;
		CRAWL_STEPS = 8;
		REFINE_STEPS = 3;
		SHRINK_STEPS = 8;
		SOLUTION_LIMIT = 8;
	});

	Shape = table.freeze({
		RUN_BUDGET = 4096;
		ELLIPSIS = "\u{2026}";
		OVERFLOW_TOLERANCE = 0.5;
	});

	Native = table.freeze({
		CHURN_WINDOW = 1.5;
		CHURN_LIMIT = 3;
	});

	Schedule = table.freeze({
		FRAME_BUDGET = 0.002;
		STARVE_FRAMES = 30;
		COST_WEIGHT = 0.25;
		OUTLIER_RATIO = 4;
		COMPACT_FLOOR = 64;
	});

	Pool = table.freeze({
		LIMIT = 256;
		SPARE_LIMIT = 32;
	});

	Backdrop = table.freeze({
		SPARE_LIMIT = 16;
	});

	Segment = table.freeze({
		HOVER_TINT = 0.35;
		EFFECT_SEED_SCALE = 0.045;
	});

	Animate = table.freeze({
		FULL_RATE_HEIGHT = 12;
		VISIBLE_SHIFT = 0.5;
		RATE_PER_PIXEL = 5;
		LONGEST_INTERVAL = 0.25;
		PACE_INTERVAL = 0.25;
		PHASE_SPREAD = 0.0731;
	});

	Classes = table.freeze({
		INLINE_CODE_CORNER_LIMIT = 4;
		CODE_WRAP_TOLERANCE = 0.5;
		CODE_LAYOUT_LIMIT = 16;
		CODE_METRICS_LIMIT = 64;
		CODE_MARGIN_RATIO = 0.4;
		CODE_HEADER_RATIO = 0.75;
		HIGHLIGHTED_LANGUAGES = table.freeze({["lua"] = true, ["luau"] = true});
		MAXIMUM_EFFECT_AMPLITUDE = 50;
		MAXIMUM_EFFECT_FREQUENCY = 60;
		GRADIENT_LOOP_RESOLUTION = 12;
		GRADIENT_LOOP_FRAMES = 60;
		MAXIMUM_GRADIENT_COLORS = 20;
		MAXIMUM_GRADIENT_SPEED = 4;
		MAXIMUM_IMAGE_DIMENSION = 1024;
	});

	Theme = table.freeze({
		CodeFamily = "RobotoMono";
		CodeTextColor = Color3.fromHex("D4D4D4");
		CodeBackground = Color3.fromHex("1E1E1E");
		CodeBackgroundTransparency = 0;
		CodePadding = 8;
		CodeCornerRadius = 6;
		QuoteColor = Color3.fromHex("808080");
		RuleColor = Color3.fromHex("808080");
		HeadingScale = table.freeze({2, 1.6, 1.35, 1.15, 1, 0.9});
	});

	Syntax = table.freeze({
		Text = Color3.fromHex("D4D4D4");
		Keyword = Color3.fromHex("C586C0");
		Storage = Color3.fromHex("569CD6");
		Literal = Color3.fromHex("569CD6");
		Builtin = Color3.fromHex("4EC9B0");
		Type = Color3.fromHex("4EC9B0");
		String = Color3.fromHex("CE9178");
		Interpolation = Color3.fromHex("569CD6");
		Comment = Color3.fromHex("6A9955");
		Number = Color3.fromHex("B5CEA8");
		Function = Color3.fromHex("DCDCAA");
		Local = Color3.fromHex("9CDCFE");
		Operator = Color3.fromHex("D4D4D4");
	});

	Markdown = table.freeze({
		BASE_SIZE = 14;
		MAX_DEPTH = 12;
		MAX_HEADING_LEVEL = 6;
		MAX_ORDERED_DIGITS = 9;
		MAX_DESTINATION = 1024;
		AMPLIFICATION_LIMIT = 32;
		OUTPUT_SLACK = 16384;
		TAB_WIDTH = 4;
		NON_BREAKING_SPACE = NON_BREAKING_SPACE;
		LIST_INDENT = string.rep(NON_BREAKING_SPACE, 2);
		BULLET_GLYPHS = table.freeze({"•", "◦", "▪"});
		UNCHECKED_GLYPH = "☐";
		CHECKED_GLYPH = "☑";
		QUOTE_GLYPH = "▍";
	});
})
