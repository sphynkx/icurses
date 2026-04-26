IcText: module
{
	PATH: con "/dis/lib/icurses/text.dis";

	init: fn();

	strlen2: fn(s: string, width: int): int;
	wrapline: fn(s: string, width: int): array of string;
	wrapnums: fn(n: int): array of int;
};