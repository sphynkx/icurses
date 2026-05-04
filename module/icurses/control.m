include "icurses/ui.m";

IcControl: module
{
	PATH: con "/dis/lib/icurses/control.dis";

	GroupSingle: con 0;
	GroupMulti:  con 1;

	StyleCheckbox: con 0;
	StyleRadio:    con 1;
	StyleSwitch:   con 2;

	init: fn();

	group: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, mode: int): int;

	checkbox: fn(u: ref IcUi->Ui, parentid, id: int,
		x, y, w: int,
		label, hotkey: string, targetid: int, command: string,
		checked: int): int;

	radio: fn(u: ref IcUi->Ui, groupid, id: int,
		x, y, w: int,
		label, hotkey: string, targetid: int, command: string,
		checked: int): int;

	switchbox: fn(u: ref IcUi->Ui, parentid, id: int,
		x, y, w: int,
		label, hotkey: string, targetid: int, command: string,
		on: int): int;

	checked: fn(u: ref IcUi->Ui, id: int): int;
	setchecked: fn(u: ref IcUi->Ui, id: int, checked: int): int;
	toggle: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	selectradio: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;

	selected: fn(u: ref IcUi->Ui, groupid: int): int;
	setenabled: fn(u: ref IcUi->Ui, id: int, enabled: int): int;

	activatefocused: fn(u: ref IcUi->Ui): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};