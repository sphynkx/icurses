#
# 06_04_resize_polling.b
#
# Demonstrates resize polling.
#
# The example periodically checks terminal geometry. When the size changes, it
# rebuilds the Ui to avoid drawing outside the new renderer bounds.
#

implement ResizePollingDemo;

include "draw.m";
include "icurses/ui.m";

ResizePollingDemo: module
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
SizeId: con 13;
ResizeId: con 14;
HintId: con 15;
BtnExitId: con 16;

ResizeCheckMs: con 250;

cw: int;
ch: int;
resizes: int;
lastresizecheck: int;

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

readsize()
{
	w, h: int;

	(w, h) = ic->termsize();

	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	cw = w;
	ch = h;
}

setrows(u: ref IcUi->Ui)
{
	if(ch >= 2)
		ui->setstatusrows(u, ch - 2, ch - 1);
	else
		ui->setstatusrows(u, -1, -1);
}

refresh(u: ref IcUi->Ui, note: string)
{
	ui->settext(u, SizeId, "Current size: " + sys->sprint("%d", cw) + " x " + sys->sprint("%d", ch));
	ui->settext(u, ResizeId, "Detected resize count: " + sys->sprint("%d", resizes));
	ui->settext(u, HintId, "Resize the console; polling runs on tick events.");

	if(note == "")
		note = "resize polling active";

	ui->setstatus(u, note);
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
	if(w > 70)
		w = 70;
	if(w < 1)
		w = cw;

	h = 11;
	if(h > usableh)
		h = usableh;
	if(h < 1)
		h = 1;

	x = center(cw, w);
	y = center(usableh, h);

	textw = w - 6;
	if(textw < 1)
		textw = 1;

	setrows(u);
	ui->sethelp(u, " Resize polling: tick checks terminal size | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, cw, ch) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Resize polling ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, textw, "Resize is detected by comparing current and previous geometry.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, SizeId, 3, 4, textw, "") < 0)
		raise "fail:size";

	if(ui->label(u, WinId, ResizeId, 3, 5, textw, "") < 0)
		raise "fail:resize";

	if(ui->label(u, WinId, HintId, 3, 7, textw, "") < 0)
		raise "fail:hint";

	if(w >= 20 && h >= 10){
		if(ui->button(u, WinId, BtnExitId, 3, h - 2, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
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
	note: string;

	nu = ui->new(out, cw, ch);
	if(nu == nil)
		return u;

	detachold(u);

	nu.running = 1;
	nu.tickms = 100;

	resizes++;

	build(nu);

	note = "resize " +
		sys->sprint("%d", oldw) +
		"x" +
		sys->sprint("%d", oldh) +
		" -> " +
		sys->sprint("%d", cw) +
		"x" +
		sys->sprint("%d", ch);

	refresh(nu, note);

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

	enterappscreen();

	readsize();

	u = ui->new(out, cw, ch);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	ui->settick(u, 100);
	build(u);
	refresh(u, "resize polling active");

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