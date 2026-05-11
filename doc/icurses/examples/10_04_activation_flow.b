#
# 10_04_activation_flow.b
#
# Demonstrates activation flow.
#
# Each action has its own visible pipeline:
#
#   - Compile runs: focus -> command -> compiler -> object file.
#   - Test runs: focus -> command -> test runner -> test report.
#   - Deploy runs: focus -> command -> uploader -> release slot.
#
# This makes it clear that activation is the same mechanism, but application
# meaning depends on the produced command.
#

implement ActivationFlowDemo;

include "draw.m";
include "icurses/ui.m";

ActivationFlowDemo: module
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

CompileBoxId: con 20;
CompileTitleId: con 21;
CompileStep1Id: con 22;
CompileStep2Id: con 23;
CompileStep3Id: con 24;
CompileProgressId: con 25;

TestBoxId: con 30;
TestTitleId: con 31;
TestStep1Id: con 32;
TestStep2Id: con 33;
TestStep3Id: con 34;
TestProgressId: con 35;

DeployBoxId: con 40;
DeployTitleId: con 41;
DeployStep1Id: con 42;
DeployStep2Id: con 43;
DeployStep3Id: con 44;
DeployProgressId: con 45;

ResultBoxId: con 50;
ResultFocusId: con 51;
ResultCmdId: con 52;
ResultCountsId: con 53;

BtnCompileId: con 60;
BtnTestId: con 61;
BtnDeployId: con 62;
BtnResetId: con 63;
BtnExitId: con 64;

active: string;
stage: int;
compiled: int;
tested: int;
deployed: int;
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

mark(which, text: string): string
{
	if(active == which)
		return ">> " + text;

	return "   " + text;
}

stepmark(which: string, n: int, text: string): string
{
	if(active == which && stage >= n)
		return "[x] " + text;

	return "[ ] " + text;
}

progress(which: string): int
{
	if(active != which)
		return 0;

	if(stage <= 0)
		return 0;
	if(stage == 1)
		return 35;
	if(stage == 2)
		return 70;
	return 100;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, CompileTitleId, mark("compile", "Compile pipeline"));
	ui->settext(u, CompileStep1Id, stepmark("compile", 1, "read sources"));
	ui->settext(u, CompileStep2Id, stepmark("compile", 2, "run compiler"));
	ui->settext(u, CompileStep3Id, stepmark("compile", 3, "write object file"));
	ui->setprogress(u, CompileProgressId, progress("compile"), 100);

	ui->settext(u, TestTitleId, mark("test", "Test pipeline"));
	ui->settext(u, TestStep1Id, stepmark("test", 1, "collect tests"));
	ui->settext(u, TestStep2Id, stepmark("test", 2, "run assertions"));
	ui->settext(u, TestStep3Id, stepmark("test", 3, "write report"));
	ui->setprogress(u, TestProgressId, progress("test"), 100);

	ui->settext(u, DeployTitleId, mark("deploy", "Deploy pipeline"));
	ui->settext(u, DeployStep1Id, stepmark("deploy", 1, "pack release"));
	ui->settext(u, DeployStep2Id, stepmark("deploy", 2, "upload bundle"));
	ui->settext(u, DeployStep3Id, stepmark("deploy", 3, "activate slot"));
	ui->setprogress(u, DeployProgressId, progress("deploy"), 100);

	ui->settext(u, ResultFocusId, "Active focus/action: " + active);
	ui->settext(u, ResultCmdId, "Last command: " + lastcmd);
	ui->settext(u, ResultCountsId, " compile=" + sys->sprint("%d", compiled) +
		" test=" + sys->sprint("%d", tested) +
		" deploy=" + sys->sprint("%d", deployed));

	ui->setstatus(u, "activation command: " + lastcmd);
	ui->draw(u);
}

animate(u: ref IcUi->Ui, which, cmd: string)
{
	active = which;
	lastcmd = cmd;

	stage = 1;
	refresh(u);
	sys->sleep(120);

	stage = 2;
	refresh(u);
	sys->sleep(120);

	stage = 3;
	refresh(u);
}

