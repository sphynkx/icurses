#
# 13_01_theme_color_glyphs.b
#
# Demonstrates themes, color capabilities and glyph policy.
#
# The demo reads /dev/consinfo through Icurses, initializes IcTheme and IcGlyph,
# then displays:
#
#   - terminal color capabilities;
#   - truecolor and UTF-8 flags;
#   - semantic theme attributes;
#   - frame glyph policy;
#   - scrollbar and block glyphs;
#   - double-width text warning;
#   - Windows console related capability notes.
#
# Buttons:
#
#   - Toggle switches between core and effect attributes.
#   - Frame changes frame style for all UI boxes.
#   - Palette switches preview color sets.
#   - Exit closes the demo.
#

implement ThemeColorGlyphsDemo;

include "draw.m";
include "icurses/ui.m";

ThemeColorGlyphsDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
theme: IcTheme;
glyph: IcGlyph;

out: ref Sys->FD;
appscreen: int;
ci: Icurses->ConsInfo;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

CapsBoxId: con 20;
Caps1Id: con 21;
Caps2Id: con 22;
Caps3Id: con 23;
Caps4Id: con 24;
Caps5Id: con 25;

ThemeBoxId: con 30;
ThemeCanvasId: con 31;

FrameBoxId: con 40;
AsciiFrameId: con 41;
SingleFrameId: con 42;
DoubleFrameId: con 43;
GlyphPolicyId: con 44;
ScrollBlockId: con 45;

TextBoxId: con 50;
DoubleWidthId: con 51;
WindowsId: con 52;
FallbackId: con 53;

BtnToggleId: con 60;
BtnFrameId: con 61;
BtnPaletteId: con 62;
BtnExitId: con 63;

showeffects: int;
framestyle: int;
palette: int;

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

	theme = load IcTheme IcTheme->PATH;
	if(theme == nil)
		raise "fail:load ictheme";

	glyph = load IcGlyph IcGlyph->PATH;
	if(glyph == nil)
		raise "fail:load icglyph";

	ic->init();
	ui->init();

	ci = ic->consinfo();
	theme->init(ci);
	glyph->init(ci);
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

booltext(v: int): string
{
	if(v)
		return "yes";

	return "no";
}

profiletext(): string
{
	if(glyph->profile() == IcGlyph->ProfileUnicode)
		return "unicode";

	return "ascii";
}

framestylename(): string
{
	if(framestyle == IcPaint->FrameAscii)
		return "ascii";
	if(framestyle == IcPaint->FrameSingle)
		return "single";
	return "double";
}

palettename(): string
{
	if(palette == 0)
		return "auto theme";
	if(palette == 1)
		return "light";
	if(palette == 2)
		return "console";
	return "matrix";
}

colorsummary(): string
{
	if(theme->truecolor())
		return "truecolor semantic palette";

	if(theme->colors() >= 256)
		return "indexed color palette";

	return "16-color fallback palette";
}

frametext(style: int): string
{
	f: IcGlyph->Frame;

	f = glyph->frame(style);

	return f.nw + f.h + f.h + f.h + f.ne + "  " +
		f.v + "box" + f.v + "  " +
		f.sw + f.h + f.h + f.h + f.se;
}

palettecode(index: int): string
{
	if(palette == 0){
		if(index == 0)
			return theme->sgr(IcTheme->AttrNormal);
		if(index == 1)
			return theme->sgr(IcTheme->AttrWindow);
		if(index == 2)
			return theme->sgr(IcTheme->AttrFrame);
		if(index == 3)
			return theme->sgr(IcTheme->AttrTitle);
		if(index == 4)
			return theme->sgr(IcTheme->AttrButton);
		if(index == 5)
			return theme->sgr(IcTheme->AttrFocus);
		if(index == 6)
			return theme->sgr(IcTheme->AttrStatus);
		if(index == 7)
			return theme->sgr(IcTheme->AttrScroll);
		return theme->sgr(IcTheme->AttrShadow);
	}

	if(palette == 1){
		if(index == 0)
			return "30;47";
		if(index == 1)
			return "37;44";
		if(index == 2)
			return "1;37;44";
		if(index == 3)
			return "1;33;44";
		if(index == 4)
			return "30;46";
		if(index == 5)
			return "30;43";
		if(index == 6)
			return "30;47";
		if(index == 7)
			return "33;44";
		return "37;100";
	}

	if(palette == 2){
		if(index == 0)
			return "37;40";
		if(index == 1)
			return "32;40";
		if(index == 2)
			return "1;32;40";
		if(index == 3)
			return "1;37;40";
		if(index == 4)
			return "30;42";
		if(index == 5)
			return "30;46";
		if(index == 6)
			return "30;47";
		if(index == 7)
			return "1;33;40";
		return "30;100";
	}

	if(index == 0)
		return "32;40";
	if(index == 1)
		return "1;32;40";
	if(index == 2)
		return "0;32;40";
	if(index == 3)
		return "1;37;40";
	if(index == 4)
		return "30;42";
	if(index == 5)
		return "30;46";
	if(index == 6)
		return "30;47";
	if(index == 7)
		return "1;32;40";
	return "0;30;40";
}

