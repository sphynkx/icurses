#
# 03_01_runtime_setup.b
#
# Runtime setup and adaptive terminal geometry for a small icurses application.
#
# This example demonstrates:
#   - interface include files;
#   - runtime module loading;
#   - module initialization;
#   - terminal size detection through Icurses;
#   - creation of the Ui object;
#   - live resize detection;
#   - rebuilding the Ui after terminal size changes.
#

implement RuntimeSetupDemo;

include "draw.m";
include "icurses/ui.m";

RuntimeSetupDemo: module
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
ModulesId: con 13;
InitId: con 14;
TerminalId: con 15;
UiId: con 16;
ResizeId: con 17;
HintId: con 18;
BtnRefreshId: con 19;
BtnExitId: con 20;

DefaultW: con 80;
DefaultH: con 24;
MinW: con 20;
MinH: con 8;
MaxW: con 300;
MaxH: con 120;

ResizeCheckMs: con 250;

cw: int;
ch: int;
conssource: string;
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

clamp(v, lo, hi: int): int
{
	if(hi < lo)
		hi = lo;

	if(v < lo)
		return lo;

	if(v > hi)
		return hi;

	return v;
}

center(total, size: int): int
{
	x: int;

	x = (total - size) / 2;
	if(x < 0)
		x = 0;

	return x;
}

fieldw(winw: int): int
{
	w: int;

	w = winw - 6;
	if(w < 1)
		w = 1;

	return w;
}

readconsoleparams()
{
	ci: Icurses->ConsInfo;
	w, h: int;

	cw = DefaultW;
	ch = DefaultH;
	conssource = "default";

	ci = ic->consinfo();

	if(ci.ok){
		cw = ci.cols;
		ch = ci.rows;
		conssource = ci.source;
	}
	else{
		(w, h) = ic->termsize();
		if(w > 0)
			cw = w;
		if(h > 0)
			ch = h;
		conssource = "termsize";
	}

	if(cw <= 0 || cw > MaxW)
		cw = DefaultW;
	if(ch <= 0 || ch > MaxH)
		ch = DefaultH;

	if(cw < MinW)
		cw = MinW;
	if(ch < MinH)
		ch = MinH;
}

setrows(u: ref IcUi->Ui, h: int)
{
	if(h >= 2)
		ui->setstatusrows(u, h - 2, h - 1);
	else
		ui->setstatusrows(u, -1, -1);
}

refresh(u: ref IcUi->Ui, note: string)
{
	if(u == nil)
		return;

	ui->settext(u, ModulesId, "Loaded modules: Sys, Icurses, IcUi");
	ui->settext(u, InitId, "Initialized modules: Icurses, IcUi");
	ui->settext(u, TerminalId, "Terminal: " +
		sys->sprint("%d", cw) +
		" x " +
		sys->sprint("%d", ch) +
		" source=" +
		conssource);
	ui->settext(u, UiId, "Ui object: tree + renderer + keymap + help/status + event channels");
	ui->settext(u, ResizeId, "Resize rebuilds: " + sys->sprint("%d", resizes));
	ui->settext(u, HintId, "Resize the console: this example polls geometry and rebuilds the Ui.");

	if(note != "")
		ui->setstatus(u, note);
	else
		ui->setstatus(u, "runtime setup ready");

	ui->draw(u);
}

build(u: ref IcUi->Ui)
{
	root, x, y, w, h, usableh, fw: int;

	root = ui->rootid(u);

	usableh = ch;
	if(usableh > 2)
		usableh -= 2;
	if(usableh < 1)
		usableh = ch;

	w = 72;
	if(w > cw)
		w = cw;
	if(w < 1)
		w = 1;

	h = 14;
	if(h > usableh)
		h = usableh;
	if(h < 1)
		h = 1;

	x = center(cw, w);
	y = center(usableh, h);

	fw = fieldw(w);

	setrows(u, ch);
	ui->sethelp(u, " r refreshes terminal information | resize console to rebuild | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, cw, ch) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Runtime setup ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, fw, "Runtime module setup and live terminal geometry.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, ModulesId, 3, 4, fw, "") < 0)
		raise "fail:modules label";

	if(ui->label(u, WinId, InitId, 3, 5, fw, "") < 0)
		raise "fail:init label";

	if(ui->label(u, WinId, TerminalId, 3, 6, fw, "") < 0)
		raise "fail:terminal label";

	if(ui->label(u, WinId, UiId, 3, 7, fw, "") < 0)
		raise "fail:ui label";

	if(ui->label(u, WinId, ResizeId, 3, 8, fw, "") < 0)
		raise "fail:resize label";

	if(ui->label(u, WinId, HintId, 3, 9, fw, "") < 0)
		raise "fail:hint label";

	if(h >= 13 && w >= 34){
		if(ui->button(u, WinId, BtnRefreshId, 3, 11, 14, 1, "Refresh", "r", AppTarget, "app.refresh") < 0)
			raise "fail:refresh button";

		if(ui->button(u, WinId, BtnExitId, 20, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
			raise "fail:exit button";

		ui->setfocus(u, BtnRefreshId);
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

	#
	# The input/tick worker processes are already running. The new Ui object is
	# attached to the existing event flow by marking it as running.
	#
	nu.running = 1;

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

	readconsoleparams();

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

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.refresh"){
		readconsoleparams();
		refresh(u, "terminal information refreshed");
		return 0;
	}

	ui->draw(u);
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
	readconsoleparams();

	u = ui->new(out, cw, ch);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	ui->settick(u, 100);
	build(u);
	refresh(u, "runtime setup ready");

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
			if(u == nil){
				done = 1;
				break;
			}

			if(ui->isquit(s.key))
				done = 1;
			else
				done = handlecmd(u, s.msg.cmd);

		IcUi->StepTick =>
			u = maybecheckresize(u);
			if(u == nil)
				done = 1;

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	if(u != nil)
		ui->close(u);

	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}