resetstate(u: ref IcUi->Ui)
{
	active = "none";
	stage = 0;
	compiled = 0;
	tested = 0;
	deployed = 0;
	lastcmd = "app.reset";
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Activate Compile/Test/Deploy to run different pipelines | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 22, " Activation flow ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 78, "Activation produces a command; each command has its own application pipeline.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CompileBoxId, 3, 4, 25, 9, " Compile ") < 0)
		raise "fail:compile box";

	if(ui->label(u, CompileBoxId, CompileTitleId, 2, 1, 20, "") < 0)
		raise "fail:compile title";

	if(ui->label(u, CompileBoxId, CompileStep1Id, 2, 3, 20, "") < 0)
		raise "fail:compile step 1";

	if(ui->label(u, CompileBoxId, CompileStep2Id, 2, 4, 20, "") < 0)
		raise "fail:compile step 2";

	if(ui->label(u, CompileBoxId, CompileStep3Id, 2, 5, 20, "") < 0)
		raise "fail:compile step 3";

	if(ui->progress(u, CompileBoxId, CompileProgressId, 2, 7, 19, 0, 100) < 0)
		raise "fail:compile progress";

	if(ui->window(u, WinId, TestBoxId, 30, 4, 25, 9, " Test ") < 0)
		raise "fail:test box";

	if(ui->label(u, TestBoxId, TestTitleId, 2, 1, 20, "") < 0)
		raise "fail:test title";

	if(ui->label(u, TestBoxId, TestStep1Id, 2, 3, 20, "") < 0)
		raise "fail:test step 1";

	if(ui->label(u, TestBoxId, TestStep2Id, 2, 4, 20, "") < 0)
		raise "fail:test step 2";

	if(ui->label(u, TestBoxId, TestStep3Id, 2, 5, 20, "") < 0)
		raise "fail:test step 3";

	if(ui->progress(u, TestBoxId, TestProgressId, 2, 7, 19, 0, 100) < 0)
		raise "fail:test progress";

	if(ui->window(u, WinId, DeployBoxId, 57, 4, 25, 9, " Deploy ") < 0)
		raise "fail:deploy box";

	if(ui->label(u, DeployBoxId, DeployTitleId, 2, 1, 20, "") < 0)
		raise "fail:deploy title";

	if(ui->label(u, DeployBoxId, DeployStep1Id, 2, 3, 20, "") < 0)
		raise "fail:deploy step 1";

	if(ui->label(u, DeployBoxId, DeployStep2Id, 2, 4, 20, "") < 0)
		raise "fail:deploy step 2";

	if(ui->label(u, DeployBoxId, DeployStep3Id, 2, 5, 20, "") < 0)
		raise "fail:deploy step 3";

	if(ui->progress(u, DeployBoxId, DeployProgressId, 2, 7, 19, 0, 100) < 0)
		raise "fail:deploy progress";

	if(ui->window(u, WinId, ResultBoxId, 3, 14, 79, 4, " Activation result ") < 0)
		raise "fail:result box";

	if(ui->label(u, ResultBoxId, ResultFocusId, 2, 1, 72, "") < 0)
		raise "fail:result focus";

	if(ui->label(u, ResultBoxId, ResultCmdId, 2, 2, 72, "") < 0)
		raise "fail:result cmd";

	if(ui->label(u, ResultBoxId, ResultCountsId, 2, 3, 32, "") < 0)
		raise "fail:result counts";

	if(ui->button(u, WinId, BtnCompileId, 3, 20, 12, 1, "Compile", "c", AppTarget, "app.compile") < 0)
		raise "fail:compile button";

	if(ui->button(u, WinId, BtnTestId, 17, 20, 10, 1, "Test", "t", AppTarget, "app.test") < 0)
		raise "fail:test button";

	if(ui->button(u, WinId, BtnDeployId, 29, 20, 12, 1, "Deploy", "d", AppTarget, "app.deploy") < 0)
		raise "fail:deploy button";

	if(ui->button(u, WinId, BtnResetId, 43, 20, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset button";

	if(ui->button(u, WinId, BtnExitId, 55, 20, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	active = "none";
	stage = 0;
	compiled = 0;
	tested = 0;
	deployed = 0;
	lastcmd = "none";

	ui->setfocus(u, BtnCompileId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.compile"){
		ui->setfocus(u, BtnCompileId);
		compiled++;
		animate(u, "compile", cmd);
		return 0;
	}

	if(cmd == "app.test"){
		ui->setfocus(u, BtnTestId);
		tested++;
		animate(u, "test", cmd);
		return 0;
	}

	if(cmd == "app.deploy"){
		ui->setfocus(u, BtnDeployId);
		deployed++;
		animate(u, "deploy", cmd);
		return 0;
	}

	if(cmd == "app.reset"){
		ui->setfocus(u, BtnResetId);
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