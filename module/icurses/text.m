# WARNING
# On this target/runtime, internal helper functions in this module may crash
# if they create local heap-managed values (for example string, array, list, ref).
# Keep such allocations in exported/top-level call functions and pass the values
# into helpers as arguments instead.

IcText: module
{
	PATH: con "/dis/lib/icurses/text.dis";

	init: fn();

	padright: fn(s: string, w: int): string;
	slicestr: fn(s: string, start, width: int): string;

	linecount: fn(s: string): int;
	splitlines: fn(s: string): array of string;

	wrapline: fn(s: string, width: int): array of string;
	wrapbuflines: fn(buf: string, width: int): array of string;
};