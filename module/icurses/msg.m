IcMsg: module
{
	PATH: con "/dis/lib/icurses/msg.dis";

	KindNone:      con 0;
	KindInput:     con 1;
	KindCommand:   con 2;
	KindNotify:    con 3;
	KindLifecycle: con 4;
	KindFocus:     con 5;
	KindPaint:     con 6;

	RouteDirect: con 0;
	RouteBubble: con 1;
	RouteSubtree: con 2;

	Msg: adt
	{
		src:     string;
		dst:     string;
		kind:    int;
		cmd:     string;
		route:   int;
		flags:   int;
		seq:     int;

		sarg:    string;
		iarg0:   int;
		iarg1:   int;
		iarg2:   int;

		handled: int;
	};

	init: fn();

	none: fn(): Msg;
	newmsg: fn(src, dst: string, kind: int, cmd: string): Msg;
	isnone: fn(m: Msg): int;
};