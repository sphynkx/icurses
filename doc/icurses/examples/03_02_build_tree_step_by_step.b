#
# 03_02_build_tree_step_by_step.b
#
# Builds a small UI tree and shows the structure on screen.
#
# This example is useful for understanding:
#   - root container;
#   - application layer;
#   - window;
#   - nested group;
#   - labels and buttons as tree nodes.
#

implement BuildTreeStepByStepDemo;

include "draw.m";
include "icurses/ui.m";

BuildTreeStepByStepDemo: module
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
TreeTitleId: con 12;
RootLineId: con 13;
LayerLineId: con 14;
WindowLineId: con 15;
GroupLineId: con 16;
ButtonLineId: con 17;

ButtonGroupId: con 20;
BtnToggleId: con 21;
BtnExitId: con 22;

ExtraGroupId: con 30;
ExtraLine1Id: con 31;
ExtraLine2Id: con 32;

extra_visible: int;

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

nodemsg(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui)
{
	if(extra_visible)
		ui->setstatus(u, "extra group is visible");
	else
		ui->setstatus(u, "extra group is hidden");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 72;
	h = 17;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " t toggles an additional group | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Building a UI tree ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TreeTitleId, 3, 2, 60, "The screen below mirrors the tree created by build().") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, RootLineId, 3, 4, 60, "root -> LayerId") < 0)
		raise "fail:root line";

	if(ui->label(u, WinId, LayerLineId, 5, 5, 60, "LayerId -> WinId") < 0)
		raise "fail:layer line";

	if(ui->label(u, WinId, WindowLineId, 7, 6, 60, "WinId -> labels, ButtonGroupId, ExtraGroupId") < 0)
		raise "fail:window line";

	if(ui->label(u, WinId, GroupLineId, 9, 7, 60, "ButtonGroupId -> Toggle, Exit") < 0)
		raise "fail:group line";

	if(ui->label(u, WinId, ButtonLineId, 9, 8, 60, "ExtraGroupId -> two informational labels") < 0)
		raise "fail:button line";

	if(ui->group(u, WinId, ButtonGroupId, 3, 11, 28, 1) < 0)
		raise "fail:button group";

	if(ui->button(u, ButtonGroupId, BtnToggleId, 0, 0, 12, 1, "Toggle", "t", AppTarget, "app.toggle") < 0)
		raise "fail:toggle button";

	if(ui->button(u, ButtonGroupId, BtnExitId, 15, 0, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	if(ui->group(u, WinId, ExtraGroupId, 35, 11, 30, 3) < 0)
		raise "fail:extra group";

	if(ui->label(u, ExtraGroupId, ExtraLine1Id, 0, 0, 28, "This is a nested group.") < 0)
		raise "fail:extra line 1";

	if(ui->label(u, ExtraGroupId, ExtraLine2Id, 0, 1, 29, "It can be hidden as one node.") < 0)
		raise "fail:extra line 2";

	ui->setfocus(u, BtnToggleId);
	extra_visible = 1;
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.toggle"){
		nodemsg(u, ExtraGroupId, "node.toggle");
		extra_visible = !extra_visible;
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
	extra_visible = 1;

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