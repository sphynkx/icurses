#
# 08_04_main_loop.b
#
# Demonstrates the application main loop as a visible processing pipeline:
# input step -> command handling -> state update -> redraw.
#

implement MainLoopDemo;

include "draw.m";
include "icurses/ui.m";

MainLoopDemo: module
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

PipelineId: con 20;
StageInputId: con 21;
StageCommandId: con 22;
StageStateId: con 23;
StageRedrawId: con 24;

StateBoxId: con 30;
WorkId: con 31;
StepsId: con 32;
LastCmdId: con 33;

BtnWorkId: con 40;
BtnResetId: con 41;
BtnExitId: con 42;

work: int;
steps: int;
stage: int;
lastcmd: string;

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

stagetext(id: int, name: string): string
{
	if(stage == id)
		return ">> " + name + " <<";

	return "   " + name;
}

refresh(u: ref IcUi->Ui, note: string)
{
	ui->settext(u, StageInputId, stagetext(0, "1 input step"));
	ui->settext(u, StageCommandId, stagetext(1, "2 command"));
	ui->settext(u, StageStateId, stagetext(2, "3 state update"));
	ui->settext(u, StageRedrawId, stagetext(3, "4 redraw"));

	ui->settext(u, WorkId, "Application work value: " + sys->sprint("%d", work));
	ui->settext(u, StepsId, "Main loop iterations: " + sys->sprint("%d", steps));
	ui->settext(u, LastCmdId, "Last command: " + lastcmd);

	if(note == "")
		note = "main loop ready";

	ui->setstatus(u, note);
	ui->draw(u);
}

animatepipeline(u: ref IcUi->Ui, cmd: string)
{
	lastcmd = cmd;

	stage = 0;
	refresh(u, "input step received");
	sys->sleep(120);

	stage = 1;
	refresh(u, "command decoded");
	sys->sleep(120);

	stage = 2;
	refresh(u, "application state updated");
	sys->sleep(120);

	stage = 3;
	refresh(u, "redraw completed");
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 78);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Work animates main-loop pipeline | Reset clears state | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 18, " Main loop pipeline ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 68, "The main loop combines event, command, state update, and redraw.") < 0)
		raise "fail:info";

	if(ui->window(u, WinId, PipelineId, 3, 4, 68, 7, " Processing pipeline ") < 0)
		raise "fail:pipeline";

	if(ui->label(u, PipelineId, StageInputId, 3, 1, 58, "") < 0)
		raise "fail:input";

	if(ui->label(u, PipelineId, StageCommandId, 3, 2, 58, "") < 0)
		raise "fail:command";

	if(ui->label(u, PipelineId, StageStateId, 3, 3, 58, "") < 0)
		raise "fail:state";

	if(ui->label(u, PipelineId, StageRedrawId, 3, 4, 58, "") < 0)
		raise "fail:redraw";

	if(ui->window(u, WinId, StateBoxId, 3, 12, 68, 4, " Application state ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, WorkId, 2, 1, 60, "") < 0)
		raise "fail:work";

	if(ui->label(u, StateBoxId, StepsId, 2, 2, 60, "") < 0)
		raise "fail:steps";

	if(ui->label(u, StateBoxId, LastCmdId, 2, 3, 30, "") < 0)
		raise "fail:last cmd";

	if(ui->button(u, WinId, BtnWorkId, 3, 16, 10, 1, "Work", "w", AppTarget, "app.work") < 0)
		raise "fail:work button";

	if(ui->button(u, WinId, BtnResetId, 15, 16, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 27, 16, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnWorkId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.work"){
		work++;
		animatepipeline(u, cmd);
		return 0;
	}

	if(cmd == "app.reset"){
		work = 0;
		animatepipeline(u, cmd);
		return 0;
	}

	refresh(u, "unknown command");
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	work = 0;
	steps = 0;
	stage = 3;
	lastcmd = "none";

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
		steps++;

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