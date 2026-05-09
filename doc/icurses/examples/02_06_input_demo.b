#
# 02_06_input_demo.b
#
# Demonstrates keyboard, command, tick, and optional mouse events returned by
# IcUi->step().
#
# The example intentionally shows several independent counters:
#   - key events;
#   - command messages;
#   - tick events;
#   - mouse events.
#

implement InputDemo;

include "draw.m";
include "icurses/ui.m";

InputDemo: module
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
KeyId: con 13;
CmdId: con 14;
TickId: con 15;
MouseId: con 16;
SummaryId: con 17;

BtnMarkId: con 20;
BtnResetId: con 21;
BtnExitId: con 22;

ticks: int;
keys: int;
commands: int;
mouseevents: int;
marks: int;
mouseok: int;

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
	ui->settext(u, TickId, "Tick events: " + sys->sprint("%d", ticks));

	ui->settext(u, SummaryId,
		"Keys=" +
		sys->sprint("%d", keys) +
		" commands=" +
		sys->sprint("%d", commands) +
		" ticks=" +
		sys->sprint("%d", ticks) +
		" mouse=" +
		sys->sprint("%d", mouseevents));

	ui->setstatus(u,
		"keys=" +
		sys->sprint("%d", keys) +
		" commands=" +
		sys->sprint("%d", commands) +
		" ticks=" +
		sys->sprint("%d", ticks) +
		" mouse=" +
		sys->sprint("%d", mouseevents));

	ui->draw(u);
}

resetstats(u: ref IcUi->Ui)
{
	ticks = 0;
	keys = 0;
	commands = 0;
	mouseevents = 0;
	marks = 0;

	ui->settext(u, KeyId, "Last key: none");
	ui->settext(u, CmdId, "Last command: none");
	if(mouseok)
		ui->settext(u, MouseId, "Mouse events: 0 | mouse mode requested");
	else
		ui->settext(u, MouseId, "Mouse events: 0 | mouse mode unavailable");

	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 16;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Press keys, try mouse if supported | m mark | r reset | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Input events ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, IntroId, 3, 2, 64, "IcUi->step() reports keyboard, command, tick, mouse, and done events.") < 0)
		raise "fail:intro";

	if(ui->label(u, WinId, KeyId, 3, 4, 64, "Last key: none") < 0)
		raise "fail:key label";

	if(ui->label(u, WinId, CmdId, 3, 5, 64, "Last command: none") < 0)
		raise "fail:cmd label";

	if(ui->label(u, WinId, TickId, 3, 6, 64, "") < 0)
		raise "fail:tick label";

	if(ui->label(u, WinId, MouseId, 3, 7, 64, "") < 0)
		raise "fail:mouse label";

	if(ui->label(u, WinId, SummaryId, 3, 9, 64, "") < 0)
		raise "fail:summary label";

	if(ui->button(u, WinId, BtnMarkId, 3, 12, 10, 1, "Mark", "m", AppTarget, "app.mark") < 0)
		raise "fail:mark button";

	if(ui->button(u, WinId, BtnResetId, 15, 12, 12, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset button";

	if(ui->button(u, WinId, BtnExitId, 29, 12, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	mouseok = ui->enablemouse(u, 1);
	if(mouseok >= 0)
		mouseok = 1;
	else
		mouseok = 0;

	ui->setfocus(u, BtnMarkId);
	resetstats(u);
}

handlecommand(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "")
		return 0;

	if(cmd == "app.exit")
		return 1;

	commands++;

	if(cmd == "app.mark"){
		marks++;
		ui->settext(u, CmdId, "Last command: app.mark | marks=" + sys->sprint("%d", marks));
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetstats(u);
		return 0;
	}

	ui->settext(u, CmdId, "Last command: " + cmd);
	refresh(u);
	return 0;
}

handlekey(u: ref IcUi->Ui, s: IcUi->Step): int
{
	keys++;

	ui->settext(u, KeyId, "Last key: " + ic->keyname(s.key));

	if(handlecommand(u, s.msg.cmd))
		return 1;

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
	ticks = 0;
	keys = 0;
	commands = 0;
	mouseevents = 0;
	marks = 0;
	mouseok = 0;

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
				done = handlekey(u, s);

		IcUi->StepTick =>
			ticks++;
			refresh(u);

		IcUi->StepMouse =>
			mouseevents++;
			ui->settext(u, MouseId,
				"Mouse events: " +
				sys->sprint("%d", mouseevents) +
				" | last=" +
				s.status);
			refresh(u);

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