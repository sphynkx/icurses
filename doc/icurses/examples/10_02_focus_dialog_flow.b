#
# 10_02_focus_dialog_flow.b
#
# Demonstrates focus switching when a temporary dialog appears.
#
# The main area and dialog area are both visible concepts on screen:
#
#   - Open shows a real dialog window inside the UI tree.
#   - Focus is moved to the dialog OK button.
#   - OK or Cancel hides the dialog and restores focus to the Open button.
#   - Main highlights the main area and runs a main-screen action.
#

implement FocusDialogFlowDemo;

include "draw.m";
include "icurses/ui.m";

FocusDialogFlowDemo: module
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

MainBoxId: con 20;
MainTitleId: con 21;
MainFocusId: con 22;
MainActionId: con 23;
MainRouteId: con 24;

FocusMapId: con 30;
MapMainId: con 31;
MapDialogId: con 32;
MapRestoreId: con 33;
MapStateId: con 34;

BtnOpenId: con 40;
BtnMainActionId: con 41;
BtnExitId: con 42;

DialogPanelId: con 50;
DialogTitleId: con 51;
DialogTextId: con 52;
DialogFocusId: con 53;
BtnDialogOkId: con 54;
BtnDialogCancelId: con 55;

dialogvisible: int;
mainactions: int;
dialogactions: int;
focusowner: string;

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
	if(dialogvisible){
		ui->settext(u, MainTitleId, "   Main area");
		ui->settext(u, DialogTitleId, ">> Dialog area");
		ui->settext(u, MapMainId, "[ ] main focus owner");
		ui->settext(u, MapDialogId, "[x] dialog focus owner");
		ui->settext(u, MapRestoreId, "[ ] restore focus after close");
	}
	else{
		ui->settext(u, MainTitleId, ">> Main area");
		ui->settext(u, DialogTitleId, "   Dialog area");
		ui->settext(u, MapMainId, "[x] main focus owner");
		ui->settext(u, MapDialogId, "[ ] dialog focus owner");
		ui->settext(u, MapRestoreId, "[x] focus restored to Open");
	}

	ui->settext(u, MainFocusId, "Focus owner: " + focusowner);
	ui->settext(u, MainActionId, "Main actions: " + sys->sprint("%d", mainactions));
	ui->settext(u, MainRouteId, "Dialog OK actions: " + sys->sprint("%d", dialogactions));

	if(dialogvisible){
		ui->settext(u, DialogTextId, "This dialog is visible and owns focus.");
		ui->settext(u, DialogFocusId, "Focused control: BtnDialogOkId");
	}
	else{
		ui->settext(u, DialogTextId, "Dialog hidden.");
		ui->settext(u, DialogFocusId, "Focused control: none");
	}

	ui->settext(u, MapStateId, "Current route: " + focusowner);

	ui->setstatus(u, "focus owner: " + focusowner);
	ui->draw(u);
}

opendialog(u: ref IcUi->Ui)
{
	dialogvisible = 1;
	focusowner = "dialog -> BtnDialogOkId";
	sendnode(u, DialogPanelId, "node.show");
	ui->setfocus(u, BtnDialogOkId);
	refresh(u);
}

closedialog(u: ref IcUi->Ui, countok: int)
{
	if(countok)
		dialogactions++;

	dialogvisible = 0;
	focusowner = "main -> BtnOpenId";
	sendnode(u, DialogPanelId, "node.hide");
	ui->setfocus(u, BtnOpenId);
	refresh(u);
}

mainaction(u: ref IcUi->Ui)
{
	mainactions++;
	dialogvisible = 0;
	focusowner = "main -> BtnMainActionId";

	sendnode(u, DialogPanelId, "node.hide");
	ui->setfocus(u, BtnMainActionId);
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Open shows dialog and moves focus inside | OK/Cancel restores focus | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 86, 22, " Focus dialog flow ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "Temporary UI layers should move focus inside and restore it when closed.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, MainBoxId, 3, 4, 36, 8, " Main ") < 0)
		raise "fail:main box";

	if(ui->label(u, MainBoxId, MainTitleId, 2, 1, 28, "") < 0)
		raise "fail:main title";

	if(ui->label(u, MainBoxId, MainFocusId, 2, 2, 30, "") < 0)
		raise "fail:main focus";

	if(ui->label(u, MainBoxId, MainActionId, 2, 4, 30, "") < 0)
		raise "fail:main action";

	if(ui->label(u, MainBoxId, MainRouteId, 2, 5, 30, "") < 0)
		raise "fail:main route";

	if(ui->window(u, WinId, FocusMapId, 42, 4, 40, 8, " Focus route ") < 0)
		raise "fail:focus map";

	if(ui->label(u, FocusMapId, MapMainId, 2, 1, 30, "") < 0)
		raise "fail:map main";

	if(ui->label(u, FocusMapId, MapDialogId, 2, 2, 30, "") < 0)
		raise "fail:map dialog";

	if(ui->label(u, FocusMapId, MapRestoreId, 2, 3, 30, "") < 0)
		raise "fail:map restore";

	if(ui->label(u, FocusMapId, MapStateId, 2, 5, 36, "") < 0)
		raise "fail:map state";

	if(ui->window(u, WinId, DialogPanelId, 22, 12, 40, 7, " Dialog ") < 0)
		raise "fail:dialog panel";

	if(ui->label(u, DialogPanelId, DialogTitleId, 3, 1, 30, "") < 0)
		raise "fail:dialog title";

	if(ui->label(u, DialogPanelId, DialogTextId, 3, 2, 32, "") < 0)
		raise "fail:dialog text";

	if(ui->label(u, DialogPanelId, DialogFocusId, 3, 3, 32, "") < 0)
		raise "fail:dialog focus";

	if(ui->button(u, DialogPanelId, BtnDialogOkId, 9, 5, 10, 1, "OK", "", AppTarget, "app.dialog.ok") < 0)
		raise "fail:dialog ok";

	if(ui->button(u, DialogPanelId, BtnDialogCancelId, 21, 5, 12, 1, "Cancel", "", AppTarget, "app.dialog.cancel") < 0)
		raise "fail:dialog cancel";

	if(ui->button(u, WinId, BtnOpenId, 3, 20, 10, 1, "Open", "o", AppTarget, "app.open") < 0)
		raise "fail:open";

	if(ui->button(u, WinId, BtnMainActionId, 15, 20, 12, 1, "Main", "m", AppTarget, "app.main") < 0)
		raise "fail:main button";

	if(ui->button(u, WinId, BtnExitId, 29, 20, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	sendnode(u, DialogPanelId, "node.hide");

	dialogvisible = 0;
	mainactions = 0;
	dialogactions = 0;
	focusowner = "main -> BtnOpenId";

	ui->setfocus(u, BtnOpenId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.open"){
		opendialog(u);
		return 0;
	}

	if(cmd == "app.main"){
		mainaction(u);
		return 0;
	}

	if(cmd == "app.dialog.ok"){
		closedialog(u, 1);
		return 0;
	}

	if(cmd == "app.dialog.cancel"){
		closedialog(u, 0);
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