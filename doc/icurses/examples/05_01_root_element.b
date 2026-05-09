#
# 05_01_root_element.b
#
# Demonstrates the root element as the top-level container of an IcUi tree.
#
# The example draws a visual tree and opens an inspector popup for root,
# application layer, and main window nodes.
#

implement RootElementDemo;

include "draw.m";
include "icurses/ui.m";

RootElementDemo: module
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
TreeBoxId: con 13;
MarkerRootId: con 14;
MarkerLayerId: con 15;
MarkerWindowId: con 16;
LineRootId: con 17;
LineLayerId: con 18;
LineWindowId: con 19;
LineControlsId: con 20;
SelectionId: con 21;

BtnRootId: con 30;
BtnLayerId: con 31;
BtnWindowId: con 32;
BtnExitId: con 33;

InspectLayerId: con 40;
InspectShadowId: con 41;
InspectWinId: con 42;
InspectTitleId: con 43;
InspectIdId: con 44;
InspectParentId: con 45;
InspectRoleId: con 46;
BtnInspectCloseId: con 47;

SelRoot: con 0;
SelLayer: con 1;
SelWindow: con 2;

rootidvalue: int;
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

mark(which: int): string
{
	if(selected == which)
		return ">>";

	return "  ";
}

nodename(): string
{
	if(selected == SelRoot)
		return "root";
	if(selected == SelLayer)
		return "LayerId";
	return "WinId";
}

nodeid(): int
{
	if(selected == SelRoot)
		return rootidvalue;
	if(selected == SelLayer)
		return LayerId;
	return WinId;
}

parentname(): string
{
	if(selected == SelRoot)
		return "none";
	if(selected == SelLayer)
		return "root";
	return "LayerId";
}

noderole(): string
{
	if(selected == SelRoot)
		return "Implicit root container created by ui->new().";
	if(selected == SelLayer)
		return "Top-level application group under root.";
	return "Main window node inside LayerId.";
}

refreshmarkers(u: ref IcUi->Ui)
{
	ui->settext(u, MarkerRootId, mark(SelRoot));
	ui->settext(u, MarkerLayerId, mark(SelLayer));
	ui->settext(u, MarkerWindowId, mark(SelWindow));

	ui->settext(u, SelectionId, "Selected node: " + nodename() +
		" id=" + sys->sprint("%d", nodeid()));

	ui->setstatus(u, "selected " + nodename());
	ui->draw(u);
}

refreshinspector(u: ref IcUi->Ui)
{
	ui->settext(u, InspectTitleId, "Inspector: " + nodename());
	ui->settext(u, InspectIdId, "id: " + sys->sprint("%d", nodeid()));
	ui->settext(u, InspectParentId, "parent: " + parentname());
	ui->settext(u, InspectRoleId, noderole());
	ui->draw(u);
}

showinspector(u: ref IcUi->Ui)
{
	sendnode(u, InspectLayerId, "node.show");
	ui->setfocus(u, BtnInspectCloseId);
	refreshinspector(u);
}

hideinspector(u: ref IcUi->Ui)
{
	sendnode(u, InspectLayerId, "node.hide");

	if(selected == SelRoot)
		ui->setfocus(u, BtnRootId);
	else if(selected == SelLayer)
		ui->setfocus(u, BtnLayerId);
	else
		ui->setfocus(u, BtnWindowId);

	refreshmarkers(u);
}

selectnode(u: ref IcUi->Ui, which: int)
{
	selected = which;
	refreshmarkers(u);
	showinspector(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, ix, iy: int;

	root = ui->rootid(u);
	rootidvalue = root;

	x = center(sw, 76);
	y = center(sh, 18);
	ix = center(sw, 54);
	iy = center(sh, 10);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Select root/layer/window to inspect tree nodes | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 76, 18, " Root element and tree ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 66, "The root node is implicit. Application nodes are children under it.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TreeBoxId, 3, 4, 66, 8, " Visual tree ") < 0)
		raise "fail:tree box";

	if(ui->label(u, TreeBoxId, MarkerRootId, 2, 1, 2, "") < 0)
		raise "fail:marker root";

	if(ui->label(u, TreeBoxId, MarkerLayerId, 2, 2, 2, "") < 0)
		raise "fail:marker layer";

	if(ui->label(u, TreeBoxId, MarkerWindowId, 2, 3, 2, "") < 0)
		raise "fail:marker window";

	if(ui->label(u, TreeBoxId, LineRootId, 5, 1, 55, "root  -- automatic container from ui->new()") < 0)
		raise "fail:root line";

	if(ui->label(u, TreeBoxId, LineLayerId, 5, 2, 55, "`-- LayerId  -- application layer group") < 0)
		raise "fail:layer line";

	if(ui->label(u, TreeBoxId, LineWindowId, 9, 3, 51, "`-- WinId  -- main window node") < 0)
		raise "fail:window line";

	if(ui->label(u, TreeBoxId, LineControlsId, 13, 4, 47, "`-- labels, buttons, inspector overlay") < 0)
		raise "fail:controls line";

	if(ui->label(u, WinId, SelectionId, 3, 13, 66, "") < 0)
		raise "fail:selection";

	if(ui->button(u, WinId, BtnRootId, 3, 15, 10, 1, "Root", "", AppTarget, "app.root") < 0)
		raise "fail:root button";

	if(ui->button(u, WinId, BtnLayerId, 15, 15, 10, 1, "Layer", "", AppTarget, "app.layer") < 0)
		raise "fail:layer button";

	if(ui->button(u, WinId, BtnWindowId, 27, 15, 12, 1, "Window", "", AppTarget, "app.window") < 0)
		raise "fail:window button";

	if(ui->button(u, WinId, BtnExitId, 41, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	if(ui->group(u, LayerId, InspectLayerId, 0, 0, sw, sh) < 0)
		raise "fail:inspect layer";

	if(ui->shadowwindow(u, InspectLayerId, InspectShadowId, InspectWinId, ix, iy, 54, 10, " Node inspector ", 1, 1) < 0)
		raise "fail:inspect shadowwindow";

	if(ui->label(u, InspectWinId, InspectTitleId, 3, 2, 44, "") < 0)
		raise "fail:inspect title";

	if(ui->label(u, InspectWinId, InspectIdId, 3, 4, 44, "") < 0)
		raise "fail:inspect id";

	if(ui->label(u, InspectWinId, InspectParentId, 3, 5, 44, "") < 0)
		raise "fail:inspect parent";

	if(ui->label(u, InspectWinId, InspectRoleId, 3, 6, 46, "") < 0)
		raise "fail:inspect role";

	if(ui->button(u, InspectWinId, BtnInspectCloseId, 21, 8, 10, 1, "Close", "", AppTarget, "app.inspect.close") < 0)
		raise "fail:inspect close";

	sendnode(u, InspectLayerId, "node.hide");

	selected = SelRoot;
	ui->setfocus(u, BtnRootId);
	refreshmarkers(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.root"){
		selectnode(u, SelRoot);
		return 0;
	}

	if(cmd == "app.layer"){
		selectnode(u, SelLayer);
		return 0;
	}

	if(cmd == "app.window"){
		selectnode(u, SelWindow);
		return 0;
	}

	if(cmd == "app.inspect.close"){
		hideinspector(u);
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