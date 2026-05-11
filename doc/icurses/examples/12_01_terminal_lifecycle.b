#
# 12_01_terminal_lifecycle.b
#
# Demonstrates terminal lifecycle.
#
# This demo makes terminal lifecycle visible without damaging the real terminal.
#
# The application really enters the alternate screen, hides the cursor and
# starts raw input through IcUi. The visible panels explain which parts are
# actual runtime state and which parts are safe simulations.
#
# Buttons:
#
#   - Step highlights the next cleanup step.
#   - Cursor toggles cursor visibility and a visible cursor marker.
#   - Clear clears only the renderer-owned workspace canvas.
#   - Emergency opens a simulated emergency panel but does not crash or exit.
#   - Close inside the emergency panel closes that panel.
#   - Exit leaves through the normal cleanup path.
#

implement TerminalLifecycleDemo;

include "draw.m";
include "icurses/ui.m";

TerminalLifecycleDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;
cursorhidden: int;
rawactive: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

RuntimeBoxId: con 20;
RuntimeTitleId: con 21;
RuntimeAppScreenId: con 22;
RuntimeRawId: con 23;
RuntimeCursorId: con 24;
RuntimeOwnerId: con 25;

WorkspaceBoxId: con 30;
WorkspaceCanvasId: con 31;

CleanupBoxId: con 40;
CleanupTitleId: con 41;
CleanupStep1Id: con 42;
CleanupStep2Id: con 43;
CleanupStep3Id: con 44;
CleanupStep4Id: con 45;
CleanupStep5Id: con 46;

LogBoxId: con 50;
Log1Id: con 51;
Log2Id: con 52;
Log3Id: con 53;
Log4Id: con 54;

EmergencyLayerId: con 60;
EmergencyShadowId: con 61;
EmergencyWinId: con 62;
EmergencyTitleId: con 63;
EmergencyLine1Id: con 64;
EmergencyLine2Id: con 65;
EmergencyLine3Id: con 66;
BtnEmergencyCloseId: con 67;

BtnStepId: con 70;
BtnCursorId: con 71;
BtnClearId: con 72;
BtnEmergencyId: con 73;
BtnExitId: con 74;

cleanupstep: int;
clears: int;
ticks: int;
emergency: int;
workspaceversion: int;
lastaction: string;

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
	cursorhidden = 1;
}

leaveappscreen()
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	cursorhidden = 0;

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

setemergencyvisible(u: ref IcUi->Ui, visible: int)
{
	if(visible)
		sendnode(u, EmergencyLayerId, "node.show");
	else
		sendnode(u, EmergencyLayerId, "node.hide");
}

yesno(v: int): string
{
	if(v)
		return "yes";

	return "no";
}

runtimeicon(v: int): string
{
	if(v)
		return "[ACTIVE] ";

	return "[ off ] ";
}

cleanupmark(n: int, text: string): string
{
	if(cleanupstep == n)
		return ">> " + text;

	return "   " + text;
}

