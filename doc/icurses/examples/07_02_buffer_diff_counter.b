#
# 07_02_buffer_diff_counter.b
#
# Demonstrates front/back buffer style updates from the application point of
# view. The app calls ui->draw() after small state changes; the renderer decides
# which terminal cells actually need to be flushed.
#

implement BufferDiffCounterDemo;

include "draw.m";
include "icurses/ui.m";

BufferDiffCounterDemo: module
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
CounterId: con 13;
ProgressId: con 14;
HintId: con 15;

BtnIncId: con 20;
BtnDecId: con 21;
BtnResetId: con 22;
BtnExitId: con 23;

value: int;
draws: int;

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
	draws++;

	ui->settext(u, CounterId, "Value: " + sys->sprint("%d", value) +
		" | ui->draw calls: " + sys->sprint("%d", draws));
	ui->setprogress(u, ProgressId, value, 100);
	ui->setstatus(u, "small update; renderer compares back buffer with front buffer");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 70;
	h = 14;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Change a small value; renderer flushes only changed cells | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Front/back buffers ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 60, "Application updates state; renderer computes terminal differences.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, CounterId, 3, 4, 60, "") < 0)
		raise "fail:counter";

	if(ui->progress(u, WinId, ProgressId, 3, 6, 50, value, 100) < 0)
		raise "fail:progress";

	if(ui->label(u, WinId, HintId, 3, 8, 60, "The whole tree is drawn into the back buffer before flush.") < 0)
		raise "fail:hint";

	if(ui->button(u, WinId, BtnIncId, 3, 11, 8, 1, "Inc", "+", AppTarget, "app.inc") < 0)
		raise "fail:inc";

	if(ui->button(u, WinId, BtnDecId, 13, 11, 8, 1, "Dec", "-", AppTarget, "app.dec") < 0)
		raise "fail:dec";

	if(ui->button(u, WinId, BtnResetId, 23, 11, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 35, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

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
	draws = 0;

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