#
# 07_03_dirty_status_updates.b
#
# Demonstrates small dirty-friendly updates:
#   - status row only;
#   - one small badge box;
#   - one details panel inside the window.
#

implement DirtyStatusUpdatesDemo;

include "draw.m";
include "icurses/ui.m";

DirtyStatusUpdatesDemo: module
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
InfoId: con 12;

StatusBoxId: con 20;
CountId: con 21;

BadgeBoxId: con 30;
BadgeId: con 31;

PanelId: con 40;
PanelTitleId: con 41;
PanelLine1Id: con 42;
PanelLine2Id: con 43;

BtnStatusId: con 50;
BtnBadgeId: con 51;
BtnPanelId: con 52;
BtnExitId: con 53;

statusupdates: int;
badgeupdates: int;
panelvisible: int;

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

refresh(u: ref IcUi->Ui, status: string)
{
	ui->settext(u, CountId, "Status updates: " +
		sys->sprint("%d", statusupdates) +
		" | Badge updates: " +
		sys->sprint("%d", badgeupdates));

	ui->settext(u, BadgeId, "BADGE " + sys->sprint("%d", badgeupdates));

	if(panelvisible)
		ui->settext(u, PanelLine2Id, "Panel is visible and only this region changes.");
	else
		ui->settext(u, PanelLine2Id, "Panel is hidden.");

	ui->setstatus(u, status);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 76);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Status changes bottom row | Badge changes small box | Panel toggles block ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 76, 18, " Dirty rendering ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 66, "Dirty rendering is visible when small independent regions change.") < 0)
		raise "fail:info";

	if(ui->window(u, WinId, StatusBoxId, 3, 4, 32, 5, " Status-only area ") < 0)
		raise "fail:status box";

	if(ui->label(u, StatusBoxId, CountId, 2, 2, 28, "") < 0)
		raise "fail:count";

	if(ui->window(u, WinId, BadgeBoxId, 39, 4, 28, 5, " Badge area ") < 0)
		raise "fail:badge box";

	if(ui->label(u, BadgeBoxId, BadgeId, 8, 2, 14, "") < 0)
		raise "fail:badge";

	if(ui->window(u, WinId, PanelId, 3, 10, 64, 4, " Details panel ") < 0)
		raise "fail:panel";

	if(ui->label(u, PanelId, PanelTitleId, 2, 1, 58, "This framed block is toggled by the Panel button.") < 0)
		raise "fail:panel title";

	if(ui->label(u, PanelId, PanelLine1Id, 2, 2, 58, "Renderer compares final cells and flushes only changed parts.") < 0)
		raise "fail:panel line 1";

	if(ui->label(u, PanelId, PanelLine2Id, 2, 3, 58, "") < 0)
		raise "fail:panel line 2";

	if(ui->button(u, WinId, BtnStatusId, 3, 15, 12, 1, "Status", "s", AppTarget, "app.status") < 0)
		raise "fail:status button";

	if(ui->button(u, WinId, BtnBadgeId, 17, 15, 12, 1, "Badge", "b", AppTarget, "app.badge") < 0)
		raise "fail:badge button";

	if(ui->button(u, WinId, BtnPanelId, 31, 15, 12, 1, "Panel", "p", AppTarget, "app.panel") < 0)
		raise "fail:panel button";

	if(ui->button(u, WinId, BtnExitId, 45, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	panelvisible = 1;

	ui->setfocus(u, BtnStatusId);
	refresh(u, "ready");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.status"){
		statusupdates++;
		refresh(u, "status row update #" + sys->sprint("%d", statusupdates));
		return 0;
	}

	if(cmd == "app.badge"){
		badgeupdates++;
		refresh(u, "badge box updated");
		return 0;
	}

	if(cmd == "app.panel"){
		sendnode(u, PanelId, "node.toggle");
		panelvisible = !panelvisible;

		if(panelvisible)
			refresh(u, "details panel shown");
		else
			refresh(u, "details panel hidden");
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
	statusupdates = 0;
	badgeupdates = 0;
	panelvisible = 1;

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