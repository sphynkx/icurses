#
# 04_03_button_helper_module.b
#
# Module connection scheme for an application that uses an icurses helper
# module directly.
#
# The program includes icurses/button.m because it calls IcButton functions
# directly. IcButton's include chain makes IcUi and IcMsg visible too, but
# runtime modules still have to be loaded when this application calls them.
#

implement ButtonHelperModuleDemo;

include "draw.m";
include "icurses/button.m";

ButtonHelperModuleDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
button: IcButton;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;
SchemeId: con 13;
HelperId: con 14;
CountId: con 15;
LastId: con 16;

BtnSaveId: con 20;
BtnBuildId: con 21;
BtnExitId: con 22;

savecount: int;
buildcount: int;

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

	button = load IcButton IcButton->PATH;
	if(button == nil)
		raise "fail:load icbutton";

	ic->init();
	ui->init();
	button->init();
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

refresh(u: ref IcUi->Ui, last: string)
{
	ui->settext(u, CountId, "Save count: " +
		sys->sprint("%d", savecount) +
		" | Build count: " +
		sys->sprint("%d", buildcount));

	if(last != "")
		ui->settext(u, LastId, "Last helper action: " + last);

	ui->setstatus(u, "IcButton helper module is loaded and initialized directly");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 15;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " s save | b build | Enter activates focused button | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Helper module connection ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 65, "This app calls IcButton directly, so it loads and initializes it.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, SchemeId, 3, 4, 65, "include: draw.m + icurses/button.m") < 0)
		raise "fail:scheme";

	if(ui->label(u, WinId, HelperId, 3, 5, 65, "load/init: Sys, Icurses, IcUi, IcButton") < 0)
		raise "fail:helper";

	if(ui->label(u, WinId, CountId, 3, 7, 65, "") < 0)
		raise "fail:count";

	if(ui->label(u, WinId, LastId, 3, 8, 65, "Last helper action: none") < 0)
		raise "fail:last";

	if(ui->button(u, WinId, BtnSaveId, 3, 11, 10, 1, "Save", "s", AppTarget, "app.save") < 0)
		raise "fail:save button";

	if(ui->button(u, WinId, BtnBuildId, 15, 11, 10, 1, "Build", "b", AppTarget, "app.build") < 0)
		raise "fail:build button";

	if(ui->button(u, WinId, BtnExitId, 27, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnSaveId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.save"){
		savecount++;
		button->press(u, BtnSaveId, 90);
		refresh(u, "button->press(save)");
		return 0;
	}

	if(cmd == "app.build"){
		buildcount++;
		button->press(u, BtnBuildId, 90);
		refresh(u, "button->press(build)");
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
	savecount = 0;
	buildcount = 0;

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