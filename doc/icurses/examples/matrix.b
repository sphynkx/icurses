implement Matrix;

include "draw.m";
include "icurses/ui.m";

Matrix: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

#
# Loaded runtime modules.
#
# sys provides Inferno system calls.
# ui is the high-level icurses UI facade.
# ic provides low-level terminal/keyboard helpers and /dev/consinfo parsing.
# msg provides message constants and constructors used by UI dispatch.
#
sys: Sys;
ui: IcUi;
ic: Icurses;
msg: IcMsg;

#
# Terminal output FD. The demo writes directly to stdout for fast animation,
# while still keeping the icurses canvas state synchronized.
#
out: ref Sys->FD;

#
# Safe fallback terminal size. Used when /dev/consinfo is missing or reports
# dimensions too small for the demo.
#
DefaultW: con 80;
DefaultH: con 24;

#
# Runtime terminal geometry.
#
# cw/ch are columns and rows.
# statusy0/statusy1 reserve the last two rows for icurses help/status lines.
#
cw: int;
ch: int;
statusy0: int;
statusy1: int;

#
# ID of the icurses canvas node used as the backing store for the animation.
#
CanvasId: con "canvas.matrix";

#
# Character sets used by streams.
#
# ASCII and Cyrillic are safe on most terminals.
# CJK and Matrix glyph sets look best on UTF-8 terminals with suitable fonts.
# Depending on terminal/font configuration, some glyphs may render double-width.
#
AsciiChars: con "0123456789+=&%$?#№ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
CyrillicChars: con "1234567890+=&%$?#№АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЭЮЯабвгдежзиклмнопрстуфхцчшэюя";
CjkChars: con "日月火水木金土天地山川森林雨風雷電光闇龍鳥魚人心夢影空海石花竹門道星";

#
# Original Matrix-style glyph orders:
# https://github.com/Rezmason/matrix/blob/master/glyph%20order.txt
#
RevolChars: con "モエヤキオカ7ケサスz152ヨタワ4ネヌナ98ヒ0ホア3ウ セ¦:\"꞊ミラリ╌ツテニハソ▪—<>0|+*コシマムメ";
ResurChars: con "モエヤキオカ7ケサスz152ヨタワ4ネヌナ98ヒ0ホア3ウ セ¦:\"꞊ミラリ╌ツテニハソコ—<ム0|*▪メシマ>+";

#
# Charset mode constants.
#
# The actual cycling order is terminal-dependent:
#
#   UTF-8 terminals:
#     Revol -> Resur -> CJK -> ASCII -> Cyrillic -> Revol
#
#   non-UTF-8 terminals:
#     ASCII -> Cyrillic -> Revol -> Resur -> CJK -> ASCII
#
CharsetAscii:    con 0;
CharsetCyrillic: con 1;
CharsetCjk:      con 2;
CharsetRevol:    con 3;
CharsetResur:    con 4;

#
# Control panel geometry.
#
# The panel is drawn by icurses over the matrix canvas. Matrix cells under
# this rectangle are still stored in the canvas, but not emitted directly.
#
PanelX: con 2;
PanelY: con 2;
PanelW: con 58;
PanelH: con 8;

#
# Number of independent falling streams.
#
# Each stream has its own timer process and column. This demonstrates how
# a real icurses application can combine UI widgets with asynchronous work.
#
MaxStreams: con 20;

#
# Active charset string and deterministic pseudo-random generator state.
#
chars: string;
seed: int;

#
# Global animation/UI state.
#
# paused       - non-zero pauses stream movement.
# speedcoef    - global speed multiplier, clamped to [1..8].
# charsetmode  - current charset mode.
# running      - shared flag used by background processes.
# lastkey      - last keyboard code seen by the main loop.
# panelvisible - mirrors visibility of the control panel for coverage checks.
#
paused: int;
speedcoef: int;
charsetmode: int;
running: int;
lastkey: int;
panelvisible: int;

