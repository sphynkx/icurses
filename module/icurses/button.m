include "icurses/ui.m";

IcButton: module
{
	PATH: con "/dis/lib/icurses/button.dis";

	init: fn();

	#
	# Temporarily redraw a button-like node using a generated pressed label:
	#   "Label" -> "> Label <"
	#
	press: fn(u: ref IcUi->Ui, id: int, ms: int): int;

	#
	# Temporarily redraw a button-like node using an explicit pressed label.
	#
	presslabel: fn(u: ref IcUi->Ui, id: int, pressed: string, ms: int): int;

	#
	# Dispatch the button/node action as a command message.
	# If targetid is empty, dst becomes id.
	# If command is empty, cmd becomes "button.click".
	#
	click: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;

	#
	# Visual press followed by click dispatch.
	#
	activate: fn(u: ref IcUi->Ui, id: int, ms: int): IcMsg->Msg;

	#
	# Generic enable/disable for a button-like node.
	#
	setenabled: fn(u: ref IcUi->Ui, id: int, enabled: int): int;
};