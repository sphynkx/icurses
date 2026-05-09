#
# 01_canvas_clock.b
#
# Demonstrates renderer-managed canvas drawing with timer updates.
#

implement CanvasClockDemo;

include "draw.m";
include "icurses/ui.m";

CanvasClockDemo: module
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
TickId: con 14;
BtnPauseId: con 15;
BtnExitId: con 16;

CanvasW: con 48;
CanvasH: con 7;

tick: int;
paused: int;

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

bartext(pos, w: int): string
{
	i: int;
	s: string;

	s = "";
	for(i = 0; i < w; i++){
		if(i == pos)
			s += "*";
		else if(i % 6 == 0)
			s += "|";
		else
			s += "-";
	}

	return s;
}

drawcanvas(u: ref IcUi->Ui)
{
	pos, row: int;
	line: string;

	pos = tick % CanvasW;

	ui->canvasclear(u, CanvasId, " ", "0");
	ui->canvasputs(u, CanvasId, 0, 0, "+----------------------------------------------+", "0");

	for(row = 1; row < CanvasH - 1; row++){
		line = "|" + bartext((pos + row * 5) % (CanvasW - 2), CanvasW - 2) + "|";
		ui->canvasputs(u, CanvasId, 0, row, line, "0");
	}

	ui->canvasputs(u, CanvasId, 0, CanvasH - 1, "+----------------------------------------------+", "0");

	ui->settext(u, TickId, "Tick: " + sys->sprint("%d", tick) + " | Canvas is redrawn through IcUi canvas helpers.");

	if(paused)
		ui->setstatus(u, "paused");
	else
		ui->setstatus(u, "running");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 70;
	h = 16;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " p pauses animation | timer updates canvas | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Canvas renderer ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 62, "Canvas is still part of the renderer-owned UI tree.") < 0)
		raise "fail:info";

	if(ui->canvas(u, WinId, CanvasId, 10, 4, CanvasW, CanvasH) < 0)
		raise "fail:canvas";

	if(ui->label(u, WinId, TickId, 3, 12, 62, "") < 0)
		raise "fail:tick label";

	if(ui->button(u, WinId, BtnPauseId, 3, 14, 12, 1, "Pause", "p", AppTarget, "app.pause") < 0)
		raise "fail:pause button";

	if(ui->button(u, WinId, BtnExitId, 17, 14, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnPauseId);
	drawcanvas(u);
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

		drawcanvas(u);
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
	tick = 0;
	paused = 0;

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

	ui->settick(u, 150);
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
				tick++;
				drawcanvas(u);
			}

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