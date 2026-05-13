include "icurses/paint.m";
include "icurses/keymap.m";

IcUi: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	StepDone:  con 0;
	StepKey:   con 1;
	StepTick:  con 2;
	StepMouse: con 3;

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

		keyc:      chan of int;
		tickc:     chan of int;
		tickms:    int;
		ticks:     int;

		quitkey1:  string;
		quitkey2:  string;
	};

	Step: adt
	{
		kind:   int;
		done:   int;
		key:    int;
		tick:   int;
		msg:    IcMsg->Msg;
		status: string;
	};

	init: fn();

	new: fn(out: ref Sys->FD, w, h: int): ref Ui;
	close: fn(u: ref Ui);

	start: fn(u: ref Ui): int;
	step: fn(u: ref Ui): Step;
	stop: fn(u: ref Ui);

	settick: fn(u: ref Ui, ms: int);
	setquitkeys: fn(u: ref Ui, key1, key2: string);

	enablemouse: fn(u: ref Ui, enabled: int): int;
	ismouseenabled: fn(u: ref Ui): int;
	ismouseopen: fn(u: ref Ui): int;

	openinput: fn(): int;
	closeinput: fn();
	readkey: fn(): int;
	isquit: fn(k: int): int;

	rootid: fn(u: ref Ui): int;

	setframestyle: fn(u: ref Ui, style: int);
	sethelp: fn(u: ref Ui, help: string);
	setstatus: fn(u: ref Ui, status: string);
	setstatusrows: fn(u: ref Ui, helprow, statusrow: int);

	node: fn(u: ref Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	group: fn(u: ref Ui, parentid, id: int, x, y, w, h: int): int;
	label: fn(u: ref Ui, parentid, id: int, x, y, w: int, text: string): int;
	window: fn(u: ref Ui, parentid, id: int, x, y, w, h: int, title: string): int;
	shadowwindow: fn(u: ref Ui, parentid, shadowid, id: int, x, y, w, h: int, title: string, dx, dy: int): int;
	button: fn(u: ref Ui, parentid, id: int, x, y, w, h: int, label, hotkey: string, targetid: int, command: string): int;
	canvas: fn(u: ref Ui, parentid, id: int, x, y, w, h: int): int;

	hbar: fn(u: ref Ui, parentid, id: int, x, y, w, value, total: int): int;
	vbar: fn(u: ref Ui, parentid, id: int, x, y, h, value, total: int): int;
	setbar: fn(u: ref Ui, id: int, value, total: int): int;

	progress: fn(u: ref Ui, parentid, id: int, x, y, w, value, total: int): int;
	setprogress: fn(u: ref Ui, id: int, value, total: int): int;
	progressstyle: fn(u: ref Ui, id: int, style: int): int;

	spinner: fn(u: ref Ui, parentid, id: int, x, y, style: int): int;
	setspinner: fn(u: ref Ui, id: int, frame: int): int;
	tickspinner: fn(u: ref Ui, id: int): int;

	listbox: fn(u: ref Ui, parentid, id: int, x, y, w, h: int, title: string): int;
	setlistbox: fn(u: ref Ui, id: int, items: array of string, top, sel: int): int;

	taskdialog: fn(u: ref Ui, parentid, id: int, x, y, w: int, title: string): int;
	settaskdialog: fn(u: ref Ui, id: int, phase, src, dst, item: string, itemvalue, totalvalue, meter: int): int;
	ticktaskdialog: fn(u: ref Ui, id: int): int;

	bindkey: fn(u: ref Ui, key: string, targetid: int, command: string): int;
	bindkeyargs: fn(u: ref Ui, key: string, targetid: int, command, sarg: string, iarg0, iarg1, iarg2: int): int;

	settext: fn(u: ref Ui, id: int, text: string): int;
	setcontent: fn(u: ref Ui, id: int, content: string): int;
	setscroll: fn(u: ref Ui, id: int, scroll, scrollpos: int): int;
	setframe: fn(u: ref Ui, id: int, frame: int): int;
	setargs: fn(u: ref Ui, id: int, sarg: string, iarg0, iarg1, iarg2: int): int;
	setfocus: fn(u: ref Ui, id: int): int;

	canvasclear: fn(u: ref Ui, id: int, ch, code: string): int;
	canvasfill: fn(u: ref Ui, id: int, x, y, w, h: int, ch, code: string): int;
	canvasputc: fn(u: ref Ui, id: int, x, y: int, ch, code: string): int;
	canvasputs: fn(u: ref Ui, id: int, x, y: int, text, code: string): int;

	draw: fn(u: ref Ui);

	handlekey: fn(u: ref Ui, k: int): IcMsg->Msg;
	dispatch: fn(u: ref Ui, m: IcMsg->Msg): IcMsg->Msg;
};