#
# 10_01_focus_spotlight.b
#
# Demonstrates focus as the current active UI node.
#
# The left side shows three focus targets. The right side shows a focus
# inspector. Focus buttons move focus to a real action button. Activating that
# button changes application state.
#

implement FocusSpotlightDemo;

include "draw.m";
include "icurses/ui.m";

FocusSpotlightDemo: module
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

TargetsBoxId: con 20;
CardAId: con 21;
CardATitleId: con 22;
CardATextId: con 23;
BtnActionAId: con 24;

CardBId: con 30;
CardBTitleId: con 31;
CardBTextId: con 32;
BtnActionBId: con 33;

CardCId: con 40;
CardCTitleId: con 41;
CardCTextId: con 42;
BtnActionCId: con 43;

InspectorBoxId: con 50;
FocusNodeId: con 51;
FocusRoleId: con 52;
ActivationId: con 53;

BtnFocusAId: con 60;
BtnFocusBId: con 61;
BtnFocusCId: con 62;
BtnExitId: con 63;

focusid: int;
activations: int;
lastactivation: string;

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

mark(id: int): string
{
	if(focusid == id)
		return ">> ";

	return "   ";
}

focusname(): string
{
	if(focusid == BtnActionAId)
		return "BtnActionAId";
	if(focusid == BtnActionBId)
		return "BtnActionBId";
	if(focusid == BtnActionCId)
		return "BtnActionCId";
	return "none";
}

focusrole(): string
{
	if(focusid == BtnActionAId)
		return "Action A receives Enter/Space activation.";
	if(focusid == BtnActionBId)
		return "Action B is the current keyboard target.";
	if(focusid == BtnActionCId)
		return "Action C is the current keyboard target.";
	return "No focus target selected.";
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, CardATitleId, mark(BtnActionAId) + "Action A");
	ui->settext(u, CardBTitleId, mark(BtnActionBId) + "Action B");
	ui->settext(u, CardCTitleId, mark(BtnActionCId) + "Action C");

	ui->settext(u, FocusNodeId, "Current focus id: " + sys->sprint("%d", focusid) + "  " + focusname());
	ui->settext(u, FocusRoleId, focusrole());
	ui->settext(u, ActivationId, "Activations: " + sys->sprint("%d", activations) + "  last=" + lastactivation);

	ui->setstatus(u, "focus target: " + focusname());
	ui->draw(u);
}

setfocusnode(u: ref IcUi->Ui, id: int)
{
	focusid = id;
	ui->setfocus(u, id);
	refresh(u);
}

activate(u: ref IcUi->Ui, name: string)
{
	activations++;
	lastactivation = name;
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 21);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Focus A/B/C moves focus to action buttons | Enter activates focused button | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 21, " Focus spotlight ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "Focus is the active node that receives keyboard activation.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, TargetsBoxId, 3, 4, 42, 11, " Focus targets ") < 0)
		raise "fail:targets box";

	if(ui->window(u, TargetsBoxId, CardAId, 2, 1, 36, 3, " Target A ") < 0)
		raise "fail:card a";

	if(ui->label(u, CardAId, CardATitleId, 2, 1, 20, "") < 0)
		raise "fail:card a title";

	if(ui->label(u, CardAId, CardATextId, 18, 1, 14, "safe action") < 0)
		raise "fail:card a text";

	if(ui->button(u, CardAId, BtnActionAId, 2, 2, 12, 1, "Run A", "", AppTarget, "app.action.a") < 0)
		raise "fail:action a";

	if(ui->window(u, TargetsBoxId, CardBId, 2, 4, 36, 3, " Target B ") < 0)
		raise "fail:card b";

	if(ui->label(u, CardBId, CardBTitleId, 2, 1, 20, "") < 0)
		raise "fail:card b title";

	if(ui->label(u, CardBId, CardBTextId, 18, 1, 14, "build action") < 0)
		raise "fail:card b text";

	if(ui->button(u, CardBId, BtnActionBId, 2, 2, 12, 1, "Run B", "", AppTarget, "app.action.b") < 0)
		raise "fail:action b";

	if(ui->window(u, TargetsBoxId, CardCId, 2, 7, 36, 3, " Target C ") < 0)
		raise "fail:card c";

	if(ui->label(u, CardCId, CardCTitleId, 2, 1, 20, "") < 0)
		raise "fail:card c title";

	if(ui->label(u, CardCId, CardCTextId, 18, 1, 14, "deploy action") < 0)
		raise "fail:card c text";

	if(ui->button(u, CardCId, BtnActionCId, 2, 2, 12, 1, "Run C", "", AppTarget, "app.action.c") < 0)
		raise "fail:action c";

	if(ui->window(u, WinId, InspectorBoxId, 48, 4, 31, 11, " Focus inspector ") < 0)
		raise "fail:inspector";

	if(ui->label(u, InspectorBoxId, FocusNodeId, 2, 1, 27, "") < 0)
		raise "fail:focus node";

	if(ui->label(u, InspectorBoxId, FocusRoleId, 2, 3, 27, "") < 0)
		raise "fail:focus role";

	if(ui->label(u, InspectorBoxId, ActivationId, 2, 6, 27, "") < 0)
		raise "fail:activation";

	if(ui->button(u, WinId, BtnFocusAId, 3, 17, 10, 1, "Focus A", "a", AppTarget, "app.focus.a") < 0)
		raise "fail:focus a";

	if(ui->button(u, WinId, BtnFocusBId, 15, 17, 10, 1, "Focus B", "b", AppTarget, "app.focus.b") < 0)
		raise "fail:focus b";

	if(ui->button(u, WinId, BtnFocusCId, 27, 17, 10, 1, "Focus C", "c", AppTarget, "app.focus.c") < 0)
		raise "fail:focus c";

	if(ui->button(u, WinId, BtnExitId, 39, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	focusid = BtnActionAId;
	activations = 0;
	lastactivation = "none";

	ui->setfocus(u, BtnActionAId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.focus.a"){
		setfocusnode(u, BtnActionAId);
		return 0;
	}

	if(cmd == "app.focus.b"){
		setfocusnode(u, BtnActionBId);
		return 0;
	}

	if(cmd == "app.focus.c"){
		setfocusnode(u, BtnActionCId);
		return 0;
	}

	if(cmd == "app.action.a"){
		focusid = BtnActionAId;
		activate(u, "A");
		return 0;
	}

	if(cmd == "app.action.b"){
		focusid = BtnActionBId;
		activate(u, "B");
		return 0;
	}

	if(cmd == "app.action.c"){
		focusid = BtnActionCId;
		activate(u, "C");
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