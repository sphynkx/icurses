#
# 05_05_visibility_accessibility.b
#
# Demonstrates visibility and accessibility state.
#
# A whole details group can be hidden. A separate action button can be disabled.
#

implement VisibilityAccessibilityDemo;

include "draw.m";
include "icurses/ui.m";

VisibilityAccessibilityDemo: module
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

DetailsId: con 20;
DetailsTitleId: con 21;
DetailsTextId: con 22;

BtnToggleDetailsId: con 30;
BtnToggleActionId: con 31;
BtnActionId: con 32;
BtnExitId: con 33;

detailsvisible: int;
actionenabled: int;
actioncount: int;

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

	s = "Details: ";
	if(detailsvisible)
		s += "visible";
	else
		s += "hidden";

	s += " | Action: ";
	if(actionenabled)
		s += "enabled";
	else
		s += "disabled";

	s += " | Action count: " + sys->sprint("%d", actioncount);

	ui->settext(u, StateId, s);
	ui->setstatus(u, s);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 16;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Hide/show group | enable/disable action | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Visibility and accessibility ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 64, "Visibility affects drawing. Accessibility affects interaction.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, StateId, 3, 4, 64, "") < 0)
		raise "fail:state";

	if(ui->group(u, WinId, DetailsId, 3, 6, 62, 3) < 0)
		raise "fail:details";

	if(ui->label(u, DetailsId, DetailsTitleId, 0, 0, 60, "Details group") < 0)
		raise "fail:details title";

	if(ui->label(u, DetailsId, DetailsTextId, 2, 1, 60, "This whole group disappears when its parent node is hidden.") < 0)
		raise "fail:details text";

	if(ui->button(u, WinId, BtnToggleDetailsId, 3, 12, 16, 1, "Details", "d", AppTarget, "app.details") < 0)
		raise "fail:details button";

	if(ui->button(u, WinId, BtnToggleActionId, 21, 12, 16, 1, "Enable", "e", AppTarget, "app.enable") < 0)
		raise "fail:enable button";

	if(ui->button(u, WinId, BtnActionId, 39, 12, 14, 1, "Action", "a", AppTarget, "app.action") < 0)
		raise "fail:action button";

	if(ui->button(u, WinId, BtnExitId, 55, 12, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnToggleDetailsId);
	detailsvisible = 1;
	actionenabled = 1;
	actioncount = 0;
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.details"){
		sendnode(u, DetailsId, "node.toggle");
		detailsvisible = !detailsvisible;
		refresh(u);
		return 0;
	}

	if(cmd == "app.enable"){
		if(actionenabled){
			sendnode(u, BtnActionId, "node.disable");
			actionenabled = 0;
			ui->settext(u, BtnToggleActionId, "[ Enable ]");
		}
		else{
			sendnode(u, BtnActionId, "node.enable");
			actionenabled = 1;
			ui->settext(u, BtnToggleActionId, "[ Disable ]");
		}

		refresh(u);
		return 0;
	}

	if(cmd == "app.action"){
		actioncount++;
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