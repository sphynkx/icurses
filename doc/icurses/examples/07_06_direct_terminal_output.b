#
# 07_06_direct_terminal_output.b
#
# Demonstrates direct terminal output and renderer recovery.
#
# The Direct button writes a red banner outside IcUi. Then the example forces a
# renderer redraw by invalidating the front buffer. This keeps the visible demo
# effect while avoiding a full Ui rebuild.
#

implement DirectTerminalOutputDemo;

include "draw.m";
include "icurses/ui.m";

DirectTerminalOutputDemo: module
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
WarningId: con 13;
RecoverId: con 14;
CountId: con 15;

BtnDirectId: con 20;
BtnExitId: con 21;

directwrites: int;
bannerrow: int;
bannercol: int;

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

refresh(u: ref IcUi->Ui, note: string)
{
	ui->settext(u, CountId, "Direct writes: " + sys->sprint("%d", directwrites));

	if(note == "")
		note = "renderer owns the screen";

	ui->setstatus(u, note);
	ui->draw(u);
}

directwrite()
{
	if(out == nil)
		return;

	ic->cup(out, bannerrow + 1, bannercol + 1);
	ic->sgr(out, "1;37;41");
	sys->fprint(out, " DIRECT TERMINAL OUTPUT OUTSIDE RENDERER ");
	ic->resettty(out);

	sys->sleep(350);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 76);
	y = center(sh, 15);

	bannerrow = y + 6;
	bannercol = x + 16;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Direct writes a red banner, then renderer redraws itself | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 76, 15, " Direct terminal output ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 66, "Direct terminal writes bypass renderer front/back buffer state.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, WarningId, 3, 4, 66, "The red banner is printed outside IcUi for a short moment.") < 0)
		raise "fail:warning";

	if(ui->label(u, WinId, RecoverId, 3, 5, 66, "Then the front buffer is invalidated and Ui redraws the screen.") < 0)
		raise "fail:recover";

	if(ui->label(u, WinId, CountId, 3, 8, 66, "") < 0)
		raise "fail:count";

	if(ui->button(u, WinId, BtnDirectId, 3, 11, 12, 1, "Direct", "d", AppTarget, "app.direct") < 0)
		raise "fail:direct button";

	if(ui->button(u, WinId, BtnExitId, 17, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnDirectId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.direct"){
		directwrites++;
		directwrite();
		invalidatefront(u);
		refresh(u, "renderer redrawn after direct terminal output");
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
	directwrites = 0;

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