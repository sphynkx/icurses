#
# 01_status_and_help.b
#
# Demonstrates the IcUi object as the central application context:
# help text, status text, focus, commands, and the step-based loop.
#

implement StatusAndHelpDemo;

include "draw.m";
include "icurses/ui.m";

StatusAndHelpDemo: module
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
ModeId: con 13;
InfoId: con 14;
BtnModeId: con 15;
BtnStatusId: con 16;
BtnExitId: con 17;

mode: int;
statuscount: int;

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

modename(): string
{
	case mode {
	0 =>
		return "Mode: browse";
	1 =>
		return "Mode: edit";
	2 =>
		return "Mode: review";
	* =>
		return "Mode: unknown";
	}
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, ModeId, modename());
	ui->settext(u, InfoId, "The Ui object owns tree, renderer, keymap, help, status, and event state.");
	ui->setstatus(u, "status update #" + sys->sprint("%d", statuscount));
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 64;
	h = 11;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Tab changes focus | Enter activates | m mode | s status | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " UI context ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 52, "Application state and UI state are kept separate.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, ModeId, 3, 4, 40, modename()) < 0)
		raise "fail:mode";

	if(ui->label(u, WinId, InfoId, 3, 5, 55, "") < 0)
		raise "fail:info";

	if(ui->button(u, WinId, BtnModeId, 3, 8, 14, 1, "Mode", "m", AppTarget, "app.mode") < 0)
		raise "fail:mode button";

	if(ui->button(u, WinId, BtnStatusId, 20, 8, 16, 1, "Status", "s", AppTarget, "app.status") < 0)
		raise "fail:status button";

	if(ui->button(u, WinId, BtnExitId, 39, 8, 12, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnModeId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.mode"){
		mode = (mode + 1) % 3;
		statuscount++;
		refresh(u);
		return 0;
	}

	if(cmd == "app.status"){
		statuscount++;
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
	mode = 0;
	statuscount = 0;

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