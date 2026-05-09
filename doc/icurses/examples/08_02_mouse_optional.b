#
# 08_02_mouse_optional.b
#
# Demonstrates optional mouse events in the Step model.
#
# Mouse support depends on the host environment. If mouse start fails, the
# example falls back to keyboard-only mode and says so on screen.
#

implement MouseOptionalDemo;

include "draw.m";
include "icurses/ui.m";

MouseOptionalDemo: module
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
InfoId: con 12;
MouseModeId: con 13;
MouseCountId: con 14;
LastMouseId: con 15;

BtnResetId: con 20;
BtnExitId: con 21;

mousemode: int;
mouseevents: int;

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

refresh(u: ref IcUi->Ui, last: string)
{
	if(mousemode)
		ui->settext(u, MouseModeId, "Mouse mode: enabled");
	else
		ui->settext(u, MouseModeId, "Mouse mode: unavailable or disabled");

	ui->settext(u, MouseCountId, "Mouse events: " + sys->sprint("%d", mouseevents));

	if(last != "")
		ui->settext(u, LastMouseId, "Last mouse step: " + last);

	ui->setstatus(u, "mouse step demo");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 72;
	h = 14;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Mouse events are optional | r reset count | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Optional mouse events ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 62, "If available, mouse input appears as IcUi->StepMouse.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, MouseModeId, 3, 4, 62, "") < 0)
		raise "fail:mouse mode";

	if(ui->label(u, WinId, MouseCountId, 3, 5, 62, "") < 0)
		raise "fail:mouse count";

	if(ui->label(u, WinId, LastMouseId, 3, 7, 62, "Last mouse step: none") < 0)
		raise "fail:last mouse";

	if(ui->button(u, WinId, BtnResetId, 3, 10, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 15, 10, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnResetId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.reset"){
		mouseevents = 0;
		refresh(u, "none");
		return 0;
	}

	ui->draw(u);
	return 0;
}

makeui(w, h, wantmouse: int): ref IcUi->Ui
{
	u: ref IcUi->Ui;

	u = ui->new(out, w, h);
	if(u == nil)
		return nil;

	mousemode = wantmouse;
	if(wantmouse)
		ui->enablemouse(u, 1);

	build(u, w, h);

	if(ui->start(u) < 0){
		ui->close(u);
		return nil;
	}

	return u;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	mouseevents = 0;

	enterappscreen();

	(w, h) = ic->termsize();
	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	u = makeui(w, h, 1);
	if(u == nil)
		u = makeui(w, h, 0);

	if(u == nil){
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
			mouseevents++;
			refresh(u, s.status);

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