effectcode(index: int): string
{
	if(palette == 0){
		if(index == 0)
			return theme->sgr(IcTheme->AttrEffectHead);
		if(index == 1)
			return theme->sgr(IcTheme->AttrEffectBright);
		if(index == 2)
			return theme->sgr(IcTheme->AttrEffectMid);
		if(index == 3)
			return theme->sgr(IcTheme->AttrEffectDim);
		if(index == 4)
			return theme->sgr(IcTheme->AttrEffectDark);
		return theme->sgr(IcTheme->AttrNormal);
	}

	if(palette == 1){
		if(index == 0)
			return "30;47";
		if(index == 1)
			return "30;46";
		if(index == 2)
			return "30;43";
		if(index == 3)
			return "37;44";
		if(index == 4)
			return "37;100";
		return "0";
	}

	if(palette == 2){
		if(index == 0)
			return "1;37;40";
		if(index == 1)
			return "1;32;40";
		if(index == 2)
			return "0;32;40";
		if(index == 3)
			return "1;33;40";
		if(index == 4)
			return "0;30;40";
		return "0";
	}

	if(index == 0)
		return "1;37;40";
	if(index == 1)
		return "1;32;40";
	if(index == 2)
		return "0;32;40";
	if(index == 3)
		return "0;32;40";
	if(index == 4)
		return "0;30;40";
	return "0";
}

drawswatch(u: ref IcUi->Ui, y: int, name: string, code: string)
{
	ui->canvasfill(u, ThemeCanvasId, 0, y, 58, 1, " ", code);
	ui->canvasputs(u, ThemeCanvasId, 2, y, name, code);
	ui->canvasputs(u, ThemeCanvasId, 28, y, "sample text", code);
}

drawtheme(u: ref IcUi->Ui)
{
	ui->canvasclear(u, ThemeCanvasId, " ", "0");

	if(showeffects){
		drawswatch(u, 0, "Effect head", effectcode(0));
		drawswatch(u, 1, "Effect bright", effectcode(1));
		drawswatch(u, 2, "Effect mid", effectcode(2));
		drawswatch(u, 3, "Effect dim", effectcode(3));
		drawswatch(u, 4, "Effect dark", effectcode(4));
		drawswatch(u, 5, "Normal", effectcode(5));
	}
	else{
		drawswatch(u, 0, "Normal", palettecode(0));
		drawswatch(u, 1, "Window", palettecode(1));
		drawswatch(u, 2, "Frame", palettecode(2));
		drawswatch(u, 3, "Title", palettecode(3));
		drawswatch(u, 4, "Button", palettecode(4));
		drawswatch(u, 5, "Focus", palettecode(5));
		drawswatch(u, 6, "Status", palettecode(6));
		drawswatch(u, 7, "Scroll", palettecode(7));
		drawswatch(u, 8, "Shadow", palettecode(8));
	}
}

