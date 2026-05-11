#
# 14_07_resize_app.b
#
# Demonstrates a resize-aware application template.
#
# Current IcUi examples use fixed trees. This template demonstrates the
# application-side pattern: keep several layout profiles as layers and switch
# between them when the application decides the terminal geometry class changed.
#

implement ResizeTemplate;

include "draw.m";
include "icurses/ui.m";

ResizeTemplate: module
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

RootLayerId: con 10;
WinId: con 11;
TitleId: con 12;

WideLayerId: con 20;
WideBoxId: con 21;
WideLeftId: con 22;
WideRightId: con 23;

NarrowLayerId: con 30;
NarrowBoxId: con 31;
NarrowTopId: con 32;
NarrowBottomId: con 33;

TallLayerId: con 40;
TallBoxId: con 41;
TallOneId: con 42;
TallTwoId: con 43;
TallThreeId: con 44;

InfoBoxId: con 50;
Info1Id: con 51;
Info2Id: con 52;
Info3Id: con 53;
Info4Id: con 54;

BtnWideId: con 60;
BtnNarrowId: con 61;
BtnTallId: con 62;
BtnExitId: con 63;

layoutmode: int;
switches: int;

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

layoutname(): string
{
	if(layoutmode == 0)
		return "wide";
	if(layoutmode == 1)
		return "narrow";
	return "tall";
}

showlayout(u: ref IcUi->Ui)
{
	sendnode(u, WideLayerId, "node.hide");
	sendnode(u, NarrowLayerId, "node.hide");
	sendnode(u, TallLayerId, "node.hide");

	if(layoutmode == 0)
		sendnode(u, WideLayerId, "node.show");
	else if(layoutmode == 1)
		sendnode(u, NarrowLayerId, "node.show");
	else
		sendnode(u, TallLayerId, "node.show");
}

refresh(u: ref IcUi->Ui)
{
	showlayout(u);

	ui->settext(u, Info1Id, "Active layout profile: " + layoutname());
	ui->settext(u, Info2Id, "Switches: " + sys->sprint("%d", switches));
	ui->settext(u, Info3Id, "Pattern: detect geometry,");
	ui->settext(u, Info4Id, "then rebuild or switch layout.");

	ui->setstatus(u, "resize template: " + layoutname());
	ui->draw(u);
}

setlayout(u: ref IcUi->Ui, mode: int)
{
	layoutmode = mode;
	switches++;
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 100);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Resize-aware pattern | switch layout profiles | q/Esc exits ");

	if(ui->group(u, root, RootLayerId, 0, 0, sw, sh) < 0)
		raise "fail:root layer";

	if(ui->window(u, RootLayerId, WinId, x, y, 98, 22, " Resize-aware application template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "A resize-aware app separates application state from layout profile.") < 0)
		raise "fail:title";

	if(ui->group(u, WinId, WideLayerId, 3, 4, 54, 10) < 0)
		raise "fail:wide layer";

	if(ui->window(u, WideLayerId, WideBoxId, 0, 0, 54, 10, " Wide layout ") < 0)
		raise "fail:wide box";

	if(ui->label(u, WideBoxId, WideLeftId, 2, 2, 22, "Left panel: navigation") < 0)
		raise "fail:wide left";

	if(ui->label(u, WideBoxId, WideRightId, 27, 2, 22, "Right panel: details") < 0)
		raise "fail:wide right";

	if(ui->group(u, WinId, NarrowLayerId, 3, 4, 54, 10) < 0)
		raise "fail:narrow layer";

	if(ui->window(u, NarrowLayerId, NarrowBoxId, 0, 0, 30, 10, " Narrow layout ") < 0)
		raise "fail:narrow box";

	if(ui->label(u, NarrowBoxId, NarrowTopId, 2, 2, 24, "Top: commands") < 0)
		raise "fail:narrow top";

	if(ui->label(u, NarrowBoxId, NarrowBottomId, 2, 5, 24, "Bottom: details") < 0)
		raise "fail:narrow bottom";

	if(ui->group(u, WinId, TallLayerId, 3, 4, 54, 10) < 0)
		raise "fail:tall layer";

	if(ui->window(u, TallLayerId, TallBoxId, 0, 0, 24, 10, " Tall layout ") < 0)
		raise "fail:tall box";

	if(ui->label(u, TallBoxId, TallOneId, 2, 2, 18, "1. header") < 0)
		raise "fail:tall one";

	if(ui->label(u, TallBoxId, TallTwoId, 2, 4, 18, "2. content") < 0)
		raise "fail:tall two";

	if(ui->label(u, TallBoxId, TallThreeId, 2, 6, 18, "3. actions") < 0)
		raise "fail:tall three";

	if(ui->window(u, WinId, InfoBoxId, 60, 4, 34, 10, " State ") < 0)
		raise "fail:info box";

	if(ui->label(u, InfoBoxId, Info1Id, 2, 2, 17, "") < 0)
		raise "fail:info 1";

	if(ui->label(u, InfoBoxId, Info2Id, 2, 4, 17, "") < 0)
		raise "fail:info 2";

	if(ui->label(u, InfoBoxId, Info3Id, 2, 6, 30, "") < 0)
		raise "fail:info 3";

	if(ui->label(u, InfoBoxId, Info4Id, 2, 7, 30, "") < 0)
		raise "fail:info 4";

	if(ui->button(u, WinId, BtnWideId, 3, 19, 10, 1, "Wide", "w", AppTarget, "app.wide") < 0)
		raise "fail:wide";

	if(ui->button(u, WinId, BtnNarrowId, 15, 19, 12, 1, "Narrow", "n", AppTarget, "app.narrow") < 0)
		raise "fail:narrow";

	if(ui->button(u, WinId, BtnTallId, 29, 19, 10, 1, "Tall", "t", AppTarget, "app.tall") < 0)
		raise "fail:tall";

	if(ui->button(u, WinId, BtnExitId, 41, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	layoutmode = 0;
	switches = 0;

	ui->setfocus(u, BtnWideId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.wide"){
		setlayout(u, 0);
		return 0;
	}

	if(cmd == "app.narrow"){
		setlayout(u, 1);
		return 0;
	}

	if(cmd == "app.tall"){
		setlayout(u, 2);
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