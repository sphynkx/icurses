#
# 14_02_settings_form.b
#
# Demonstrates a settings form application template.
#
# The template keeps form state in application variables. Buttons change state,
# Apply commits it, and Reset restores defaults. Theme and Level have visible
# effects in the preview area so the form demonstrates real UI feedback.
#

implement SettingsFormTemplate;

include "draw.m";
include "icurses/ui.m";

SettingsFormTemplate: module
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

FormBoxId: con 20;
ThemeId: con 21;
AutosaveId: con 22;
LevelId: con 23;
DirtyId: con 24;
LevelProgressId: con 25;

PreviewBoxId: con 30;
PreviewCanvasId: con 31;
Preview1Id: con 32;
Preview2Id: con 33;

BtnThemeId: con 40;
BtnAutosaveId: con 41;
BtnLevelId: con 42;
BtnApplyId: con 43;
BtnResetId: con 44;
BtnExitId: con 45;

themeid: int;
autosave: int;
level: int;
dirty: int;
applies: int;

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

themename(): string
{
	if(themeid == 0)
		return "classic";
	if(themeid == 1)
		return "light";
	return "matrix";
}

onoff(v: int): string
{
	if(v)
		return "on";

	return "off";
}

themecode(): string
{
	if(themeid == 0)
		return "37;44";
	if(themeid == 1)
		return "30;47";
	return "1;32;40";
}

themefocus(): string
{
	if(themeid == 0)
		return "30;46";
	if(themeid == 1)
		return "30;43";
	return "30;42";
}

drawpreview(u: ref IcUi->Ui)
{
	i, filled: int;
	code, focus: string;

	code = themecode();
	focus = themefocus();

	ui->canvasclear(u, PreviewCanvasId, " ", code);
	ui->canvasputs(u, PreviewCanvasId, 2, 1, "Theme preview: " + themename(), code);

	if(autosave)
		ui->canvasputs(u, PreviewCanvasId, 2, 3, "Autosave indicator: ON ", focus);
	else
		ui->canvasputs(u, PreviewCanvasId, 2, 3, "Autosave indicator: OFF", code);

	ui->canvasputs(u, PreviewCanvasId, 2, 5, "Level intensity:", code);

	filled = level * 4;
	for(i = 0; i < 24; i++){
		if(i < filled)
			ui->canvasputc(u, PreviewCanvasId, 2 + i, 6, "#", focus);
		else
			ui->canvasputc(u, PreviewCanvasId, 2 + i, 6, ".", code);
	}
}

refresh(u: ref IcUi->Ui)
{
	drawpreview(u);

	ui->settext(u, ThemeId, "Theme: " + themename());
	ui->settext(u, AutosaveId, "Autosave: " + onoff(autosave));
	ui->settext(u, LevelId, "Level: " + sys->sprint("%d", level));

	if(dirty)
		ui->settext(u, DirtyId, "State: modified, Apply is needed");
	else
		ui->settext(u, DirtyId, "State: clean");

	ui->setprogress(u, LevelProgressId, level, 5);

	ui->settext(u, Preview1Id, "Applied count: " + sys->sprint("%d", applies));
	ui->settext(u, Preview2Id, "Preview is redrawn from form state.");

	ui->setstatus(u, "settings form: theme=" + themename() + " level=" + sys->sprint("%d", level));
	ui->draw(u);
}

resetdefaults()
{
	themeid = 0;
	autosave = 1;
	level = 2;
	dirty = 0;
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 21);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Theme changes preview colors | Level changes progress/intensity | Apply commits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 21, " Settings form template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 78, "Form state is stored in application variables and reflected in preview UI.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, FormBoxId, 3, 4, 34, 11, " Settings ") < 0)
		raise "fail:form box";

	if(ui->label(u, FormBoxId, ThemeId, 2, 2, 28, "") < 0)
		raise "fail:theme";

	if(ui->label(u, FormBoxId, AutosaveId, 2, 3, 28, "") < 0)
		raise "fail:autosave";

	if(ui->label(u, FormBoxId, LevelId, 2, 4, 28, "") < 0)
		raise "fail:level";

	if(ui->progress(u, FormBoxId, LevelProgressId, 2, 6, 24, 0, 5) < 0)
		raise "fail:level progress";

	if(ui->label(u, FormBoxId, DirtyId, 2, 8, 28, "") < 0)
		raise "fail:dirty";

	if(ui->window(u, WinId, PreviewBoxId, 41, 4, 40, 11, " Live preview ") < 0)
		raise "fail:preview box";

	if(ui->canvas(u, PreviewBoxId, PreviewCanvasId, 2, 1, 30, 7) < 0)
		raise "fail:preview canvas";

	if(ui->label(u, PreviewBoxId, Preview1Id, 2, 8, 30, "") < 0)
		raise "fail:preview 1";

	if(ui->label(u, PreviewBoxId, Preview2Id, 2, 9, 36, "") < 0)
		raise "fail:preview 2";

	if(ui->button(u, WinId, BtnThemeId, 3, 18, 10, 1, "Theme", "t", AppTarget, "app.theme") < 0)
		raise "fail:theme button";

	if(ui->button(u, WinId, BtnAutosaveId, 15, 18, 13, 1, "Autosave", "a", AppTarget, "app.autosave") < 0)
		raise "fail:autosave button";

	if(ui->button(u, WinId, BtnLevelId, 30, 18, 10, 1, "Level", "l", AppTarget, "app.level") < 0)
		raise "fail:level button";

	if(ui->button(u, WinId, BtnApplyId, 42, 18, 10, 1, "Apply", "p", AppTarget, "app.apply") < 0)
		raise "fail:apply";

	if(ui->button(u, WinId, BtnResetId, 54, 18, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 66, 18, 9, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	resetdefaults();
	applies = 0;

	ui->setfocus(u, BtnThemeId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.theme"){
		themeid++;
		if(themeid > 2)
			themeid = 0;
		dirty = 1;
		refresh(u);
		return 0;
	}

	if(cmd == "app.autosave"){
		autosave = !autosave;
		dirty = 1;
		refresh(u);
		return 0;
	}

	if(cmd == "app.level"){
		level++;
		if(level > 5)
			level = 1;
		dirty = 1;
		refresh(u);
		return 0;
	}

	if(cmd == "app.apply"){
		dirty = 0;
		applies++;
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetdefaults();
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