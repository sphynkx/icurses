#
# 09_01_message_purpose.b
#
# Demonstrates why messages exist.
#
# Buttons do not execute application logic directly. They produce command
# messages. The application receives the message, inspects the command, updates
# its own state, and redraws the UI.
#

implement MessagePurposeDemo;

include "draw.m";
include "icurses/ui.m";

MessagePurposeDemo: module
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

FlowBoxId: con 20;
FlowButtonId: con 21;
FlowMsgId: con 22;
FlowAppId: con 23;
FlowStateId: con 24;

StateBoxId: con 30;
SavedId: con 31;
DeletedId: con 32;
NotifyId: con 33;
LastCmdId: con 34;

BtnSaveId: con 40;
BtnDeleteId: con 41;
BtnNotifyId: con 42;
BtnResetId: con 43;
BtnExitId: con 44;

saved: int;
deleted: int;
notifications: int;
lastcmd: string;

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

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	ui->settext(u, SavedId, "Saved records: " + sys->sprint("%d", saved));
	ui->settext(u, DeletedId, "Deleted records: " + sys->sprint("%d", deleted));
	ui->settext(u, NotifyId, "Notifications: " + sys->sprint("%d", notifications));
	ui->settext(u, LastCmdId, "Last command: " + lastcmd);

	if(m.kind != IcMsg->KindNone)
		ui->settext(u, FlowMsgId, "2. Message: cmd=" + m.cmd + " src=" + sys->sprint("%d", m.src) + " dst=" + sys->sprint("%d", m.dst));
	else
		ui->settext(u, FlowMsgId, "2. Message: none yet");

	ui->setstatus(u, "message purpose demo");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Buttons create messages; application handles commands | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Message purpose ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "Messages decouple UI controls from application state changes.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, FlowBoxId, 3, 4, 72, 7, " Message flow ") < 0)
		raise "fail:flow box";

	if(ui->label(u, FlowBoxId, FlowButtonId, 2, 1, 64, "1. Button or hotkey creates an IcMsg command.") < 0)
		raise "fail:flow button";

	if(ui->label(u, FlowBoxId, FlowMsgId, 2, 2, 66, "") < 0)
		raise "fail:flow msg";

	if(ui->label(u, FlowBoxId, FlowAppId, 2, 3, 64, "3. Application reads m.cmd and changes its own state.") < 0)
		raise "fail:flow app";

	if(ui->label(u, FlowBoxId, FlowStateId, 2, 4, 64, "4. UI is updated from application state and redrawn.") < 0)
		raise "fail:flow state";

	if(ui->window(u, WinId, StateBoxId, 3, 12, 72, 5, " Application state ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, SavedId, 2, 1, 30, "") < 0)
		raise "fail:saved";

	if(ui->label(u, StateBoxId, DeletedId, 34, 1, 30, "") < 0)
		raise "fail:deleted";

	if(ui->label(u, StateBoxId, NotifyId, 2, 2, 30, "") < 0)
		raise "fail:notify";

	if(ui->label(u, StateBoxId, LastCmdId, 2, 3, 64, "") < 0)
		raise "fail:last cmd";

	if(ui->button(u, WinId, BtnSaveId, 3, 18, 10, 1, "Save", "s", AppTarget, "app.save") < 0)
		raise "fail:save";

	if(ui->button(u, WinId, BtnDeleteId, 15, 18, 12, 1, "Delete", "d", AppTarget, "app.delete") < 0)
		raise "fail:delete";

	if(ui->button(u, WinId, BtnNotifyId, 29, 18, 12, 1, "Notify", "n", AppTarget, "app.notify") < 0)
		raise "fail:notify button";

	if(ui->button(u, WinId, BtnResetId, 43, 18, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 55, 18, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnSaveId);
	refresh(u, msg->none());
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.kind == IcMsg->KindNone){
		ui->draw(u);
		return 0;
	}

	if(m.cmd == "app.exit")
		return 1;

	if(m.cmd == "app.save"){
		saved++;
		lastcmd = "app.save";
	}
	else if(m.cmd == "app.delete"){
		deleted++;
		lastcmd = "app.delete";
	}
	else if(m.cmd == "app.notify"){
		notifications++;
		lastcmd = "app.notify";
	}
	else if(m.cmd == "app.reset"){
		saved = 0;
		deleted = 0;
		notifications = 0;
		lastcmd = "app.reset";
	}
	else
		lastcmd = m.cmd;

	refresh(u, m);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	saved = 0;
	deleted = 0;
	notifications = 0;
	lastcmd = "none";

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