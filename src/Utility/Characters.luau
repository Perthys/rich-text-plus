--!strict

return table.freeze({
	TAB = 9;
	NEWLINE = 10;
	SPACE = 32;
	HASH = 35;
	ASCII_LIMIT = 0x80;
	WIDE_PATTERN = "[\128-\255]";
	Separators = table.freeze({[9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [32] = true}) :: { [number]: boolean };
	Whitespace = table.freeze({[9] = true, [10] = true, [12] = true, [13] = true, [32] = true}) :: { [number]: boolean };
})
