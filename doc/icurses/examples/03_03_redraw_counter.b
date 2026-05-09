#
# 03_03_redraw_counter.b
#
# Demonstrates explicit redraw after changing UI state.
#
# The counter value is application state. Labels and progress bar are UI state.
#

implement RedrawCounterDemo;

include "draw.m";
include "icurses/ui.m";

RedrawCounterDemo: module
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
ValueId: con 13;
ProgressId: con 14;
HintId: con 15;

BtnDecId: con 20;
BtnIncId: con 21;
BtnResetId: con 22;
BtnExitId: con 23;

value: int;

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

clamp(v, lo, hi: int): int
{
	if(v < lo)
		return lo;
	if(v > hi)
		return hi;
	return v;
}

refresh(u: ref IcUi->Ui)
{
	value = clamp(value, 0, 100);

	ui->settext(u, ValueId, "Counter value: " + sys->sprint("%d", value));
	ui->setprogress(u, ProgressId, value, 100);

	ui->setstatus(u, "draw after state change, value=" + sys->sprint("%d", value));
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 68;
	h = 14;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " + increases | - decreases | r resets | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Redraw after update ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 58, "Change application state, update nodes, then call ui->draw().") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, ValueId, 3, 4, 40, "") < 0)
		raise "fail:value label";

	if(ui->progress(u, WinId, ProgressId, 3, 6, 50, value, 100) < 0)
		raise "fail:progress";

	if(ui->label(u, WinId, HintId, 3, 8, 58, "The renderer compares buffers and flushes the visible result.") < 0)
		raise "fail:hint";

	if(ui->button(u, WinId, BtnDecId, 3, 11, 8, 1, "Dec", "-", AppTarget, "app.dec") < 0)
		raise "fail:dec button";

	if(ui->button(u, WinId, BtnIncId, 13, 11, 8, 1, "Inc", "+", AppTarget, "app.inc") < 0)
		raise "fail:inc button";

	if(ui->button(u, WinId, BtnResetId, 23, 11, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset button";

	if(ui->button(u, WinId, BtnExitId, 35, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnIncId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.inc"){
		value += 5;
		refresh(u);
		return 0;
	}

	if(cmd == "app.dec"){
		value -= 5;
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		value = 0;
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
	value = 35;

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