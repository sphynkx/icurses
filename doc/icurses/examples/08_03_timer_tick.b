#
# 08_03_timer_tick.b
#
# Demonstrates timer events through IcUi->StepTick.
#
# Tick updates an ASCII spinner, a progress bar, and a small activity canvas
# without requiring keyboard input.
#

implement TimerTickDemo;

include "draw.m";
include "icurses/ui.m";

TimerTickDemo: module
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
SpinnerBoxId: con 13;
SpinnerLabelId: con 14;
TickId: con 15;
ProgressId: con 16;
CanvasId: con 17;

BtnPauseId: con 20;
BtnExitId: con 21;

ticks: int;
paused: int;

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

spinnerchar(): string
{
	case ticks % 4 {
	0 =>
		return "|";
	1 =>
		return "/";
	2 =>
		return "-";
	* =>
		return "\\";
	}
}

drawactivity(u: ref IcUi->Ui)
{
	i, pos: int;
	line: string;

	line = "";
	pos = ticks % 40;

	for(i = 0; i < 40; i++){
		if(i == pos)
			line += "*";
		else if(i % 5 == 0)
			line += "|";
		else
			line += "-";
	}

	ui->canvasclear(u, CanvasId, " ", "0");
	ui->canvasputs(u, CanvasId, 0, 0, line, "0");
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, SpinnerLabelId, "ASCII spinner: " + spinnerchar());
	ui->settext(u, TickId, "Tick count: " + sys->sprint("%d", ticks));
	ui->setprogress(u, ProgressId, ticks % 101, 100);
	drawactivity(u);

	if(paused)
		ui->setstatus(u, "timer paused");
	else
		ui->setstatus(u, "timer running");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 70);
	y = center(sh, 16);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Tick events update spinner, progress and canvas | p pause | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 16, " Timer events ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 66, "StepTick is useful for animation, polling, and scheduled refresh.") < 0)
		raise "fail:info";

	if(ui->window(u, WinId, SpinnerBoxId, 3, 4, 28, 5, " Tick-driven state ") < 0)
		raise "fail:spinner box";

	if(ui->label(u, SpinnerBoxId, SpinnerLabelId, 2, 1, 22, "") < 0)
		raise "fail:spinner label";

	if(ui->label(u, SpinnerBoxId, TickId, 2, 2, 22, "") < 0)
		raise "fail:tick";

	if(ui->progress(u, WinId, ProgressId, 35, 5, 25, 0, 100) < 0)
		raise "fail:progress";

	if(ui->canvas(u, WinId, CanvasId, 15, 10, 40, 1) < 0)
		raise "fail:canvas";

	if(ui->button(u, WinId, BtnPauseId, 3, 13, 10, 1, "Pause", "p", AppTarget, "app.pause") < 0)
		raise "fail:pause";

	if(ui->button(u, WinId, BtnExitId, 15, 13, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnPauseId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.pause"){
		paused = !paused;

		if(paused)
			ui->settext(u, BtnPauseId, "[ Run ]");
		else
			ui->settext(u, BtnPauseId, "[ Pause ]");

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
	ticks = 0;
	paused = 0;

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

	ui->settick(u, 200);
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
			if(!paused){
				ticks++;
				refresh(u);
			}

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