#
# Terminal capabilities read from /dev/consinfo.
#
# terminalutf8 controls the default charset and charset cycling order.
# Note: an SSH session from Windows may still report the server-side terminal
# capabilities rather than the original client console. We intentionally trust
# /dev/consinfo here and keep the policy simple.
#
colors: int;
truecolor: int;
terminalutf8: int;
conssource: string;

#
# Event channels.
#
# keyc receives keyboard events from keyproc().
# streamc receives stream IDs from streamproc(i).
#
keyc: chan of int;
streamc: chan of int;

#
# Per-stream state arrays.
#
# sx         - stream column.
# shead      - current stream head row.
# soldhead   - previous head row.
# stail      - immutable stream length until restart.
# sbasedelay - base stream wake-up delay in milliseconds.
# sdrift     - slowly changing delay offset.
# sphase     - reserved random phase value for future visual effects.
#
sx: array of int;
shead: array of int;
soldhead: array of int;
stail: array of int;
sbasedelay: array of int;
sdrift: array of int;
sphase: array of int;

#
# UI tree construction.
#
build: fn(u: ref IcUi->Ui);

#
# Terminal detection.
#
readconsoleparams: fn();

#
# Charset helpers.
#
defaultcharset: fn(): int;
setcharset: fn();
nextcharset: fn();
charsetname: fn(): string;

#
# Status and controls.
#
statusline: fn(): string;
setspeed: fn(u: ref IcUi->Ui, speed: int);

#
# Random helpers.
#
rand: fn(n: int): int;
rndchar: fn(): string;

#
# Matrix stream lifecycle.
#
initmatrix: fn();
resetmatrix: fn(u: ref IcUi->Ui);
resetstream: fn(i: int);

#
# Stream geometry.
#
streamtop: fn(head, tail: int): int;
streambottom: fn(head: int): int;

#
# Stream update/render.
#
updatestream: fn(u: ref IcUi->Ui, i: int);
drawstream: fn(u: ref IcUi->Ui, i: int, oldhead, newhead: int);
clearstream: fn(u: ref IcUi->Ui, i: int, oldhead: int);

#
# Cell rendering helpers.
#
fadecode: fn(v: int): string;
streamvalue: fn(pos, tail: int): int;
putcell: fn(u: ref IcUi->Ui, x, y: int, ch, code: string);
covered: fn(x, y: int): int;

#
# Full redraw helpers.
#
invalidateui: fn(u: ref IcUi->Ui);
fulldraw: fn(u: ref IcUi->Ui);
resyncmatrix: fn(u: ref IcUi->Ui);

#
# Input and command handling.
#
handleanimkey: fn(u: ref IcUi->Ui, k: int): int;
appmsg: fn(u: ref IcUi->Ui, m: IcMsg->Msg);

#
# Background processes.
#
keyproc: fn();
streamproc: fn(i: int);
streamdelay: fn(i: int): int;

#
# Read terminal geometry and capabilities through Icurses->consinfo().
#
# This function centralizes all terminal-dependent policy:
# - geometry fallback;
# - color/truecolor detection;
# - UTF-8 detection;
# - source string used in the status line.
#
readconsoleparams()
{
	ci: Icurses->ConsInfo;

	cw = DefaultW;
	ch = DefaultH;
	statusy0 = ch - 2;
	statusy1 = ch - 1;

	colors = 16;
	truecolor = 0;
	terminalutf8 = 0;
	conssource = "default";

	ci = ic->consinfo();

	cw = ci.cols;
	ch = ci.rows;

	if(cw < 40)
		cw = DefaultW;
	if(ch < 15)
		ch = DefaultH;

	colors = ci.colors;
	truecolor = ci.truecolor;
	terminalutf8 = ci.utf8;
	conssource = ci.source;

	statusy0 = ch - 2;
	statusy1 = ch - 1;
}

#
# Return the default charset for the detected terminal.
#
# UTF-8 terminals start with the native Matrix glyph order.
# Non-UTF-8 terminals start with ASCII for maximum safety.
#
defaultcharset(): int
{
	if(terminalutf8)
		return CharsetRevol;

	return CharsetAscii;
}

