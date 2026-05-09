#
# 07_05_canvas_wave.b
#
# Demonstrates a renderer-owned canvas used for animated custom drawing.
#
# Clear empties the canvas and restarts the wave so new animation enters from
# the right side. This makes the clear action visible and meaningful.
#

implement CanvasWaveDemo;

include "draw.m";
include "icurses/ui.m";

CanvasWaveDemo: module
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
InfoId: con 12;
CanvasId: con 13;
FrameId: con 14;

BtnPauseId: con 20;
BtnClearId: con 21;
BtnExitId: con 22;

CanvasW: con 54;
CanvasH: con 8;

frame: int;
paused: int;
clearing: int;
sweep: int;

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

wavechar(x, y, f: int): string
{
	v: int;

	v = (x + f + y * 3) % 12;

	if(v == 0)
		return "*";
	if(v == 1 || v == 11)
		return "+";
	if(v == 2 || v == 10)
		return "-";
	if(v == 3 || v == 9)
		return ".";
	return " ";
}

drawwave(u: ref IcUi->Ui)
{
	x, y, visiblefrom: int;
	line: string;

	ui->canvasclear(u, CanvasId, " ", "0");

	visiblefrom = 0;
	if(clearing)
		visiblefrom = CanvasW - sweep;

	for(y = 0; y < CanvasH; y++){
		line = "";
		for(x = 0; x < CanvasW; x++){
			if(clearing && x < visiblefrom)
				line += " ";
			else
				line += wavechar(x, y, frame);
		}

		ui->canvasputs(u, CanvasId, 0, y, line, "0");
	}

	if(clearing)
		ui->settext(u, FrameId, "Canvas clear/restart sweep: " + sys->sprint("%d", sweep) + "/" + sys->sprint("%d", CanvasW));
	else
		ui->settext(u, FrameId, "Canvas frame: " + sys->sprint("%d", frame));

	if(paused)
		ui->setstatus(u, "canvas animation paused");
	else if(clearing)
		ui->setstatus(u, "new wave enters from the right");
	else
		ui->setstatus(u, "canvas animation running");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, wx, wy: int;

	root = ui->rootid(u);

	wx = center(sw, 70);
	wy = center(sh, 17);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Canvas wave | Clear restarts wave from right | p pauses | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, wx, wy, 70, 17, " Canvas wave ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 60, "Canvas content is renderer-owned and can be animated safely.") < 0)
		raise "fail:info";

	if(ui->canvas(u, WinId, CanvasId, 8, 4, CanvasW, CanvasH) < 0)
		raise "fail:canvas";

	if(ui->label(u, WinId, FrameId, 3, 13, 60, "") < 0)
		raise "fail:frame label";

	if(ui->button(u, WinId, BtnPauseId, 3, 15, 13, 1, "Pause", "p", AppTarget, "app.pause") < 0)
		raise "fail:pause";

	if(ui->button(u, WinId, BtnClearId, 18, 15, 10, 1, "Clear", "c", AppTarget, "app.clear") < 0)
		raise "fail:clear";

	if(ui->button(u, WinId, BtnExitId, 30, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnPauseId);
	drawwave(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.pause"){
		paused = !paused;
		if(paused)
			ui->settext(u, BtnPauseId, "[ Run ]");
		else
			ui->settext(u, BtnPauseId, "[ Pause ]");

		drawwave(u);
		return 0;
	}

	if(cmd == "app.clear"){
		clearing = 1;
		sweep = 0;
		frame = 0;
		ui->canvasclear(u, CanvasId, " ", "0");
		ui->settext(u, FrameId, "Canvas cleared; waiting for new wave.");
		ui->setstatus(u, "canvas cleared");
		ui->draw(u);
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
	frame = 0;
	paused = 0;
	clearing = 0;
	sweep = 0;

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
			if(!paused){
				frame++;
				if(clearing){
					sweep += 3;
					if(sweep >= CanvasW){
						sweep = CanvasW;
						clearing = 0;
					}
				}
				drawwave(u);
			}

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