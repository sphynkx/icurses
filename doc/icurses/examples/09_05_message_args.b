#
# 09_05_message_args.b
#
# Demonstrates additional message parameters.
#
# The Move buttons create messages with iarg0/iarg1 deltas and sarg text.
# The application shows the arguments and uses them to move a visual marker.
#

implement MessageArgsDemo;

include "draw.m";
include "icurses/ui.m";

MessageArgsDemo: module
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

StageId: con 20;
MarkerId: con 21;
MarkerTextId: con 22;

ArgsBoxId: con 30;
CmdId: con 31;
SargId: con 32;
IargId: con 33;
PositionId: con 34;

BtnLeftId: con 40;
BtnRightId: con 41;
BtnUpId: con 42;
BtnDownId: con 43;
BtnResetId: con 44;
BtnExitId: con 45;

mx: int;
my: int;

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

sendmove(u: ref IcUi->Ui, dx, dy: int, label: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, AppTarget, IcMsg->KindCommand, "app.move.marker");
	m.sarg = label;
	m.iarg0 = dx;
	m.iarg1 = dy;

	mx += dx;
	my += dy;

	if(mx < 1)
		mx = 1;
	if(mx > 22)
		mx = 22;
	if(my < 1)
		my = 1;
	if(my > 5)
		my = 5;

	refresh(u, m);
}

movemarker(u: ref IcUi->Ui, oldx, oldy: int)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, MarkerId, IcMsg->KindCommand, "node.move");
	m.iarg0 = mx - oldx;
	m.iarg1 = my - oldy;
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	ui->settext(u, CmdId, "cmd: " + m.cmd);
	ui->settext(u, SargId, "sarg: " + m.sarg);
	ui->settext(u, IargId, "iarg0=" + sys->sprint("%d", m.iarg0) +
		" iarg1=" + sys->sprint("%d", m.iarg1));
	ui->settext(u, PositionId, "marker position: x=" + sys->sprint("%d", mx) +
		" y=" + sys->sprint("%d", my));

	ui->setstatus(u, "message args: " + m.sarg);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Move marker with message iarg0/iarg1 | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Message arguments ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "Additional parameters refine the command without replacing it.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, StageId, 3, 4, 34, 9, " Marker stage ") < 0)
		raise "fail:stage";

	mx = 12;
	my = 3;

	if(ui->window(u, StageId, MarkerId, mx, my, 8, 3, " M ") < 0)
		raise "fail:marker";

	if(ui->label(u, MarkerId, MarkerTextId, 2, 1, 4, "M") < 0)
		raise "fail:marker text";

	if(ui->window(u, WinId, ArgsBoxId, 40, 4, 35, 9, " Message args ") < 0)
		raise "fail:args box";

	if(ui->label(u, ArgsBoxId, CmdId, 2, 1, 30, "") < 0)
		raise "fail:cmd";

	if(ui->label(u, ArgsBoxId, SargId, 2, 2, 30, "") < 0)
		raise "fail:sarg";

	if(ui->label(u, ArgsBoxId, IargId, 2, 3, 30, "") < 0)
		raise "fail:iarg";

	if(ui->label(u, ArgsBoxId, PositionId, 2, 5, 30, "") < 0)
		raise "fail:position";

	if(ui->button(u, WinId, BtnLeftId, 3, 16, 10, 1, "Left", "", AppTarget, "app.left") < 0)
		raise "fail:left";

	if(ui->button(u, WinId, BtnRightId, 15, 16, 10, 1, "Right", "", AppTarget, "app.right") < 0)
		raise "fail:right";

	if(ui->button(u, WinId, BtnUpId, 27, 16, 8, 1, "Up", "", AppTarget, "app.up") < 0)
		raise "fail:up";

	if(ui->button(u, WinId, BtnDownId, 37, 16, 10, 1, "Down", "", AppTarget, "app.down") < 0)
		raise "fail:down";

	if(ui->button(u, WinId, BtnResetId, 49, 16, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 61, 16, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	m = msg->newmsg(AppTarget, AppTarget, IcMsg->KindCommand, "app.move.marker");
	m.sarg = "initial";
	m.iarg0 = 0;
	m.iarg1 = 0;

	ui->setfocus(u, BtnRightId);
	refresh(u, m);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	oldx, oldy: int;
	m: IcMsg->Msg;

	if(cmd == "app.exit")
		return 1;

	oldx = mx;
	oldy = my;

	if(cmd == "app.left")
		sendmove(u, -2, 0, "move left");
	else if(cmd == "app.right")
		sendmove(u, 2, 0, "move right");
	else if(cmd == "app.up")
		sendmove(u, 0, -1, "move up");
	else if(cmd == "app.down")
		sendmove(u, 0, 1, "move down");
	else if(cmd == "app.reset"){
		mx = 12;
		my = 3;

		m = msg->newmsg(AppTarget, AppTarget, IcMsg->KindCommand, "app.move.marker");
		m.sarg = "reset marker";
		m.iarg0 = mx - oldx;
		m.iarg1 = my - oldy;
		refresh(u, m);
	}
	else{
		ui->draw(u);
		return 0;
	}

	movemarker(u, oldx, oldy);
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