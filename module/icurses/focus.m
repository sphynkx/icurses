include "icurses/ui.m";

IcFocus: module
{
	PATH: con "/dis/lib/icurses/focus.dis";

	init: fn();

	focusid: fn(u: ref IcUi->Ui): string;
	first: fn(u: ref IcUi->Ui): string;
	next: fn(u: ref IcUi->Ui): string;
	prev: fn(u: ref IcUi->Ui): string;
	set: fn(u: ref IcUi->Ui, id: string): int;
	clear: fn(u: ref IcUi->Ui);

	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};