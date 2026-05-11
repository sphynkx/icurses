#
# 11_09_task_progress.b
#
# Demonstrates progress bars and a spinner as a task dashboard.
#
# The example avoids hidden helper behavior and builds a visible task dashboard
# directly from windows, labels, progress bars and a spinner.
#

implement TaskProgressDemo;

include "draw.m";
include "icurses/ui.m";

TaskProgressDemo: module
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
TitleId: con 12;

TaskBoxId: con 20;
PhaseId: con 21;
ItemId: con 22;
ItemProgressId: con 23;
TotalProgressId: con 24;
SpinnerId: con 25;

FlowBoxId: con 30;
StepScanId: con 31;
StepBuildId: con 32;
StepPackageId: con 33;

LogBoxId: con 40;
Log1Id: con 41;
Log2Id: con 42;
Log3Id: con 43;

BtnStartId: con 50;
BtnPauseId: con 51;
BtnResetId: con 52;
BtnExitId: con 53;

running: int;
paused: int;
phase: int;
item: int;
total: int;
ticks: int;

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

phasename(): string
{
	if(phase == 0)
		return "idle";
	if(phase == 1)
		return "scan";
	if(phase == 2)
		return "build";
	if(phase == 3)
		return "package";
	return "done";
}

currentitem(): string
{
	if(phase == 1)
		return "source tree";
	if(phase == 2)
		return "object files";
	if(phase == 3)
		return "release bundle";
	if(phase >= 4)
		return "complete";
	return "waiting";
}

stepmark(n: int, text: string): string
{
	if(phase > n)
		return "[x] " + text;

	if(phase == n)
		return ">> " + text;

	return "[ ] " + text;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, PhaseId, "Phase: " + phasename());
	ui->settext(u, ItemId, "Current item: " + currentitem());

	ui->setprogress(u, ItemProgressId, item, 100);
	ui->setprogress(u, TotalProgressId, total, 100);

	ui->settext(u, StepScanId, stepmark(1, "scan files"));
	ui->settext(u, StepBuildId, stepmark(2, "build objects"));
	ui->settext(u, StepPackageId, stepmark(3, "package release"));

	ui->settext(u, Log1Id, "Ticks: " + sys->sprint("%d", ticks));
	ui->settext(u, Log2Id, "Running=" + sys->sprint("%d", running) + " paused=" + sys->sprint("%d", paused));
	ui->settext(u, Log3Id, "Item=" + sys->sprint("%d", item) + "% total=" + sys->sprint("%d", total) + "%");

	if(running && !paused)
		ui->tickspinner(u, SpinnerId);

	if(paused)
		ui->setstatus(u, "task paused");
	else if(running)
		ui->setstatus(u, "task running");
	else
		ui->setstatus(u, "task ready");

	ui->draw(u);
}

resetstate(u: ref IcUi->Ui)
{
	running = 0;
	paused = 0;
	phase = 0;
	item = 0;
	total = 0;
	ticks = 0;
	ui->settext(u, BtnPauseId, "[ Pause ]");
	refresh(u);
}

advance(u: ref IcUi->Ui)
{
	if(!running || paused)
		return;

	item += 8;
	total += 3;

	if(item >= 100){
		item = 0;
		phase++;
	}

	if(phase <= 0)
		phase = 1;

	if(phase >= 4){
		phase = 4;
		item = 100;
		total = 100;
		running = 0;
	}

	if(total > 100)
		total = 100;

	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 21);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Start runs task | Pause freezes tick updates | Reset clears progress | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 21, " Task and progress ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 68, "Task feedback can be built from labels, progress bars and spinner.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TaskBoxId, 3, 4, 42, 8, " Task dashboard ") < 0)
		raise "fail:task box";

	if(ui->label(u, TaskBoxId, PhaseId, 2, 1, 34, "") < 0)
		raise "fail:phase";

	if(ui->label(u, TaskBoxId, ItemId, 2, 2, 34, "") < 0)
		raise "fail:item";

	if(ui->progress(u, TaskBoxId, ItemProgressId, 2, 4, 32, 0, 100) < 0)
		raise "fail:item progress";

	if(ui->progress(u, TaskBoxId, TotalProgressId, 2, 6, 32, 0, 100) < 0)
		raise "fail:total progress";

	if(ui->spinner(u, TaskBoxId, SpinnerId, 36, 1, 0) < 0)
		raise "fail:spinner";

	if(ui->window(u, WinId, FlowBoxId, 48, 4, 26, 8, " Pipeline ") < 0)
		raise "fail:flow box";

	if(ui->label(u, FlowBoxId, StepScanId, 2, 2, 20, "") < 0)
		raise "fail:scan";

	if(ui->label(u, FlowBoxId, StepBuildId, 2, 3, 20, "") < 0)
		raise "fail:build";

	if(ui->label(u, FlowBoxId, StepPackageId, 2, 4, 20, "") < 0)
		raise "fail:package";

	if(ui->window(u, WinId, LogBoxId, 3, 13, 71, 4, " Task log ") < 0)
		raise "fail:log box";

	if(ui->label(u, LogBoxId, Log1Id, 2, 1, 62, "") < 0)
		raise "fail:log1";

	if(ui->label(u, LogBoxId, Log2Id, 22, 1, 40, "") < 0)
		raise "fail:log2";

	if(ui->label(u, LogBoxId, Log3Id, 2, 2, 62, "") < 0)
		raise "fail:log3";

	if(ui->button(u, WinId, BtnStartId, 3, 19, 10, 1, "Start", "s", AppTarget, "app.start") < 0)
		raise "fail:start";

	if(ui->button(u, WinId, BtnPauseId, 15, 19, 12, 1, "Pause", "p", AppTarget, "app.pause") < 0)
		raise "fail:pause";

	if(ui->button(u, WinId, BtnResetId, 29, 19, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 41, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	resetstate(u);
	ui->setfocus(u, BtnStartId);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.start"){
		running = 1;
		paused = 0;
		if(phase == 0 || phase >= 4)
			phase = 1;
		ui->settext(u, BtnPauseId, "[ Pause ]");
		refresh(u);
		return 0;
	}

	if(cmd == "app.pause"){
		if(running){
			paused = !paused;
			if(paused)
				ui->settext(u, BtnPauseId, "[ Run ]");
			else
				ui->settext(u, BtnPauseId, "[ Pause ]");
		}
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetstate(u);
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

	ui->settick(u, 150);
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
			ticks++;
			advance(u);

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