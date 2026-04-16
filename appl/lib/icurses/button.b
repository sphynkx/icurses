implement IcButton;

include "sys.m";
	sys: Sys;
include "icurses/theme.m";
include "icurses/button.m";

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

new(x, y: int, label: string): ref IcButton->Button
{
	b := ref IcButton->Button;
	b.label = label;
	b.focused = 0;
	b.r.x = x;
	b.r.y = y;
	b.r.w = len label + 4;
	b.r.h = 1;
	return b;
}

contains(b: ref IcButton->Button, x, y: int): int
{
	if(b == nil)
		return 0;
	return x >= b.r.x && x < b.r.x + b.r.w && y >= b.r.y && y < b.r.y + b.r.h;
}

setfocus(b: ref IcButton->Button, focused: int)
{
	if(b == nil)
		return;
	b.focused = focused;
}

draw(screen: IcScreen, scr: ref IcScreen->Screen, b: ref IcButton->Button)
{
	attr: int;

	if(b == nil)
		return;

	if(b.focused)
		attr = IcTheme->AttrFocus;
	else
		attr = IcTheme->AttrButton;

	screen->text(scr, b.r.x, b.r.y, "[ ", attr);
	screen->text(scr, b.r.x + 2, b.r.y, b.label, attr);
	screen->text(scr, b.r.x + 2 + len b.label, b.r.y, " ]", attr);
}