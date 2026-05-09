#
# 01_nested_containers.b
#
# Demonstrates nested containers and local coordinates by moving a whole
# toolbox group while its children keep their positions inside it.
#

implement NestedContainersDemo;

include "draw.m";
include "icurses/ui.m";

NestedContainersDemo: module
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

ToolGroupId: con 20;
ToolTitleId: con 21;
ToolHintId: con 22;
BtnLeftId: con 23;
BtnRightId: con 24;
BtnUpId: con 25;
BtnDownId: con 26;

BtnResetId: con 30;
BtnExitId: con 31;

toolx: int;
tooly: int;

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

refreshpos(u: ref IcUi->Ui)
{
	ui->settext(u, PosId, "Toolbox local origin inside window: x=" +
		sys->sprint("%d", toolx) +
		" y=" +
		sys->sprint("%d", tooly));

	ui->setstatus(u, "toolbox at " + sys->sprint("%d", toolx) + "," + sys->sprint("%d", tooly));
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

	toolx = 5;
	tooly = 7;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Arrow buttons move the whole group | r reset | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Nested containers ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 64, "The toolbox is a group node. Its children use local coordinates.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, PosId, 3, 4, 64, "") < 0)
		raise "fail:position";

	if(ui->group(u, WinId, ToolGroupId, toolx, tooly, 36, 6) < 0)
		raise "fail:tool group";

	if(ui->label(u, ToolGroupId, ToolTitleId, 0, 0, 32, "Movable toolbox") < 0)
		raise "fail:tool title";

	if(ui->label(u, ToolGroupId, ToolHintId, 2, 1, 30, "Children stay local to group.") < 0)
		raise "fail:tool hint";

	if(ui->button(u, ToolGroupId, BtnLeftId, 2, 3, 7, 1, "Left", "", AppTarget, "app.left") < 0)
		raise "fail:left button";

	if(ui->button(u, ToolGroupId, BtnRightId, 10, 3, 8, 1, "Right", "", AppTarget, "app.right") < 0)
		raise "fail:right button";

	if(ui->button(u, ToolGroupId, BtnUpId, 19, 3, 6, 1, "Up", "", AppTarget, "app.up") < 0)
		raise "fail:up button";

	if(ui->button(u, ToolGroupId, BtnDownId, 26, 3, 7, 1, "Down", "", AppTarget, "app.down") < 0)
		raise "fail:down button";

	if(ui->button(u, WinId, BtnResetId, 46, 12, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset button";

	if(ui->button(u, WinId, BtnExitId, 58, 12, 9, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnRightId);
	refreshpos(u);
}

movebox(u: ref IcUi->Ui, dx, dy: int)
{
	toolx += dx;
	tooly += dy;

	if(toolx < 1){
		dx += 1 - toolx;
		toolx = 1;
	}
	if(tooly < 6){
		dy += 6 - tooly;
		tooly = 6;
	}
	if(toolx > 34){
		dx -= toolx - 34;
		toolx = 34;
	}
	if(tooly > 11){
		dy -= tooly - 11;
		tooly = 11;
	}

	movenode(u, ToolGroupId, dx, dy);
	refreshpos(u);
}

resetbox(u: ref IcUi->Ui)
{
	dx, dy: int;

	dx = 5 - toolx;
	dy = 7 - tooly;
	toolx = 5;
	tooly = 7;

	movenode(u, ToolGroupId, dx, dy);
	refreshpos(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.left"){
		movebox(u, -2, 0);
		return 0;
	}

	if(cmd == "app.right"){
		movebox(u, 2, 0);
		return 0;
	}

	if(cmd == "app.up"){
		movebox(u, 0, -1);
		return 0;
	}

	if(cmd == "app.down"){
		movebox(u, 0, 1);
		return 0;
	}

	if(cmd == "app.reset"){
		resetbox(u);
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