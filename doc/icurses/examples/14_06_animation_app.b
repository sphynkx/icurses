#
# 14_06_animation_app.b
#
# Demonstrates an animation application template.
#
# The application uses UI ticks for periodic updates. Animation state is stored
# in application variables, then rendered into a canvas on each tick.
#

implement AnimationTemplate;

include "draw.m";
include "icurses/ui.m";

AnimationTemplate: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

CanvasW: con 54;
CanvasH: con 10;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

CanvasBoxId: con 20;
CanvasId: con 21;

StateBoxId: con 30;
State1Id: con 31;
State2Id: con 32;
State3Id: con 33;

BtnStartId: con 40;
BtnPauseId: con 41;
BtnResetId: con 42;
BtnExitId: con 43;

running: int;
frame: int;
xpos: int;
dx: int;

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

drawanim(u: ref IcUi->Ui)
{
	i: int;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(i = 0; i < CanvasW; i++){
		if(i % 6 == 0)
			ui->canvasputc(u, CanvasId, i, CanvasH / 2, ".", "0");
	}

	ui->canvasputs(u, CanvasId, xpos, CanvasH / 2, "@@@", "7");
	ui->canvasputs(u, CanvasId, 2, 1, "tick-driven renderer-owned animation", "0");
}

refresh(u: ref IcUi->Ui)
{
	drawanim(u);

	if(running)
		ui->settext(u, State1Id, "Running: yes");
	else
		ui->settext(u, State1Id, "Running: no");

	ui->settext(u, State2Id, "Frame: " + sys->sprint("%d", frame));
	ui->settext(u, State3Id, "Position: " + sys->sprint("%d", xpos));

	ui->setstatus(u, "animation frame=" + sys->sprint("%d", frame));
	ui->draw(u);
}

tick(u: ref IcUi->Ui)
{
	if(!running)
		return;

	frame++;
	xpos += dx;

	if(xpos <= 0){
		xpos = 0;
		dx = 1;
	}

	if(xpos >= CanvasW - 3){
		xpos = CanvasW - 3;
		dx = -1;
	}

	refresh(u);
}

resetstate(u: ref IcUi->Ui)
{
	running = 0;
	frame = 0;
	xpos = 2;
	dx = 1;
	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 20);

	ui->settick(u, 120);
	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Animation template | ticks update state, then redraw canvas | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 20, " Animation template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 76, "Animation state belongs to the application; drawing belongs to the renderer.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CanvasBoxId, 3, 4, 60, 12, " Animation canvas ") < 0)
		raise "fail:canvas box";

	if(ui->canvas(u, CanvasBoxId, CanvasId, 2, 1, CanvasW, CanvasH) < 0)
		raise "fail:canvas";

	if(ui->window(u, WinId, StateBoxId, 66, 4, 15, 12, " State ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, State1Id, 1, 2, 12, "") < 0)
		raise "fail:state 1";

	if(ui->label(u, StateBoxId, State2Id, 1, 4, 11, "") < 0)
		raise "fail:state 2";

	if(ui->label(u, StateBoxId, State3Id, 1, 6, 11, "") < 0)
		raise "fail:state 3";

	if(ui->button(u, WinId, BtnStartId, 3, 17, 10, 1, "Start", "s", AppTarget, "app.start") < 0)
		raise "fail:start";

	if(ui->button(u, WinId, BtnPauseId, 15, 17, 10, 1, "Pause", "p", AppTarget, "app.pause") < 0)
		raise "fail:pause";

	if(ui->button(u, WinId, BtnResetId, 27, 17, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 39, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	running = 0;
	frame = 0;
	xpos = 2;
	dx = 1;

	ui->setfocus(u, BtnStartId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.start"){
		running = 1;
		refresh(u);
		return 0;
	}

	if(cmd == "app.pause"){
		running = 0;
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetstate(u);
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
			tick(u);

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