#
# 07_04_tree_layering.b
#
# Demonstrates tree drawing order and layering.
#
# The left side shows a visual tree. The right side shows overlapping cards.
# Buttons toggle the middle and top layers independently, so the visible stage
# clearly shows how later tree nodes are drawn above earlier ones.
#

implement TreeLayeringDemo;

include "draw.m";
include "icurses/ui.m";

TreeLayeringDemo: module
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

TreeBoxId: con 20;
TreeRootId: con 21;
TreeBackId: con 22;
TreeMainId: con 23;
TreeTopId: con 24;
TreeNote1Id: con 25;
TreeNote2Id: con 26;

StageId: con 30;
BackCardId: con 31;
BackTextId: con 32;
MainCardId: con 33;
MainTextId: con 34;
TopCardId: con 35;
TopTextId: con 36;

BtnMainId: con 40;
BtnTopId: con 41;
BtnExitId: con 42;

mainvisible: int;
topvisible: int;

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
	if(mainvisible){
		ui->settext(u, TreeMainId, "`-- MainCardId  next   [visible]");
		ui->settext(u, BtnMainId, "[ Hide Main ]");
	}
	else{
		ui->settext(u, TreeMainId, "`-- MainCardId  next   [hidden]");
		ui->settext(u, BtnMainId, "[ Show Main ]");
	}

	if(topvisible){
		ui->settext(u, TreeTopId, "`-- TopCardId   last   [visible]");
		ui->settext(u, BtnTopId, "[ Hide Top ]");
	}
	else{
		ui->settext(u, TreeTopId, "`-- TopCardId   last   [hidden]");
		ui->settext(u, BtnTopId, "[ Show Top ]");
	}

	if(mainvisible && topvisible){
		ui->settext(u, TreeNote1Id, "All layers visible:");
		ui->settext(u, TreeNote2Id, "Back < Main < Top");
		ui->setstatus(u, "all layers visible");
	}
	else if(mainvisible && !topvisible){
		ui->settext(u, TreeNote1Id, "Top hidden:");
		ui->settext(u, TreeNote2Id, "Back < Main");
		ui->setstatus(u, "top hidden, main visible");
	}
	else if(!mainvisible && topvisible){
		ui->settext(u, TreeNote1Id, "Main hidden:");
		ui->settext(u, TreeNote2Id, "Back < Top");
		ui->setstatus(u, "main hidden, top visible");
	}
	else{
		ui->settext(u, TreeNote1Id, "Main and Top hidden:");
		ui->settext(u, TreeNote2Id, "Only Back remains");
		ui->setstatus(u, "only back layer visible");
	}

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Toggle Main and Top independently to see tree layering | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Tree layering ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "Drawing follows tree order: later nodes are drawn above earlier nodes.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TreeBoxId, 3, 4, 34, 11, " Tree order ") < 0)
		raise "fail:tree box";

	if(ui->label(u, TreeBoxId, TreeRootId, 2, 1, 28, "root") < 0)
		raise "fail:tree root";

	if(ui->label(u, TreeBoxId, TreeBackId, 4, 2, 28, "`-- BackCardId  first  [visible]") < 0)
		raise "fail:tree back";

	if(ui->label(u, TreeBoxId, TreeMainId, 4, 3, 28, "") < 0)
		raise "fail:tree main";

	if(ui->label(u, TreeBoxId, TreeTopId, 4, 4, 28, "") < 0)
		raise "fail:tree top";

	if(ui->label(u, TreeBoxId, TreeNote1Id, 2, 7, 28, "") < 0)
		raise "fail:tree note 1";

	if(ui->label(u, TreeBoxId, TreeNote2Id, 2, 8, 28, "") < 0)
		raise "fail:tree note 2";

	if(ui->window(u, WinId, StageId, 40, 4, 36, 11, " Visual stage ") < 0)
		raise "fail:stage";

	if(ui->window(u, StageId, BackCardId, 2, 1, 24, 6, " Back ") < 0)
		raise "fail:back card";

	if(ui->label(u, BackCardId, BackTextId, 2, 2, 18, "Lowest layer") < 0)
		raise "fail:back text";

	if(ui->window(u, StageId, MainCardId, 6, 3, 24, 6, " Main ") < 0)
		raise "fail:main card";

	if(ui->label(u, MainCardId, MainTextId, 2, 2, 18, "Middle layer") < 0)
		raise "fail:main text";

	if(ui->window(u, StageId, TopCardId, 10, 5, 22, 5, " Top ") < 0)
		raise "fail:top card";

	if(ui->label(u, TopCardId, TopTextId, 2, 2, 16, "Highest layer") < 0)
		raise "fail:top text";

	if(ui->button(u, WinId, BtnMainId, 3, 17, 17, 1, "Hide Main", "m", AppTarget, "app.main") < 0)
		raise "fail:main button";

	if(ui->button(u, WinId, BtnTopId, 22, 17, 16, 1, "Hide Top", "t", AppTarget, "app.top") < 0)
		raise "fail:top button";

	if(ui->button(u, WinId, BtnExitId, 40, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	mainvisible = 1;
	topvisible = 1;

	ui->setfocus(u, BtnMainId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.main"){
		sendnode(u, MainCardId, "node.toggle");
		mainvisible = !mainvisible;
		refresh(u);
		return 0;
	}

	if(cmd == "app.top"){
		sendnode(u, TopCardId, "node.toggle");
		topvisible = !topvisible;
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