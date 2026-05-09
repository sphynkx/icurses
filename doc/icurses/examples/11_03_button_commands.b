#
# 11_03_button_commands.b
#
# Demonstrates Button elements.
#
# Buttons are focusable action controls. Activating a button produces a command
# message. The application handles that command and updates visible state.
#

implement ButtonCommandsDemo;

include "draw.m";
include "icurses/ui.m";

ButtonCommandsDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

ToolbarBoxId: con 20;
BtnNewId: con 21;
BtnSaveId: con 22;
BtnDeleteId: con 23;

MessageBoxId: con 30;
CommandId: con 31;
SourceId: con 32;
CountId: con 33;

DocumentBoxId: con 40;
DocTitleId: con 41;
DocStateId: con 42;
DocChangesId: con 43;

BtnExitId: con 50;

created: int;
saved: int;
deleted: int;
changes: int;
lastcmd: string;
lastsrc: int;

loadmods()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	ic->init();
	ui->init();
}

enterappscreen()
{
	if(out == nil || appscreen)
		return;

	sys->fprint(out, "%c[?1049h", 27);
	ic->resettty(out);
	ic->hidecursor(out);
	ic->cleartty(out);

	appscreen = 1;
}

leaveappscreen()
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	ic->cleartty(out);

	if(appscreen){
		sys->fprint(out, "%c[?1049l", 27);
		appscreen = 0;
	}

	ic->resettty(out);
	ic->showcursor(out);
}

center(total, size: int): int
{
	x: int;

	x = (total - size) / 2;
	if(x < 0)
		x = 0;

	return x;
}

srcname(id: int): string
{
	if(id == BtnNewId)
		return "BtnNewId";
	if(id == BtnSaveId)
		return "BtnSaveId";
	if(id == BtnDeleteId)
		return "BtnDeleteId";
	return "none";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, CommandId, "Last command: " + lastcmd);
	ui->settext(u, SourceId, "Message source: " + srcname(lastsrc) + " id=" + sys->sprint("%d", lastsrc));
	ui->settext(u, CountId, "New=" + sys->sprint("%d", created) +
		" Save=" + sys->sprint("%d", saved) +
		" Delete=" + sys->sprint("%d", deleted));

	if(deleted > 0 && created == 0)
		ui->settext(u, DocStateId, "Document state: deleted");
	else if(created > saved)
		ui->settext(u, DocStateId, "Document state: modified");
	else
		ui->settext(u, DocStateId, "Document state: saved");

	ui->settext(u, DocChangesId, "Unsaved changes: " + sys->sprint("%d", changes));

	ui->setstatus(u, "button command: " + lastcmd);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Buttons produce command messages | n/s/d hotkeys | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Button commands ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "A button has text, hotkey, target id and command string.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, ToolbarBoxId, 3, 4, 28, 8, " Toolbar ") < 0)
		raise "fail:toolbar";

	if(ui->button(u, ToolbarBoxId, BtnNewId, 3, 2, 12, 1, "New", "n", AppTarget, "app.new") < 0)
		raise "fail:new";

	if(ui->button(u, ToolbarBoxId, BtnSaveId, 3, 4, 12, 1, "Save", "s", AppTarget, "app.save") < 0)
		raise "fail:save";

	if(ui->button(u, ToolbarBoxId, BtnDeleteId, 3, 6, 12, 1, "Delete", "d", AppTarget, "app.delete") < 0)
		raise "fail:delete";

	if(ui->window(u, WinId, MessageBoxId, 34, 4, 42, 8, " Last button message ") < 0)
		raise "fail:message box";

	if(ui->label(u, MessageBoxId, CommandId, 2, 1, 36, "") < 0)
		raise "fail:command";

	if(ui->label(u, MessageBoxId, SourceId, 2, 3, 36, "") < 0)
		raise "fail:source";

	if(ui->label(u, MessageBoxId, CountId, 2, 5, 36, "") < 0)
		raise "fail:count";

	if(ui->window(u, WinId, DocumentBoxId, 3, 13, 73, 4, " Application state ") < 0)
		raise "fail:document box";

	if(ui->label(u, DocumentBoxId, DocTitleId, 2, 1, 64, "Button commands update this document state.") < 0)
		raise "fail:doc title";

	if(ui->label(u, DocumentBoxId, DocStateId, 2, 2, 64, "") < 0)
		raise "fail:doc state";

	if(ui->label(u, DocumentBoxId, DocChangesId, 2, 3, 64, "") < 0)
		raise "fail:doc changes";

	if(ui->button(u, WinId, BtnExitId, 3, 18, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	created = 0;
	saved = 0;
	deleted = 0;
	changes = 0;
	lastcmd = "none";
	lastsrc = -1;

	ui->setfocus(u, BtnNewId);
	refresh(u);
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.cmd == "app.exit")
		return 1;

	lastcmd = m.cmd;
	lastsrc = m.src;

	if(m.cmd == "app.new"){
		created++;
		changes++;
	}
	else if(m.cmd == "app.save"){
		saved = created;
		changes = 0;
	}
	else if(m.cmd == "app.delete"){
		deleted++;
		created = 0;
		changes = 0;
	}

	refresh(u);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;

	enterappscreen();

	(w, h) = ic->termsize();
	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	u = ui->new(out, w, h);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	build(u, w, h);

	if(ui->start(u) < 0){
		ui->close(u);
		leaveappscreen();
		sys->print("cannot start ui\n");
		return;
	}

	done = 0;

	for(; !done;){
		s = ui->step(u);

		case s.kind {
		IcUi->StepDone =>
			done = 1;

		IcUi->StepKey =>
			if(ui->isquit(s.key))
				done = 1;
			else
				done = handlemsg(u, s.msg);

		IcUi->StepTick =>
			;

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	ui->close(u);
	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}