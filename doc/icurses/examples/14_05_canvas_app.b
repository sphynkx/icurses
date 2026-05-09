#
# 14_05_canvas_app.b
#
# Demonstrates a canvas-backed application template.
#
# The canvas is the main content area. Application state is rendered into it,
# while buttons and labels provide ordinary UI controls around the canvas.
#
# Shift moves the graph left. Unshift moves it right. Clear blanks the graph
# and Reset restores a complete visible data set.
#

implement CanvasAppTemplate;

include "draw.m";
include "icurses/ui.m";

CanvasAppTemplate: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

GraphW: con 50;
GraphH: con 10;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

CanvasBoxId: con 20;
CanvasId: con 21;

InfoBoxId: con 30;
Info1Id: con 31;
Info2Id: con 32;
Info3Id: con 33;

BtnShiftId: con 40;
BtnUnshiftId: con 41;
BtnClearId: con 42;
BtnResetId: con 43;
BtnExitId: con 44;

values: array of int;
seed: int;
updates: int;
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

nextvalue(): int
{
	seed = (seed * 37 + 17) % 100;
	return seed;
}

drawcanvas(u: ref IcUi->Ui)
{
	x, y, h, n: int;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(x = 0; x < GraphW; x++){
		n = values[x];
		h = (n * GraphH) / 100;

		for(y = 0; y < GraphH; y++){
			if(GraphH - y <= h)
				ui->canvasputc(u, CanvasId, x, y, "#", "0");
			else
				ui->canvasputc(u, CanvasId, x, y, ".", "0");
		}
	}

	ui->canvasputs(u, CanvasId, 2, 0, "canvas-owned scrolling graph", "7");
}

refresh(u: ref IcUi->Ui)
{
	drawcanvas(u);

	ui->settext(u, Info1Id, "Updates: " + sys->sprint("%d", updates));
	ui->settext(u, Info2Id, "Seed: " + sys->sprint("%d", seed));
	ui->settext(u, Info3Id, "Last action: " + lastaction);

	ui->setstatus(u, "canvas app: " + lastaction);
	ui->draw(u);
}

shiftleft()
{
	i: int;

	for(i = 0; i < GraphW - 1; i++)
		values[i] = values[i + 1];

	values[GraphW - 1] = nextvalue();
}

shiftright()
{
	i: int;

	for(i = GraphW - 1; i > 0; i--)
		values[i] = values[i - 1];

	values[0] = nextvalue();
}

clearvalues()
{
	i: int;

	for(i = 0; i < GraphW; i++)
		values[i] = 0;
}

resetvalues()
{
	i: int;

	seed = 23;
	for(i = 0; i < GraphW; i++)
		values[i] = nextvalue();
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Canvas-backed app | Shift left/right | Clear blanks | Reset restores graph ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 22, " Canvas application template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "Canvas is useful when standard widgets are not enough for the main content.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CanvasBoxId, 3, 4, 56, 12, " Canvas content ") < 0)
		raise "fail:canvas box";

	if(ui->canvas(u, CanvasBoxId, CanvasId, 2, 1, GraphW, GraphH) < 0)
		raise "fail:canvas";

	if(ui->window(u, WinId, InfoBoxId, 62, 4, 19, 12, " State ") < 0)
		raise "fail:info box";

	if(ui->label(u, InfoBoxId, Info1Id, 2, 2, 15, "") < 0)
		raise "fail:info 1";

	if(ui->label(u, InfoBoxId, Info2Id, 2, 4, 15, "") < 0)
		raise "fail:info 2";

	if(ui->label(u, InfoBoxId, Info3Id, 2, 6, 15, "") < 0)
		raise "fail:info 3";

	if(ui->button(u, WinId, BtnShiftId, 3, 19, 10, 1, "Shift", "s", AppTarget, "app.shift") < 0)
		raise "fail:shift";

	if(ui->button(u, WinId, BtnUnshiftId, 15, 19, 12, 1, "Unshift", "u", AppTarget, "app.unshift") < 0)
		raise "fail:unshift";

	if(ui->button(u, WinId, BtnClearId, 29, 19, 10, 1, "Clear", "c", AppTarget, "app.clear") < 0)
		raise "fail:clear";

	if(ui->button(u, WinId, BtnResetId, 41, 19, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 53, 19, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	values = array[GraphW] of int;
	resetvalues();

	updates = 0;
	lastaction = "initial graph";

	ui->setfocus(u, BtnShiftId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.shift"){
		shiftleft();
		updates++;
		lastaction = "shifted graph left";
		refresh(u);
		return 0;
	}

	if(cmd == "app.unshift"){
		shiftright();
		updates++;
		lastaction = "shifted graph right";
		refresh(u);
		return 0;
	}

	if(cmd == "app.clear"){
		clearvalues();
		updates++;
		lastaction = "cleared graph";
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetvalues();
		updates++;
		lastaction = "reset graph";
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