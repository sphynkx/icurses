#
# 09_03_message_kind.b
#
# Demonstrates message kind values.
#
# The buttons create sample messages of different kinds. The application shows
# how the kind changes the interpretation of the same general Msg structure.
#

implement MessageKindDemo;

include "draw.m";
include "icurses/ui.m";

MessageKindDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

KindBoxId: con 20;
KindCommandId: con 21;
KindNotifyId: con 22;
KindLifecycleId: con 23;
KindFocusId: con 24;

MessageBoxId: con 30;
MsgKindId: con 31;
MsgCmdId: con 32;
MsgMeaningId: con 33;
MsgCountId: con 34;

BtnCommandId: con 40;
BtnNotifyId: con 41;
BtnLifecycleId: con 42;
BtnFocusId: con 43;
BtnExitId: con 44;

lastkind: int;
lastcmd: string;
count: int;

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

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic->init();
	ui->init();
	msg->init();
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

kindname(k: int): string
{
	if(k == IcMsg->KindCommand)
		return "KindCommand";
	if(k == IcMsg->KindNotify)
		return "KindNotify";
	if(k == IcMsg->KindLifecycle)
		return "KindLifecycle";
	if(k == IcMsg->KindFocus)
		return "KindFocus";
	if(k == IcMsg->KindInput)
		return "KindInput";
	if(k == IcMsg->KindPaint)
		return "KindPaint";
	return "KindNone";
}

meaning(k: int): string
{
	if(k == IcMsg->KindCommand)
		return "Command requests an action.";
	if(k == IcMsg->KindNotify)
		return "Notify reports that something happened.";
	if(k == IcMsg->KindLifecycle)
		return "Lifecycle describes start, stop, open or close states.";
	if(k == IcMsg->KindFocus)
		return "Focus message describes focus-related state.";
	return "No special meaning selected.";
}

card(active, name: string): string
{
	if(active == name)
		return ">> " + name;
	return "   " + name;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, KindCommandId, card(kindname(lastkind), "KindCommand"));
	ui->settext(u, KindNotifyId, card(kindname(lastkind), "KindNotify"));
	ui->settext(u, KindLifecycleId, card(kindname(lastkind), "KindLifecycle"));
	ui->settext(u, KindFocusId, card(kindname(lastkind), "KindFocus"));

	ui->settext(u, MsgKindId, "kind: " + kindname(lastkind));
	ui->settext(u, MsgCmdId, "cmd: " + lastcmd);
	ui->settext(u, MsgMeaningId, meaning(lastkind));
	ui->settext(u, MsgCountId, "sample messages created: " + sys->sprint("%d", count));

	ui->setstatus(u, "message kind: " + kindname(lastkind));
	ui->draw(u);
}

setkind(u: ref IcUi->Ui, k: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, AppTarget, k, cmd);

	lastkind = m.kind;
	lastcmd = m.cmd;
	count++;

	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 100);
	y = center(sh, 19);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Create sample messages of different kinds | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 100, 19, " Message kind ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 84, "The same Msg structure can represent commands, notifications and lifecycle events.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, KindBoxId, 3, 4, 34, 9, " Kind selector ") < 0)
		raise "fail:kind box";

	if(ui->label(u, KindBoxId, KindCommandId, 2, 1, 26, "") < 0)
		raise "fail:kind command";

	if(ui->label(u, KindBoxId, KindNotifyId, 2, 2, 26, "") < 0)
		raise "fail:kind notify";

	if(ui->label(u, KindBoxId, KindLifecycleId, 2, 3, 26, "") < 0)
		raise "fail:kind lifecycle";

	if(ui->label(u, KindBoxId, KindFocusId, 2, 4, 26, "") < 0)
		raise "fail:kind focus";

	if(ui->window(u, WinId, MessageBoxId, 40, 4, 58, 9, " Message view ") < 0)
		raise "fail:message box";

	if(ui->label(u, MessageBoxId, MsgKindId, 2, 1, 54, "") < 0)
		raise "fail:msg kind";

	if(ui->label(u, MessageBoxId, MsgCmdId, 2, 2, 54, "") < 0)
		raise "fail:msg cmd";

	if(ui->label(u, MessageBoxId, MsgMeaningId, 2, 4, 54, "") < 0)
		raise "fail:msg meaning";

	if(ui->label(u, MessageBoxId, MsgCountId, 2, 6, 54, "") < 0)
		raise "fail:msg count";

	if(ui->button(u, WinId, BtnCommandId, 3, 15, 12, 1, "Command", "c", AppTarget, "app.kind.command") < 0)
		raise "fail:command";

	if(ui->button(u, WinId, BtnNotifyId, 17, 15, 12, 1, "Notify", "n", AppTarget, "app.kind.notify") < 0)
		raise "fail:notify";

	if(ui->button(u, WinId, BtnLifecycleId, 31, 15, 14, 1, "Lifecycle", "l", AppTarget, "app.kind.lifecycle") < 0)
		raise "fail:lifecycle";

	if(ui->button(u, WinId, BtnFocusId, 47, 15, 10, 1, "Focus", "f", AppTarget, "app.kind.focus") < 0)
		raise "fail:focus";

	if(ui->button(u, WinId, BtnExitId, 59, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	lastkind = IcMsg->KindCommand;
	lastcmd = "app.sample";
	count = 0;

	ui->setfocus(u, BtnCommandId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.kind.command"){
		setkind(u, IcMsg->KindCommand, "app.save");
		return 0;
	}

	if(cmd == "app.kind.notify"){
		setkind(u, IcMsg->KindNotify, "notify.changed");
		return 0;
	}

	if(cmd == "app.kind.lifecycle"){
		setkind(u, IcMsg->KindLifecycle, "life.close");
		return 0;
	}

	if(cmd == "app.kind.focus"){
		setkind(u, IcMsg->KindFocus, "focus.changed");
		return 0;
	}

	ui->draw(u);
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
				done = handlecmd(u, s.msg.cmd);

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