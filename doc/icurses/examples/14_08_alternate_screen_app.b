#
# 14_08_alternate_screen_app.b
#
# Demonstrates an alternate-screen application template.
#
# The application really enters the alternate screen at startup and restores
# the normal terminal screen on exit. Since the real normal screen is not
# readable by the application, this demo shows a model of the preserved normal
# scrollback next to the active application workspace.
#
# The important pattern:
#
#   - normal screen is preserved by the terminal;
#   - the application owns a separate full-screen workspace;
#   - temporary panels are implemented as top layers;
#   - exit restores the original terminal view.
#

implement AlternateScreenTemplate;

include "draw.m";
include "icurses/ui.m";

AlternateScreenTemplate: module
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

NormalBoxId: con 20;
NormalCanvasId: con 21;

AppBoxId: con 30;
AppCanvasId: con 31;

StateBoxId: con 40;
State1Id: con 41;
State2Id: con 42;
State3Id: con 43;

PreviewLayerId: con 50;
PreviewShadowId: con 51;
PreviewWinId: con 52;
PreviewCanvasId: con 53;
PreviewTextId: con 54;
BtnPreviewCloseId: con 55;

HelpLayerId: con 60;
HelpShadowId: con 61;
HelpWinId: con 62;
HelpText1Id: con 63;
HelpText2Id: con 64;
BtnHelpCloseId: con 65;

BtnWorkId: con 70;
BtnPreviewId: con 71;
BtnHelpId: con 72;
BtnExitId: con 73;

workcount: int;
normalticks: int;
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

drawnormal(u: ref IcUi->Ui, canvasid: int)
{
	ui->canvasclear(u, canvasid, " ", "0");

	ui->canvasputs(u, canvasid, 1, 1, "$ limbo build.b", "0");
	ui->canvasputs(u, canvasid, 1, 2, "build: ok", "0");
	ui->canvasputs(u, canvasid, 1, 3, "$ emu -r. /dis/app.dis", "0");
	ui->canvasputs(u, canvasid, 1, 4, "normal terminal content", "0");
	ui->canvasputs(u, canvasid, 1, 5, "is preserved behind the", "0");
	ui->canvasputs(u, canvasid, 1, 6, "alternate app screen.", "0");
	ui->canvasputs(u, canvasid, 1, 8, "preview tick: " + sys->sprint("%d", normalticks), "7");
}

drawapp(u: ref IcUi->Ui)
{
	i, x: int;

	ui->canvasclear(u, AppCanvasId, " ", "0");

	ui->canvasputs(u, AppCanvasId, 2, 1, "Alternate screen workspace", "7");
	ui->canvasputs(u, AppCanvasId, 2, 3, "The app can redraw freely here.", "0");
	ui->canvasputs(u, AppCanvasId, 2, 4, "Normal scrollback is not destroyed.", "0");
	ui->canvasputs(u, AppCanvasId, 2, 6, "Work units:", "0");

	for(i = 0; i < workcount && i < 20; i++){
		x = 14 + i;
		ui->canvasputc(u, AppCanvasId, x, 6, "#", "0");
	}

	ui->canvasputs(u, AppCanvasId, 2, 8, "Temporary dialogs are top layers.", "0");
}

refresh(u: ref IcUi->Ui)
{
	drawnormal(u, NormalCanvasId);
	drawapp(u);

	if(appscreen)
		ui->settext(u, State1Id, "Actual app screen: active");
	else
		ui->settext(u, State1Id, "Actual app screen: inactive");

	ui->settext(u, State2Id, "Work count: " + sys->sprint("%d", workcount));
	ui->settext(u, State3Id, "Last action: " + lastaction);

	ui->setstatus(u, "alternate screen template: " + lastaction);
	ui->draw(u);
}

showpreview(u: ref IcUi->Ui)
{
	drawnormal(u, PreviewCanvasId);
	sendnode(u, PreviewLayerId, "node.show");
	ui->setfocus(u, BtnPreviewCloseId);
	lastaction = "normal screen preview opened";
	refresh(u);
}

hidepreview(u: ref IcUi->Ui)
{
	sendnode(u, PreviewLayerId, "node.hide");
	ui->setfocus(u, BtnPreviewId);
	lastaction = "normal screen preview closed";
	refresh(u);
}

showhelp(u: ref IcUi->Ui)
{
	sendnode(u, HelpLayerId, "node.show");
	ui->setfocus(u, BtnHelpCloseId);
	lastaction = "help opened";
	refresh(u);
}

