include "icurses/ui.m";

IcSlider: module
{
	PATH: con "/dis/lib/icurses/slider.dis";

	init: fn();

	slider: fn(u: ref IcUi->Ui, parentid, id: string,
		x, y, w: int,
		label, hotkey, targetid, command: string,
		value, min, max: int): int;

	value: fn(u: ref IcUi->Ui, id: string): int;
	setvalue: fn(u: ref IcUi->Ui, id: string, value: int): IcMsg->Msg;

	inc: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	dec: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	pageup: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	pagedown: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	home: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;
	end: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;

	setenabled: fn(u: ref IcUi->Ui, id: string, enabled: int): int;

	activatefocused: fn(u: ref IcUi->Ui): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;
};