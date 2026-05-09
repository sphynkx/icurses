#
# 02_04_message_routing.b
#
# Demonstrates command messages routed from UI elements to application code.
#
# Each button sends a command message. The application receives the message,
# inspects its cmd/src/dst fields, updates application state, and redraws the UI.
#

implement MessageRoutingDemo;

include "draw.m";
include "icurses/ui.m";

MessageRoutingDemo: module
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
IntroId: con 12;
RouteId: con 13;
CountId: con 14;
PingId: con 15;
LastActionId: con 16;
LastMsgId: con 17;

BtnAddId: con 20;
BtnSubId: con 21;
BtnResetId: con 22;
BtnPingId: con 23;
BtnExitId: con 24;

value: int;
pings: int;
handled: int;
lastaction: string;

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

msgline(m: IcMsg->Msg): string
{
	if(m.kind == IcMsg->KindNone)
		return "Last message: none";

	return "Last message: cmd=" +
		m.cmd +
		" src=" +
		sys->sprint("%d", m.src) +
		" dst=" +
		sys->sprint("%d", m.dst) +
		" seq=" +
		sys->sprint("%d", m.seq) +
		" handled=" +
		sys->sprint("%d", m.handled);
}

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	ui->settext(u, CountId, "Counter: " + sys->sprint("%d", value));
	ui->settext(u, PingId, "Ping replies: " + sys->sprint("%d", pings));
	ui->settext(u, LastActionId, "Last action: " + lastaction);
	ui->settext(u, LastMsgId, msgline(m));

	ui->setstatus(u, "handled commands=" + sys->sprint("%d", handled));
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 76;
	h = 16;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Buttons send command messages to AppTarget | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Message routing ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, IntroId, 3, 2, 66, "Each button sends an IcMsg command. The app handles m.cmd.") < 0)
		raise "fail:intro";

	if(ui->label(u, WinId, RouteId, 3, 4, 66, "Commands: app.add, app.sub, app.reset, app.ping, app.exit") < 0)
		raise "fail:route";

	if(ui->label(u, WinId, CountId, 3, 6, 66, "") < 0)
		raise "fail:count";

	if(ui->label(u, WinId, PingId, 3, 7, 66, "") < 0)
		raise "fail:ping";

	if(ui->label(u, WinId, LastActionId, 3, 8, 66, "") < 0)
		raise "fail:last action";

	if(ui->label(u, WinId, LastMsgId, 3, 10, 68, "") < 0)
		raise "fail:last msg";

	if(ui->button(u, WinId, BtnAddId, 3, 13, 10, 1, "Add", "+", AppTarget, "app.add") < 0)
		raise "fail:add button";

	if(ui->button(u, WinId, BtnSubId, 15, 13, 10, 1, "Sub", "-", AppTarget, "app.sub") < 0)
		raise "fail:sub button";

	if(ui->button(u, WinId, BtnResetId, 27, 13, 12, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset button";

	if(ui->button(u, WinId, BtnPingId, 41, 13, 10, 1, "Ping", "p", AppTarget, "app.ping") < 0)
		raise "fail:ping button";

	if(ui->button(u, WinId, BtnExitId, 53, 13, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	ui->setfocus(u, BtnAddId);
	refresh(u, msg->none());
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.kind == IcMsg->KindNone){
		ui->draw(u);
		return 0;
	}

	if(m.cmd == "app.exit")
		return 1;

	handled++;

	if(m.cmd == "app.add"){
		value++;
		lastaction = "Add command increased the counter.";
	}
	else if(m.cmd == "app.sub"){
		value--;
		lastaction = "Sub command decreased the counter.";
	}
	else if(m.cmd == "app.reset"){
		value = 0;
		pings = 0;
		lastaction = "Reset command cleared counter and ping replies.";
	}
	else if(m.cmd == "app.ping"){
		pings++;
		lastaction = "Ping command was routed to the app and acknowledged.";
	}
	else
		lastaction = "Unknown command: " + m.cmd;

	refresh(u, m);
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
	pings = 0;
	handled = 0;
	lastaction = "none";

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
				done = handlemsg(u, s.msg);

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