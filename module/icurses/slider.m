include "icurses/ui.m";

IcSlider: module
{
	PATH: con "/dis/lib/icurses/slider.dis";

	init: fn();

	slider: fn(u: ref IcUi->Ui, parentid, id: int,
		x, y, w: int,
		label, hotkey: string, targetid: int, command: string,
		value, min, max: int): int;

	value: fn(u: ref IcUi->Ui, id: int): int;
	setvalue: fn(u: ref IcUi->Ui, id: int, value: int): IcMsg->Msg;

	inc: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	dec: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	pageup: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	pagedown: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	home: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;
	end: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;

	setenabled: fn(u: ref IcUi->Ui, id: int, enabled: int): int;

	activatefocused: fn(u: ref IcUi->Ui): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};