#
# 11_05_controls_check_radio_switch.b
#
# Demonstrates checkbox, radio and switch controls.
#
# Controls are focusable button-like elements with internal checked/on state.
# The helper module updates the visible control text and returns change messages.
#

implement ControlsDemo;

include "draw.m";
include "icurses/control.m";

ControlsDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
control: IcControl;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

CheckBoxId: con 20;
CheckTitleId: con 21;
CheckLogId: con 22;
CheckFastId: con 23;
CheckSafeId: con 24;

RadioGroupId: con 30;
RadioTitleId: con 31;
RadioDevId: con 32;
RadioStageId: con 33;
RadioProdId: con 34;

SwitchBoxId: con 40;
SwitchTitleId: con 41;
SwitchNetworkId: con 42;
SwitchCacheId: con 43;

StateBoxId: con 50;
StateLine1Id: con 51;
StateLine2Id: con 52;
StateLine3Id: con 53;

BtnExitId: con 60;

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

	control = load IcControl IcControl->PATH;
	if(control == nil)
		raise "fail:load iccontrol";

	ic->init();
	ui->init();
	control->init();
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

radioname(id: int): string
{
	if(id == RadioDevId)
		return "dev";
	if(id == RadioStageId)
		return "stage";
	if(id == RadioProdId)
		return "prod";
	return "none";
}

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	selected: int;

	selected = control->selected(u, RadioGroupId);

	ui->settext(u, StateLine1Id, "Checkboxes: log=" + sys->sprint("%d", control->checked(u, CheckLogId)) +
		" fast=" + sys->sprint("%d", control->checked(u, CheckFastId)) +
		" safe=" + sys->sprint("%d", control->checked(u, CheckSafeId)));

	ui->settext(u, StateLine2Id, "Radio selected: " + radioname(selected));

	ui->settext(u, StateLine3Id, "Switches: network=" + sys->sprint("%d", control->checked(u, SwitchNetworkId)) +
		" cache=" + sys->sprint("%d", control->checked(u, SwitchCacheId)));

	if(m.kind != IcMsg->KindNone)
		ui->setstatus(u, "control message: " + m.cmd + " value=" + sys->sprint("%d", m.iarg0));
	else
		ui->setstatus(u, "controls ready");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Space/Enter toggles focused control | hotkeys l/f/s/d/g/p/n/c | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 20, " Checkbox, radio and switch ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "Controls keep checked/on state and return command messages when changed.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CheckBoxId, 3, 4, 25, 9, " Checkboxes ") < 0)
		raise "fail:checkbox box";

	if(ui->label(u, CheckBoxId, CheckTitleId, 2, 1, 18, "Multi selection") < 0)
		raise "fail:check title";

	if(control->checkbox(u, CheckBoxId, CheckLogId, 2, 3, 18, "Log events", "l", AppTarget, "app.check.log", 1) < 0)
		raise "fail:check log";

	if(control->checkbox(u, CheckBoxId, CheckFastId, 2, 4, 18, "Fast mode", "f", AppTarget, "app.check.fast", 0) < 0)
		raise "fail:check fast";

	if(control->checkbox(u, CheckBoxId, CheckSafeId, 2, 5, 18, "Safe mode", "s", AppTarget, "app.check.safe", 1) < 0)
		raise "fail:check safe";

	if(ui->window(u, WinId, RadioGroupId, 30, 4, 22, 9, " Radio group ") < 0)
		raise "fail:radio group";

	if(ui->label(u, RadioGroupId, RadioTitleId, 2, 1, 16, "Single selection") < 0)
		raise "fail:radio title";

	if(control->radio(u, RadioGroupId, RadioDevId, 2, 3, 16, "Dev", "d", AppTarget, "app.radio.dev", 1) < 0)
		raise "fail:radio dev";

	if(control->radio(u, RadioGroupId, RadioStageId, 2, 4, 16, "Stage", "g", AppTarget, "app.radio.stage", 0) < 0)
		raise "fail:radio stage";

	if(control->radio(u, RadioGroupId, RadioProdId, 2, 5, 16, "Prod", "p", AppTarget, "app.radio.prod", 0) < 0)
		raise "fail:radio prod";

	if(ui->window(u, WinId, SwitchBoxId, 55, 4, 24, 9, " Switches ") < 0)
		raise "fail:switch box";

	if(ui->label(u, SwitchBoxId, SwitchTitleId, 2, 1, 18, "On/off state") < 0)
		raise "fail:switch title";

	if(control->switchbox(u, SwitchBoxId, SwitchNetworkId, 2, 3, 18, "Network", "n", AppTarget, "app.switch.network", 1) < 0)
		raise "fail:switch network";

	if(control->switchbox(u, SwitchBoxId, SwitchCacheId, 2, 5, 18, "Cache", "c", AppTarget, "app.switch.cache", 0) < 0)
		raise "fail:switch cache";

	if(ui->window(u, WinId, StateBoxId, 3, 14, 76, 4, " Combined state ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, StateLine1Id, 2, 1, 70, "") < 0)
		raise "fail:state line 1";

	if(ui->label(u, StateBoxId, StateLine2Id, 2, 2, 70, "") < 0)
		raise "fail:state line 2";

	if(ui->label(u, StateBoxId, StateLine3Id, 2, 3, 70, "") < 0)
		raise "fail:state line 3";

	if(ui->button(u, WinId, BtnExitId, 3, 18, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, CheckLogId);
	m = control->toggle(u, CheckLogId);
	control->toggle(u, CheckLogId);
	refresh(u, m);
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.cmd == "app.exit")
		return 1;

	refresh(u, m);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	m: IcMsg->Msg;
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
			else{
				m = control->handlekey(u, s.key);
				if(m.kind == IcMsg->KindNone)
					m = s.msg;
				done = handlemsg(u, m);
			}

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