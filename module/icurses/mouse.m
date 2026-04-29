include "sys.m";

IcMouse: module
{
	PATH: con "/dis/lib/icurses/mouse.dis";

	MousePath: con "/dev/emouse";

	ButtonNone:   con 0;
	ButtonLeft:   con 1;

	#
	# Keep IcMouse aligned with the current /dev/emouse backend stream:
	# bit 2 is reported as right, bit 4 is reported as middle.
	#
	ButtonRight:  con 2;
	ButtonMiddle: con 4;

	ButtonWheelUp:   con 8;
	ButtonWheelDown: con 16;

	ButtonMask: con ButtonLeft | ButtonMiddle | ButtonRight;
	WheelMask: con ButtonWheelUp | ButtonWheelDown;

	ModNone:  con 0;
	ModShift: con 1;
	ModCtrl:  con 2;
	ModAlt:   con 4;

	KindNone:    con 0;
	KindMove:    con 1;
	KindPress:   con 2;
	KindRelease: con 3;
	KindDrag:    con 4;
	KindWheel:   con 5;
	KindChange:  con 6;

	Event: adt
	{
		x:       int;
		y:       int;
		buttons: int;
		mods:    int;

		kind:     int;
		changed:  int;
		pressed:  int;
		released: int;

		ok:      int;
		raw:     string;
	};

	init: fn();

	open: fn(): int;
	close: fn();

	read: fn(): Event;
	parse: fn(s: string): Event;

	buttons: fn(e: Event): string;
	mods: fn(e: Event): string;
	kind: fn(e: Event): string;

	hasbutton: fn(e: Event, b: int): int;
	hasmod: fn(e: Event, m: int): int;

	inside: fn(e: Event, x, y, w, h: int): int;
};