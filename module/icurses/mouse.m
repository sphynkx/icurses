IcMouse: module
{
	PATH: con "/dis/lib/icurses/mouse.dis";

	MousePath: con "/dev/emouse";

	KindNone:   con 0;
	KindMove:   con 1;
	KindDown:   con 2;
	KindUp:     con 3;
	KindDrag:   con 4;
	KindButton: con 5;

	ButtonLeft:   con 1;
	ButtonMiddle: con 4;
	ButtonRight:  con 2;

	ModShift: con 1;
	ModCtrl:  con 2;
	ModAlt:   con 4;

	Event: adt
	{
		x:           int;
		y:           int;
		buttons:     int;
		lastbuttons: int;
		mods:        int;

		dx:          int;
		dy:          int;

		kind:        int;
	};

	init: fn();

	open: fn(): int;
	close: fn();
	isopen: fn(): int;

	none: fn(): Event;
	parse: fn(s: string): Event;
	read: fn(): Event;

	kindname: fn(kind: int): string;
	buttondown: fn(e: Event, button: int): int;
	buttonup: fn(e: Event, button: int): int;
	pressed: fn(e: Event, button: int): int;

	shift: fn(e: Event): int;
	ctrl: fn(e: Event): int;
	altmod: fn(e: Event): int;

	summary: fn(e: Event): string;
};