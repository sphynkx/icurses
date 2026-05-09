#
# 04_02_low_level_terminal.b
#
# Low-level terminal-only icurses application.
#
# This example does not use IcUi, the element tree, messages, or renderer.
# It includes only:
#   - draw.m
#   - icurses/icurses.m
#
# This scheme is useful when an application wants direct terminal control:
# cursor movement, SGR attributes, terminal size, and raw keyboard input.
#

implement LowLevelTerminalDemo;

include "draw.m";
include "icurses/icurses.m";

LowLevelTerminalDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;

out: ref Sys->FD;
appscreen: int;

loadmods()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ic->init();
}

enterappscreen()
{
	if(out == nil || appscreen)
		return;

	sys->fprint(out, "%c[?1049h", 27);
	ic->resettty(out);
	ic->hidecursor(out);
	ic->cleartty(out);

	appscreen = 1;
}

leaveappscreen()
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	ic->cleartty(out);

	if(appscreen){
		sys->fprint(out, "%c[?1049l", 27);
		appscreen = 0;
	}

	ic->resettty(out);
	ic->showcursor(out);
}

drawline(row: int, text: string)
{
	if(out == nil)
		return;

	ic->cup(out, row, 1);
	ic->sgr(out, "0");
	sys->fprint(out, "%s", text);
}

drawheader(w, h: int)
{
	ic->cleartty(out);

	drawline(1, "Low-level Icurses terminal example");
	drawline(3, "No IcUi object is created in this program.");
	drawline(4, "No tree, renderer, buttons, messages, or step model are used.");
	drawline(6, "Terminal size: " + sys->sprint("%d", w) + " x " + sys->sprint("%d", h));
	drawline(8, "Press any key to inspect it.");
	drawline(9, "Press q, Q, or Esc to exit.");
}

drawkey(k, count: int)
{
	drawline(11, "Key count: " + sys->sprint("%d", count) + "          ");
	drawline(12, "Last key: " + ic->keyname(k) + " code=" + sys->sprint("%d", k) + "          ");
}

run()
{
	w, h, k, count, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	count = 0;
	done = 0;

	enterappscreen();

	(w, h) = ic->termsize();
	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	drawheader(w, h);

	if(ic->openkbd() < 0){
		leaveappscreen();
		sys->print("cannot open keyboard\n");
		return;
	}

	for(; !done;){
		k = ic->readkey();

		if(k < 0)
			break;

		if(k == 'q' || k == 'Q' || ic->iscancel(k)){
			done = 1;
			break;
		}

		count++;
		drawkey(k, count);
	}

	ic->closekbd();
	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}