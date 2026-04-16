IcScreen: module
{
	PATH: con "/dis/lib/icurses/screen.dis";

	Cell: adt
	{
		ch:	string;
		attr:	int;
		sig:	int;
	};

	Screen: adt
	{
		w:	int;
		h:	int;
		front:	array of Cell;
		back:	array of Cell;
		dirty:	array of int;
	};

	init:		fn();
	new:		fn(w, h: int): ref Screen;
	reset:		fn(scr: ref Screen);
	invalidate:	fn(scr: ref Screen);
	clear:		fn(scr: ref Screen, ch: string, attr: int);
	clearrect:	fn(scr: ref Screen, x, y, w, h: int, ch: string, attr: int);
	putc:		fn(scr: ref Screen, x, y: int, ch: string, attr: int);
	put:		fn(scr: ref Screen, x, y: int, s: string, attr: int);
	text:		fn(scr: ref Screen, x, y: int, s: string, attr: int);
	fill:		fn(scr: ref Screen, x, y, w, h: int, ch: string, attr: int);
	hline:		fn(scr: ref Screen, x, y, w: int, ch: string, attr: int);
	vline:		fn(scr: ref Screen, x, y, h: int, ch: string, attr: int);
	boxdouble:	fn(scr: ref Screen, x, y, w, h: int, attr: int);
	shadow:		fn(scr: ref Screen, x, y, w, h: int, attr: int);
};