#
# 07_07_full_redraw_rebuild.b
#
# Demonstrates full redraw by invalidating renderer front buffer.
#
# Damage writes over the canvas area outside the renderer and leaves the screen
# visually inconsistent. FullDraw invalidates the front buffer and redraws the
# current tree state, restoring the canvas.
#

implement FullRedrawRebuildDemo;

include "draw.m";
include "icurses/ui.m";

FullRedrawRebuildDemo: module
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
TitleId: con 12;
StateId: con 13;
ExplainId: con 14;
CanvasId: con 15;

BtnUpdateId: con 20;
BtnDamageId: con 21;
BtnFullDrawId: con 22;
BtnExitId: con 23;

value: int;
fulldraws: int;
damages: int;
damagex: int;
damagey: int;

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

invalidatefront(u: ref IcUi->Ui)
{
	i, n: int;
	bad: IcPaint->Cell;

	if(u == nil || u.renderer == nil || u.renderer.front == nil)
		return;

	bad.ch = "\001";
	bad.code = "";
	bad.sig = -999999;

	n = len u.renderer.front;
	for(i = 0; i < n; i++)
		u.renderer.front[i] = bad;
}

drawcanvas(u: ref IcUi->Ui)
{
	y, x, pos: int;
	line: string;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(y = 0; y < 5; y++){
		line = "";
		pos = (value + y * 4) % 54;

		for(x = 0; x < 54; x++){
			if(x == pos)
				line += "*";
			else if(x % 6 == 0)
				line += "|";
			else
				line += "-";
		}

		ui->canvasputs(u, CanvasId, 0, y, line, "0");
	}
}

refresh(u: ref IcUi->Ui, note: string)
{
	drawcanvas(u);

	ui->settext(u, StateId, "value=" +
		sys->sprint("%d", value) +
		" damages=" +
		sys->sprint("%d", damages) +
		" full redraws=" +
		sys->sprint("%d", fulldraws));

	if(note == "")
		note = "normal renderer-owned draw";

	ui->setstatus(u, note);
	ui->draw(u);
}

damage()
{
	if(out == nil)
		return;

	ic->cup(out, damagey + 1, damagex + 1);
	ic->sgr(out, "1;37;41");
	sys->fprint(out, " SCREEN DAMAGE OUTSIDE RENDERER ");
	ic->resettty(out);
}

fulldraw(u: ref IcUi->Ui)
{
	fulldraws++;
	invalidatefront(u);
	refresh(u, "full redraw repaired renderer-owned screen");
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 76);
	y = center(sh, 18);

	damagex = x + 18;
	damagey = y + 10;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Damage corrupts canvas outside renderer | FullDraw repairs | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 76, 18, " Full redraw ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 66, "Full redraw is visible when screen state is no longer trustworthy.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, StateId, 3, 4, 66, "") < 0)
		raise "fail:state";

	if(ui->label(u, WinId, ExplainId, 3, 5, 66, "Use Damage, then FullDraw to repair the canvas area.") < 0)
		raise "fail:explain";

	if(ui->canvas(u, WinId, CanvasId, 8, 8, 54, 5) < 0)
		raise "fail:canvas";

	if(ui->button(u, WinId, BtnUpdateId, 3, 15, 10, 1, "Update", "u", AppTarget, "app.update") < 0)
		raise "fail:update";

	if(ui->button(u, WinId, BtnDamageId, 15, 15, 12, 1, "Damage", "d", AppTarget, "app.damage") < 0)
		raise "fail:damage";

	if(ui->button(u, WinId, BtnFullDrawId, 29, 15, 14, 1, "FullDraw", "f", AppTarget, "app.fulldraw") < 0)
		raise "fail:fulldraw";

	if(ui->button(u, WinId, BtnExitId, 45, 15, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnUpdateId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.update"){
		value++;
		refresh(u, "canvas changed through renderer");
		return 0;
	}

	if(cmd == "app.damage"){
		damages++;
		damage();
		ui->setstatus(u, "screen damaged outside renderer; press FullDraw");
		return 0;
	}

	if(cmd == "app.fulldraw"){
		fulldraw(u);
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
	value = 0;
	fulldraws = 0;
	damages = 0;

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