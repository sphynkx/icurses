include "icurses/paint.m";
include "icurses/keymap.m";

IcUi: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	Ui: adt
	{
		tree:      ref IcView->Tree;
		renderer:  ref IcPaint->Renderer;
		keymap:    ref IcKeymap->Keymap;

		status:    string;
		help:      string;
		helprow:   int;
		statusrow: int;

		lastmsg:   IcMsg->Msg;
		running:   int;
	};

	Step: adt
	{
		done:   int;
		key:    int;
		msg:    IcMsg->Msg;
		status: string;
	};

	init: fn();

	new: fn(out: ref Sys->FD, w, h: int): ref Ui;
	close: fn(u: ref Ui);

	start: fn(u: ref Ui): int;
	step: fn(u: ref Ui): Step;
	stop: fn(u: ref Ui);

	openinput: fn(): int;
	closeinput: fn();
	readkey: fn(): int;
	isquit: fn(k: int): int;

	rootid: fn(u: ref Ui): string;

	setframestyle: fn(u: ref Ui, style: int);
	sethelp: fn(u: ref Ui, help: string);
	setstatus: fn(u: ref Ui, status: string);
	setstatusrows: fn(u: ref Ui, helprow, statusrow: int);

	node: fn(u: ref Ui, parentid, id, kind: string, x, y, w, h: int): int;
	group: fn(u: ref Ui, parentid, id: string, x, y, w, h: int): int;
	window: fn(u: ref Ui, parentid, id: string, x, y, w, h: int, title: string): int;
	button: fn(u: ref Ui, parentid, id: string, x, y, w, h: int, label, hotkey, targetid, command: string): int;

	bindkey: fn(u: ref Ui, key, targetid, command: string): int;
	bindkeyargs: fn(u: ref Ui, key, targetid, command, sarg: string, iarg0, iarg1, iarg2: int): int;

	setcontent: fn(u: ref Ui, id, content: string): int;
	setscroll: fn(u: ref Ui, id: string, scroll, scrollpos: int): int;
	setframe: fn(u: ref Ui, id: string, frame: int): int;
	setargs: fn(u: ref Ui, id, sarg: string, iarg0, iarg1, iarg2: int): int;
	setfocus: fn(u: ref Ui, id: string): int;

	draw: fn(u: ref Ui);

	handlekey: fn(u: ref Ui, k: int): IcMsg->Msg;
	dispatch: fn(u: ref Ui, m: IcMsg->Msg): IcMsg->Msg;
};