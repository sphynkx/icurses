IcDialog: module
{
	PATH: con "/dis/lib/icurses/dialog.dis";

	Dialog: adt
	{
		x:		int;
		y:		int;
		w:		int;
		h:		int;

		title:		string;
		msg1:		string;
		msg2:		string;
		msg3:		string;
		msg4:		string;

		focus:		int;
		selected:	int;
	};

	BtnOK:     con 0;
	BtnCancel: con 1;
	BtnHelp:   con 2;

	init: fn();
	new: fn(x, y, w, h: int, title, msg1, msg2, msg3, msg4: string): ref Dialog;
	nextfocus: fn(d: ref Dialog);
	prevfocus: fn(d: ref Dialog);
	select: fn(d: ref Dialog): int;
	selectedlabel: fn(d: ref Dialog): string;
};