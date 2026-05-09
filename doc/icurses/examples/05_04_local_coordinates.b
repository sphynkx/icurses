#
# 05_04_local_coordinates.b
#
# Demonstrates local coordinates.
#
# The movable panel is a child of the window. Buttons inside the panel keep
# their local coordinates while the parent group moves.
#

implement LocalCoordinatesDemo;

include "draw.m";
include "icurses/ui.m";

LocalCoordinatesDemo: module
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
InfoId: con 12;
PosId: con 13;

PanelId: con 20;
PanelTitleId: con 21;
PanelLocalId: con 22;
BtnLeftId: con 23;
BtnRightId: con 24;
BtnUpId: con 25;
BtnDownId: con 26;

BtnResetId: con 30;
BtnExitId: con 31;

px: int;
py: int;

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
	ui->settext(u, PosId, "Panel local position inside window: x=" +
		sys->sprint("%d", px) +
		" y=" +
		sys->sprint("%d", py));

	ui->setstatus(u, "panel x=" + sys->sprint("%d", px) + " y=" + sys->sprint("%d", py));
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 18;
	x = center(sw, w);
	y = center(sh, h);

	px = 5;
	py = 7;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Move the panel; child button coordinates remain local | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Local coordinates ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 64, "Changing a parent group's x/y changes all children on screen.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, PosId, 3, 4, 64, "") < 0)
		raise "fail:position";

	if(ui->group(u, WinId, PanelId, px, py, 40, 6) < 0)
		raise "fail:panel";

	if(ui->label(u, PanelId, PanelTitleId, 0, 0, 36, "Movable parent group") < 0)
		raise "fail:panel title";

	if(ui->label(u, PanelId, PanelLocalId, 2, 1, 36, "Buttons below are local to this group.") < 0)
		raise "fail:panel local";

	if(ui->button(u, PanelId, BtnLeftId, 2, 3, 7, 1, "Left", "", AppTarget, "app.left") < 0)
		raise "fail:left";

	if(ui->button(u, PanelId, BtnRightId, 10, 3, 8, 1, "Right", "", AppTarget, "app.right") < 0)
		raise "fail:right";

	if(ui->button(u, PanelId, BtnUpId, 19, 3, 6, 1, "Up", "", AppTarget, "app.up") < 0)
		raise "fail:up";

	if(ui->button(u, PanelId, BtnDownId, 26, 3, 7, 1, "Down", "", AppTarget, "app.down") < 0)
		raise "fail:down";

	if(ui->button(u, WinId, BtnResetId, 48, 12, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 60, 12, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnRightId);
	refresh(u);
}

moveby(u: ref IcUi->Ui, dx, dy: int)
{
	px += dx;
	py += dy;

	if(px < 1){
		dx += 1 - px;
		px = 1;
	}
	if(py < 6){
		dy += 6 - py;
		py = 6;
	}
	if(px > 32){
		dx -= px - 32;
		px = 32;
	}
	if(py > 11){
		dy -= py - 11;
		py = 11;
	}

	movenode(u, PanelId, dx, dy);
	refresh(u);
}

resetpos(u: ref IcUi->Ui)
{
	dx, dy: int;

	dx = 5 - px;
	dy = 7 - py;

	px = 5;
	py = 7;

	movenode(u, PanelId, dx, dy);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.left"){
		moveby(u, -2, 0);
		return 0;
	}

	if(cmd == "app.right"){
		moveby(u, 2, 0);
		return 0;
	}

	if(cmd == "app.up"){
		moveby(u, 0, -1);
		return 0;
	}

	if(cmd == "app.down"){
		moveby(u, 0, 1);
		return 0;
	}

	if(cmd == "app.reset"){
		resetpos(u);
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