refresh(u: ref IcUi->Ui)
{
	sb: IcGlyph->Scrollbar;

	ui->setframestyle(u, framestyle);

	sb = glyph->scrollbar();

	ui->settext(u, Caps1Id, "Terminal size: " + sys->sprint("%d", ci.cols) + "x" + sys->sprint("%d", ci.rows));
	ui->settext(u, Caps2Id, "Colors: " + sys->sprint("%d", theme->colors()) + "  truecolor=" + booltext(theme->truecolor()));
	ui->settext(u, Caps3Id, "UTF8=" + booltext(ci.utf8) + "  VT=" + booltext(ci.vt) + "  consinfo.ok=" + booltext(ci.ok));
	ui->settext(u, Caps4Id, "Source: " + ci.source);
	ui->settext(u, Caps5Id, "Preview palette: " + palettename());

	drawtheme(u);

	ui->settext(u, AsciiFrameId, "ASCII frame:  " + frametext(IcGlyph->StyleAscii));
	ui->settext(u, SingleFrameId, "Single frame: " + frametext(IcGlyph->StyleSingle));
	ui->settext(u, DoubleFrameId, "Double frame: " + frametext(IcGlyph->StyleDouble));
	ui->settext(u, GlyphPolicyId, "Glyph profile: " + profiletext() + "  UI frame=" + framestylename());
	ui->settext(u, ScrollBlockId, "Scrollbar: v=" + sb.v + " h=" + sb.h + " thumb=" + sb.thumb + " block=" + glyph->block(1));

	ui->settext(u, DoubleWidthId, "Double-width policy: avoid wide glyphs in fixed cell layouts.");
	ui->settext(u, WindowsId, "Windows console note: VT=" + booltext(ci.vt) + " truecolor=" + booltext(ci.truecolor));
	ui->settext(u, FallbackId, "Fallbacks: ASCII frames and 16-color SGR keep UI readable.");

	if(showeffects)
		ui->setstatus(u, "theme view: effect attributes | frame=" + framestylename() + " | palette=" + palettename());
	else
		ui->setstatus(u, "theme view: core attributes | frame=" + framestylename() + " | palette=" + palettename());

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 23);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Toggle core/effects | Frame changes all box frames | Palette changes color preview ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 23, " Theme, colors and glyphs ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "Theme and glyph policy are selected from terminal capabilities.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, CapsBoxId, 3, 4, 40, 8, " Terminal capabilities ") < 0)
		raise "fail:caps box";

	if(ui->label(u, CapsBoxId, Caps1Id, 2, 1, 34, "") < 0)
		raise "fail:caps 1";

	if(ui->label(u, CapsBoxId, Caps2Id, 2, 2, 34, "") < 0)
		raise "fail:caps 2";

	if(ui->label(u, CapsBoxId, Caps3Id, 2, 3, 34, "") < 0)
		raise "fail:caps 3";

	if(ui->label(u, CapsBoxId, Caps4Id, 2, 5, 34, "") < 0)
		raise "fail:caps 4";

	if(ui->label(u, CapsBoxId, Caps5Id, 2, 6, 34, "") < 0)
		raise "fail:caps 5";

	if(ui->window(u, WinId, ThemeBoxId, 46, 4, 35, 12, " Theme swatches ") < 0)
		raise "fail:theme box";

	if(ui->canvas(u, ThemeBoxId, ThemeCanvasId, 2, 1, 30, 9) < 0)
		raise "fail:theme canvas";

	if(ui->window(u, WinId, FrameBoxId, 3, 13, 40, 7, " Glyphs ") < 0)
		raise "fail:frame box";

	if(ui->label(u, FrameBoxId, AsciiFrameId, 2, 1, 34, "") < 0)
		raise "fail:ascii frame";

	if(ui->label(u, FrameBoxId, SingleFrameId, 2, 2, 34, "") < 0)
		raise "fail:single frame";

	if(ui->label(u, FrameBoxId, DoubleFrameId, 2, 3, 34, "") < 0)
		raise "fail:double frame";

	if(ui->label(u, FrameBoxId, GlyphPolicyId, 2, 5, 34, "") < 0)
		raise "fail:glyph policy";

	if(ui->label(u, FrameBoxId, ScrollBlockId, 2, 6, 34, "") < 0)
		raise "fail:scroll block";

	if(ui->window(u, WinId, TextBoxId, 46, 17, 35, 4, " Text policy ") < 0)
		raise "fail:text box";

	if(ui->label(u, TextBoxId, DoubleWidthId, 2, 1, 29, "") < 0)
		raise "fail:double width";

	if(ui->label(u, TextBoxId, WindowsId, 2, 2, 29, "") < 0)
		raise "fail:windows";

	if(ui->label(u, TextBoxId, FallbackId, 2, 3, 29, "") < 0)
		raise "fail:fallback";

	if(ui->button(u, WinId, BtnToggleId, 3, 21, 10, 1, "Toggle", "t", AppTarget, "app.toggle") < 0)
		raise "fail:toggle";

	if(ui->button(u, WinId, BtnFrameId, 15, 21, 10, 1, "Frame", "f", AppTarget, "app.frame") < 0)
		raise "fail:frame";

	if(ui->button(u, WinId, BtnPaletteId, 27, 21, 12, 1, "Palette", "p", AppTarget, "app.palette") < 0)
		raise "fail:palette";

	if(ui->button(u, WinId, BtnExitId, 41, 21, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	showeffects = 0;
	framestyle = IcPaint->FrameDouble;
	palette = 0;

	ui->setfocus(u, BtnToggleId);
	refresh(u);
}

cycleframe()
{
	if(framestyle == IcPaint->FrameAscii){
		framestyle = IcPaint->FrameSingle;
		return;
	}

	if(framestyle == IcPaint->FrameSingle){
		framestyle = IcPaint->FrameDouble;
		return;
	}

	framestyle = IcPaint->FrameAscii;
}

cyclepalette()
{
	palette++;
	if(palette > 3)
		palette = 0;
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.toggle"){
		showeffects = !showeffects;
		refresh(u);
		return 0;
	}

	if(cmd == "app.frame"){
		cycleframe();
		refresh(u);
		return 0;
	}

	if(cmd == "app.palette"){
		cyclepalette();
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