#
# Select the active glyph string from charsetmode.
#
# Invalid modes are normalized through defaultcharset(), so callers can rely
# on chars being usable after this function returns.
#
setcharset()
{
	case charsetmode {
	CharsetAscii =>
		chars = AsciiChars;

	CharsetCyrillic =>
		chars = CyrillicChars;

	CharsetCjk =>
		chars = CjkChars;

	CharsetRevol =>
		chars = RevolChars;

	CharsetResur =>
		chars = ResurChars;

	* =>
		charsetmode = defaultcharset();
		setcharset();
		return;
	}

	if(chars == "")
		chars = AsciiChars;
}

#
# Advance to the next charset.
#
# The order is intentionally terminal-dependent:
#
# UTF-8:
#   Revol -> Resur -> CJK -> ASCII -> Cyrillic -> Revol
#
# non-UTF-8:
#   ASCII -> Cyrillic -> Revol -> Resur -> CJK -> ASCII
#
nextcharset()
{
	if(terminalutf8){
		case charsetmode {
		CharsetRevol =>
			charsetmode = CharsetResur;

		CharsetResur =>
			charsetmode = CharsetCjk;

		CharsetCjk =>
			charsetmode = CharsetAscii;

		CharsetAscii =>
			charsetmode = CharsetCyrillic;

		CharsetCyrillic =>
			charsetmode = CharsetRevol;

		* =>
			charsetmode = CharsetRevol;
		}
	}
	else{
		case charsetmode {
		CharsetAscii =>
			charsetmode = CharsetCyrillic;

		CharsetCyrillic =>
			charsetmode = CharsetRevol;

		CharsetRevol =>
			charsetmode = CharsetResur;

		CharsetResur =>
			charsetmode = CharsetCjk;

		CharsetCjk =>
			charsetmode = CharsetAscii;

		* =>
			charsetmode = CharsetAscii;
		}
	}

	setcharset();
}

#
# Human-readable current charset name for status/debug output.
#
charsetname(): string
{
	case charsetmode {
	CharsetAscii =>
		return "ascii";

	CharsetCyrillic =>
		return "cyrillic";

	CharsetCjk =>
		return "cjk";

	CharsetRevol =>
		return "matrix-revol";

	CharsetResur =>
		return "matrix-resur";

	* =>
		return "unknown";
	}
}

#
# Build the bottom status line.
#
# Real applications usually centralize status text construction like this,
# because many actions can update the same status area.
#
statusline(): string
{
	state: string;

	if(paused)
		state = "paused";
	else
		state = "running";

	return state +
		" | key=" + string lastkey +
		" | speed=" + string speedcoef +
		" | streams=" + string MaxStreams +
		" | charset=" + charsetname() +
		" | utf8=" + string terminalutf8 +
		" | truecolor=" + string truecolor +
		" | colors=" + string colors +
		" | size=" + string cw + "x" + string ch +
		" | " + conssource;
}

#
# Clamp and apply the global speed coefficient.
#
setspeed(u: ref IcUi->Ui, speed: int)
{
	if(speed < 1)
		speed = 1;
	if(speed > 8)
		speed = 8;

	speedcoef = speed;
	ui->setstatus(u, statusline());
}

#
# Small deterministic pseudo-random generator.
#
# This is not cryptographic randomness. It is deliberately simple and stable
# so the demo remains deterministic enough for testing.
#
rand(n: int): int
{
	r: int;

	if(n <= 0)
		return 0;

	seed = seed + 7919 + (seed % 97) * 131;

	if(seed < 0)
		seed = -seed;

	if(seed > 1000000000)
		seed = seed % 1000000000;

	r = seed % n;

	if(r < 0)
		r = -r;

	if(r >= n)
		r = n - 1;

	return r;
}

