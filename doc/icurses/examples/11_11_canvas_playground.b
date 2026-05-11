#
# 11_11_canvas_playground.b
#
# Demonstrates Canvas elements.
#
# Canvas is a renderer-owned custom drawing area. This example draws a moving
# marker, grid lines and a small trail without writing directly to terminal.
#

implement CanvasPlaygroundDemo;

include "draw.m";
include "icurses/ui.m";

CanvasPlaygroundDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

CanvasW: con 50;
CanvasH: con 10;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

CanvasFrameId: con 20;
CanvasId: con 21;

InspectorBoxId: con 30;
PositionId: con 31;
FramesId: con 32;
ModeId: con 33;

BtnLeftId: con 40;
BtnRightId: con 41;
BtnUpId: con 42;
BtnDownId: con 43;
BtnAutoId: con 44;
BtnClearId: con 45;
BtnExitId: con 46;

px: int;
py: int;
frames: int;
auto: int;
dx: int;
dy: int;

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

clamp(v, lo, hi: int): int
{
	if(v < lo)
		return lo;
	if(v > hi)
		return hi;
	return v;
}

drawcanvas(u: ref IcUi->Ui)
{
	x, y: int;
	line: string;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(y = 0; y < CanvasH; y++){
		line = "";
		for(x = 0; x < CanvasW; x++){
			if(x == px && y == py)
				line += "@";
			else if((x + y + frames) % 17 == 0)
				line += "*";
			else if(x % 10 == 0 && y % 2 == 0)
				line += "+";
			else if(y == CanvasH / 2)
				line += "-";
			else if(x == CanvasW / 2)
				line += "|";
			else
				line += ".";
		}
		ui->canvasputs(u, CanvasId, 0, y, line, "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	drawcanvas(u);

	ui->settext(u, PositionId, "Marker position: x=" + sys->sprint("%d", px) + " y=" + sys->sprint("%d", py));
	ui->settext(u, FramesId, "Canvas frames: " + sys->sprint("%d", frames));

	if(auto)
		ui->settext(u, ModeId, "Mode: auto animation");
	else
		ui->settext(u, ModeId, "Mode: manual movement");

	if(auto)
		ui->setstatus(u, "canvas auto animation");
	else
		ui->setstatus(u, "canvas manual drawing");

	ui->draw(u);
}

move(u: ref IcUi->Ui, mx, my: int)
{
	px = clamp(px + mx, 0, CanvasW - 1);
	py = clamp(py + my, 0, CanvasH - 1);
	frames++;
	refresh(u);
}

tickmove(u: ref IcUi->Ui)
{
	if(!auto)
		return;

	px += dx;
	py += dy;

	if(px < 0){
		px = 0;
		dx = 1;
	}
	if(px >= CanvasW){
		px = CanvasW - 1;
		dx = -1;
	}
	if(py < 0){
		py = 0;
		dy = 1;
	}
	if(py >= CanvasH){
		py = CanvasH - 1;
		dy = -1;
	}

	frames++;
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Canvas drawing stays renderer-owned | arrows/buttons move marker | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 90, 22, " Canvas playground ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "Canvas is a custom drawing area owned by the renderer.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CanvasFrameId, 3, 4, 56, 12, " Canvas ") < 0)
		raise "fail:canvas frame";

	if(ui->canvas(u, CanvasFrameId, CanvasId, 2, 1, CanvasW, CanvasH) < 0)
		raise "fail:canvas";

	if(ui->window(u, WinId, InspectorBoxId, 62, 4, 26, 12, " Inspector ") < 0)
		raise "fail:inspector";

	if(ui->label(u, InspectorBoxId, PositionId, 2, 2, 22, "") < 0)
		raise "fail:position";

	if(ui->label(u, InspectorBoxId, FramesId, 2, 5, 22, "") < 0)
		raise "fail:frames";

	if(ui->label(u, InspectorBoxId, ModeId, 2, 8, 22, "") < 0)
		raise "fail:mode";

	if(ui->button(u, WinId, BtnLeftId, 2, 19, 8, 1, "Left", "a", AppTarget, "app.left") < 0)
		raise "fail:left";

	if(ui->button(u, WinId, BtnRightId, 12, 19, 10, 1, "Right", "d", AppTarget, "app.right") < 0)
		raise "fail:right";

	if(ui->button(u, WinId, BtnUpId, 24, 19, 8, 1, "Up", "w", AppTarget, "app.up") < 0)
		raise "fail:up";

	if(ui->button(u, WinId, BtnDownId, 34, 19, 10, 1, "Down", "s", AppTarget, "app.down") < 0)
		raise "fail:down";

	if(ui->button(u, WinId, BtnAutoId, 46, 19, 9, 1, "Auto", "m", AppTarget, "app.auto") < 0)
		raise "fail:auto";

	if(ui->button(u, WinId, BtnClearId, 57, 19, 11, 1, "Clear", "c", AppTarget, "app.clear") < 0)
		raise "fail:clear";

	if(ui->button(u, WinId, BtnExitId, 70, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	px = CanvasW / 2;
	py = CanvasH / 2;
	frames = 0;
	auto = 0;
	dx = 1;
	dy = 1;

	ui->setfocus(u, BtnAutoId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.left"){
		move(u, -1, 0);
		return 0;
	}

	if(cmd == "app.right"){
		move(u, 1, 0);
		return 0;
	}

	if(cmd == "app.up"){
		move(u, 0, -1);
		return 0;
	}

	if(cmd == "app.down"){
		move(u, 0, 1);
		return 0;
	}

	if(cmd == "app.auto"){
		auto = !auto;
		if(auto)
			ui->settext(u, BtnAutoId, "Stop");
		else
			ui->settext(u, BtnAutoId, "Auto");
		refresh(u);
		return 0;
	}

	if(cmd == "app.clear"){
		frames = 0;
		px = CanvasW / 2;
		py = CanvasH / 2;
		ui->canvasclear(u, CanvasId, " ", "0");
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

	ui->settick(u, 120);
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
			tickmove(u);

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