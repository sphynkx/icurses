#
# 03_05_clean_shutdown.b
#
# Visible shutdown sequence demo.
#
# The example shows a final checklist inside the main window before exit.
# It is intentionally not a one-button demo: the user can prepare shutdown,
# advance visible final steps, and then exit through the normal cleanup path.
#

implement CleanShutdownDemo;

include "draw.m";
include "icurses/ui.m";

CleanShutdownDemo: module
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
IntroId: con 12;
RunStateId: con 13;
TickId: con 14;

ChecklistId: con 20;
ChecklistTitleId: con 21;
Step1Id: con 22;
Step2Id: con 23;
Step3Id: con 24;
ProgressId: con 25;
FinalNoteId: con 26;

BtnPrepareId: con 30;
BtnNextId: con 31;
BtnResetId: con 32;
BtnExitId: con 33;

ticks: int;
phase: int;
prepared: int;

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

checkbox(done: int, text: string): string
{
	if(done)
		return "[x] " + text;

	return "[ ] " + text;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, TickId, "Ticks while input/timer processing is active: " + sys->sprint("%d", ticks));

	if(!prepared)
		ui->settext(u, RunStateId, "State: running. Press Prepare to begin visible shutdown steps.");
	else if(phase < 3)
		ui->settext(u, RunStateId, "State: preparing shutdown, step " + sys->sprint("%d", phase) + " of 3.");
	else
		ui->settext(u, RunStateId, "State: ready. Exit will close Ui and restore terminal.");

	ui->settext(u, Step1Id, checkbox(phase >= 1, "Review pending UI state"));
	ui->settext(u, Step2Id, checkbox(phase >= 2, "Prepare application state snapshot"));
	ui->settext(u, Step3Id, checkbox(phase >= 3, "Confirm ui->close() and terminal restore path"));
	ui->setprogress(u, ProgressId, phase, 3);

	if(phase >= 3)
		ui->settext(u, FinalNoteId, "Final Exit is now meaningful: application state is prepared.");
	else
		ui->settext(u, FinalNoteId, "Exit is always safe, but preparation makes the sequence visible.");

	ui->setstatus(u, "clean shutdown demo: phase=" + sys->sprint("%d", phase));
	ui->draw(u);
}

prepare(u: ref IcUi->Ui)
{
	prepared = 1;
	if(phase == 0)
		phase = 1;

	ui->setfocus(u, BtnNextId);
	refresh(u);
}

nextstep(u: ref IcUi->Ui)
{
	prepared = 1;

	if(phase < 3)
		phase++;

	ui->setfocus(u, BtnNextId);
	refresh(u);
}

resetsteps(u: ref IcUi->Ui)
{
	prepared = 0;
	phase = 0;
	ui->setfocus(u, BtnPrepareId);
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Prepare starts visible shutdown sequence | Next advances | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 18, " Clean shutdown ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, IntroId, 3, 2, 68, "This demo shows application-side preparation before normal cleanup.") < 0)
		raise "fail:intro";

	if(ui->label(u, WinId, RunStateId, 3, 4, 68, "") < 0)
		raise "fail:state";

	if(ui->label(u, WinId, TickId, 3, 5, 68, "") < 0)
		raise "fail:tick";

	if(ui->window(u, WinId, ChecklistId, 3, 7, 68, 7, " Visible shutdown checklist ") < 0)
		raise "fail:checklist";

	if(ui->label(u, ChecklistId, ChecklistTitleId, 2, 1, 60, "Application-side steps before returning to shell:") < 0)
		raise "fail:checklist title";

	if(ui->label(u, ChecklistId, Step1Id, 4, 2, 58, "") < 0)
		raise "fail:step1";

	if(ui->label(u, ChecklistId, Step2Id, 4, 3, 58, "") < 0)
		raise "fail:step2";

	if(ui->label(u, ChecklistId, Step3Id, 4, 4, 58, "") < 0)
		raise "fail:step3";

	if(ui->progress(u, ChecklistId, ProgressId, 4, 5, 44, 0, 3) < 0)
		raise "fail:progress";

	if(ui->label(u, WinId, FinalNoteId, 3, 14, 68, "") < 0)
		raise "fail:final note";

	if(ui->button(u, WinId, BtnPrepareId, 3, 16, 12, 1, "Prepare", "p", AppTarget, "app.prepare") < 0)
		raise "fail:prepare";

	if(ui->button(u, WinId, BtnNextId, 17, 16, 10, 1, "Next", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnResetId, 29, 16, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 41, 16, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnPrepareId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.prepare"){
		prepare(u);
		return 0;
	}

	if(cmd == "app.next"){
		nextstep(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetsteps(u);
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
	phase = 0;
	prepared = 0;

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

	ui->settick(u, 500);
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
			refresh(u);

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	ui->close(u);
	leaveappscreen();

	if(phase >= 3)
		sys->print("result: clean shutdown after visible checklist\n");
	else
		sys->print("result: clean shutdown\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}