#
# Pick one random glyph from the current character set.
#
rndchar(): string
{
	i, n: int;

	n = len chars;
	if(n <= 0)
		return " ";

	i = rand(n);

	if(i < 0)
		i = 0;
	if(i >= n)
		i = n - 1;

	return chars[i:i+1];
}

#
# Map logical brightness to an SGR code.
#
# In truecolor mode we use explicit RGB greens.
# Otherwise we fall back to common 16-color SGR sequences.
#
fadecode(v: int): string
{
	if(truecolor){
		case v {
		6 =>
			return "38;2;220;255;220;40";

		5 =>
			return "38;2;100;255;140;40";

		4 =>
			return "38;2;0;230;80;40";

		3 =>
			return "38;2;0;155;50;40";

		2 =>
			return "38;2;0;85;28;40";

		1 =>
			return "38;2;0;30;10;40";

		* =>
			if(v > 6)
				return "38;2;220;255;220;40";
			return "0;30;40";
		}
	}

	case v {
	6 =>
		return "1;37;40";

	5 =>
		return "1;32;40";

	4 =>
		return "1;32;40";

	3 =>
		return "0;32;40";

	2 =>
		return "0;32;40";

	1 =>
		return "0;30;40";

	* =>
		if(v > 6)
			return "1;37;40";
		return "0;30;40";
	}
}

#
# Convert a cell position inside a stream to brightness.
#
# pos=0 is the head. Larger values are farther into the tail.
#
streamvalue(pos, tail: int): int
{
	if(pos <= 0)
		return 6;

	if(pos == 1)
		return 5;

	if(pos < tail / 3)
		return 4;

	if(pos < (tail * 2) / 3)
		return 3;

	return 2;
}

#
# First occupied row for a stream.
#
streamtop(head, tail: int): int
{
	return head - tail + 1;
}

#
# Last occupied row for a stream.
#
streambottom(head: int): int
{
	return head;
}

#
# Allocate and initialize all stream state arrays.
#
initmatrix()
{
	i, spacing, x: int;

	setcharset();

	seed = 1234567;

	sx = array[MaxStreams] of int;
	shead = array[MaxStreams] of int;
	soldhead = array[MaxStreams] of int;
	stail = array[MaxStreams] of int;
	sbasedelay = array[MaxStreams] of int;
	sdrift = array[MaxStreams] of int;
	sphase = array[MaxStreams] of int;

	spacing = cw / MaxStreams;
	if(spacing < 3)
		spacing = 3;

	for(i = 0; i < MaxStreams; i++){
		x = 2 + i * spacing;

		if(x < 0)
			x = 0;
		if(x >= cw)
			x = cw - 1;

		sx[i] = x;
		resetstream(i);
	}
}

#
# Reset one stream while keeping its assigned column.
#
resetstream(i: int)
{
	if(i < 0 || i >= MaxStreams)
		return;

	shead[i] = -rand(ch);
	soldhead[i] = shead[i];

	stail[i] = 6 + rand(18);
	sbasedelay[i] = 45 + rand(160);
	sdrift[i] = rand(41) - 20;
	sphase[i] = rand(1000);
}

#
# Reset all streams and clear the backing canvas.
#
resetmatrix(u: ref IcUi->Ui)
{
	initmatrix();
	ui->canvasclear(u, CanvasId, " ", "0;30;40");
	resyncmatrix(u);
}

#
# Return non-zero if a cell is currently covered by UI chrome.
#
# Covered matrix cells are still stored in the canvas, but direct terminal
# writes are suppressed so the panel/status area remains readable.
#
covered(x, y: int): int
{
	if(y >= statusy0)
		return 1;

	if(panelvisible){
		if(x >= PanelX && x < PanelX + PanelW && y >= PanelY && y < PanelY + PanelH)
			return 1;
	}

	return 0;
}

