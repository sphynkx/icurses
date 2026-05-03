implement HelloIcurses;

include "draw.m";
include "icurses/ui.m";

HelloIcurses: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;

AppLayer: con "layer.app";
AppX: con 10;
AppY: con 10;

Background: con "canvas.background";
BgCode: con "0";

MainWin: con "win.main";
MainText: con "lbl.main";
MainButtons: con "grp.main.buttons";
BtnOk: con "btn.ok";
BtnHelp: con "btn.help";

HelpLayer: con "layer.help";
HelpWin: con "win.help";
HelpText: con "lbl.help";
BtnHelpOk: con "btn.help.ok";

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

minint(a, b: int): int
{
	if(a < b)
		return a;

	return b;
}

maxint(a, b: int): int
{
	if(a > b)
		return a;

	return b;
}

center(v, size: int): int
{
	x: int;

	x = (v - size) / 2;
	if(x < 0)
		x = 0;

	return x;
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

enterappscreen()
{
	if(out == nil)
		return;

	if(appscreen)
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

sampleline(i: int): string
{
	case i % 5 {
	0 =>
		return "Renderer-owned background text. Shadow keeps glyphs and changes only their style.";

	1 =>
		return "Containers form a tree: root, windows, groups, controls, labels, and canvas nodes.";

	2 =>
		return "This short text block is drawn by canvas so layered windows can be demonstrated.";

	3 =>
		return "Terminal default colors are used here: no explicit black background is requested.";

	* =>
		return "Open Help to see a grouped window and its shadow shown and hidden together.";
	}
}

drawbackground(u: ref IcUi->Ui, w, h, y0, y1: int)
{
	y, n, lastrow: int;
	line: string;

	ui->canvasclear(u, Background, " ", BgCode);

	lastrow = h - 1;
	if(lastrow < 0)
		lastrow = 0;

	y0 = clamp(y0, 0, lastrow);
	y1 = clamp(y1, 0, lastrow);

	if(y1 < y0)
		return;

	n = 0;
	for(y = y0; y <= y1; y++){
		line = sampleline(n);
		ui->canvasputs(u, Background, 1, y, line, BgCode);
		n++;
	}

	w = w;
}

showhelp(u: ref IcUi->Ui)
{
	m: IcMsg->Msg;

	m = msg->newmsg("app", HelpLayer, IcMsg->KindCommand, "node.show");
	ui->dispatch(u, m);

	ui->setfocus(u, BtnHelpOk);
	ui->setstatus(u, "Help opened");
	ui->draw(u);
}

hidehelp(u: ref IcUi->Ui)
{
	m: IcMsg->Msg;

	m = msg->newmsg("app", HelpLayer, IcMsg->KindCommand, "node.hide");
	ui->dispatch(u, m);

	ui->setfocus(u, BtnHelp);
	ui->setstatus(u, "Help closed");
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root: string;
	appx, appy, appw, apph: int;
	mainx, mainy, mainw, mainh: int;
	helpx, helpy, helpw, helph: int;
	usableh, blockx, blocky, blockw, blockh: int;
	bgy0, bgy1: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);

	mainw = 44;
	mainh = 9;
	helpw = 36;
	helph = 7;

	usableh = sh;
	if(usableh > 2)
		usableh -= 2;

	if(usableh < 1)
		usableh = sh;

	appx = AppX;
	appy = AppY;
	appw = sw - appx;
	apph = usableh - appy;

	if(appw < mainw){
		appx = 0;
		appw = sw;
	}

	if(apph < mainh){
		appy = 0;
		apph = usableh;
	}

	if(appw < 1)
		appw = 1;
	if(apph < 1)
		apph = 1;

	if(appw >= mainw + helpw + 6){
		blockw = mainw + helpw + 6;
		blockh = maxint(mainh, helph);

		blockx = center(appw, blockw);
		blocky = center(apph, blockh);

		mainx = blockx;
		mainy = blocky + center(blockh, mainh);

		helpx = blockx + mainw + 4;
		helpy = blocky + center(blockh, helph);
	}
	else{
		blockw = maxint(mainw, helpw);
		blockh = mainh + helph + 2;

		blockx = center(appw, blockw);
		blocky = center(apph, blockh);

		mainx = blockx + center(blockw, mainw);
		mainy = blocky;

		helpx = blockx + center(blockw, helpw);
		helpy = blocky + mainh + 2;

		if(blockh > apph){
			mainy = center(apph, mainh);
			helpy = mainy + mainh + 1;

			if(helpy + helph > apph)
				helpy = mainy - helph - 1;

			if(helpy < 0)
				helpy = clamp(mainy + mainh + 1, 0, apph - helph);
		}
	}

	mainx = clamp(mainx, 0, appw - mainw);
	helpx = clamp(helpx, 0, appw - helpw);
	mainy = clamp(mainy, 0, apph - mainh);
	helpy = clamp(helpy, 0, apph - helph);

	ui->setframestyle(u, IcPaint->FrameDouble);
	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Enter activates focused button | Tab changes focus | q/Esc exits ");

	ui->group(u, root, AppLayer, appx, appy, appw, apph);

	ui->canvas(u, AppLayer, Background, 0, 0, appw, apph);

	bgy0 = minint(mainy, helpy) - 2;
	bgy1 = maxint(mainy + mainh, helpy + helph) + 1;
	drawbackground(u, appw, apph, bgy0, bgy1);

	ui->shadowwindow(u, AppLayer, MainWin, mainx, mainy, mainw, mainh, " Hello ", 1, 1);
	ui->label(u, MainWin, MainText, 4, 2, 34, "Welcome to Inferno!!");

	ui->group(u, MainWin, MainButtons, 8, 5, 28, 1);
	ui->button(u, MainButtons, BtnOk, 0, 0, 10, 1, "OK", "", "app", "app.ok");
	ui->button(u, MainButtons, BtnHelp, 14, 0, 10, 1, "Help", "", "app", "app.help");

	ui->group(u, AppLayer, HelpLayer, 0, 0, appw, apph);
	ui->shadowwindow(u, HelpLayer, HelpWin, helpx, helpy, helpw, helph, " Help ", 1, 1);
	ui->label(u, HelpWin, HelpText, 4, 2, 26, "Welcome to Icurses!!");
	ui->button(u, HelpWin, BtnHelpOk, 13, 4, 10, 1, "OK", "", "app", "app.help.ok");

	m = msg->newmsg("app", HelpLayer, IcMsg->KindCommand, "node.hide");
	ui->dispatch(u, m);

	ui->setfocus(u, BtnOk);
	ui->setstatus(u, "Ready");
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
	ui->draw(u);

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
			if(s.msg.cmd == "app.ok")
				done = 1;
			else if(s.msg.cmd == "app.help")
				showhelp(u);
			else if(s.msg.cmd == "app.help.ok")
				hidehelp(u);
			else
				ui->draw(u);

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