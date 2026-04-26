implement IcText;

include "sys.m";
include "icurses/text.m";

sys: Sys;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

strlen2(s: string, width: int): int
{
	width = width;
	return len s;
}

wrapline(s: string, width: int): array of string
{
	n, i, start, k, ls: int;
	lines: array of string;

	if(width <= 0)
		width = 1;

	ls = len s;
	if(ls == 0)
		return array[] of { "" };

	n = (ls + width - 1) / width;
	lines = array[n] of string;

	start = 0;
	k = 0;
	while(start < ls){
		i = start + width;
		if(i > ls)
			i = ls;
		lines[k++] = s[start:i];
		start = i;
	}

	return lines;
}

wrapnums(n: int): array of int
{
	a: array of int;

	if(n < 0)
		n = 0;

	a = array[3] of int;
	a[0] = n;
	a[1] = n + 1;
	a[2] = n + 2;

	return a;
}