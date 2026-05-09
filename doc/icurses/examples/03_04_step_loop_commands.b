#
# 03_04_step_loop_commands.b
#
# Demonstrates the step-based event loop and command handling.
#
# Buttons and global key bindings both produce command messages.
#

implement StepLoopCommandsDemo;

include "draw.m";
include "icurses/ui.m";

StepLoopCommandsDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
InfoId: con 12;
LastKeyId: con 13;
LastCmdId: con 14;
LastMsgId: con 15;
CountId: con 16;

BtnAlphaId: con 20;
BtnBetaId: con 21;
BtnGammaId: con 22;
BtnExitId: con 23;

count: int;

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

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic->init();
	ui->init();
	msg->init();
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

msgsummary(m: IcMsg->Msg): string
{
	if(m.kind == IcMsg->KindNone)
		return "message: none";

	return "message: cmd=" +
		m.cmd +
		" src=" +
		sys->sprint("%d", m.src) +
		" dst=" +
		sys->sprint("%d", m.dst) +
		" seq=" +
		sys->sprint("%d", m.seq);
}

refresh(u: ref IcUi->Ui, key: int, m: IcMsg->Msg)
{
	if(key >= 0)
		ui->settext(u, LastKeyId, "Last key: " + ic->keyname(key) + " code=" + sys->sprint("%d", key));

	if(m.kind != IcMsg->KindNone)
		ui->settext(u, LastCmdId, "Last command: " + m.cmd);

	ui->settext(u, LastMsgId, msgsummary(m));
	ui->settext(u, CountId, "Handled command count: " + sys->sprint("%d", count));

	ui->setstatus(u, "step loop processed " + sys->sprint("%d", count) + " commands");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 74;
	h = 15;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " a/b/g are global key bindings | Tab/Enter uses focused buttons | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Step loop and commands ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 64, "IcUi->step() returns key events, command messages, ticks, and done.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, LastKeyId, 3, 4, 64, "Last key: none") < 0)
		raise "fail:key label";

	if(ui->label(u, WinId, LastCmdId, 3, 5, 64, "Last command: none") < 0)
		raise "fail:cmd label";

	if(ui->label(u, WinId, LastMsgId, 3, 6, 64, "message: none") < 0)
		raise "fail:msg label";

	if(ui->label(u, WinId, CountId, 3, 8, 64, "") < 0)
		raise "fail:count label";

	if(ui->button(u, WinId, BtnAlphaId, 3, 11, 10, 1, "Alpha", "", AppTarget, "app.alpha") < 0)
		raise "fail:alpha button";

	if(ui->button(u, WinId, BtnBetaId, 15, 11, 10, 1, "Beta", "", AppTarget, "app.beta") < 0)
		raise "fail:beta button";

	if(ui->button(u, WinId, BtnGammaId, 27, 11, 10, 1, "Gamma", "", AppTarget, "app.gamma") < 0)
		raise "fail:gamma button";

	if(ui->button(u, WinId, BtnExitId, 39, 11, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	if(ui->bindkey(u, "a", AppTarget, "app.alpha") < 0)
		raise "fail:bind alpha";

	if(ui->bindkey(u, "b", AppTarget, "app.beta") < 0)
		raise "fail:bind beta";

	if(ui->bindkey(u, "g", AppTarget, "app.gamma") < 0)
		raise "fail:bind gamma";

	ui->setfocus(u, BtnAlphaId);
	refresh(u, -1, msg->none());
}

handlemsg(u: ref IcUi->Ui, key: int, m: IcMsg->Msg): int
{
	if(m.cmd == "app.exit")
		return 1;

	if(m.cmd == "app.alpha" || m.cmd == "app.beta" || m.cmd == "app.gamma")
		count++;

	refresh(u, key, m);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	count = 0;

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
				done = handlemsg(u, s.key, s.msg);

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