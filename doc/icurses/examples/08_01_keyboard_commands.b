#
# 08_01_keyboard_commands.b
#
# Demonstrates keyboard handling through IcUi step model.
#
# The example shows a small keyboard map. Pressing A/S/D changes highlighted
# keys and runs command messages. Tab/Enter can still activate buttons.
#

implement KeyboardCommandsDemo;

include "draw.m";
include "icurses/ui.m";

KeyboardCommandsDemo: module
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

KeyboardBoxId: con 20;
KeyAId: con 21;
KeySId: con 22;
KeyDId: con 23;
KeyQId: con 24;

EventBoxId: con 30;
LastKeyId: con 31;
LastCmdId: con 32;
CountId: con 33;

BtnAId: con 40;
BtnSId: con 41;
BtnDId: con 42;
BtnExitId: con 43;

lastkey: int;
lastcmd: string;
keys: int;
commands: int;
active: string;

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

keycap(name: string): string
{
	if(active == name)
		return "[*" + name + "*]";

	return "[ " + name + " ]";
}

keytext(k: int): string
{
	if(k < 0)
		return "none";

	if(k >= 32 && k < 127)
		return sys->sprint("%c", k);

	return ic->keyname(k);
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, KeyAId, keycap("A"));
	ui->settext(u, KeySId, keycap("S"));
	ui->settext(u, KeyDId, keycap("D"));
	ui->settext(u, KeyQId, keycap("Q"));

	ui->settext(u, LastKeyId, "Last key: " + keytext(lastkey));
	ui->settext(u, LastCmdId, "Last command: " + lastcmd);
	ui->settext(u, CountId, "Key events: " + sys->sprint("%d", keys) +
		" | command messages: " + sys->sprint("%d", commands));

	ui->setstatus(u, "keyboard demo active key=" + active);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);

	x = center(sw, 76);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Press A/S/D or activate buttons | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 86, 18, " Keyboard commands ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, InfoId, 3, 2, 66, "Keyboard input is mapped to commands and visual key states.") < 0)
		raise "fail:info";

	if(ui->window(u, WinId, KeyboardBoxId, 3, 4, 34, 6, " Keyboard map ") < 0)
		raise "fail:keyboard box";

	if(ui->label(u, KeyboardBoxId, KeyAId, 4, 2, 8, "") < 0)
		raise "fail:key a";

	if(ui->label(u, KeyboardBoxId, KeySId, 13, 2, 8, "") < 0)
		raise "fail:key s";

	if(ui->label(u, KeyboardBoxId, KeyDId, 22, 2, 8, "") < 0)
		raise "fail:key d";

	if(ui->label(u, KeyboardBoxId, KeyQId, 13, 3, 8, "") < 0)
		raise "fail:key q";

	if(ui->window(u, WinId, EventBoxId, 40, 4, 40, 6, " Last event ") < 0)
		raise "fail:event box";

	if(ui->label(u, EventBoxId, LastKeyId, 2, 1, 26, "") < 0)
		raise "fail:last key";

	if(ui->label(u, EventBoxId, LastCmdId, 2, 2, 26, "") < 0)
		raise "fail:last cmd";

	if(ui->label(u, EventBoxId, CountId, 2, 3, 36, "") < 0)
		raise "fail:count";

	if(ui->button(u, WinId, BtnAId, 3, 13, 10, 1, "A", "a", AppTarget, "app.key.a") < 0)
		raise "fail:button a";

	if(ui->button(u, WinId, BtnSId, 15, 13, 10, 1, "S", "s", AppTarget, "app.key.s") < 0)
		raise "fail:button s";

	if(ui->button(u, WinId, BtnDId, 27, 13, 10, 1, "D", "d", AppTarget, "app.key.d") < 0)
		raise "fail:button d";

	if(ui->button(u, WinId, BtnExitId, 39, 13, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	if(ui->bindkey(u, "a", AppTarget, "app.key.a") < 0)
		raise "fail:bind a";

	if(ui->bindkey(u, "s", AppTarget, "app.key.s") < 0)
		raise "fail:bind s";

	if(ui->bindkey(u, "d", AppTarget, "app.key.d") < 0)
		raise "fail:bind d";

	ui->setfocus(u, BtnAId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "")
		return 0;

	if(cmd == "app.exit")
		return 1;

	commands++;
	lastcmd = cmd;

	if(cmd == "app.key.a")
		active = "A";
	else if(cmd == "app.key.s")
		active = "S";
	else if(cmd == "app.key.d")
		active = "D";

	refresh(u);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;
	lastkey = -1;
	lastcmd = "none";
	keys = 0;
	commands = 0;
	active = "A";

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
			lastkey = s.key;
			keys++;

			if(ui->isquit(s.key))
				done = 1;
			else
				done = handlecmd(u, s.msg.cmd);

			if(!done && s.msg.cmd == "")
				refresh(u);

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