IcCanvas: module
{
	PATH: con "/dis/lib/icurses/canvas.dis";

	Cell: adt
	{
		ch:   string;
		code: string;
	};

	Canvas: adt
	{
		id:    string;
		w:     int;
		h:     int;
		cells: array of Cell;
	};

	init: fn();

	newcanvas: fn(id: string, w, h: int): ref Canvas;
	find: fn(id: string): ref Canvas;
	remove: fn(id: string);

	clear: fn(c: ref Canvas, ch, code: string);
	fillrect: fn(c: ref Canvas, x, y, w, h: int, ch, code: string);
	putc: fn(c: ref Canvas, x, y: int, ch, code: string);
	puts: fn(c: ref Canvas, x, y: int, text, code: string);

	w: fn(c: ref Canvas): int;
	h: fn(c: ref Canvas): int;
	cell: fn(c: ref Canvas, x, y: int): Cell;
};