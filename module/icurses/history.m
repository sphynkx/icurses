include "icurses/input.m";

IcHistory: module
{
	PATH: con "/dis/lib/icurses/history.dis";

	History: adt
	{
		inputid:  string;
		items:    array of string;
		sel:      int;
		maxitems: int;
		wrap:     int;
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

	apply: fn(u: ref IcUi->Ui, h: ref History): IcMsg->Msg;
	submit: fn(u: ref IcUi->Ui, h: ref History): IcMsg->Msg;

	handlekey: fn(u: ref IcUi->Ui, h: ref History, k: int): IcMsg->Msg;
};