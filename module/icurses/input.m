include "icurses/ui.m";

IcInput: module
{
	PATH: con "/dis/lib/icurses/input.dis";

	init: fn();

	input: fn(u: ref IcUi->Ui, parentid, id: int,
		x, y, w: int,
		label, hotkey: string, targetid: int, command, text: string,
		maxlen: int): int;

	text: fn(u: ref IcUi->Ui, id: int): string;
	settext: fn(u: ref IcUi->Ui, id: int, text: string): IcMsg->Msg;
	setcursor: fn(u: ref IcUi->Ui, id: int, cursor: int): int;
	setenabled: fn(u: ref IcUi->Ui, id: int, enabled: int): int;

	insert: fn(u: ref IcUi->Ui, id: int, s: string): IcMsg->Msg;
	backspace: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	delchar: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	submit: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;

	activatefocused: fn(u: ref IcUi->Ui): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};