#
# 06_02_adaptive_layout.b
#
# Demonstrates adaptive layout at startup.
#
# The same dashboard is built in wide or narrow mode depending on terminal
# width. The content is shown as framed panels, not as a single changed label.
#

implement AdaptiveLayoutDemo;

include "draw.m";
include "icurses/ui.m";

AdaptiveLayoutDemo: module
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
ModeId: con 12;
MapId: con 13;

NavId: con 20;
NavTitleId: con 21;
BtnInboxId: con 22;
BtnArchiveId: con 23;

ContentId: con 30;
ContentTitleId: con 31;
ContentLine1Id: con 32;
ContentLine2Id: con 33;
ContentLine3Id: con 34;

PreviewId: con 40;
PreviewTitleId: con 41;
PreviewLine1Id: con 42;
PreviewLine2Id: con 43;

BtnExitId: con 50;

selected: int;
wide: int;

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

refresh(u: ref IcUi->Ui)
{
	if(wide)
		ui->settext(u, ModeId, "Layout: wide mode, navigation and panels are side by side");
	else
		ui->settext(u, ModeId, "Layout: narrow mode, panels are stacked");

	if(selected == 0){
		ui->settext(u, ContentTitleId, "Inbox");
		ui->settext(u, ContentLine1Id, "Unread messages: 12");
		ui->settext(u, ContentLine2Id, "Flagged messages: 3");
		ui->settext(u, ContentLine3Id, "Latest: renderer test report");

		ui->settext(u, PreviewTitleId, "Inbox preview");
		ui->settext(u, PreviewLine1Id, "Subject: nightly build");
		ui->settext(u, PreviewLine2Id, "Status: two warnings, no failures");
	}
	else{
		ui->settext(u, ContentTitleId, "Archive");
		ui->settext(u, ContentLine1Id, "Stored records: 248");
		ui->settext(u, ContentLine2Id, "Oldest item: release notes");
		ui->settext(u, ContentLine3Id, "Index state: compact");

		ui->settext(u, PreviewTitleId, "Archive preview");
		ui->settext(u, PreviewLine1Id, "Subject: saved documentation draft");
		ui->settext(u, PreviewLine2Id, "Status: archived and indexed");
	}

	ui->setstatus(u, "adaptive layout shows real panels");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, ww, wh: int;
	navx, navy, navw, navh: int;
	cx, cy, cw, ch: int;
	px, py, pw, ph: int;

	root = ui->rootid(u);

	wide = sw >= 90;

	ww = 82;
	if(sw < 86)
		ww = sw - 2;
	if(ww < 54)
		ww = 54;

	wh = 21;
	if(sh < 25)
		wh = sh - 4;
	if(wh < 17)
		wh = 17;

	x = center(sw, ww);
	y = center(sh, wh);

	if(wide){
		navx = 3;
		navy = 2;
		navw = 22;
		navh = 9;

		cx = 28;
		cy = 2;
		cw = 24;
		ch = 9;

		px = 55;
		py = 2;
		pw = ww - 59;
		ph = 9;
	}
	else{
		navx = 3;
		navy = 2;
		navw = ww - 6;
		navh = 5;

		cx = 3;
		cy = 8;
		cw = ww - 6;
		ch = 5;

		px = 3;
		py = 14;
		pw = ww - 6;
		ph = 5;
	}

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Same data, different layout at startup | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, ww, wh, " Adaptive layout ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, ModeId, 3, 2, ww - 6, "") < 0)
		raise "fail:mode";

	if(ui->window(u, WinId, MapId, 3, 4, ww - 6, wh - 7, " Adaptive dashboard ") < 0)
		raise "fail:map";

	if(ui->window(u, MapId, NavId, navx, navy, navw, navh, " Navigation ") < 0)
		raise "fail:nav";

	if(ui->label(u, NavId, NavTitleId, 2, 1, navw - 4, "Choose panel:") < 0)
		raise "fail:nav title";

	if(ui->button(u, NavId, BtnInboxId, 2, 3, 10, 1, "Inbox", "i", AppTarget, "app.inbox") < 0)
		raise "fail:inbox";

	if(ui->button(u, NavId, BtnArchiveId, 2, 5, 12, 1, "Archive", "a", AppTarget, "app.archive") < 0)
		raise "fail:archive";

	if(ui->window(u, MapId, ContentId, cx, cy, cw, ch, " Content ") < 0)
		raise "fail:content";

	if(ui->label(u, ContentId, ContentTitleId, 2, 1, cw - 4, "") < 0)
		raise "fail:content title";

	if(ui->label(u, ContentId, ContentLine1Id, 2, 2, cw - 4, "") < 0)
		raise "fail:content line 1";

	if(ui->label(u, ContentId, ContentLine2Id, 2, 3, cw - 4, "") < 0)
		raise "fail:content line 2";

	if(ui->label(u, ContentId, ContentLine3Id, 2, 4, cw - 4, "") < 0)
		raise "fail:content line 3";

	if(ui->window(u, MapId, PreviewId, px, py, pw, ph, " Preview ") < 0)
		raise "fail:preview";

	if(ui->label(u, PreviewId, PreviewTitleId, 2, 1, pw - 4, "") < 0)
		raise "fail:preview title";

	if(ui->label(u, PreviewId, PreviewLine1Id, 2, 2, pw - 4, "") < 0)
		raise "fail:preview line 1";

	if(ui->label(u, PreviewId, PreviewLine2Id, 2, 3, pw - 4, "") < 0)
		raise "fail:preview line 2";

	if(ui->button(u, WinId, BtnExitId, ww - 13, wh - 3, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnInboxId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.inbox"){
		selected = 0;
		refresh(u);
		return 0;
	}

	if(cmd == "app.archive"){
		selected = 1;
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
	selected = 0;

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