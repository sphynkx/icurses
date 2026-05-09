#
# 05_06_focusability.b
#
# Demonstrates focusable elements.
#
# Labels and groups are part of the tree but do not participate in focus
# navigation. Buttons are focusable, unless hidden or disabled.
#

implement FocusabilityDemo;

include "draw.m";
include "icurses/ui.m";

FocusabilityDemo: module
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
TitleId: con 12;
InfoId: con 13;
StateId: con 14;
ActivatedId: con 15;

BtnAId: con 20;
BtnBId: con 21;
BtnCId: con 22;
BtnHideBId: con 23;
BtnDisableCId: con 24;
BtnRestoreId: con 25;
BtnExitId: con 26;

bvisible: int;
cenabled: int;

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

sendnode(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

refresh(u: ref IcUi->Ui)
{
	s: string;

	s = "Button B: ";
	if(bvisible)
		s += "visible";
	else
		s += "hidden";

	s += " | Button C: ";
	if(cenabled)
		s += "enabled";
	else
		s += "disabled";

	ui->settext(u, StateId, s);
	ui->setstatus(u, s);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, w, h: int;

	root = ui->rootid(u);

	w = 76;
	h = 17;
	x = center(sw, w);
	y = center(sh, h);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Tab moves between focusable buttons | hide/disable changes focus flow | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, w, h, " Focusable elements ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 66, "Buttons are focusable. Labels and groups are tree nodes but not focus targets.") < 0)
		raise "fail:title";

	if(ui->label(u, WinId, InfoId, 3, 4, 66, "Try Tab before and after hiding Button B or disabling Button C.") < 0)
		raise "fail:info";

	if(ui->label(u, WinId, StateId, 3, 6, 66, "") < 0)
		raise "fail:state";

	if(ui->label(u, WinId, ActivatedId, 3, 8, 66, "Activated: none") < 0)
		raise "fail:activated";

	if(ui->button(u, WinId, BtnAId, 3, 11, 10, 1, "A", "", AppTarget, "app.a") < 0)
		raise "fail:a";

	if(ui->button(u, WinId, BtnBId, 15, 11, 10, 1, "B", "", AppTarget, "app.b") < 0)
		raise "fail:b";

	if(ui->button(u, WinId, BtnCId, 27, 11, 10, 1, "C", "", AppTarget, "app.c") < 0)
		raise "fail:c";

	if(ui->button(u, WinId, BtnHideBId, 3, 14, 12, 1, "Hide B", "b", AppTarget, "app.hide.b") < 0)
		raise "fail:hide b";

	if(ui->button(u, WinId, BtnDisableCId, 17, 14, 14, 1, "Disable C", "c", AppTarget, "app.disable.c") < 0)
		raise "fail:disable c";

	if(ui->button(u, WinId, BtnRestoreId, 33, 14, 12, 1, "Restore", "r", AppTarget, "app.restore") < 0)
		raise "fail:restore";

	if(ui->button(u, WinId, BtnExitId, 47, 14, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	bvisible = 1;
	cenabled = 1;

	ui->setfocus(u, BtnAId);
	refresh(u);
}

activate(u: ref IcUi->Ui, name: string)
{
	ui->settext(u, ActivatedId, "Activated: " + name);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.a"){
		activate(u, "Button A");
		return 0;
	}

	if(cmd == "app.b"){
		activate(u, "Button B");
		return 0;
	}

	if(cmd == "app.c"){
		activate(u, "Button C");
		return 0;
	}

	if(cmd == "app.hide.b"){
		if(bvisible){
			sendnode(u, BtnBId, "node.hide");
			bvisible = 0;
		}
		else{
			sendnode(u, BtnBId, "node.show");
			bvisible = 1;
		}
		refresh(u);
		return 0;
	}

	if(cmd == "app.disable.c"){
		if(cenabled){
			sendnode(u, BtnCId, "node.disable");
			cenabled = 0;
		}
		else{
			sendnode(u, BtnCId, "node.enable");
			cenabled = 1;
		}
		refresh(u);
		return 0;
	}

	if(cmd == "app.restore"){
		if(!bvisible){
			sendnode(u, BtnBId, "node.show");
			bvisible = 1;
		}
		if(!cenabled){
			sendnode(u, BtnCId, "node.enable");
			cenabled = 1;
		}
		refresh(u);
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