#
# Update one cell in the canvas and optionally emit it directly.
#
# This demo uses direct terminal output for animation speed, but keeps the
# icurses canvas synchronized so full redraws still work correctly.
#
putcell(u: ref IcUi->Ui, x, y: int, chs, code: string)
{
	if(x < 0 || y < 0 || x >= cw || y >= ch)
		return;

	if(chs == "")
		chs = " ";

	if(code == "")
		code = "0;30;40";

	ui->canvasputc(u, CanvasId, x, y, chs, code);

	if(covered(x, y))
		return;

	ic->cup(out, y + 1, x + 1);
	ic->sgr(out, code);
	sys->fprint(out, "%s", chs);
}

#
# Clear cells previously occupied by one stream.
#
clearstream(u: ref IcUi->Ui, i: int, oldhead: int)
{
	x, y, top, bot: int;

	if(i < 0 || i >= MaxStreams)
		return;

	x = sx[i];

	top = streamtop(oldhead, stail[i]);
	bot = streambottom(oldhead);

	if(top < 0)
		top = 0;
	if(bot >= ch)
		bot = ch - 1;

	for(y = top; y <= bot; y++)
		putcell(u, x, y, " ", "0;30;40");

	ic->resettty(out);
}

#
# Redraw a stream in the union of its old and new vertical ranges.
#
# Only cells touched by this stream are changed. Other streams are not
# recomputed, which keeps the animation lightweight.
#
drawstream(u: ref IcUi->Ui, i: int, oldhead, newhead: int)
{
	x, y, oldtop, oldbot, newtop, newbot, top, bot, pos, v: int;
	chs, code: string;

	if(i < 0 || i >= MaxStreams)
		return;

	x = sx[i];

	oldtop = streamtop(oldhead, stail[i]);
	oldbot = streambottom(oldhead);

	newtop = streamtop(newhead, stail[i]);
	newbot = streambottom(newhead);

	top = oldtop;
	if(newtop < top)
		top = newtop;

	bot = oldbot;
	if(newbot > bot)
		bot = newbot;

	if(top < 0)
		top = 0;
	if(bot >= ch)
		bot = ch - 1;

	for(y = top; y <= bot; y++){
		if(y < newtop || y > newbot){
			putcell(u, x, y, " ", "0;30;40");
			continue;
		}

		pos = newhead - y;
		v = streamvalue(pos, stail[i]);

		chs = rndchar();
		code = fadecode(v);

		putcell(u, x, y, chs, code);
	}

	ic->resettty(out);
}

#
# Advance one stream and repaint the changed area.
#
updatestream(u: ref IcUi->Ui, i: int)
{
	old, step: int;

	if(i < 0 || i >= MaxStreams)
		return;

	if(paused)
		return;

	old = shead[i];

	sdrift[i] += rand(7) - 3;

	if(sdrift[i] < -50)
		sdrift[i] = -50;
	if(sdrift[i] > 50)
		sdrift[i] = 50;

	step = 1;

	if(speedcoef >= 3 && rand(100) < 35)
		step++;
	if(speedcoef >= 5 && rand(100) < 25)
		step++;
	if(speedcoef >= 7 && rand(100) < 20)
		step++;

	shead[i] += step;

	if(shead[i] >= ch + stail[i]){
		clearstream(u, i, old);
		resetstream(i);
		return;
	}

	drawstream(u, i, old, shead[i]);
	soldhead[i] = shead[i];
}

#
# Compute the next wake-up delay for one stream process.
#
streamdelay(i: int): int
{
	d: int;

	if(i < 0 || i >= MaxStreams)
		return 100;

	d = sbasedelay[i] + sdrift[i];

	if(speedcoef > 1)
		d = d / speedcoef;

	d += rand(31) - 15;

	if(d < 8)
		d = 8;
	if(d > 500)
		d = 500;

	return d;
}

#
# Re-emit all streams after UI has redrawn over the terminal.
#
resyncmatrix(u: ref IcUi->Ui)
{
	i, old: int;

	for(i = 0; i < MaxStreams; i++){
		old = shead[i];
		drawstream(u, i, old - stail[i] - 1, old);
	}
}

