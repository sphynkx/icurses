#
# 08_05_step_model.b
#
# Demonstrates the IcUi Step model with visible event cards.
#
# StepKey and StepTick are shown as separate cards. Commands update the message
# card. Tick periodically highlights the tick card.
#

implement StepModelDemo;

include "draw.m";
include "icurses/ui.m";

StepModelDemo: module
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

KeyCardId: con 20;
KeyTitleId: con 21;
KeyLineId: con 22;

TickCardId: con 30;
TickTitleId: con 31;
TickLineId: con 32;

MsgCardId: con 40;
MsgTitleId: con 41;
MsgLineId: con 42;
MsgRouteId: con 43;

BtnAlphaId: con 50;
BtnBetaId: con 51;
BtnExitId: con 52;

ticks: int;
lastkey: int;
lastcmd: string;
activecard: string;

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

keytext(k: int): string
{
	if(k < 0)
		return "none";

	if(k >= 32 && k < 127)
		return sys->sprint("%c", k);

	return ic->keyname(k);
}

title(card, name: string): string
{
	if(activecard == card)
		return ">> " + name;

	return "   " + name;
}

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	ui->settext(u, KeyTitleId, title("key", "StepKey card"));
	ui->settext(u, TickTitleId, title("tick", "StepTick card"));
	ui->settext(u, MsgTitleId, title("msg", "Message card"));

	ui->settext(u, KeyLineId, "Last key: " + keytext(lastkey));
	ui->settext(u, TickLineId, "Ticks: " + sys->sprint("%d", ticks));

	if(m.kind == IcMsg->KindNone){
		ui->settext(u, MsgLineId, "Message: none");
		ui->settext(u, MsgRouteId, "Route: none");
	}
	else{
		ui->settext(u, MsgLineId, "cmd=" + m.cmd);
		ui->settext(u, MsgRouteId, "src=" + sys->sprint("%d", m.src) +
			" dst=" + sys->sprint("%d", m.dst));
	}

	ui->setstatus(u, "last active step card: " + activecard);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 78);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Press buttons or wait for tick to see Step cards update | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 18, " Step model ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 68, "IcUi->step() returns normalized events: key, tick, mouse, done.") < 0)
		raise "fail:info";

	if(ui->window(u, WinId, KeyCardId, 3, 4, 22, 6, " Key ") < 0)
		raise "fail:key card";

	if(ui->label(u, KeyCardId, KeyTitleId, 2, 1, 18, "") < 0)
		raise "fail:key title";

	if(ui->label(u, KeyCardId, KeyLineId, 2, 3, 18, "") < 0)
		raise "fail:key line";

	if(ui->window(u, WinId, TickCardId, 28, 4, 22, 6, " Tick ") < 0)
		raise "fail:tick card";

	if(ui->label(u, TickCardId, TickTitleId, 2, 1, 18, "") < 0)
		raise "fail:tick title";

	if(ui->label(u, TickCardId, TickLineId, 2, 3, 18, "") < 0)
		raise "fail:tick line";

	if(ui->window(u, WinId, MsgCardId, 53, 4, 22, 6, " Msg ") < 0)
		raise "fail:msg card";

	if(ui->label(u, MsgCardId, MsgTitleId, 2, 1, 18, "") < 0)
		raise "fail:msg title";

	if(ui->label(u, MsgCardId, MsgLineId, 2, 2, 18, "") < 0)
		raise "fail:msg line";

	if(ui->label(u, MsgCardId, MsgRouteId, 2, 3, 18, "") < 0)
		raise "fail:msg route";

	if(ui->button(u, WinId, BtnAlphaId, 3, 13, 10, 1, "Alpha", "a", AppTarget, "app.alpha") < 0)
		raise "fail:alpha";

	if(ui->button(u, WinId, BtnBetaId, 15, 13, 10, 1, "Beta", "b", AppTarget, "app.beta") < 0)
		raise "fail:beta";

	if(ui->button(u, WinId, BtnExitId, 27, 13, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	ui->setfocus(u, BtnAlphaId);
	refresh(u, msg->none());
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	ticks = 0;
	lastkey = -1;
	lastcmd = "none";
	activecard = "none";

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

	ui->settick(u, 1000);
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
			lastkey = s.key;
			activecard = "key";

			if(ui->isquit(s.key) || s.msg.cmd == "app.exit")
				done = 1;
			else{
				if(s.msg.kind != IcMsg->KindNone)
					activecard = "msg";
				refresh(u, s.msg);
			}

		IcUi->StepTick =>
			ticks++;
			activecard = "tick";
			refresh(u, msg->none());

		IcUi->StepMouse =>
			activecard = "mouse";
			refresh(u, msg->none());

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