include "icurses/ui.m";

IcList: module
{
	PATH: con "/dis/lib/icurses/list.dis";

	List: adt
	{
		id:    int;
		items: array of string;

		top:   int;
		sel:   int;
		rows:  int;
		wrap:  int;
	};

	init: fn();

	new: fn(id: int, rows: int): ref List;
	clear: fn(l: ref List);

	setitems: fn(l: ref List, items: array of string): int;
	setrows: fn(l: ref List, rows: int): int;
	setwrap: fn(l: ref List, wrap: int): int;

	count: fn(l: ref List): int;
	selected: fn(l: ref List): int;
	topindex: fn(l: ref List): int;
	current: fn(l: ref List): string;

	render: fn(u: ref IcUi->Ui, l: ref List): int;

	select: fn(u: ref IcUi->Ui, l: ref List, sel: int): IcMsg->Msg;
	next: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;
	prev: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;
	pageup: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;
	pagedown: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;
	home: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;
	end: fn(u: ref IcUi->Ui, l: ref List): IcMsg->Msg;

	handlekey: fn(u: ref IcUi->Ui, l: ref List, k: int): IcMsg->Msg;
};