#
# Force icurses renderer to treat every cell as dirty.
#
# This is useful when the demo has done direct terminal writes outside the
# normal renderer path.
#
invalidateui(u: ref IcUi->Ui)
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

#
# Full UI redraw followed by matrix resync.
#
fulldraw(u: ref IcUi->Ui)
{
	invalidateui(u);
	ui->draw(u);
	resyncmatrix(u);
}

#
# Build the widget tree.
#
# This demonstrates typical icurses application setup:
# - configure frame/status rows;
# - create a canvas;
# - create a control panel;
# - bind keys to commands;
# - set focus and initial status.
#
build(u: ref IcUi->Ui)
{
	root: string;

	root = ui->rootid(u);

	ui->setframestyle(u, IcPaint->FrameSingle);
	ui->setstatusrows(u, statusy0, statusy1);
	ui->sethelp(u, " Matrix | + faster | - slower | c charset | t truecolor | h panel | Space pause | q/Esc quit ");

	ui->canvas(u, root, CanvasId, 0, 0, cw, ch);

	ui->window(u, root, "win.panel", PanelX, PanelY, PanelW, PanelH, "Animation control (press `h` to hide)");
	ui->setframe(u, "win.panel", IcPaint->FrameDouble);
	ui->setcontent(u, "win.panel",
		"Sparse async stream model. c cycles charset order based on utf8 from /dev/consinfo. t toggles truecolor.");
	ui->setscroll(u, "win.panel", IcView->ScrollClip, 0);

	ui->button(u, "win.panel", "btn.pause", 2, 5, 11, 1, "Pause", "", "app", "app.pause");
	ui->button(u, "win.panel", "btn.faster", 14, 5, 11, 1, "Fast", "", "app", "app.fast");
	ui->button(u, "win.panel", "btn.slower", 26, 5, 11, 1, "Slow", "", "app", "app.slow");
	ui->button(u, "win.panel", "btn.charset", 38, 5, 11, 1, "Charset", "", "app", "app.charset");
	ui->button(u, "win.panel", "btn.truecolor", 2, 6, 14, 1, "Truecolor", "", "app", "app.truecolor");

	ui->bindkey(u, " ", "app", "app.pause");
	ui->bindkey(u, "+", "app", "app.fast");
	ui->bindkey(u, "=", "app", "app.fast");
	ui->bindkey(u, "-", "app", "app.slow");
	ui->bindkey(u, "_", "app", "app.slow");
	ui->bindkey(u, "c", "app", "app.charset");
	ui->bindkey(u, "C", "app", "app.charset");
	ui->bindkey(u, "t", "app", "app.truecolor");
	ui->bindkey(u, "T", "app", "app.truecolor");
	ui->bindkey(u, "h", "win.panel", "node.toggle");
	ui->bindkey(u, "H", "win.panel", "node.toggle");

	ui->setfocus(u, "btn.pause");
	ui->setstatus(u, statusline());
}

#
# Handle demo-specific keys before passing input to generic UI navigation.
#
handleanimkey(u: ref IcUi->Ui, k: int): int
{
	lastkey = k;

	case k {
	' ' =>
		paused = !paused;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return 1;

	'+' =>
		setspeed(u, speedcoef + 1);
		fulldraw(u);
		return 1;

	'=' =>
		setspeed(u, speedcoef + 1);
		fulldraw(u);
		return 1;

	'-' =>
		setspeed(u, speedcoef - 1);
		fulldraw(u);
		return 1;

	'_' =>
		setspeed(u, speedcoef - 1);
		fulldraw(u);
		return 1;

	'c' =>
		nextcharset();
		ui->setstatus(u, "charset switch | " + statusline());
		fulldraw(u);
		return 1;

	'C' =>
		nextcharset();
		ui->setstatus(u, "charset switch | " + statusline());
		fulldraw(u);
		return 1;

	't' =>
		truecolor = !truecolor;
		ui->setstatus(u, "truecolor toggle | " + statusline());
		fulldraw(u);
		return 1;

	'T' =>
		truecolor = !truecolor;
		ui->setstatus(u, "truecolor toggle | " + statusline());
		fulldraw(u);
		return 1;

	'h' =>
		ui->dispatch(u, msg->newmsg("anim", "win.panel", IcMsg->KindCommand, "node.toggle"));
		panelvisible = !panelvisible;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return 1;

	'H' =>
		ui->dispatch(u, msg->newmsg("anim", "win.panel", IcMsg->KindCommand, "node.toggle"));
		panelvisible = !panelvisible;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return 1;

	* =>
		return 0;
	}
}

