include "icurses/menu.m";

IcMenuNav: module
{
	PATH: con "/dis/lib/icurses/menunav.dis";

	ActiveNav: con 0;
	ActivePopup: con 1;
	ActiveAction: con 2;

	Menu: adt
	{
		navid: int;
		popupid: int;
		actionid: int;

		navitems: array of IcMenu->Item;
		popupitems: array of IcMenu->Item;
		actionitems: array of IcMenu->Item;

		navsel: int;
		popupsel: int;
		actionsel: int;

		active: int;
		wrap: int;
	};

	init: fn();

	new: fn(navid, popupid, actionid: int): ref Menu;

	setnav: fn(m: ref Menu, id: int, items: array of IcMenu->Item, sel: int): int;
	setpopup: fn(m: ref Menu, id: int, items: array of IcMenu->Item, sel: int): int;
	setaction: fn(m: ref Menu, id: int, items: array of IcMenu->Item, sel: int): int;

	setwrap: fn(m: ref Menu, wrap: int): int;

	setactive: fn(u: ref IcUi->Ui, m: ref Menu, active: int): IcMsg->Msg;
	activeid: fn(m: ref Menu): string;
	activeindex: fn(m: ref Menu): int;
	activecount: fn(m: ref Menu): int;
	activeitem: fn(m: ref Menu): IcMenu->Item;

	render: fn(u: ref IcUi->Ui, m: ref Menu): int;

	select: fn(u: ref IcUi->Ui, m: ref Menu, index: int): IcMsg->Msg;
	next: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;
	prev: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;
	home: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;
	end: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;

	hotkey: fn(u: ref IcUi->Ui, m: ref Menu, k: int): IcMsg->Msg;

	togglechecked: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;
	activate: fn(u: ref IcUi->Ui, m: ref Menu): IcMsg->Msg;

	summary: fn(m: ref Menu): string;
};