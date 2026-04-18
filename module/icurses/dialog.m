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

	Step: adt
	{
		done:   int;
		code:   int;
		label:  string;
		status: string;
	};

	BtnOK:     con 0;
	BtnCancel: con 1;
	BtnHelp:   con 2;

	NavNone:  con 0;
	NavPrev:  con 1;
	NavNext:  con 2;
	NavFirst: con 3;
	NavLast:  con 4;

	ActNone:     con 0;
	ActNavPrev:  con 1;
	ActNavNext:  con 2;
	ActNavFirst: con 3;
	ActNavLast:  con 4;
	ActConfirm:  con 5;
	ActCancel:   con 6;

	init: fn();
	new: fn(x, y, w, h: int, title, msg1, msg2, msg3, msg4: string): ref Dialog;
	reset: fn(d: ref Dialog);

	x: fn(d: ref Dialog): int;
	y: fn(d: ref Dialog): int;
	w: fn(d: ref Dialog): int;
	h: fn(d: ref Dialog): int;
	contentx: fn(d: ref Dialog): int;
	buttony: fn(d: ref Dialog): int;

	nextfocus: fn(d: ref Dialog);
	prevfocus: fn(d: ref Dialog);
	focusfirst: fn(d: ref Dialog);
	focuslast: fn(d: ref Dialog);
	focused: fn(d: ref Dialog): int;
	isfocused: fn(d: ref Dialog, btn: int): int;
	titletext: fn(d: ref Dialog): string;
	titlex: fn(d: ref Dialog): int;
	titley: fn(d: ref Dialog): int;
	linecount: fn(): int;
	lineat: fn(d: ref Dialog, i: int): string;
	liney: fn(d: ref Dialog, i: int): int;
	buttoncount: fn(): int;
	buttonat: fn(i: int): int;
	buttonlabel: fn(btn: int): string;
	buttonx: fn(d: ref Dialog, btn: int): int;
	navigate: fn(d: ref Dialog, nav: int): int;
	select: fn(d: ref Dialog): int;
	cancel: fn(d: ref Dialog): int;
	selected: fn(d: ref Dialog): int;
	isselected: fn(d: ref Dialog, btn: int): int;
	selectedlabel: fn(d: ref Dialog): string;
	activate: fn(d: ref Dialog): string;
	finish: fn(d: ref Dialog, cancel: int): string;
	step: fn(d: ref Dialog, act: int): Step;
};