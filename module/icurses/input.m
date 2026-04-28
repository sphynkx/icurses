include "icurses/ui.m";

IcInput: module
{
	PATH: con "/dis/lib/icurses/input.dis";

	init: fn();

	input: fn(u: ref IcUi->Ui, parentid, id: string,
		x, y, w: int,
		label, hotkey, targetid, command, text: string,
		maxlen: int): int;

	text: fn(u: ref IcUi->Ui, id: string): string;
	settext: fn(u: ref IcUi->Ui, id, text: string): IcMsg->Msg;
	setcursor: fn(u: ref IcUi->Ui, id: string, cursor: int): int;
	setenabled: fn(u: ref IcUi->Ui, id: string, enabled: int): int;

	insert: fn(u: ref IcUi->Ui, id, s: string): IcMsg->Msg;
	backspace: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	delchar: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	submit: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;

	activatefocused: fn(u: ref IcUi->Ui): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};