#
# Handle command messages produced by UI buttons/key bindings.
#
appmsg(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	if(m.handled)
		return;

	if(m.kind != IcMsg->KindCommand)
		return;

	case m.cmd {
	"app.pause" =>
		paused = !paused;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return;

	"app.fast" =>
		setspeed(u, speedcoef + 1);
		fulldraw(u);
		return;

	"app.slow" =>
		setspeed(u, speedcoef - 1);
		fulldraw(u);
		return;

	"app.charset" =>
		nextcharset();
		ui->setstatus(u, "charset switch | " + statusline());
		fulldraw(u);
		return;

	"app.truecolor" =>
		truecolor = !truecolor;
		ui->setstatus(u, "truecolor toggle | " + statusline());
		fulldraw(u);
		return;

	* =>
		return;
	}
}

#
# Keyboard reader process.
#
# The process exits when running is cleared or input closes.
#
keyproc()
{
	k: int;

	for(;;){
		if(!running)
			return;

		k = ui->readkey();

		if(!running)
			return;

		keyc <-= k;

		if(k < 0)
			return;
	}
}

#
# Independent per-stream timer process.
#
# Instead of a single global animation loop, each stream sleeps according to
# its own speed and then posts its stream index to streamc.
#
streamproc(i: int)
{
	for(;;){
		if(!running)
			return;

		sys->sleep(streamdelay(i));

		if(!running)
			return;

		streamc <-= i;
	}
}

#
# Program entry point.
#
# The overall application lifecycle is:
#
# 1. Load modules.
# 2. Read terminal capabilities.
# 3. Initialize model state.
# 4. Build the icurses UI tree.
# 5. Open keyboard input.
# 6. Spawn background processes.
# 7. Run the main event loop.
# 8. Close input/UI cleanly.
#
init(nil: ref Draw->Context, nil: list of string)
{
	u: ref IcUi->Ui;
	k, sid, done, i: int;
	m: IcMsg->Msg;

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

	out = sys->fildes(1);

	readconsoleparams();

	paused = 0;
	speedcoef = 1;
	charsetmode = defaultcharset();
	running = 0;
	lastkey = 0;
	panelvisible = 1;

	setcharset();

	keyc = chan of int;
	streamc = chan of int;

	initmatrix();

	u = ui->new(out, cw, ch);
	build(u);

	ui->canvasclear(u, CanvasId, " ", "0;30;40");
	fulldraw(u);

	if(ui->openinput() < 0){
		ui->close(u);
		sys->print("cannot open keyboard\n");
		return;
	}

	running = 1;
	done = 0;

	spawn keyproc();

	for(i = 0; i < MaxStreams; i++)
		spawn streamproc(i);

	for(; !done;) alt {
	k = <-keyc =>
		lastkey = k;

		if(k < 0){
			done = 1;
			break;
		}

		if(ui->isquit(k)){
			done = 1;
			break;
		}

		if(handleanimkey(u, k))
			break;

		m = ui->handlekey(u, k);
		fulldraw(u);
		appmsg(u, m);

		if(m.kind == IcMsg->KindNone){
			ui->setstatus(u, "raw unhandled key=" + string k + " | " + statusline());
			fulldraw(u);
		}

	sid = <-streamc =>
		if(sid >= 0 && sid < MaxStreams)
			updatestream(u, sid);
	}

	running = 0;
	ui->closeinput();
	ui->close(u);

	sys->print("\nresult: ok\n");
}