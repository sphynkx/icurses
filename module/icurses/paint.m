include "icurses/view.m";
include "icurses/glyph.m";
include "icurses/canvas.m";

IcPaint: module
{
	PATH: con "/dis/lib/icurses/paint.dis";

	FrameAscii:  con 0;
	FrameSingle: con 1;
	FrameDouble: con 2;

	ProgressSolid:   con 0;
	ProgressText:    con 1;
	ProgressPercent: con 2;
	ProgressTail:    con 3;

	SpinnerAscii: con 0;
	SpinnerLine:  con 1;
	SpinnerDots:  con 2;

	Cell: adt
	{
		ch:   string;
		code: string;
		sig:  int;
	};

	Renderer: adt
	{
		out:        ref Sys->FD;
		w:          int;
		h:          int;
		front:      array of Cell;
		back:       array of Cell;
		framestyle: int;
	};

	init: fn();

	new: fn(out: ref Sys->FD, w, h: int): ref Renderer;
	close: fn(r: ref Renderer);

	setframestyle: fn(r: ref Renderer, style: int);

	clear: fn(r: ref Renderer);
	drawtree: fn(r: ref Renderer, t: ref IcView->Tree);
	status: fn(r: ref Renderer, row: int, text: string);
	flush: fn(r: ref Renderer);

	putc: fn(r: ref Renderer, x, y: int, ch, code: string);
	puts: fn(r: ref Renderer, x, y: int, text, code: string);
	fillrect: fn(r: ref Renderer, x, y, w, h: int, ch, code: string);

	box: fn(r: ref Renderer, x, y, w, h, style: int, code: string);
	hbar: fn(r: ref Renderer, x, y, w, value, total: int, code: string);
	vbar: fn(r: ref Renderer, x, y, h, value, total: int, code: string);

	canvasnew: fn(id: int, w, h: int): int;
	canvasclear: fn(id: int, ch, code: string): int;
	canvasfill: fn(id: int, x, y, w, h: int, ch, code: string): int;
	canvasputc: fn(id: int, x, y: int, ch, code: string): int;
	canvasputs: fn(id: int, x, y: int, text, code: string): int;
};