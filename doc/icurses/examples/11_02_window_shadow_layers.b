#
# 11_02_window_shadow_layers.b
#
# Demonstrates Window and shadowwindow elements.
#
# Windows are containers. shadowwindow() creates a shadow node and a window
# node. The example toggles a detail window and shows the tree nodes involved.
#

implement WindowShadowLayersDemo;

include "draw.m";
include "icurses/ui.m";

WindowShadowLayersDemo: module
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
BackgroundId: con 11;

MainShadowId: con 20;
MainWinId: con 21;
TitleId: con 22;
MainTextId: con 23;

TreeBoxId: con 30;
TreeRootId: con 31;
TreeLayerId: con 32;
TreeMainShadowId: con 33;
TreeMainWinId: con 34;
TreeDetailLayerId: con 35;
TreeDetailShadowId: con 36;
TreeDetailWinId: con 37;

DetailLayerId: con 40;
DetailShadowId: con 41;
DetailWinId: con 42;
DetailText1Id: con 43;
DetailText2Id: con 44;
DetailText3Id: con 45;

BtnDetailsId: con 50;
BtnExitId: con 51;

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

setdetailvisible(u: ref IcUi->Ui, visible: int)
{
	detailsvisible = visible;

	if(visible){
		sendnode(u, DetailLayerId, "node.show");
		sendnode(u, DetailShadowId, "node.show");
		sendnode(u, DetailWinId, "node.show");
		sendnode(u, DetailText1Id, "node.show");
		sendnode(u, DetailText2Id, "node.show");
		sendnode(u, DetailText3Id, "node.show");
	}
	else{
		sendnode(u, DetailText1Id, "node.hide");
		sendnode(u, DetailText2Id, "node.hide");
		sendnode(u, DetailText3Id, "node.hide");
		sendnode(u, DetailWinId, "node.hide");
		sendnode(u, DetailShadowId, "node.hide");
		sendnode(u, DetailLayerId, "node.hide");
	}
}

drawbackground(u: ref IcUi->Ui, w, h: int)
{
	y: int;

	ui->canvasclear(u, BackgroundId, " ", "0");

	for(y = 0; y < h; y++){
		if(y % 2 == 0)
			ui->canvasputs(u, BackgroundId, 2, y, "renderer-owned background canvas under windows", "0");
		else
			ui->canvasputs(u, BackgroundId, 8, y, "shadow and window nodes are drawn above canvas", "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	if(detailsvisible){
		ui->settext(u, TreeDetailLayerId, "    +-- DetailLayerId [visible]");
		ui->settext(u, TreeDetailShadowId, "    |   +-- DetailShadowId");
		ui->settext(u, TreeDetailWinId, "    |   `-- DetailWinId");
		ui->settext(u, BtnDetailsId, "[ Hide Details ]");
		ui->setstatus(u, "detail window visible");
	}
	else{
		ui->settext(u, TreeDetailLayerId, "    +-- DetailLayerId [hidden]");
		ui->settext(u, TreeDetailShadowId, "    |   +-- DetailShadowId [hidden]");
		ui->settext(u, TreeDetailWinId, "    |   `-- DetailWinId [hidden]");
		ui->settext(u, BtnDetailsId, "[ Show Details ]");
		ui->setstatus(u, "detail window hidden");
	}

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Show/Hide details window to see shadow/window nodes | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->canvas(u, LayerId, BackgroundId, 0, 0, sw, sh - 2) < 0)
		raise "fail:background";

	drawbackground(u, sw, sh - 2);

	if(ui->shadowwindow(u, LayerId, MainShadowId, MainWinId, x, y, 78, 22, " Window and shadowwindow ", 1, 1) < 0)
		raise "fail:main shadowwindow";

	if(ui->label(u, MainWinId, TitleId, 3, 2, 68, "Window is a visible frame and a container for child elements.") < 0)
		raise "fail:title";

	if(ui->label(u, MainWinId, MainTextId, 3, 4, 68, "shadowwindow() creates both shadow and window nodes.") < 0)
		raise "fail:main text";

	if(ui->window(u, MainWinId, TreeBoxId, 3, 6, 42, 12, " Tree nodes ") < 0)
		raise "fail:tree box";

	if(ui->label(u, TreeBoxId, TreeRootId, 2, 1, 32, "root") < 0)
		raise "fail:tree root";

	if(ui->label(u, TreeBoxId, TreeLayerId, 2, 2, 32, "+-- LayerId") < 0)
		raise "fail:tree layer";

	if(ui->label(u, TreeBoxId, TreeMainShadowId, 4, 3, 32, "+-- MainShadowId") < 0)
		raise "fail:tree main shadow";

	if(ui->label(u, TreeBoxId, TreeMainWinId, 4, 4, 32, "+-- MainWinId") < 0)
		raise "fail:tree main window";

	if(ui->label(u, TreeBoxId, TreeDetailLayerId, 4, 6, 32, "") < 0)
		raise "fail:tree detail layer";

	if(ui->label(u, TreeBoxId, TreeDetailShadowId, 4, 7, 36, "") < 0)
		raise "fail:tree detail shadow";

	if(ui->label(u, TreeBoxId, TreeDetailWinId, 4, 8, 32, "") < 0)
		raise "fail:tree detail win";

	if(ui->group(u, MainWinId, DetailLayerId, 45, 7, 30, 10) < 0)
		raise "fail:detail layer";

	if(ui->shadowwindow(u, DetailLayerId, DetailShadowId, DetailWinId, 1, 1, 28, 7, " Details ", 1, 1) < 0)
		raise "fail:detail shadowwindow";

	if(ui->label(u, DetailWinId, DetailText1Id, 3, 2, 20, "This is a window.") < 0)
		raise "fail:detail text 1";

	if(ui->label(u, DetailWinId, DetailText2Id, 3, 3, 20, "It has a shadow.") < 0)
		raise "fail:detail text 2";

	if(ui->label(u, DetailWinId, DetailText3Id, 3, 4, 20, "Layer toggles both.") < 0)
		raise "fail:detail text 3";

	if(ui->button(u, MainWinId, BtnDetailsId, 3, 19, 18, 1, "Hide Details", "s", AppTarget, "app.details") < 0)
		raise "fail:details button";

	if(ui->button(u, MainWinId, BtnExitId, 23, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	detailsvisible = 1;

	ui->setfocus(u, BtnDetailsId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.details"){
		if(detailsvisible)
			setdetailvisible(u, 0);
		else
			setdetailvisible(u, 1);

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