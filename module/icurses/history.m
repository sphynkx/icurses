include "icurses/input.m";

IcHistory: module
{
	PATH: con "/dis/lib/icurses/history.dis";

	History: adt
	{
		inputid:  string;
		popupid:  string;

		items:    array of string;
		sel:      int;
		maxitems: int;
		wrap:     int;

		visible:  int;
		rows:     int;
	};

	init: fn();

	new: fn(inputid: string, maxitems: int): ref History;

	clear: fn(h: ref History);
	add: fn(h: ref History, text: string): int;

	count: fn(h: ref History): int;
	current: fn(h: ref History): string;
	summary: fn(h: ref History): string;

	prev: fn(h: ref History): string;
	next: fn(h: ref History): string;

	popup: fn(u: ref IcUi->Ui, h: ref History,
		parentid, id: string,
		x, y, w, rows: int): int;

	show: fn(u: ref IcUi->Ui, h: ref History): int;
	hide: fn(u: ref IcUi->Ui, h: ref History): int;
	isvisible: fn(h: ref History): int;

	apply: fn(u: ref IcUi->Ui, h: ref History): IcMsg->Msg;
	submit: fn(u: ref IcUi->Ui, h: ref History): IcMsg->Msg;

	handlekey: fn(u: ref IcUi->Ui, h: ref History, k: int): IcMsg->Msg;
};