hidehelp(u: ref IcUi->Ui)
{
	sendnode(u, HelpLayerId, "node.hide");
	ui->setfocus(u, BtnHelpId);
	lastaction = "help closed";
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 23);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Alternate screen app | Preview shows preserved normal screen model | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 23, " Alternate screen application template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "The terminal preserves normal screen content while the app owns another screen.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, NormalBoxId, 3, 4, 34, 11, " Preserved normal screen model ") < 0)
		raise "fail:normal box";

	if(ui->canvas(u, NormalBoxId, NormalCanvasId, 2, 1, 30, 9) < 0)
		raise "fail:normal canvas";

	if(ui->window(u, WinId, AppBoxId, 40, 4, 41, 11, " Active app screen ") < 0)
		raise "fail:app box";

	if(ui->canvas(u, AppBoxId, AppCanvasId, 2, 1, 37, 9) < 0)
		raise "fail:app canvas";

	if(ui->window(u, WinId, StateBoxId, 3, 16, 78, 3, " Lifecycle state ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, State1Id, 2, 1, 72, "") < 0)
		raise "fail:state 1";

	if(ui->label(u, StateBoxId, State2Id, 30, 1, 20, "") < 0)
		raise "fail:state 2";

	if(ui->label(u, StateBoxId, State3Id, 2, 2, 72, "") < 0)
		raise "fail:state 3";

	if(ui->group(u, WinId, PreviewLayerId, 0, 0, 84, 23) < 0)
		raise "fail:preview layer";

	if(ui->shadowwindow(u, PreviewLayerId, PreviewShadowId, PreviewWinId, 20, 5, 44, 14, " Normal screen preview ", 1, 1) < 0)
		raise "fail:preview window";

	if(ui->canvas(u, PreviewWinId, PreviewCanvasId, 3, 2, 38, 9) < 0)
		raise "fail:preview canvas";

	if(ui->label(u, PreviewWinId, PreviewTextId, 3, 11, 36, "This is a model of what returns after exit.") < 0)
		raise "fail:preview text";

	if(ui->button(u, PreviewWinId, BtnPreviewCloseId, 16, 12, 12, 1, "Close", "", AppTarget, "app.preview.close") < 0)
		raise "fail:preview close";

	if(ui->group(u, WinId, HelpLayerId, 0, 0, 84, 23) < 0)
		raise "fail:help layer";

	if(ui->shadowwindow(u, HelpLayerId, HelpShadowId, HelpWinId, 23, 7, 38, 8, " Help ", 1, 1) < 0)
		raise "fail:help window";

	if(ui->label(u, HelpWinId, HelpText1Id, 3, 2, 30, "Help is a temporary top layer.") < 0)
		raise "fail:help text 1";

	if(ui->label(u, HelpWinId, HelpText2Id, 3, 3, 30, "Hide the whole layer to close it.") < 0)
		raise "fail:help text 2";

	if(ui->button(u, HelpWinId, BtnHelpCloseId, 14, 5, 12, 1, "Close", "", AppTarget, "app.help.close") < 0)
		raise "fail:help close";

	if(ui->button(u, WinId, BtnWorkId, 3, 21, 10, 1, "Work", "w", AppTarget, "app.work") < 0)
		raise "fail:work";

	if(ui->button(u, WinId, BtnPreviewId, 15, 21, 12, 1, "Preview", "p", AppTarget, "app.preview") < 0)
		raise "fail:preview";

	if(ui->button(u, WinId, BtnHelpId, 29, 21, 10, 1, "Help", "h", AppTarget, "app.help") < 0)
		raise "fail:help";

	if(ui->button(u, WinId, BtnExitId, 41, 21, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	sendnode(u, PreviewLayerId, "node.hide");
	sendnode(u, HelpLayerId, "node.hide");

	workcount = 0;
	normalticks = 0;
	lastaction = "ready";

	ui->setfocus(u, BtnWorkId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.work"){
		workcount++;
		if(workcount > 20)
			workcount = 0;
		lastaction = "app workspace updated";
		refresh(u);
		return 0;
	}

	if(cmd == "app.preview"){
		showpreview(u);
		return 0;
	}

	if(cmd == "app.preview.close"){
		hidepreview(u);
		return 0;
	}

	if(cmd == "app.help"){
		showhelp(u);
		return 0;
	}

	if(cmd == "app.help.close"){
		hidehelp(u);
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

	ui->settick(u, 500);
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
			normalticks++;
			refresh(u);

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