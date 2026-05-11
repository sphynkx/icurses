#
# 08_06_input_shutdown.b
#
# Demonstrates input shutdown with visible resource states.
#
# This differs from the generic clean shutdown demo: it focuses on input/timer
# resources owned by IcUi while the loop is running.
#

implement InputShutdownDemo;

include "draw.m";
include "icurses/ui.m";

InputShutdownDemo: module
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

ResourceBoxId: con 20;
KeyboardId: con 21;
TimerId: con 22;
RendererId: con 23;
TerminalId: con 24;

TickBoxId: con 30;
TickId: con 31;
SpinnerId: con 32;

BtnArmId: con 40;
BtnCancelId: con 41;
BtnExitId: con 42;

ticks: int;
armed: int;

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

spinner(): string
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

resource(active: int, name: string): string
{
	if(armed)
		return "[will close] " + name;

	if(active)
		return "[active] " + name;

	return "[closed] " + name;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, KeyboardId, resource(1, "keyboard reader"));
	ui->settext(u, TimerId, resource(1, "tick timer"));
	ui->settext(u, RendererId, resource(1, "renderer state"));
	ui->settext(u, TerminalId, resource(1, "alternate screen and cursor"));

	ui->settext(u, TickId, "Ticks while input is running: " + sys->sprint("%d", ticks));
	ui->settext(u, SpinnerId, "Input loop spinner: " + spinner());

	if(armed)
		ui->setstatus(u, "shutdown armed: Exit will close input and restore terminal");
	else
		ui->setstatus(u, "input resources are active");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 100);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Arm marks resources for shutdown | Exit calls ui->close | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 92, 18, " Input shutdown ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, IntroId, 3, 2, 66, "The Ui object owns input readers, timer events, and renderer state.") < 0)
		raise "fail:intro";

	if(ui->window(u, WinId, ResourceBoxId, 3, 4, 46, 8, " Resources ") < 0)
		raise "fail:resources";

	if(ui->label(u, ResourceBoxId, KeyboardId, 2, 1, 42, "") < 0)
		raise "fail:keyboard";

	if(ui->label(u, ResourceBoxId, TimerId, 2, 2, 42, "") < 0)
		raise "fail:timer";

	if(ui->label(u, ResourceBoxId, RendererId, 2, 3, 42, "") < 0)
		raise "fail:renderer";

	if(ui->label(u, ResourceBoxId, TerminalId, 2, 4, 42, "") < 0)
		raise "fail:terminal";

	if(ui->window(u, WinId, TickBoxId, 50, 4, 40, 8, " Live input ") < 0)
		raise "fail:tick box";

	if(ui->label(u, TickBoxId, TickId, 2, 2, 34, "") < 0)
		raise "fail:tick";

	if(ui->label(u, TickBoxId, SpinnerId, 2, 4, 20, "") < 0)
		raise "fail:spinner";

	if(ui->button(u, WinId, BtnArmId, 3, 15, 10, 1, "Arm", "a", AppTarget, "app.arm") < 0)
		raise "fail:arm";

	if(ui->button(u, WinId, BtnCancelId, 15, 15, 10, 1, "Cancel", "c", AppTarget, "app.cancel") < 0)
		raise "fail:cancel";

	if(ui->button(u, WinId, BtnExitId, 27, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnArmId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.arm"){
		armed = 1;
		ui->setfocus(u, BtnExitId);
		refresh(u);
		return 0;
	}

	if(cmd == "app.cancel"){
		armed = 0;
		ui->setfocus(u, BtnArmId);
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
	armed = 0;

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

	ui->settick(u, 400);
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

	if(armed)
		sys->print("result: input resources closed after armed shutdown\n");
	else
		sys->print("result: input resources closed\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}