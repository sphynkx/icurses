#
# 06_05_rebuild_ui.b
#
# Demonstrates full Ui rebuild with preserved application state.
#
# Inc changes visible application state. Rebuild switches between normal and
# compact layout while keeping the value, meter, and canvas pattern.
#

implement RebuildUiDemo;

include "draw.m";
include "icurses/ui.m";

RebuildUiDemo: module
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
ModeId: con 13;
ValueId: con 14;
ProgressId: con 15;
CanvasId: con 16;

BtnIncId: con 20;
BtnRebuildId: con 21;
BtnExitId: con 22;

cw: int;
ch: int;
compact: int;
value: int;
rebuilds: int;
canvasw: int;
canvash: int;

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

readsize()
{
	(cw, ch) = ic->termsize();

	if(cw <= 0)
		cw = Icurses->DefaultCols;
	if(ch <= 0)
		ch = Icurses->DefaultRows;
}

center(total, size: int): int
{
	x: int;

	x = (total - size) / 2;
	if(x < 0)
		x = 0;

	return x;
}

drawpattern(u: ref IcUi->Ui)
{
	x, y, pos: int;
	line: string;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(y = 0; y < canvash; y++){
		line = "";
		pos = (value + y * 3) % canvasw;

		for(x = 0; x < canvasw; x++){
			if(x == pos)
				line += "*";
			else if(x % 5 == 0)
				line += "|";
			else
				line += "-";
		}

		ui->canvasputs(u, CanvasId, 0, y, line, "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	mode: string;

	if(compact)
		mode = "compact";
	else
		mode = "normal";

	ui->settext(u, ModeId, "Layout mode: " + mode + " | rebuilds=" + sys->sprint("%d", rebuilds));
	ui->settext(u, ValueId, "Preserved value: " + sys->sprint("%d", value));
	ui->setprogress(u, ProgressId, value % 101, 100);
	drawpattern(u);

	ui->setstatus(u, "state is preserved across rebuild");
	ui->draw(u);
}

build(u: ref IcUi->Ui)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	if(compact){
		w = 54;
		h = 15;
		canvasw = 38;
		canvash = 3;
	}
	else{
		w = 78;
		h = 19;
		canvasw = 60;
		canvash = 5;
	}

	x = center(cw, w);
	y = center(ch, h);

	ui->setstatusrows(u, ch - 2, ch - 1);
	ui->sethelp(u, " Inc changes preserved state | Rebuild changes layout | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, cw, ch) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Rebuild Ui ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, w - 6, "Rebuild creates a new tree; application state is reapplied.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, ModeId, 3, 4, w - 6, "") < 0)
		raise "fail:mode";

	if(ui->label(u, WinId, ValueId, 3, 5, w - 6, "") < 0)
		raise "fail:value";

	if(ui->progress(u, WinId, ProgressId, 3, 7, w - 10, value % 101, 100) < 0)
		raise "fail:progress";

	if(ui->canvas(u, WinId, CanvasId, 5, 9, canvasw, canvash) < 0)
		raise "fail:canvas";

	if(ui->button(u, WinId, BtnIncId, 3, h - 3, 10, 1, "Inc", "i", AppTarget, "app.inc") < 0)
		raise "fail:inc";

	if(ui->button(u, WinId, BtnRebuildId, 15, h - 3, 14, 1, "Rebuild", "r", AppTarget, "app.rebuild") < 0)
		raise "fail:rebuild";

	if(ui->button(u, WinId, BtnExitId, 31, h - 3, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnIncId);
	refresh(u);
}

detachold(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	u.running = 0;

	if(u.renderer != nil){
		u.renderer.front = nil;
		u.renderer.back = nil;
		u.renderer.out = nil;
	}

	u.tree = nil;
}

rebuildui(u: ref IcUi->Ui): ref IcUi->Ui
{
	nu: ref IcUi->Ui;

	readsize();

	nu = ui->new(out, cw, ch);
	if(nu == nil)
		return u;

	detachold(u);

	nu.running = 1;
	rebuilds++;
	build(nu);

	return nu;
}

handlecmd(u: ref IcUi->Ui, cmd: string): (ref IcUi->Ui, int)
{
	if(cmd == "app.exit")
		return (u, 1);

	if(cmd == "app.inc"){
		value += 7;
		refresh(u);
		return (u, 0);
	}

	if(cmd == "app.rebuild"){
		compact = !compact;
		u = rebuildui(u);
		return (u, 0);
	}

	ui->draw(u);
	return (u, 0);
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	done: int;

	out = sys->fildes(1);
	appscreen = 0;
	compact = 0;
	value = 0;
	rebuilds = 0;

	enterappscreen();
	readsize();

	u = ui->new(out, cw, ch);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	build(u);

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
				(u, done) = handlecmd(u, s.msg.cmd);

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