drawworkspace(u: ref IcUi->Ui)
{
	ui->canvasclear(u, WorkspaceCanvasId, " ", "0");

	if(clears == 0){
		ui->canvasputs(u, WorkspaceCanvasId, 2, 1, "Renderer-owned workspace", "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 3, "This canvas belongs to the UI renderer.", "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 4, "Clear does not call terminal clear directly.", "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 6, "Only app-screen boundaries use terminal clear.", "0");
	}
	else{
		ui->canvasputs(u, WorkspaceCanvasId, 2, 1, "Workspace was cleared by renderer-owned canvas operations.", "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 3, "Clear count: " + sys->sprint("%d", clears), "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 5, "The terminal front buffer stays synchronized.", "0");
		ui->canvasputs(u, WorkspaceCanvasId, 2, 7, "Workspace version: " + sys->sprint("%d", workspaceversion), "0");
	}

	if(cursorhidden)
		ui->canvasputs(u, WorkspaceCanvasId, 2, 8, "Visible cursor marker: hidden", "0");
	else
		ui->canvasputs(u, WorkspaceCanvasId, 2, 8, "Visible cursor marker: █", "7");
}

refresh(u: ref IcUi->Ui)
{
	drawworkspace(u);

	ui->settext(u, RuntimeTitleId, "Actual runtime state");
	ui->settext(u, RuntimeAppScreenId, runtimeicon(appscreen) + "alternate/app screen");
	ui->settext(u, RuntimeRawId, runtimeicon(rawactive) + "raw input through IcUi");
	ui->settext(u, RuntimeCursorId, runtimeicon(cursorhidden) + "cursor hidden");
	ui->settext(u, RuntimeOwnerId, "Screen owner: renderer, not direct terminal prints");

	ui->settext(u, CleanupTitleId, "Cleanup order highlighted by Step");
	ui->settext(u, CleanupStep1Id, cleanupmark(1, "stop event loop"));
	ui->settext(u, CleanupStep2Id, cleanupmark(2, "close UI/input readers"));
	ui->settext(u, CleanupStep3Id, cleanupmark(3, "reset terminal attributes"));
	ui->settext(u, CleanupStep4Id, cleanupmark(4, "show cursor"));
	ui->settext(u, CleanupStep5Id, cleanupmark(5, "leave alternate screen"));

	ui->settext(u, Log1Id, "Last action: " + lastaction);
	ui->settext(u, Log2Id, "clear count=" + sys->sprint("%d", clears) +
		" ticks=" + sys->sprint("%d", ticks) +
		" emergency=" + yesno(emergency));
	ui->settext(u, Log3Id, "Rule: use renderer-owned clear inside UI;");
	ui->settext(u, Log4Id, "terminal clear only at boundaries.");

	if(emergency)
		setemergencyvisible(u, 1);
	else
		setemergencyvisible(u, 0);

	ui->setstatus(u, "terminal lifecycle: " + lastaction);
	ui->draw(u);
}

workspaceclear(u: ref IcUi->Ui)
{
	clears++;
	workspaceversion++;
	lastaction = "workspace cleared through canvas";
	refresh(u);
}

simulateemergency(u: ref IcUi->Ui)
{
	emergency = 1;
	cleanupstep = 1;
	lastaction = "simulated emergency opened";
	ui->setfocus(u, BtnEmergencyCloseId);
	refresh(u);
}

closeemergency(u: ref IcUi->Ui)
{
	emergency = 0;
	lastaction = "emergency panel closed";
	ui->setfocus(u, BtnEmergencyId);
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 115);
	y = center(sh, 23);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Clear changes workspace visibly | Emergency is simulated | Exit performs real cleanup ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 115, 23, " Terminal lifecycle ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "Terminal ownership must be visible, synchronized and restored safely.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, RuntimeBoxId, 3, 4, 54, 7, " Runtime ") < 0)
		raise "fail:runtime box";

	if(ui->label(u, RuntimeBoxId, RuntimeTitleId, 2, 1, 32, "") < 0)
		raise "fail:runtime title";

	if(ui->label(u, RuntimeBoxId, RuntimeAppScreenId, 2, 2, 32, "") < 0)
		raise "fail:runtime app screen";

	if(ui->label(u, RuntimeBoxId, RuntimeRawId, 2, 3, 32, "") < 0)
		raise "fail:runtime raw";

	if(ui->label(u, RuntimeBoxId, RuntimeCursorId, 2, 4, 32, "") < 0)
		raise "fail:runtime cursor";

	if(ui->label(u, RuntimeBoxId, RuntimeOwnerId, 2, 5, 50, "") < 0)
		raise "fail:runtime owner";

	if(ui->window(u, WinId, WorkspaceBoxId, 58, 4, 52, 11, " Renderer workspace ") < 0)
		raise "fail:workspace box";

	if(ui->canvas(u, WorkspaceBoxId, WorkspaceCanvasId, 2, 1, 48, 9) < 0)
		raise "fail:workspace canvas";

	if(ui->window(u, WinId, CleanupBoxId, 3, 12, 42, 8, " Cleanup path ") < 0)
		raise "fail:cleanup box";

	if(ui->label(u, CleanupBoxId, CleanupTitleId, 2, 1, 36, "") < 0)
		raise "fail:cleanup title";

	if(ui->label(u, CleanupBoxId, CleanupStep1Id, 2, 2, 36, "") < 0)
		raise "fail:cleanup step 1";

	if(ui->label(u, CleanupBoxId, CleanupStep2Id, 2, 3, 36, "") < 0)
		raise "fail:cleanup step 2";

	if(ui->label(u, CleanupBoxId, CleanupStep3Id, 2, 4, 36, "") < 0)
		raise "fail:cleanup step 3";

	if(ui->label(u, CleanupBoxId, CleanupStep4Id, 2, 5, 36, "") < 0)
		raise "fail:cleanup step 4";

	if(ui->label(u, CleanupBoxId, CleanupStep5Id, 2, 6, 36, "") < 0)
		raise "fail:cleanup step 5";

	if(ui->window(u, WinId, LogBoxId, 58, 15, 50, 6, " Log ") < 0)
		raise "fail:log box";

	if(ui->label(u, LogBoxId, Log1Id, 2, 1, 46, "") < 0)
		raise "fail:log 1";

	if(ui->label(u, LogBoxId, Log2Id, 2, 2, 46, "") < 0)
		raise "fail:log 2";

	if(ui->label(u, LogBoxId, Log3Id, 2, 3, 46, "") < 0)
		raise "fail:log 3";

	if(ui->label(u, LogBoxId, Log4Id, 2, 4, 46, "") < 0)
		raise "fail:log 4";

	if(ui->group(u, WinId, EmergencyLayerId, 20, 7, 44, 9) < 0)
		raise "fail:emergency layer";

	if(ui->shadowwindow(u, EmergencyLayerId, EmergencyShadowId, EmergencyWinId, 0, 0, 44, 9, " Emergency simulation ", 1, 1) < 0)
		raise "fail:emergency window";

	if(ui->label(u, EmergencyWinId, EmergencyTitleId, 3, 2, 40, "Simulated emergency, no crash happened.") < 0)
		raise "fail:emergency title";

	if(ui->label(u, EmergencyWinId, EmergencyLine1Id, 3, 3, 40, "Real apps should jump to cleanup path.") < 0)
		raise "fail:emergency line 1";

	if(ui->label(u, EmergencyWinId, EmergencyLine2Id, 3, 4, 40, "Close hides this panel safely.") < 0)
		raise "fail:emergency line 2";

	if(ui->label(u, EmergencyWinId, EmergencyLine3Id, 3, 5, 40, "Exit still restores terminal state.") < 0)
		raise "fail:emergency line 3";

	if(ui->button(u, EmergencyWinId, BtnEmergencyCloseId, 16, 7, 10, 1, "Close", "", AppTarget, "app.emergency.close") < 0)
		raise "fail:emergency close";

	if(ui->button(u, WinId, BtnStepId, 3, 21, 10, 1, "Step", "s", AppTarget, "app.step") < 0)
		raise "fail:step";

	if(ui->button(u, WinId, BtnCursorId, 15, 21, 12, 1, "Cursor", "c", AppTarget, "app.cursor") < 0)
		raise "fail:cursor button";

	if(ui->button(u, WinId, BtnClearId, 29, 21, 10, 1, "Clear", "l", AppTarget, "app.clear") < 0)
		raise "fail:clear button";

	if(ui->button(u, WinId, BtnEmergencyId, 41, 21, 15, 1, "Emergency", "e", AppTarget, "app.emergency") < 0)
		raise "fail:emergency button";

	if(ui->button(u, WinId, BtnExitId, 58, 21, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	cleanupstep = 1;
	clears = 0;
	ticks = 0;
	emergency = 0;
	workspaceversion = 0;
	lastaction = "UI built in alternate screen";

	setemergencyvisible(u, 0);

	ui->setfocus(u, BtnStepId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit"){
		lastaction = "normal cleanup requested";
		refresh(u);
		return 1;
	}

	if(cmd == "app.step"){
		cleanupstep++;
		if(cleanupstep > 5)
			cleanupstep = 1;
		lastaction = "cleanup step highlighted";
		refresh(u);
		return 0;
	}

	if(cmd == "app.cursor"){
		if(cursorhidden){
			ic->showcursor(out);
			cursorhidden = 0;
			lastaction = "cursor shown";
		}
		else{
			ic->hidecursor(out);
			cursorhidden = 1;
			lastaction = "cursor hidden";
		}

		refresh(u);
		return 0;
	}

	if(cmd == "app.clear"){
		workspaceclear(u);
		return 0;
	}

	if(cmd == "app.emergency"){
		simulateemergency(u);
		return 0;
	}

	if(cmd == "app.emergency.close"){
		closeemergency(u);
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
	cursorhidden = 0;
	rawactive = 0;

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

	rawactive = 1;
	lastaction = "raw input started through IcUi";
	refresh(u);

	done = 0;

	for(; !done;){
		s = ui->step(u);

		case s.kind {
		IcUi->StepDone =>
			done = 1;

		IcUi->StepKey =>
			if(ui->isquit(s.key)){
				lastaction = "quit key requested cleanup";
				refresh(u);
				done = 1;
			}
			else
				done = handlecmd(u, s.msg.cmd);

		IcUi->StepTick =>
			ticks++;

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	rawactive = 0;
	cleanupstep = 5;

	ui->close(u);
	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}