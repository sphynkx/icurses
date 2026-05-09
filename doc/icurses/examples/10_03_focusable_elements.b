#
# 10_03_focusable_elements.b
#
# Demonstrates that not every tree node is focusable.
#
# The tree contains windows, groups, labels, canvas, and buttons. The focus
# chain contains only interactive controls that are currently visible/enabled.
#

implement FocusableElementsDemo;

include "draw.m";
include "icurses/ui.m";

FocusableElementsDemo: module
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
TreeWindowId: con 22;
TreeLabelId: con 23;
TreeCanvasId: con 24;
TreeButtonAId: con 25;
TreeButtonBId: con 26;
TreeButtonCId: con 27;

CanvasId: con 30;

FocusBoxId: con 40;
ChainAId: con 41;
ChainBId: con 42;
ChainCId: con 43;
StateId: con 44;

BtnAId: con 50;
BtnBId: con 51;
BtnCId: con 52;
BtnToggleBId: con 53;
BtnDisableCId: con 54;
BtnExitId: con 55;

focusid: int;
bvisible: int;
cenabled: int;

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

mark(id: int): string
{
	if(focusid == id)
		return ">> ";

	return "   ";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, TreeButtonAId, mark(BtnAId) + "`-- BtnAId      focusable");
	if(bvisible)
		ui->settext(u, TreeButtonBId, mark(BtnBId) + "`-- BtnBId      focusable visible");
	else
		ui->settext(u, TreeButtonBId, "   `-- BtnBId      hidden, skipped");

	if(cenabled)
		ui->settext(u, TreeButtonCId, mark(BtnCId) + "`-- BtnCId      enabled");
	else
		ui->settext(u, TreeButtonCId, "   `-- BtnCId      disabled, skipped");

	ui->settext(u, ChainAId, mark(BtnAId) + "BtnAId");
	if(bvisible)
		ui->settext(u, ChainBId, mark(BtnBId) + "BtnBId");
	else
		ui->settext(u, ChainBId, "   BtnBId hidden");

	if(cenabled)
		ui->settext(u, ChainCId, mark(BtnCId) + "BtnCId");
	else
		ui->settext(u, ChainCId, "   BtnCId disabled");

	ui->settext(u, StateId, "B visible=" + sys->sprint("%d", bvisible) + "  C enabled=" + sys->sprint("%d", cenabled));
	ui->setstatus(u, "focusable elements demo");
	ui->draw(u);
}

setfocusnode(u: ref IcUi->Ui, id: int)
{
	focusid = id;
	ui->setfocus(u, id);
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 21);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Labels/windows/canvas are in tree but focus chain uses controls | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 21, " Focusable elements ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "The tree contains many nodes, but focus navigation uses only focusable controls.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TreeBoxId, 3, 4, 38, 11, " Tree nodes ") < 0)
		raise "fail:tree box";

	if(ui->label(u, TreeBoxId, TreeRootId, 2, 1, 32, "root") < 0)
		raise "fail:tree root";

	if(ui->label(u, TreeBoxId, TreeWindowId, 4, 2, 32, "`-- window/group nodes") < 0)
		raise "fail:tree window";

	if(ui->label(u, TreeBoxId, TreeLabelId, 4, 3, 32, "`-- LabelId      not focusable") < 0)
		raise "fail:tree label";

	if(ui->label(u, TreeBoxId, TreeCanvasId, 4, 4, 32, "`-- CanvasId     not focusable") < 0)
		raise "fail:tree canvas";

	if(ui->label(u, TreeBoxId, TreeButtonAId, 4, 5, 32, "") < 0)
		raise "fail:tree button a";

	if(ui->label(u, TreeBoxId, TreeButtonBId, 4, 6, 32, "") < 0)
		raise "fail:tree button b";

	if(ui->label(u, TreeBoxId, TreeButtonCId, 4, 7, 32, "") < 0)
		raise "fail:tree button c";

	if(ui->canvas(u, WinId, CanvasId, 45, 4, 30, 3) < 0)
		raise "fail:canvas";

	ui->canvasclear(u, CanvasId, ".", "0");
	ui->canvasputs(u, CanvasId, 2, 1, "canvas is visible, not focus target", "0");

	if(ui->window(u, WinId, FocusBoxId, 45, 8, 30, 7, " Focus chain ") < 0)
		raise "fail:focus box";

	if(ui->label(u, FocusBoxId, ChainAId, 2, 1, 24, "") < 0)
		raise "fail:chain a";

	if(ui->label(u, FocusBoxId, ChainBId, 2, 2, 24, "") < 0)
		raise "fail:chain b";

	if(ui->label(u, FocusBoxId, ChainCId, 2, 3, 24, "") < 0)
		raise "fail:chain c";

	if(ui->label(u, FocusBoxId, StateId, 2, 5, 24, "") < 0)
		raise "fail:state";

	if(ui->button(u, WinId, BtnAId, 3, 17, 8, 1, "A", "a", AppTarget, "app.a") < 0)
		raise "fail:a";

	if(ui->button(u, WinId, BtnBId, 13, 17, 8, 1, "B", "b", AppTarget, "app.b") < 0)
		raise "fail:b";

	if(ui->button(u, WinId, BtnCId, 23, 17, 8, 1, "C", "c", AppTarget, "app.c") < 0)
		raise "fail:c";

	if(ui->button(u, WinId, BtnToggleBId, 33, 17, 12, 1, "Toggle B", "t", AppTarget, "app.toggle.b") < 0)
		raise "fail:toggle b";

	if(ui->button(u, WinId, BtnDisableCId, 47, 17, 14, 1, "Disable C", "d", AppTarget, "app.disable.c") < 0)
		raise "fail:disable c";

	if(ui->button(u, WinId, BtnExitId, 63, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	focusid = BtnAId;
	bvisible = 1;
	cenabled = 1;

	ui->setfocus(u, BtnAId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.a"){
		setfocusnode(u, BtnAId);
		return 0;
	}

	if(cmd == "app.b"){
		if(bvisible)
			setfocusnode(u, BtnBId);
		else
			refresh(u);
		return 0;
	}

	if(cmd == "app.c"){
		if(cenabled)
			setfocusnode(u, BtnCId);
		else
			refresh(u);
		return 0;
	}

	if(cmd == "app.toggle.b"){
		sendnode(u, BtnBId, "node.toggle");
		bvisible = !bvisible;
		if(!bvisible && focusid == BtnBId)
			focusid = BtnAId;
		ui->setfocus(u, focusid);
		refresh(u);
		return 0;
	}

	if(cmd == "app.disable.c"){
		if(cenabled){
			sendnode(u, BtnCId, "node.disable");
			cenabled = 0;
			ui->settext(u, BtnDisableCId, "[ Enable C ]");
			if(focusid == BtnCId)
				focusid = BtnAId;
		}
		else{
			sendnode(u, BtnCId, "node.enable");
			cenabled = 1;
			ui->settext(u, BtnDisableCId, "[ Disable C ]");
		}
		ui->setfocus(u, focusid);
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