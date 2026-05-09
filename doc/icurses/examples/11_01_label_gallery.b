#
# 11_01_label_gallery.b
#
# Demonstrates Label elements.
#
# Labels are passive visual nodes. They do not receive focus and do not produce
# commands by themselves. Application code changes label text with settext()
# and redraws the UI.
#
# This demo uses labels as:
#
#   - a tree sketch;
#   - static explanatory text;
#   - a live dashboard with changing banner, message and state labels.
#

implement LabelGalleryDemo;

include "draw.m";
include "icurses/ui.m";

LabelGalleryDemo: module
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

TreeBoxId: con 20;
TreeRootId: con 21;
TreeWindowId: con 22;
TreeStaticId: con 23;
TreeLiveId: con 24;
TreeButtonsId: con 25;

StaticBoxId: con 30;
StaticTitleId: con 31;
StaticLine1Id: con 32;
StaticLine2Id: con 33;
StaticLine3Id: con 34;

LiveBoxId: con 40;
BannerLabelId: con 41;
MessageLabelId: con 42;
CounterLabelId: con 43;
ModeLabelId: con 44;
ResultLabelId: con 45;

BtnNextId: con 50;
BtnModeId: con 51;
BtnResetId: con 52;
BtnExitId: con 53;

counter: int;
mode: int;
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

modename(): string
{
	if(mode == 0)
		return "MONITOR";
	if(mode == 1)
		return "EDITOR";
	return "AUDIT";
}

bannertext(): string
{
	if(mode == 0)
		return ">> MONITOR DASHBOARD <<";
	if(mode == 1)
		return ">> EDITOR STATUS PANEL <<";
	return ">> AUDIT INSPECTOR <<";
}

message(): string
{
	case counter % 5 {
	0 =>
		return "Next rotates this message label.";
	1 =>
		return "Labels can show live values.";
	2 =>
		return "Labels stay passive and unfocused.";
	3 =>
		return "Buttons update application state.";
	* =>
		return "settext() refreshes visible text.";
	}
}

resulttext(): string
{
	if(mode == 0)
		return "Result: watching " + sys->sprint("%d", counter) + " events.";
	if(mode == 1)
		return "Result: edited " + sys->sprint("%d", counter) + " records.";
	return "Result: audited " + sys->sprint("%d", counter) + " entries.";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, BannerLabelId, bannertext());
	ui->settext(u, MessageLabelId, "Message label: " + message());
	ui->settext(u, CounterLabelId, "Counter label: " + sys->sprint("%d", counter));
	ui->settext(u, ModeLabelId, "Mode label: " + modename());
	ui->settext(u, ResultLabelId, resulttext());

	ui->setstatus(u, "label updates=" + sys->sprint("%d", updates) +
		" counter=" + sys->sprint("%d", counter) +
		" mode=" + modename());

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Next rotates live label values | Mode changes the dashboard meaning | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 22, " Label gallery ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "Labels are passive text nodes. Buttons below change their text.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TreeBoxId, 3, 4, 29, 12, " Element tree ") < 0)
		raise "fail:tree box";

	if(ui->label(u, TreeBoxId, TreeRootId, 2, 1, 23, "root") < 0)
		raise "fail:tree root";

	if(ui->label(u, TreeBoxId, TreeWindowId, 4, 2, 23, "+-- WinId") < 0)
		raise "fail:tree window";

	if(ui->label(u, TreeBoxId, TreeStaticId, 8, 3, 19, "+-- Static labels") < 0)
		raise "fail:tree static";

	if(ui->label(u, TreeBoxId, TreeLiveId, 8, 4, 19, "+-- Live labels") < 0)
		raise "fail:tree live";

	if(ui->label(u, TreeBoxId, TreeButtonsId, 8, 5, 19, "`-- Buttons") < 0)
		raise "fail:tree buttons";

	if(ui->window(u, WinId, StaticBoxId, 35, 4, 41, 6, " Static labels ") < 0)
		raise "fail:static box";

	if(ui->label(u, StaticBoxId, StaticTitleId, 2, 1, 35, "These labels do not change.") < 0)
		raise "fail:static title";

	if(ui->label(u, StaticBoxId, StaticLine1Id, 2, 2, 35, "Name: build-server") < 0)
		raise "fail:static line 1";

	if(ui->label(u, StaticBoxId, StaticLine2Id, 2, 3, 35, "Role: worker") < 0)
		raise "fail:static line 2";

	if(ui->label(u, StaticBoxId, StaticLine3Id, 2, 4, 35, "Labels do not receive focus.") < 0)
		raise "fail:static line 3";

	if(ui->window(u, WinId, LiveBoxId, 35, 11, 41, 7, " Live labels ") < 0)
		raise "fail:live box";

	if(ui->label(u, LiveBoxId, BannerLabelId, 2, 1, 35, "") < 0)
		raise "fail:banner label";

	if(ui->label(u, LiveBoxId, MessageLabelId, 2, 2, 35, "") < 0)
		raise "fail:message label";

	if(ui->label(u, LiveBoxId, CounterLabelId, 2, 3, 35, "") < 0)
		raise "fail:counter label";

	if(ui->label(u, LiveBoxId, ModeLabelId, 2, 4, 35, "") < 0)
		raise "fail:mode label";

	if(ui->label(u, LiveBoxId, ResultLabelId, 2, 5, 35, "") < 0)
		raise "fail:result label";

	if(ui->button(u, WinId, BtnNextId, 3, 19, 12, 1, "Next Msg", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnModeId, 17, 19, 12, 1, "Mode", "m", AppTarget, "app.mode") < 0)
		raise "fail:mode";

	if(ui->button(u, WinId, BtnResetId, 31, 19, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 43, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	counter = 0;
	mode = 0;
	updates = 0;

	ui->setfocus(u, BtnNextId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.next"){
		counter++;
		updates++;
		refresh(u);
		return 0;
	}

	if(cmd == "app.mode"){
		mode++;
		if(mode > 2)
			mode = 0;
		updates++;
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		counter = 0;
		mode = 0;
		updates++;
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