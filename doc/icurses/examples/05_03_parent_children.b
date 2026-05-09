#
# 05_03_parent_children.b
#
# Demonstrates parent/child structure in an element tree.
#
# A parent group can show or hide a whole branch of children.
#

implement ParentChildrenDemo;

include "draw.m";
include "icurses/ui.m";

ParentChildrenDemo: module
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
TreeLine1Id: con 13;
TreeLine2Id: con 14;
TreeLine3Id: con 15;
StatusId: con 16;

BranchAId: con 20;
BranchATitleId: con 21;
BranchALineId: con 22;

BranchBId: con 30;
BranchBTitleId: con 31;
BranchBLineId: con 32;

BtnToggleAId: con 40;
BtnToggleBId: con 41;
BtnExitId: con 42;

avisible: int;
bvisible: int;

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
	s: string;

	s = "Branch A: ";
	if(avisible)
		s += "visible";
	else
		s += "hidden";

	s += " | Branch B: ";
	if(bvisible)
		s += "visible";
	else
		s += "hidden";

	ui->settext(u, StatusId, s);
	ui->setstatus(u, s);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 18;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Toggle parent groups to affect their child labels | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Parent and children ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 64, "Groups are parent nodes. Labels inside them are child nodes.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, TreeLine1Id, 3, 4, 64, "WinId") < 0)
		raise "fail:tree line 1";

	if(ui->label(u, WinId, TreeLine2Id, 5, 5, 64, "|-- BranchAId -> BranchATitleId, BranchALineId") < 0)
		raise "fail:tree line 2";

	if(ui->label(u, WinId, TreeLine3Id, 5, 6, 64, "`-- BranchBId -> BranchBTitleId, BranchBLineId") < 0)
		raise "fail:tree line 3";

	if(ui->label(u, WinId, StatusId, 3, 8, 64, "") < 0)
		raise "fail:status label";

	if(ui->group(u, WinId, BranchAId, 3, 10, 30, 3) < 0)
		raise "fail:branch a";

	if(ui->label(u, BranchAId, BranchATitleId, 0, 0, 28, "Branch A title") < 0)
		raise "fail:branch a title";

	if(ui->label(u, BranchAId, BranchALineId, 2, 1, 28, "This label is child of A.") < 0)
		raise "fail:branch a line";

	if(ui->group(u, WinId, BranchBId, 38, 10, 30, 3) < 0)
		raise "fail:branch b";

	if(ui->label(u, BranchBId, BranchBTitleId, 0, 0, 28, "Branch B title") < 0)
		raise "fail:branch b title";

	if(ui->label(u, BranchBId, BranchBLineId, 2, 1, 28, "This label is child of B.") < 0)
		raise "fail:branch b line";

	if(ui->button(u, WinId, BtnToggleAId, 3, 15, 14, 1, "Toggle A", "a", AppTarget, "app.toggle.a") < 0)
		raise "fail:toggle a";

	if(ui->button(u, WinId, BtnToggleBId, 20, 15, 14, 1, "Toggle B", "b", AppTarget, "app.toggle.b") < 0)
		raise "fail:toggle b";

	if(ui->button(u, WinId, BtnExitId, 37, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnToggleAId);
	avisible = 1;
	bvisible = 1;
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.toggle.a"){
		sendnode(u, BranchAId, "node.toggle");
		avisible = !avisible;
		refresh(u);
		return 0;
	}

	if(cmd == "app.toggle.b"){
		sendnode(u, BranchBId, "node.toggle");
		bvisible = !bvisible;
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