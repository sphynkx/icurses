#
# 11_06_slider_mixer.b
#
# Demonstrates Slider helper elements and vertical value bars.
#
# Horizontal sliders are focusable controls. The right side mirrors the same
# values as vertical bars so both horizontal and vertical value presentation is
# visible in one demo.
#

implement SliderMixerDemo;

include "draw.m";
include "icurses/slider.m";

SliderMixerDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
slider: IcSlider;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

MixerBoxId: con 20;
VolumeId: con 21;
BassId: con 22;
TrebleId: con 23;

BarsBoxId: con 30;
VolumeBarId: con 31;
BassBarId: con 32;
TrebleBarId: con 33;
BarsLabelId: con 34;

SummaryId: con 40;

BtnFocusVolumeId: con 50;
BtnFocusBassId: con 51;
BtnFocusTrebleId: con 52;
BtnMinusId: con 53;
BtnPlusId: con 54;
BtnResetId: con 55;
BtnExitId: con 56;

active: int;

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

	slider = load IcSlider IcSlider->PATH;
	if(slider == nil)
		raise "fail:load icslider";

	ic->init();
	ui->init();
	slider->init();
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

activename(): string
{
	if(active == VolumeId)
		return "Volume";
	if(active == BassId)
		return "Bass";
	if(active == TrebleId)
		return "Treble";
	return "none";
}

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	v, b, t: int;

	v = slider->value(u, VolumeId);
	b = slider->value(u, BassId);
	t = slider->value(u, TrebleId);

	ui->setbar(u, VolumeBarId, v, 100);
	ui->setbar(u, BassBarId, b, 100);
	ui->setbar(u, TrebleBarId, t, 100);

	ui->settext(u, SummaryId, "Active=" + activename() +
		" volume=" + sys->sprint("%d", v) +
		" bass=" + sys->sprint("%d", b) +
		" treble=" + sys->sprint("%d", t));

	if(m.kind != IcMsg->KindNone)
		ui->setstatus(u, "slider message: " + m.cmd + " value=" + sys->sprint("%d", m.iarg0));
	else
		ui->setstatus(u, "slider mixer ready");

	ui->draw(u);
}

setactive(u: ref IcUi->Ui, id: int)
{
	active = id;
	ui->setfocus(u, id);
	refresh(u, slider->activatefocused(u));
}

changeactive(u: ref IcUi->Ui, delta: int)
{
	m: IcMsg->Msg;

	ui->setfocus(u, active);

	if(delta < 0)
		m = slider->dec(u, active);
	else
		m = slider->inc(u, active);

	refresh(u, m);
}

reset(u: ref IcUi->Ui)
{
	slider->setvalue(u, VolumeId, 65);
	slider->setvalue(u, BassId, 40);
	slider->setvalue(u, TrebleId, 55);

	active = VolumeId;
	ui->setfocus(u, active);
	refresh(u, slider->activatefocused(u));
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 21);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " v/b/t or 1/2/3 select slider | +/- changes active slider | arrows also work ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 21, " Slider mixer ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 68, "Sliders hold numeric values; vertical bars mirror those values.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, MixerBoxId, 3, 4, 48, 9, " Horizontal sliders ") < 0)
		raise "fail:mixer box";

	if(slider->slider(u, MixerBoxId, VolumeId, 3, 2, 40, "Volume", "v", AppTarget, "app.slider.volume", 65, 0, 100) < 0)
		raise "fail:volume";

	if(slider->slider(u, MixerBoxId, BassId, 3, 4, 40, "Bass", "b", AppTarget, "app.slider.bass", 40, 0, 100) < 0)
		raise "fail:bass";

	if(slider->slider(u, MixerBoxId, TrebleId, 3, 6, 40, "Treble", "t", AppTarget, "app.slider.treble", 55, 0, 100) < 0)
		raise "fail:treble";

	if(ui->window(u, WinId, BarsBoxId, 55, 4, 20, 9, " Vertical bars ") < 0)
		raise "fail:bars box";

	if(ui->vbar(u, BarsBoxId, VolumeBarId, 4, 1, 6, 65, 100) < 0)
		raise "fail:volume bar";

	if(ui->vbar(u, BarsBoxId, BassBarId, 9, 1, 6, 40, 100) < 0)
		raise "fail:bass bar";

	if(ui->vbar(u, BarsBoxId, TrebleBarId, 14, 1, 6, 55, 100) < 0)
		raise "fail:treble bar";

	if(ui->label(u, BarsBoxId, BarsLabelId, 2, 7, 16, " V    B    T") < 0)
		raise "fail:bars label";

	if(ui->label(u, WinId, SummaryId, 3, 14, 70, "") < 0)
		raise "fail:summary";

	if(ui->button(u, WinId, BtnFocusVolumeId, 3, 18, 10, 1, "Volume", "1", AppTarget, "app.focus.volume") < 0)
		raise "fail:focus volume";

	if(ui->button(u, WinId, BtnFocusBassId, 15, 18, 10, 1, "Bass", "2", AppTarget, "app.focus.bass") < 0)
		raise "fail:focus bass";

	if(ui->button(u, WinId, BtnFocusTrebleId, 27, 18, 10, 1, "Treble", "3", AppTarget, "app.focus.treble") < 0)
		raise "fail:focus treble";

	if(ui->button(u, WinId, BtnMinusId, 39, 18, 8, 1, "-", "-", AppTarget, "app.dec") < 0)
		raise "fail:minus";

	if(ui->button(u, WinId, BtnPlusId, 49, 18, 8, 1, "+", "+", AppTarget, "app.inc") < 0)
		raise "fail:plus";

	if(ui->button(u, WinId, BtnResetId, 59, 18, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 67, 18, 8, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	active = VolumeId;
	ui->setfocus(u, active);
	m = slider->activatefocused(u);
	refresh(u, m);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.focus.volume" || cmd == "app.slider.volume"){
		setactive(u, VolumeId);
		return 0;
	}

	if(cmd == "app.focus.bass" || cmd == "app.slider.bass"){
		setactive(u, BassId);
		return 0;
	}

	if(cmd == "app.focus.treble" || cmd == "app.slider.treble"){
		setactive(u, TrebleId);
		return 0;
	}

	if(cmd == "app.dec"){
		changeactive(u, -1);
		return 0;
	}

	if(cmd == "app.inc"){
		changeactive(u, 1);
		return 0;
	}

	if(cmd == "app.reset"){
		reset(u);
		return 0;
	}

	ui->draw(u);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	m: IcMsg->Msg;
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
			else{
				m = slider->handlekey(u, s.key);
				if(m.kind != IcMsg->KindNone)
					done = handlecmd(u, m.cmd);
				else
					done = handlecmd(u, s.msg.cmd);
			}

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