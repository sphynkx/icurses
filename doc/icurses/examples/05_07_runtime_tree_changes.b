#
# 05_07_runtime_tree_changes.b
#
# Demonstrates runtime tree changes.
#
# The example does not rebuild the whole UI. It changes the existing tree:
#   - switches visible cards;
#   - moves the active card;
#   - updates label text;
#   - redraws after each mutation.
#

implement RuntimeTreeChangesDemo;

include "draw.m";
include "icurses/ui.m";

RuntimeTreeChangesDemo: module
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
StateId: con 13;

CardAId: con 20;
CardATitleId: con 21;
CardATextId: con 22;

CardBId: con 30;
CardBTitleId: con 31;
CardBTextId: con 32;

CardCId: con 40;
CardCTitleId: con 41;
CardCTextId: con 42;

BtnNextId: con 50;
BtnMoveId: con 51;
BtnUpdateId: con 52;
BtnResetId: con 53;
BtnExitId: con 54;

active: int;
moves: int;
updates: int;

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

cardid(i: int): int
{
	if(i == 0)
		return CardAId;
	if(i == 1)
		return CardBId;
	return CardCId;
}

cardtextid(i: int): int
{
	if(i == 0)
		return CardATextId;
	if(i == 1)
		return CardBTextId;
	return CardCTextId;
}

cardname(i: int): string
{
	if(i == 0)
		return "Card A";
	if(i == 1)
		return "Card B";
	return "Card C";
}

sendnode(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

movenode(u: ref IcUi->Ui, id, dx, dy: int)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, "node.move");
	m.iarg0 = dx;
	m.iarg1 = dy;
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, StateId, "Active: " +
		cardname(active) +
		" | moves=" +
		sys->sprint("%d", moves) +
		" updates=" +
		sys->sprint("%d", updates));

	ui->setstatus(u, "runtime tree mutation: " + cardname(active));
	ui->draw(u);
}

showactive(u: ref IcUi->Ui, next: int)
{
	sendnode(u, cardid(active), "node.hide");
	active = next;
	sendnode(u, cardid(active), "node.show");
	refresh(u);
}

buildcard(u: ref IcUi->Ui, parent, id, titleid, textid: int, title, text: string)
{
	if(ui->group(u, parent, id, 6, 7, 54, 4) < 0)
		raise "fail:card group";

	if(ui->label(u, id, titleid, 0, 0, 50, title) < 0)
		raise "fail:card title";

	if(ui->label(u, id, textid, 2, 2, 50, text) < 0)
		raise "fail:card text";
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
	ui->sethelp(u, " Next switches visible card | Move changes active card x/y | Update changes text ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Runtime tree changes ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 64, "The existing tree is mutated and redrawn without full rebuild.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, StateId, 3, 4, 64, "") < 0)
		raise "fail:state";

	buildcard(u, WinId, CardAId, CardATitleId, CardATextId, "Card A", "This is the initially visible card.");
	buildcard(u, WinId, CardBId, CardBTitleId, CardBTextId, "Card B", "This card is created at startup but hidden.");
	buildcard(u, WinId, CardCId, CardCTitleId, CardCTextId, "Card C", "Runtime commands can show, move, and edit it.");

	sendnode(u, CardBId, "node.hide");
	sendnode(u, CardCId, "node.hide");

	if(ui->button(u, WinId, BtnNextId, 3, 14, 10, 1, "Next", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnMoveId, 15, 14, 10, 1, "Move", "m", AppTarget, "app.move") < 0)
		raise "fail:move";

	if(ui->button(u, WinId, BtnUpdateId, 27, 14, 12, 1, "Update", "u", AppTarget, "app.update") < 0)
		raise "fail:update";

	if(ui->button(u, WinId, BtnResetId, 41, 14, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 53, 14, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	active = 0;
	moves = 0;
	updates = 0;

	ui->setfocus(u, BtnNextId);
	refresh(u);
}

resetcards(u: ref IcUi->Ui)
{
	sendnode(u, CardAId, "node.show");
	sendnode(u, CardBId, "node.hide");
	sendnode(u, CardCId, "node.hide");

	ui->settext(u, CardATextId, "This is the initially visible card.");
	ui->settext(u, CardBTextId, "This card is created at startup but hidden.");
	ui->settext(u, CardCTextId, "Runtime commands can show, move, and edit it.");

	active = 0;
	moves = 0;
	updates = 0;

	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	next: int;

	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.next"){
		next = (active + 1) % 3;
		showactive(u, next);
		return 0;
	}

	if(cmd == "app.move"){
		moves++;
		movenode(u, cardid(active), 1, 0);
		refresh(u);
		return 0;
	}

	if(cmd == "app.update"){
		updates++;
		ui->settext(u, cardtextid(active), cardname(active) +
			" updated at runtime, update #" +
			sys->sprint("%d", updates));
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetcards(u);
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
