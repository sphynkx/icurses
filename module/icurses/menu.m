include "icurses/ui.m";

IcMenu: module
{
	PATH: con "/dis/lib/icurses/menu.dis";

	KindCommand:   con 0;
	KindSeparator: con 1;
	KindSubmenu:   con 2;

	FlagDisabled: con 1;
	FlagChecked:  con 2;
	FlagRadio:    con 4;

	Item: adt
	{
		kind:      int;
		flags:     int;

		label:     string;
		hotkey:    string;

		targetid:  string;
		command:   string;

		submenuid: string;
		status:    string;
	};

	init: fn();

	newitem: fn(label, hotkey, targetid, command: string): Item;
	newseparator: fn(): Item;
	newsubmenu: fn(label, hotkey, submenuid: string): Item;

	setdisabled: fn(it: Item, disabled: int): Item;
	setchecked: fn(it: Item, checked: int): Item;
	setradio: fn(it: Item, radio: int): Item;
	setstatus: fn(it: Item, status: string): Item;

	enabled: fn(it: Item): int;
	checked: fn(it: Item): int;
	radio: fn(it: Item): int;
	separator: fn(it: Item): int;
	submenu: fn(it: Item): int;

	popupwidth: fn(items: array of Item): int;

	popupmenu: fn(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, title: string, items: array of Item, sel: int): int;
	setpopupmenu: fn(u: ref IcUi->Ui, id: string, items: array of Item, sel: int): int;

	navbar: fn(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, items: array of Item, sel: int): int;
	setnavbar: fn(u: ref IcUi->Ui, id: string, items: array of Item, sel: int): int;

	actionbar: fn(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, items: array of Item, sel: int): int;
	setactionbar: fn(u: ref IcUi->Ui, id: string, items: array of Item, sel: int): int;
};