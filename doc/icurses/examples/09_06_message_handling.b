#
# 09_06_message_handling.b
#
# Demonstrates message handling.
#
# Framework commands are applied to UI nodes. Application commands are handled
# by the application and marked as processed in the visual handler pipeline.
#

implement MessageHandlingDemo;

include "draw.m";
include "icurses/ui.m";

MessageHandlingDemo: module
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

PipelineId: con 20;
StepReceiveId: con 21;
StepClassifyId: con 22;
StepApplyId: con 23;
StepRedrawId: con 24;

FrameworkPanelId: con 30;
FrameworkTextId: con 31;

AppPanelId: con 40;
AppTextId: con 41;
AppCountId: con 42;

BtnFrameworkId: con 50;
BtnAppId: con 51;
BtnResetId: con 52;
BtnExitId: con 53;

phase: int;
frameworkvisible: int;
appcount: int;
lastkind: string;

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

stage(n: int, text: string): string
{
	if(phase == n)
		return ">> " + text;

	return "   " + text;
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, StepReceiveId, stage(0, "receive message"));
	ui->settext(u, StepClassifyId, stage(1, "classify command"));
	ui->settext(u, StepApplyId, stage(2, "apply handler"));
	ui->settext(u, StepRedrawId, stage(3, "redraw result"));

	if(frameworkvisible)
		ui->settext(u, FrameworkTextId, "Framework panel is visible.");
	else
		ui->settext(u, FrameworkTextId, "Framework panel is hidden.");

	ui->settext(u, AppTextId, "Last handled kind: " + lastkind);
	ui->settext(u, AppCountId, "Application handled count: " + sys->sprint("%d", appcount));

	ui->setstatus(u, "message handling pipeline");
	ui->draw(u);
}

animate(u: ref IcUi->Ui, kind: string)
{
	lastkind = kind;

	phase = 0;
	refresh(u);
	sys->sleep(100);

	phase = 1;
	refresh(u);
	sys->sleep(100);

	phase = 2;
	refresh(u);
	sys->sleep(100);

	phase = 3;
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Framework toggles node; App updates application state | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " Message handling ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "A handler receives a message, classifies it, applies action, and redraws.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, PipelineId, 3, 4, 30, 8, " Handler pipeline ") < 0)
		raise "fail:pipeline";

	if(ui->label(u, PipelineId, StepReceiveId, 2, 1, 24, "") < 0)
		raise "fail:receive";

	if(ui->label(u, PipelineId, StepClassifyId, 2, 2, 24, "") < 0)
		raise "fail:classify";

	if(ui->label(u, PipelineId, StepApplyId, 2, 3, 24, "") < 0)
		raise "fail:apply";

	if(ui->label(u, PipelineId, StepRedrawId, 2, 4, 24, "") < 0)
		raise "fail:redraw";

	if(ui->window(u, WinId, FrameworkPanelId, 37, 4, 38, 5, " Framework command target ") < 0)
		raise "fail:framework panel";

	if(ui->label(u, FrameworkPanelId, FrameworkTextId, 2, 2, 32, "") < 0)
		raise "fail:framework text";

	if(ui->window(u, WinId, AppPanelId, 37, 10, 38, 5, " Application handler ") < 0)
		raise "fail:app panel";

	if(ui->label(u, AppPanelId, AppTextId, 2, 1, 32, "") < 0)
		raise "fail:app text";

	if(ui->label(u, AppPanelId, AppCountId, 2, 2, 32, "") < 0)
		raise "fail:app count";

	if(ui->button(u, WinId, BtnFrameworkId, 3, 17, 14, 1, "Framework", "f", AppTarget, "app.framework") < 0)
		raise "fail:framework";

	if(ui->button(u, WinId, BtnAppId, 19, 17, 10, 1, "App", "a", AppTarget, "app.work") < 0)
		raise "fail:app";

	if(ui->button(u, WinId, BtnResetId, 31, 17, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 43, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	phase = 3;
	frameworkvisible = 1;
	appcount = 0;
	lastkind = "none";

	ui->setfocus(u, BtnFrameworkId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.framework"){
		sendnode(u, FrameworkPanelId, "node.toggle");
		frameworkvisible = !frameworkvisible;
		animate(u, "framework command node.toggle");
		return 0;
	}

	if(cmd == "app.work"){
		appcount++;
		animate(u, "application command app.work");
		return 0;
	}

	if(cmd == "app.reset"){
		appcount = 0;
		lastkind = "reset";
		if(!frameworkvisible){
			sendnode(u, FrameworkPanelId, "node.show");
			frameworkvisible = 1;
		}
		animate(u, "application command app.reset");
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