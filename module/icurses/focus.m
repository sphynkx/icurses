include "icurses/ui.m";

IcFocus: module
{
	PATH: con "/dis/lib/icurses/focus.dis";

	init: fn();

	focusid: fn(u: ref IcUi->Ui): int;
	first: fn(u: ref IcUi->Ui): int;
	next: fn(u: ref IcUi->Ui): int;
	prev: fn(u: ref IcUi->Ui): int;
	set: fn(u: ref IcUi->Ui, id: int): int;
	clear: fn(u: ref IcUi->Ui);

	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};