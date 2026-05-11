#
# 14_01_simple_menu.b
#
# Demonstrates a simple menu application template.
#
# The template uses one main window, a vertical group of command buttons,
# one application target, and centralized command handling.
#

implement SimpleMenuTemplate;

include "draw.m";
include "icurses/ui.m";

SimpleMenuTemplate: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

MenuBoxId: con 20;
BtnRunId: con 21;
BtnSettingsId: con 22;
BtnAboutId: con 23;
BtnExitId: con 24;

InfoBoxId: con 30;
InfoTitleId: con 31;
InfoLine1Id: con 32;
InfoLine2Id: con 33;
InfoLine3Id: con 34;

AboutLayerId: con 40;
AboutShadowId: con 41;
AboutWinId: con 42;
AboutText1Id: con 43;
AboutText2Id: con 44;
BtnAboutCloseId: con 45;

runs: int;
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

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic->init();
	ui->init();
	msg->init();
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

sendnode(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, InfoLine1Id, "Runs: " + sys->sprint("%d", runs));
	ui->settext(u, InfoLine2Id, "Last command: " + lastcmd);
	ui->settext(u, InfoLine3Id, "Pattern: buttons -> command -> handler -> redraw");

	ui->setstatus(u, "simple menu: " + lastcmd);
	ui->draw(u);
}

showabout(u: ref IcUi->Ui)
{
	sendnode(u, AboutLayerId, "node.show");
	ui->setfocus(u, BtnAboutCloseId);
	lastcmd = "app.about";
	refresh(u);
}

hideabout(u: ref IcUi->Ui)
{
	sendnode(u, AboutLayerId, "node.hide");
	ui->setfocus(u, BtnAboutId);
	lastcmd = "app.about.close";
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Main menu template | centralized command handling | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 90, 20, " Simple menu template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 64, "A small application can start with a simple command menu.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, MenuBoxId, 3, 4, 24, 12, " Menu ") < 0)
		raise "fail:menu box";

	if(ui->button(u, MenuBoxId, BtnRunId, 4, 2, 14, 1, "Run", "r", AppTarget, "app.run") < 0)
		raise "fail:run";

	if(ui->button(u, MenuBoxId, BtnSettingsId, 4, 4, 14, 1, "Settings", "s", AppTarget, "app.settings") < 0)
		raise "fail:settings";

	if(ui->button(u, MenuBoxId, BtnAboutId, 4, 6, 14, 1, "About", "a", AppTarget, "app.about") < 0)
		raise "fail:about";

	if(ui->button(u, MenuBoxId, BtnExitId, 4, 8, 14, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	if(ui->window(u, WinId, InfoBoxId, 31, 4, 54, 12, " Application state ") < 0)
		raise "fail:info box";

	if(ui->label(u, InfoBoxId, InfoTitleId, 2, 1, 49, "The menu does not own business logic.") < 0)
		raise "fail:info title";

	if(ui->label(u, InfoBoxId, InfoLine1Id, 2, 3, 49, "") < 0)
		raise "fail:info line 1";

	if(ui->label(u, InfoBoxId, InfoLine2Id, 2, 4, 49, "") < 0)
		raise "fail:info line 2";

	if(ui->label(u, InfoBoxId, InfoLine3Id, 2, 6, 49, "") < 0)
		raise "fail:info line 3";

	#
	# The popup layer is created after the menu and info boxes so it is drawn
	# above them. It is shifted slightly to the right to avoid visually merging
	# with the menu panel.
	#
	if(ui->group(u, 0, AboutLayerId, 22, 2, 74, 20) < 0)
		raise "fail:about layer";

	if(ui->shadowwindow(u, AboutLayerId, AboutShadowId, AboutWinId, 22, 7, 36, 8, " About ", 1, 1) < 0)
		raise "fail:about window";

	if(ui->label(u, AboutWinId, AboutText1Id, 3, 2, 28, "Simple menu application.") < 0)
		raise "fail:about text 1";

	if(ui->label(u, AboutWinId, AboutText2Id, 3, 3, 28, "Commands are handled centrally.") < 0)
		raise "fail:about text 2";

	if(ui->button(u, AboutWinId, BtnAboutCloseId, 13, 5, 10, 1, "Close", "", AppTarget, "app.about.close") < 0)
		raise "fail:about close";

	sendnode(u, AboutLayerId, "node.hide");

	runs = 0;
	lastcmd = "none";

	ui->setfocus(u, BtnRunId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.run"){
		runs++;
		lastcmd = "app.run";
		refresh(u);
		return 0;
	}

	if(cmd == "app.settings"){
		lastcmd = "app.settings";
		refresh(u);
		return 0;
	}

	if(cmd == "app.about"){
		showabout(u);
		return 0;
	}

	if(cmd == "app.about.close"){
		hideabout(u);
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