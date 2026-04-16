include "icurses/screen.m";

IcButton: module
{
	PATH: con "/dis/lib/icurses/button.dis";

	Button: adt
	{
		r:		IcRect->Rect;
		label:	string;
		focused:	int;
	};

	init: fn();
	new: fn(x, y: int, label: string): ref Button;
	draw: fn(screen: IcScreen, scr: ref IcScreen->Screen, b: ref Button);
	contains: fn(b: ref Button, x, y: int): int;
	setfocus: fn(b: ref Button, focused: int);
};