include "icurses/ui.m";

IcHit: module
{
	PATH: con "/dis/lib/icurses/hit.dis";

	ButtonLeft:   con 1;
	ButtonRight:  con 2;
	ButtonMiddle: con 4;

	Hit: adt
	{
		ok:    int;

		id:    string;
		kind:  string;

		x:     int;
		y:     int;
		w:     int;
		h:     int;
	};

	init: fn();

	empty: fn(): Hit;

	bounds: fn(u: ref IcUi->Ui, id: string): Hit;
	inside: fn(u: ref IcUi->Ui, id: string, x, y: int): int;

	node: fn(u: ref IcUi->Ui, x, y: int): ref IcView->Node;
	info: fn(u: ref IcUi->Ui, x, y: int): Hit;
	id: fn(u: ref IcUi->Ui, x, y: int): string;

	focus: fn(u: ref IcUi->Ui, x, y: int): IcMsg->Msg;
	message: fn(u: ref IcUi->Ui, x, y, buttons: int): IcMsg->Msg;
	activate: fn(u: ref IcUi->Ui, x, y, buttons: int): IcMsg->Msg;

	describe: fn(h: Hit): string;
};