#
# 07_01_renderer_layers.b
#
# Demonstrates the renderer as the component that combines UI tree layers:
# canvas, shadow, window, labels, buttons, help row, and status row.
#

implement RendererLayersDemo;

include "draw.m";
include "icurses/ui.m";

RendererLayersDemo: module
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
CanvasId: con 11;

ShadowId: con 20;
WinId: con 21;
TitleId: con 22;
InfoId: con 23;
ModeId: con 24;

BtnFrameId: con 30;
BtnStatusId: con 31;
BtnExitId: con 32;

framemode: int;
statuscount: int;

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

framename(): string
{
	if(framemode == 0)
		return "single";
	if(framemode == 1)
		return "double";
	return "ascii";
}

applyframe(u: ref IcUi->Ui)
{
	if(framemode == 0)
		ui->setframestyle(u, IcPaint->FrameSingle);
	else if(framemode == 1)
		ui->setframestyle(u, IcPaint->FrameDouble);
	else
		ui->setframestyle(u, IcPaint->FrameAscii);
}

drawbackground(u: ref IcUi->Ui, w, h: int)
{
	y: int;
	line: string;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(y = 0; y < h; y++){
		if(y % 2 == 0)
			line = "renderer layer: canvas background";
		else
			line = "windows, shadows, labels and buttons are drawn above it";

		ui->canvasputs(u, CanvasId, 2, y, line, "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	applyframe(u);

	ui->settext(u, ModeId, "Frame style: " + framename());
	ui->setstatus(u, "status row update #" + sys->sprint("%d", statuscount));
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, wx, wy, ww, wh, usableh: int;

	root = ui->rootid(u);

	usableh = sh;
	if(usableh > 2)
		usableh -= 2;

	ww = 64;
	wh = 13;
	wx = center(sw, ww);
	wy = center(usableh, wh);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Renderer combines canvas, tree nodes, help and status rows | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->canvas(u, LayerId, CanvasId, 0, 0, sw, usableh) < 0)
		raise "fail:canvas";

	drawbackground(u, sw, usableh);

	if(ui->shadowwindow(u, LayerId, ShadowId, WinId, wx, wy, ww, wh, " Renderer ", 1, 1) < 0)
		raise "fail:shadowwindow";

	if(ui->label(u, WinId, TitleId, 3, 2, 54, "Renderer owns the final terminal image.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, InfoId, 3, 4, 54, "The tree describes state; renderer converts it to cells.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, ModeId, 3, 6, 54, "") < 0)
		raise "fail:mode";

	if(ui->button(u, WinId, BtnFrameId, 3, 9, 12, 1, "Frame", "f", AppTarget, "app.frame") < 0)
		raise "fail:frame";

	if(ui->button(u, WinId, BtnStatusId, 17, 9, 12, 1, "Status", "s", AppTarget, "app.status") < 0)
		raise "fail:status";

	if(ui->button(u, WinId, BtnExitId, 31, 9, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnFrameId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.frame"){
		framemode = (framemode + 1) % 3;
		refresh(u);
		return 0;
	}

	if(cmd == "app.status"){
		statuscount++;
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
	framemode = 0;
	statuscount = 0;

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