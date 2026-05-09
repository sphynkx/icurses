#
# 06_06_canvas_resize.b
#
# Demonstrates canvas rebuild after resize.
#
# Canvas size is tied to the tree node size. When terminal geometry changes,
# this example rebuilds the Ui and recreates the canvas with matching size.
#

implement CanvasResizeDemo;

include "draw.m";
include "icurses/ui.m";

CanvasResizeDemo: module
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
SizeId: con 14;
BtnExitId: con 15;

ResizeCheckMs: con 250;

cw: int;
ch: int;
canvasw: int;
canvash: int;
resizes: int;
lastresizecheck: int;
frame: int;

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

barline(pos, width: int): string
{
	i: int;
	s: string;

	s = "";

	for(i = 0; i < width; i++){
		if(i == pos)
			s += "*";
		else if(i % 5 == 0)
			s += "|";
		else
			s += "-";
	}

	return s;
}

drawcanvas(u: ref IcUi->Ui)
{
	y, pos: int;

	if(canvasw <= 0 || canvash <= 0)
		return;

	ui->canvasclear(u, CanvasId, " ", "0");

	for(y = 0; y < canvash; y++){
		pos = (frame + y * 3) % canvasw;
		ui->canvasputs(u, CanvasId, 0, y, barline(pos, canvasw), "0");
	}

	ui->settext(u, SizeId, "Canvas: " +
		sys->sprint("%d", canvasw) +
		" x " +
		sys->sprint("%d", canvash) +
		" | resizes=" +
		sys->sprint("%d", resizes));

	ui->setstatus(u, "canvas resized with Ui tree");
	ui->draw(u);
}

build(u: ref IcUi->Ui)
{
	root, usableh, x, y, w, h, textw: int;

	root = ui->rootid(u);

	usableh = ch;
	if(usableh > 2)
		usableh -= 2;

	w = cw - 4;
	if(w > 78)
		w = 78;
	if(w < 1)
		w = cw;

	h = usableh - 2;
	if(h > 20)
		h = 20;
	if(h < 8)
		h = usableh;
	if(h < 1)
		h = 1;

	x = center(cw, w);
	y = center(usableh, h);

	textw = w - 6;
	if(textw < 1)
		textw = 1;

	canvasw = w - 8;
	if(canvasw < 1)
		canvasw = 1;

	canvash = h - 8;
	if(canvash < 1)
		canvash = 1;

	if(ch >= 2)
		ui->setstatusrows(u, ch - 2, ch - 1);
	else
		ui->setstatusrows(u, -1, -1);

	ui->sethelp(u, " Canvas is recreated after resize | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, cw, ch) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Canvas resize ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, textw, "Canvas dimensions are derived from current window geometry.") < 0)
		raise "fail:info";

	if(ui->canvas(u, WinId, CanvasId, 4, 4, canvasw, canvash) < 0)
		raise "fail:canvas";

	if(ui->label(u, WinId, SizeId, 3, h - 3, textw, "") < 0)
		raise "fail:size";

	if(w >= 20 && h >= 8){
		if(ui->button(u, WinId, BtnExitId, w - 13, h - 2, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
			raise "fail:exit";

		ui->setfocus(u, BtnExitId);
	}
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

rebuildui(u: ref IcUi->Ui, oldw, oldh: int): ref IcUi->Ui
{
	nu: ref IcUi->Ui;

	nu = ui->new(out, cw, ch);
	if(nu == nil)
		return u;

	detachold(u);

	nu.running = 1;
	nu.tickms = 120;

	resizes++;

	build(nu);
	drawcanvas(nu);

	oldw = oldw;
	oldh = oldh;

	return nu;
}

checkresize(u: ref IcUi->Ui): ref IcUi->Ui
{
	oldw, oldh: int;

	oldw = cw;
	oldh = ch;

	readsize();

	if(cw == oldw && ch == oldh)
		return u;

	return rebuildui(u, oldw, oldh);
}

maybecheckresize(u: ref IcUi->Ui): ref IcUi->Ui
{
	now: int;

	now = sys->millisec();

	if(lastresizecheck != 0 && now - lastresizecheck < ResizeCheckMs)
		return u;

	lastresizecheck = now;
	return checkresize(u);
}

handlecmd(cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	done: int;

	out = sys->fildes(1);
	appscreen = 0;
	resizes = 0;
	lastresizecheck = 0;
	frame = 0;

	enterappscreen();

	readsize();

	u = ui->new(out, cw, ch);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	ui->settick(u, 120);
	build(u);
	drawcanvas(u);

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
			u = checkresize(u);
			if(ui->isquit(s.key))
				done = 1;
			else
				done = handlecmd(s.msg.cmd);

		IcUi->StepTick =>
			u = maybecheckresize(u);
			frame++;
			drawcanvas(u);

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