#
# 04_01_simple_ui_modules.b
#
# Safe module connection scheme for a regular IcUi application.
#
# This example intentionally includes only:
#   - draw.m
#   - icurses/ui.m
#
# It does not include icurses/icurses.m or icurses/msg.m directly because
# IcUi's include chain already makes the required Icurses and IcMsg names
# visible to this program.
#
# Runtime modules are still loaded explicitly if their functions are called
# directly by this application.
#

implement SimpleUiModulesDemo;

include "draw.m";
include "icurses/ui.m";

SimpleUiModulesDemo: module
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
IncludeId: con 13;
LoadId: con 14;
InitId: con 15;
RuleId: con 16;

DetailsGroupId: con 20;
DetailsLine1Id: con 21;
DetailsLine2Id: con 22;

BtnToggleId: con 30;
BtnExitId: con 31;

detailsvisible: int;

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
	if(detailsvisible)
		ui->setstatus(u, "details group is visible");
	else
		ui->setstatus(u, "details group is hidden");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 78;
	h = 16;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " t toggles details | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Simple UI module scheme ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "A regular UI app includes icurses/ui.m and loads used runtime modules.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, IncludeId, 3, 4, 70, "include: draw.m + icurses/ui.m") < 0)
		raise "fail:include label";

	if(ui->label(u, WinId, LoadId, 3, 5, 70, "load: Sys, Icurses, IcUi, IcMsg") < 0)
		raise "fail:load label";

	if(ui->label(u, WinId, InitId, 3, 6, 70, "init: ic->init(), ui->init(), msg->init()") < 0)
		raise "fail:init label";

	if(ui->label(u, WinId, RuleId, 3, 8, 70, "Rule: load and init modules whose functions are called directly.") < 0)
		raise "fail:rule label";

	if(ui->group(u, WinId, DetailsGroupId, 3, 10, 70, 3) < 0)
		raise "fail:details group";

	if(ui->label(u, DetailsGroupId, DetailsLine1Id, 0, 0, 70, "IcMsg is visible through the IcUi include chain.") < 0)
		raise "fail:details line 1";

	if(ui->label(u, DetailsGroupId, DetailsLine2Id, 0, 1, 70, "It is still loaded because this app calls msg->newmsg() directly.") < 0)
		raise "fail:details line 2";

	if(ui->button(u, WinId, BtnToggleId, 3, 13, 12, 1, "Toggle", "t", AppTarget, "app.toggle") < 0)
		raise "fail:toggle button";

	if(ui->button(u, WinId, BtnExitId, 18, 13, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnToggleId);
	detailsvisible = 1;
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.toggle"){
		sendnode(u, DetailsGroupId, "node.toggle");
		detailsvisible = !detailsvisible;
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
	detailsvisible = 1;

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