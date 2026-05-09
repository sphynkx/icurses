#
# 09_02_source_destination.b
#
# Demonstrates message source and destination fields.
#
# Different buttons are sources. They all send commands to the same application
# destination, but the application can still see which control produced the
# message through m.src.
#

implement SourceDestinationDemo;

include "draw.m";
include "icurses/ui.m";

SourceDestinationDemo: module
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

SourceBoxId: con 20;
BtnToolbarId: con 21;
BtnPanelId: con 22;
BtnDialogId: con 23;

RouteBoxId: con 30;
SrcId: con 31;
DstId: con 32;
CmdId: con 33;
RouteLineId: con 34;

TargetBoxId: con 40;
AppCardId: con 41;
AppTextId: con 42;

BtnResetId: con 50;
BtnExitId: con 51;

lastsrc: int;
lastdst: int;
lastcmd: string;
handled: int;

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

srcname(id: int): string
{
	if(id == BtnToolbarId)
		return "Toolbar button";
	if(id == BtnPanelId)
		return "Panel button";
	if(id == BtnDialogId)
		return "Dialog button";
	if(id == BtnResetId)
		return "Reset button";
	if(id < 0)
		return "none";
	return "unknown";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, SrcId, "src: " + sys->sprint("%d", lastsrc) + "  " + srcname(lastsrc));
	ui->settext(u, DstId, "dst: " + sys->sprint("%d", lastdst) + "  AppTarget");
	ui->settext(u, CmdId, "cmd: " + lastcmd);
	ui->settext(u, RouteLineId, "handled messages: " + sys->sprint("%d", handled));

	ui->settext(u, AppTextId, "Application received command from " + srcname(lastsrc));
	ui->setstatus(u, "source/destination demo");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 19);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Press source buttons and watch src/dst fields | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 19, " Source and destination ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "src identifies the sender; dst identifies the message recipient.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, SourceBoxId, 3, 4, 30, 8, " Sources ") < 0)
		raise "fail:source box";

	if(ui->button(u, SourceBoxId, BtnToolbarId, 3, 2, 16, 1, "Toolbar", "t", AppTarget, "app.from.toolbar") < 0)
		raise "fail:toolbar";

	if(ui->button(u, SourceBoxId, BtnPanelId, 3, 4, 16, 1, "Panel", "p", AppTarget, "app.from.panel") < 0)
		raise "fail:panel";

	if(ui->button(u, SourceBoxId, BtnDialogId, 3, 6, 16, 1, "Dialog", "d", AppTarget, "app.from.dialog") < 0)
		raise "fail:dialog";

	if(ui->window(u, WinId, RouteBoxId, 36, 4, 38, 8, " Message fields ") < 0)
		raise "fail:route box";

	if(ui->label(u, RouteBoxId, SrcId, 2, 1, 32, "") < 0)
		raise "fail:src";

	if(ui->label(u, RouteBoxId, DstId, 2, 2, 32, "") < 0)
		raise "fail:dst";

	if(ui->label(u, RouteBoxId, CmdId, 2, 3, 32, "") < 0)
		raise "fail:cmd";

	if(ui->label(u, RouteBoxId, RouteLineId, 2, 5, 32, "") < 0)
		raise "fail:route line";

	if(ui->window(u, WinId, TargetBoxId, 3, 13, 71, 3, " Destination ") < 0)
		raise "fail:target box";

	if(ui->label(u, TargetBoxId, AppCardId, 2, 1, 20, "AppTarget") < 0)
		raise "fail:app card";

	if(ui->label(u, TargetBoxId, AppTextId, 16, 1, 50, "") < 0)
		raise "fail:app text";

	if(ui->button(u, WinId, BtnResetId, 3, 17, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 15, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	lastsrc = -1;
	lastdst = AppTarget;
	lastcmd = "none";
	handled = 0;

	ui->setfocus(u, BtnToolbarId);
	refresh(u);
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.kind == IcMsg->KindNone){
		ui->draw(u);
		return 0;
	}

	if(m.cmd == "app.exit")
		return 1;

	if(m.cmd == "app.reset"){
		lastsrc = m.src;
		lastdst = m.dst;
		lastcmd = m.cmd;
		handled = 0;
		refresh(u);
		return 0;
	}

	lastsrc = m.src;
	lastdst = m.dst;
	lastcmd = m.cmd;
	handled++;

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