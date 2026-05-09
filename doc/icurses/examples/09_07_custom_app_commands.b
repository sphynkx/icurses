#
# 09_07_custom_app_commands.b
#
# Demonstrates custom application commands.
#
# The task board uses app.task.* commands. These commands are not framework
# commands; the application defines their meaning and updates its own state.
#

implement CustomAppCommandsDemo;

include "draw.m";
include "icurses/ui.m";

CustomAppCommandsDemo: module
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

TodoBoxId: con 20;
TodoTitleId: con 21;
TodoCountId: con 22;
TodoLastId: con 23;

RunBoxId: con 30;
RunTitleId: con 31;
RunCountId: con 32;
RunLastId: con 33;

DoneBoxId: con 40;
DoneTitleId: con 41;
DoneCountId: con 42;
DoneLastId: con 43;

CommandBoxId: con 50;
CommandLine1Id: con 51;
CommandLine2Id: con 52;
CommandLine3Id: con 53;

BtnAddId: con 60;
BtnStartId: con 61;
BtnFinishId: con 62;
BtnResetId: con 63;
BtnExitId: con 64;

todo: int;
running: int;
donecount: int;
lastcmd: string;
lastmove: string;

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

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, TodoCountId, "Tasks: " + sys->sprint("%d", todo));
	ui->settext(u, TodoLastId, "Last: " + lastmove);

	ui->settext(u, RunCountId, "Tasks: " + sys->sprint("%d", running));
	ui->settext(u, RunLastId, "Last: " + lastmove);

	ui->settext(u, DoneCountId, "Tasks: " + sys->sprint("%d", donecount));
	ui->settext(u, DoneLastId, "Last: " + lastmove);

	ui->settext(u, CommandLine1Id, "Last custom command: " + lastcmd);
	ui->settext(u, CommandLine2Id, "Commands are app.task.add, app.task.start, app.task.finish.");
	ui->settext(u, CommandLine3Id, "The framework does not know their meaning; this app defines it.");

	ui->setstatus(u, "custom app command: " + lastcmd);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Custom app.task.* commands move tasks between columns | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Custom application commands ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "Application commands are ordinary strings with application-defined meaning.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TodoBoxId, 3, 4, 22, 7, " Todo ") < 0)
		raise "fail:todo";

	if(ui->label(u, TodoBoxId, TodoTitleId, 2, 1, 16, "Queue") < 0)
		raise "fail:todo title";

	if(ui->label(u, TodoBoxId, TodoCountId, 2, 3, 16, "") < 0)
		raise "fail:todo count";

	if(ui->label(u, TodoBoxId, TodoLastId, 2, 4, 16, "") < 0)
		raise "fail:todo last";

	if(ui->window(u, WinId, RunBoxId, 29, 4, 22, 7, " Running ") < 0)
		raise "fail:running";

	if(ui->label(u, RunBoxId, RunTitleId, 2, 1, 16, "In progress") < 0)
		raise "fail:running title";

	if(ui->label(u, RunBoxId, RunCountId, 2, 3, 16, "") < 0)
		raise "fail:running count";

	if(ui->label(u, RunBoxId, RunLastId, 2, 4, 16, "") < 0)
		raise "fail:running last";

	if(ui->window(u, WinId, DoneBoxId, 55, 4, 22, 7, " Done ") < 0)
		raise "fail:done";

	if(ui->label(u, DoneBoxId, DoneTitleId, 2, 1, 16, "Completed") < 0)
		raise "fail:done title";

	if(ui->label(u, DoneBoxId, DoneCountId, 2, 3, 16, "") < 0)
		raise "fail:done count";

	if(ui->label(u, DoneBoxId, DoneLastId, 2, 4, 16, "") < 0)
		raise "fail:done last";

	if(ui->window(u, WinId, CommandBoxId, 3, 12, 74, 4, " Command log ") < 0)
		raise "fail:command box";

	if(ui->label(u, CommandBoxId, CommandLine1Id, 2, 1, 68, "") < 0)
		raise "fail:command line 1";

	if(ui->label(u, CommandBoxId, CommandLine2Id, 2, 2, 68, "") < 0)
		raise "fail:command line 2";

	if(ui->label(u, CommandBoxId, CommandLine3Id, 2, 3, 68, "") < 0)
		raise "fail:command line 3";

	if(ui->button(u, WinId, BtnAddId, 3, 18, 10, 1, "Add", "a", AppTarget, "app.task.add") < 0)
		raise "fail:add";

	if(ui->button(u, WinId, BtnStartId, 15, 18, 10, 1, "Start", "s", AppTarget, "app.task.start") < 0)
		raise "fail:start";

	if(ui->button(u, WinId, BtnFinishId, 27, 18, 10, 1, "Finish", "f", AppTarget, "app.task.finish") < 0)
		raise "fail:finish";

	if(ui->button(u, WinId, BtnResetId, 39, 18, 10, 1, "Reset", "r", AppTarget, "app.task.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 51, 18, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	todo = 0;
	running = 0;
	donecount = 0;
	lastcmd = "none";
	lastmove = "none";

	ui->setfocus(u, BtnAddId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	lastcmd = cmd;

	if(cmd == "app.task.add"){
		todo++;
		lastmove = "added to Todo";
	}
	else if(cmd == "app.task.start"){
		if(todo > 0){
			todo--;
			running++;
			lastmove = "Todo -> Running";
		}
		else
			lastmove = "no Todo task";
	}
	else if(cmd == "app.task.finish"){
		if(running > 0){
			running--;
			donecount++;
			lastmove = "Running -> Done";
		}
		else
			lastmove = "no Running task";
	}
	else if(cmd == "app.task.reset"){
		todo = 0;
		running = 0;
		donecount = 0;
		lastmove = "board cleared";
	}
	else
		lastmove = "unknown command";

	refresh(u);
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