IcButton: module
{
	PATH: con "/dis/lib/icurses/button.dis";

	Button: adt
	{
		x:		int;
		y:		int;
		w:		int;
		h:		int;
		label:		string;
		focused:	int;
	};

	init: fn();
	new: fn(x, y: int, label: string): ref Button;
	contains: fn(b: ref Button, x, y: int): int;
	setfocus: fn(b: ref Button, focused: int);
};