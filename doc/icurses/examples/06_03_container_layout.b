#
# 06_03_container_layout.b
#
# Demonstrates containers as layout blocks.
#
# A top-level layer contains a header, a body, and a footer. The body contains
# left and right panels. Child coordinates are local to each container.
#

implement ContainerLayoutDemo;

include "draw.m";
include "icurses/ui.m";

ContainerLayoutDemo: module
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

HeaderId: con 20;
HeaderTextId: con 21;

BodyId: con 30;
LeftPanelId: con 31;
LeftTitleId: con 32;
LeftTextId: con 33;
RightPanelId: con 34;
RightTitleId: con 35;
RightTextId: con 36;

FooterId: con 40;
FooterTextId: con 41;

BtnMoveId: con 50;
BtnToggleId: con 51;
BtnExitId: con 52;

offset: int;
rightvisible: int;

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

sendnode(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

movenode(u: ref IcUi->Ui, id, dx, dy: int)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, "node.move");
	m.iarg0 = dx;
	m.iarg1 = dy;
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui)
{
	s: string;

	s = "Layer offset=" + sys->sprint("%d", offset) + " | right panel ";
	if(rightvisible)
		s += "visible";
	else
		s += "hidden";

	ui->settext(u, FooterTextId, s);
	ui->setstatus(u, s);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h, bodyw: int;

	root = ui->rootid(u);

	w = 76;
	h = 18;
	x = center(sw, w);
	y = center(sh, h);

	bodyw = w - 6;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Move top layer or hide right panel to affect whole layout blocks ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Container layout blocks ") < 0)
		raise "fail:window";

	if(ui->group(u, WinId, HeaderId, 3, 2, bodyw, 2) < 0)
		raise "fail:header";

	if(ui->label(u, HeaderId, HeaderTextId, 0, 0, bodyw, "Header container: title, toolbar, or navigation could live here.") < 0)
		raise "fail:header text";

	if(ui->group(u, WinId, BodyId, 3, 5, bodyw, 8) < 0)
		raise "fail:body";

	if(ui->group(u, BodyId, LeftPanelId, 0, 0, 32, 7) < 0)
		raise "fail:left";

	if(ui->label(u, LeftPanelId, LeftTitleId, 0, 0, 30, "Left panel") < 0)
		raise "fail:left title";

	if(ui->label(u, LeftPanelId, LeftTextId, 2, 2, 30, "Local x/y inside BodyId.") < 0)
		raise "fail:left text";

	if(ui->group(u, BodyId, RightPanelId, 36, 0, 32, 7) < 0)
		raise "fail:right";

	if(ui->label(u, RightPanelId, RightTitleId, 0, 0, 30, "Right panel") < 0)
		raise "fail:right title";

	if(ui->label(u, RightPanelId, RightTextId, 2, 2, 30, "This whole panel can hide.") < 0)
		raise "fail:right text";

	if(ui->group(u, WinId, FooterId, 3, 14, bodyw, 1) < 0)
		raise "fail:footer";

	if(ui->label(u, FooterId, FooterTextId, 0, 0, bodyw, "") < 0)
		raise "fail:footer text";

	if(ui->button(u, WinId, BtnMoveId, 3, 16, 10, 1, "Move", "m", AppTarget, "app.move") < 0)
		raise "fail:move";

	if(ui->button(u, WinId, BtnToggleId, 15, 16, 12, 1, "Toggle", "t", AppTarget, "app.toggle") < 0)
		raise "fail:toggle";

	if(ui->button(u, WinId, BtnExitId, 29, 16, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	offset = 0;
	rightvisible = 1;

	ui->setfocus(u, BtnMoveId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.move"){
		if(offset == 0){
			movenode(u, LayerId, 2, 1);
			offset = 1;
		}
		else{
			movenode(u, LayerId, -2, -1);
			offset = 0;
		}
		refresh(u);
		return 0;
	}

	if(cmd == "app.toggle"){
		sendnode(u, RightPanelId, "node.toggle");
		rightvisible = !rightvisible;
		refresh(u);
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