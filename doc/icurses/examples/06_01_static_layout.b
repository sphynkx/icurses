#
# 06_01_static_layout.b
#
# Demonstrates static layout with fixed local coordinates.
#
# The cards are always created at the same x/y positions inside the window.
# Buttons select cards and show that only card content changes, not layout.
#

implement StaticLayoutDemo;

include "draw.m";
include "icurses/ui.m";

StaticLayoutDemo: module
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
MapId: con 13;
StatusId: con 14;

CardAId: con 20;
CardATitleId: con 21;
CardATextId: con 22;

CardBId: con 30;
CardBTitleId: con 31;
CardBTextId: con 32;

CardCId: con 40;
CardCTitleId: con 41;
CardCTextId: con 42;

BtnAId: con 50;
BtnBId: con 51;
BtnCId: con 52;
BtnExitId: con 53;

selected: int;

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

cardprefix(which: int): string
{
	if(selected == which)
		return ">> ";

	return "   ";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, CardATitleId, cardprefix(0) + "Card A at x=3 y=6");
	ui->settext(u, CardBTitleId, cardprefix(1) + "Card B at x=28 y=6");
	ui->settext(u, CardCTitleId, cardprefix(2) + "Card C at x=53 y=6");

	ui->settext(u, StatusId, "Selected fixed slot: " + sys->sprint("%d", selected + 1));
	ui->setstatus(u, "static layout: coordinates do not move");
	ui->draw(u);
}

buildcard(u: ref IcUi->Ui, parent, id, titleid, textid, x, y: int, text: string)
{
	if(ui->window(u, parent, id, x, y, 22, 6, " Fixed slot ") < 0)
		raise "fail:card";

	if(ui->label(u, id, titleid, 2, 1, 18, "") < 0)
		raise "fail:title";

	if(ui->label(u, id, textid, 2, 3, 18, text) < 0)
		raise "fail:text";
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " A/B/C selects fixed cards; coordinates never change | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Static layout ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "Static layout uses explicit local coordinates inside a known container.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, MapId, 3, 4, 72, 11, " Fixed coordinate map ") < 0)
		raise "fail:map";

	buildcard(u, MapId, CardAId, CardATitleId, CardATextId, 3, 1, "local slot 1");
	buildcard(u, MapId, CardBId, CardBTitleId, CardBTextId, 28, 1, "local slot 2");
	buildcard(u, MapId, CardCId, CardCTitleId, CardCTextId, 53, 1, "local slot 3");

	if(ui->label(u, WinId, StatusId, 3, 15, 72, "") < 0)
		raise "fail:status";

	if(ui->button(u, WinId, BtnAId, 3, 17, 8, 1, "A", "a", AppTarget, "app.a") < 0)
		raise "fail:a";

	if(ui->button(u, WinId, BtnBId, 13, 17, 8, 1, "B", "b", AppTarget, "app.b") < 0)
		raise "fail:b";

	if(ui->button(u, WinId, BtnCId, 23, 17, 8, 1, "C", "c", AppTarget, "app.c") < 0)
		raise "fail:c";

	if(ui->button(u, WinId, BtnExitId, 33, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	selected = 0;
	ui->setfocus(u, BtnAId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.a"){
		selected = 0;
		refresh(u);
		return 0;
	}

	if(cmd == "app.b"){
		selected = 1;
		refresh(u);
		return 0;
	}

	if(cmd == "app.c"){
		selected = 2;
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