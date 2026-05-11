#
# 05_02_stable_ids.b
#
# Demonstrates stable integer ids as addresses of tree elements.
#
# The example shows three framed node cards. Buttons update specific cards by
# their fixed numeric ids, so the visual effect is immediate and explicit.
#

implement StableIdsDemo;

include "draw.m";
include "icurses/ui.m";

StableIdsDemo: module
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
TitleId: con 12;
RouteId: con 13;
StatusId: con 14;

CardAId: con 100;
CardATitleId: con 101;
CardATextId: con 102;
CardACountId: con 103;

CardBId: con 200;
CardBTitleId: con 201;
CardBTextId: con 202;
CardBCountId: con 203;

CardCId: con 300;
CardCTitleId: con 301;
CardCTextId: con 302;
CardCCountId: con 303;

BtnUpdateAId: con 20;
BtnUpdateBId: con 21;
BtnUpdateCId: con 22;
BtnResetId: con 23;
BtnExitId: con 24;

counta: int;
countb: int;
countc: int;
lastid: int;

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

lastidtext(): string
{
	if(lastid < 0)
		return "Last updated id: none";

	return "Last updated id: " + sys->sprint("%d", lastid);
}

refreshstatus(u: ref IcUi->Ui)
{
	ui->settext(u, StatusId, lastidtext());
	ui->setstatus(u, lastidtext());
	ui->draw(u);
}

refreshcarda(u: ref IcUi->Ui)
{
	ui->settext(u, CardATextId, "Target label id: " + sys->sprint("%d", CardATextId));
	ui->settext(u, CardACountId, "Updates: " + sys->sprint("%d", counta));
}

refreshcardb(u: ref IcUi->Ui)
{
	ui->settext(u, CardBTextId, "Target label id: " + sys->sprint("%d", CardBTextId));
	ui->settext(u, CardBCountId, "Updates: " + sys->sprint("%d", countb));
}

refreshcardc(u: ref IcUi->Ui)
{
	ui->settext(u, CardCTextId, "Target label id: " + sys->sprint("%d", CardCTextId));
	ui->settext(u, CardCCountId, "Updates: " + sys->sprint("%d", countc));
}

refreshall(u: ref IcUi->Ui)
{
	refreshcarda(u);
	refreshcardb(u);
	refreshcardc(u);
	refreshstatus(u);
}

buildcard(u: ref IcUi->Ui, parent, id, titleid, textid, countid: int,
	x, y: int, title: string)
{
	if(ui->window(u, parent, id, x, y, 22, 6, title) < 0)
		raise "fail:card window";

	if(ui->label(u, id, titleid, 2, 1, 16, "Node id: " + sys->sprint("%d", id)) < 0)
		raise "fail:card title";

	if(ui->label(u, id, textid, 2, 2, 18, "") < 0)
		raise "fail:card text";

	if(ui->label(u, id, countid, 2, 3, 18, "") < 0)
		raise "fail:card count";
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 82;
	h = 20;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Update buttons address visible node cards by stable numeric ids | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Stable ids ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 78, "Each visible card has stable integer ids. Buttons update target labels by id.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, RouteId, 3, 4, 68, "Example: Update A -> CardATextId=102 and CardACountId=103") < 0)
		raise "fail:route";

	buildcard(u, WinId, CardAId, CardATitleId, CardATextId, CardACountId, 3, 6, " Card A ");
	buildcard(u, WinId, CardBId, CardBTitleId, CardBTextId, CardBCountId, 28, 6, " Card B ");
	buildcard(u, WinId, CardCId, CardCTitleId, CardCTextId, CardCCountId, 53, 6, " Card C ");

	if(ui->label(u, WinId, StatusId, 3, 14, 68, "") < 0)
		raise "fail:status";

	if(ui->button(u, WinId, BtnUpdateAId, 4, 17, 13, 1, "Update A", "a", AppTarget, "app.update.a") < 0)
		raise "fail:update a";

	if(ui->button(u, WinId, BtnUpdateBId, 20, 17, 13, 1, "Update B", "b", AppTarget, "app.update.b") < 0)
		raise "fail:update b";

	if(ui->button(u, WinId, BtnUpdateCId, 36, 17, 13, 1, "Update C", "c", AppTarget, "app.update.c") < 0)
		raise "fail:update c";

	if(ui->button(u, WinId, BtnResetId, 52, 17, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 65, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnUpdateAId);
	refreshall(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.update.a"){
		counta++;
		lastid = CardATextId;
		ui->settext(u, CardATextId, "A changed by id " + sys->sprint("%d", CardATextId));
		ui->settext(u, CardACountId, "Updates: " + sys->sprint("%d", counta));
		refreshstatus(u);
		return 0;
	}

	if(cmd == "app.update.b"){
		countb++;
		lastid = CardBTextId;
		ui->settext(u, CardBTextId, "B changed by id " + sys->sprint("%d", CardBTextId));
		ui->settext(u, CardBCountId, "Updates: " + sys->sprint("%d", countb));
		refreshstatus(u);
		return 0;
	}

	if(cmd == "app.update.c"){
		countc++;
		lastid = CardCTextId;
		ui->settext(u, CardCTextId, "C changed by id " + sys->sprint("%d", CardCTextId));
		ui->settext(u, CardCCountId, "Updates: " + sys->sprint("%d", countc));
		refreshstatus(u);
		return 0;
	}

	if(cmd == "app.reset"){
		counta = 0;
		countb = 0;
		countc = 0;
		lastid = -1;
		refreshall(u);
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
	counta = 0;
	countb = 0;
	countc = 0;
	lastid = -1;

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