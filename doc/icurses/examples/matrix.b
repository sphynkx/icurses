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
# view is used directly for a few geometry/focus operations in this example.
#
sys: Sys;
ui: IcUi;
ic: Icurses;
msg: IcMsg;
view: IcView;

#
# Terminal output FD.
#
# The demo writes directly to stdout for fast animation, while still keeping
# the icurses canvas state synchronized.
#
out: ref Sys->FD;

#
# Safe fallback terminal size.
#
# Used when /dev/consinfo is missing, incomplete, or reports invalid
# dimensions. Small but valid consoles are kept; they are clamped only to the
# minimal dimensions needed to keep the demo alive.
#
DefaultW: con 80;
DefaultH: con 24;
MinW: con 20;
MinH: con 8;
MaxW: con 300;
MaxH: con 120;

#
# Runtime terminal geometry.
#
# cw/ch are columns and rows used by the renderer and backing canvas.
# statusy0/statusy1 reserve the last two rows for icurses help/status lines.
#
cw: int;
ch: int;
statusy0: int;
statusy1: int;

#
# Resize polling.
#
# /dev/consinfo is relatively expensive, especially on hosted Windows.
# The animation produces many stream events, so resize checks are throttled.
#
ResizeCheckMs: con 300;
lastresizecheck: int;

#
# Canvas id.
#
# IcCanvas keeps a process-global registry keyed by id. When the Matrix UI is
# rebuilt after resize, using the same canvas id can accidentally reuse an old
# canvas from the registry. The active canvas id therefore includes a generation
# number derived from resizes.
#
CanvasBase: con "canvas.matrix";
canvasid: string;

#
# Alternate screen state.
#
# The demo owns the terminal while running. It enters the VT alternate screen,
# hides the cursor, and restores the normal screen on exit. If the host ignores
# alternate-screen mode, cleanup still clears the visible terminal before
# returning to the shell.
#
appscreen: int;

#
# Default background SGR code.
#
BgCode: con "0;30;40";

#
# Mouse support.
#
# Raw console mouse mode can capture wheel/scroll in hosted terminals. The demo
# enables mouse by default, but keeps the `m` toggle so users can release mouse
# wheel handling back to the host console when needed.
#
# Wheel events move focus one widget at a time.
#
MousePath: con "/dev/emouse";
MouseWheelUp: con 8;
MouseWheelDown: con 16;

#
# Character sets used by streams.
#
# ASCII is safe on every terminal.
# Cyrillic, CJK and Matrix glyph sets require a Unicode-capable terminal and
# suitable fonts. Depending on terminal/font configuration, some glyphs may
# render double-width or as replacement characters.
#
AsciiChars: con "0123456789+=&%$?#ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
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
# The actual cycling order is terminal-policy dependent:
#
#   Unicode-friendly terminals:
#     Revol -> Resur -> CJK -> ASCII -> Cyrillic -> Revol
#
#   Conservative terminals:
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
# Older versions of this demo used one process per stream. That was useful as
# an async-process example, but it was too expensive on hosted Windows. Current
# Matrix uses one animation process and schedules all streams in the main loop.
#
MaxStreams: con 20;

#
# Animation timing.
#
# animproc posts one lightweight tick to streamc every AnimTickMs. The main
# loop then updates only streams whose per-stream deadline has expired.
#
AnimTickMs: con 25;

#
# Initial head depth.
#
# Initial stream heads are placed a few cells above the top edge. This avoids
# both the artificial full-height startup flash and the visible synchronized
# all-column first frame. The first processing pass still runs immediately.
#
StartDepthMax: con 7;

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
# resizes      - number of successful UI rebuilds after terminal resize.
# mouseopen    - non-zero when the optional raw mouse reader is active.
#
paused: int;
speedcoef: int;
charsetmode: int;
running: int;
lastkey: int;
panelvisible: int;
resizes: int;
mouseopen: int;

#
# Terminal capabilities read from /dev/consinfo.
#
# terminalutf8 records the raw capability reported by the host.
# glyphutf8 records the policy used by this demo to choose the default glyph
# set and charset cycling order.
#
# Windows MinGW console can report utf8=1 while the actual console host/font
# still displays some Matrix/CJK glyphs poorly. For source=mingw-console this
# demo starts in ASCII mode by setting glyphutf8=0, while still allowing manual
# charset cycling with the `c` key.
#
colors: int;
truecolor: int;
terminalutf8: int;
glyphutf8: int;
conssource: string;

#
# Event channels.
#
# keyc receives keyboard events from keyproc().
# streamc receives animation ticks from animproc().
# mousec receives raw /dev/emouse records from mouseproc().
#
# Buffered channels reduce the chance that a background process remains blocked
# while the main loop is shutting down.
#
keyc: chan of int;
streamc: chan of int;
mousec: chan of string;

#
# Optional raw mouse reader state.
#
mousefd: ref Sys->FD;
mousebuf: array of byte;

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
# snext      - next scheduled update time in sys->millisec() units.
#
sx: array of int;
shead: array of int;
soldhead: array of int;
stail: array of int;
sbasedelay: array of int;
sdrift: array of int;
sphase: array of int;
snext: array of int;

#
# UI tree construction and dynamic geometry.
#
build: fn(u: ref IcUi->Ui);
panelw: fn(): int;
panelh: fn(): int;
makecanvasid: fn(): string;
rebuildui: fn(u: ref IcUi->Ui, oldw, oldh: int): ref IcUi->Ui;
checkresize: fn(u: ref IcUi->Ui): ref IcUi->Ui;
maybecheckresize: fn(u: ref IcUi->Ui): ref IcUi->Ui;

#
# Terminal lifecycle.
#
enterappscreen: fn();
leaveappscreen: fn();
restoreterminal: fn();

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
streamx: fn(i: int): int;
processstreams: fn(u: ref IcUi->Ui);

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
# Optional raw mouse handling.
#
parseintat: fn(s: string, i: int): (int, int, int);
openmouse: fn(): int;
closemouse: fn();
togglemouse: fn(u: ref IcUi->Ui);
handlemouse: fn(u: ref IcUi->Ui, raw: string): int;

#
# Background processes.
#
keyproc: fn();
mouseproc: fn();
animproc: fn();
streamdelay: fn(i: int): int;

#
# Cleanup.
#
cleanup: fn(u: ref IcUi->Ui);

#
# Enter alternate screen mode.
#
# Use `%c` with character code 27. Limbo string escapes such as `\033` are not
# portable here and may be printed literally by the hosted console path.
#
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

#
# Leave alternate screen mode.
#
# Clear the visible screen before leaving. If alternate-screen mode is not
# supported by the host, this still removes Matrix cells from the normal
# console buffer before returning to the shell.
#
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

#
# Restore terminal attributes that this demo may have changed.
#
restoreterminal()
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
}

#
# Read terminal geometry and capabilities through Icurses->consinfo().
#
# This function centralizes all terminal-dependent policy:
# - geometry fallback;
# - color/truecolor detection;
# - raw UTF-8 detection;
# - glyph policy;
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
	glyphutf8 = 0;
	conssource = "default";

	ci = ic->consinfo();

	if(ci.ok){
		cw = ci.cols;
		ch = ci.rows;

		colors = ci.colors;
		truecolor = ci.truecolor;
		terminalutf8 = ci.utf8;
		glyphutf8 = ci.utf8;
		conssource = ci.source;
	}
	else{
		(cw, ch) = ic->termsize();
		conssource = "termsize";
	}

	if(cw <= 0 || cw > MaxW)
		cw = DefaultW;
	if(ch <= 0 || ch > MaxH)
		ch = DefaultH;

	if(cw < MinW)
		cw = MinW;
	if(ch < MinH)
		ch = MinH;

	if(conssource == "mingw-console")
		glyphutf8 = 0;

	statusy0 = ch - 2;
	statusy1 = ch - 1;
}

#
# Current panel width, clamped to the active terminal geometry.
#
panelw(): int
{
	w, maxw: int;

	w = PanelW;
	maxw = cw - PanelX - 1;

	if(maxw < 4)
		maxw = 4;

	if(w > maxw)
		w = maxw;

	if(w < 4)
		w = 4;

	return w;
}

#
# Current panel height, clamped to leave room for status/help rows.
#
panelh(): int
{
	h, maxh: int;

	h = PanelH;
	maxh = statusy0 - PanelY;

	if(maxh < 3)
		maxh = 3;

	if(h > maxh)
		h = maxh;

	if(h < 3)
		h = 3;

	return h;
}

#
# Build a unique canvas id for the current UI generation.
#
makecanvasid(): string
{
	return CanvasBase + "." + sys->sprint("%d", resizes);
}

#
# Return the default charset for the detected terminal policy.
#
# Unicode-friendly terminals start with the native Matrix glyph order.
# Conservative terminals start with ASCII for maximum safety.
#
defaultcharset(): int
{
	if(glyphutf8)
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
# The order is intentionally terminal-policy dependent:
#
# Unicode-friendly:
#   Revol -> Resur -> CJK -> ASCII -> Cyrillic -> Revol
#
# Conservative:
#   ASCII -> Cyrillic -> Revol -> Resur -> CJK -> ASCII
#
nextcharset()
{
	if(glyphutf8){
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
# Keep it compact: Windows console scrollback and horizontal scrollbars are
# sensitive to long terminal lines. All numbers are formatted through sprint.
#
statusline(): string
{
	state: string;

	if(paused)
		state = "paused";
	else
		state = "run";

	return sys->sprint("Matrix %s spd=%d cs=%s size=%dx%d r=%d m=%d src=%s",
		state,
		speedcoef,
		charsetname(),
		cw,
		ch,
		resizes,
		mouseopen,
		conssource);
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
			return BgCode;
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
		return BgCode;
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
# Compute the horizontal column for a stream.
#
# This uses an integer error accumulator instead of a multiplication/division
# formula. It is deliberately simple and robust on the hosted Limbo runtime.
# The result maps stream indexes across the full [0..cw-1] range.
#
streamx(i: int): int
{
	k, x, err, den, span: int;

	if(cw <= 1)
		return 0;

	if(MaxStreams <= 1)
		return cw / 2;

	if(i < 0)
		i = 0;
	if(i >= MaxStreams)
		i = MaxStreams - 1;

	span = cw - 1;
	den = MaxStreams - 1;

	x = 0;
	err = 0;

	for(k = 0; k < i; k++){
		err += span;

		while(err >= den){
			x++;
			err -= den;
		}
	}

	if(x < 0)
		x = 0;
	if(x >= cw)
		x = cw - 1;

	return x;
}

#
# Allocate and initialize all stream state arrays.
#
initmatrix()
{
	i, now: int;

	setcharset();

	seed = 1234567;
	now = sys->millisec();

	sx = array[MaxStreams] of int;
	shead = array[MaxStreams] of int;
	soldhead = array[MaxStreams] of int;
	stail = array[MaxStreams] of int;
	sbasedelay = array[MaxStreams] of int;
	sdrift = array[MaxStreams] of int;
	sphase = array[MaxStreams] of int;
	snext = array[MaxStreams] of int;

	for(i = 0; i < MaxStreams; i++){
		sx[i] = streamx(i);
		resetstream(i);

		#
		# Start just above the top edge at different small depths and make the
		# first pass due immediately. This prevents a synchronized visible
		# start without reintroducing startup delay or full-height splash.
		#
		shead[i] = -(1 + rand(StartDepthMax));
		soldhead[i] = shead[i];
		snext[i] = now;
	}
}

#
# Reset one stream while keeping its assigned column.
#
resetstream(i: int)
{
	if(i < 0 || i >= MaxStreams)
		return;

	stail[i] = 6 + rand(18);
	sbasedelay[i] = 45 + rand(160);
	sdrift[i] = rand(41) - 20;
	sphase[i] = rand(1000);

	shead[i] = -(1 + rand(ch + stail[i]));
	soldhead[i] = shead[i];

	snext[i] = sys->millisec() + streamdelay(i);
}

#
# Reset all streams and clear the backing canvas.
#
resetmatrix(u: ref IcUi->Ui)
{
	initmatrix();
	ui->canvasclear(u, canvasid, " ", BgCode);
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
		if(x >= PanelX && x < PanelX + panelw() && y >= PanelY && y < PanelY + panelh())
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
		code = BgCode;

	ui->canvasputc(u, canvasid, x, y, chs, code);

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
		putcell(u, x, y, " ", BgCode);

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
			putcell(u, x, y, " ", BgCode);
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
	old, step, now: int;

	if(i < 0 || i >= MaxStreams)
		return;

	now = sys->millisec();

	if(paused){
		snext[i] = now + 100;
		return;
	}

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
	snext[i] = now + streamdelay(i);
}

#
# Process due streams on one animation tick.
#
# Only streams whose deadline has expired are redrawn. This keeps the sparse
# look of independently timed streams without using one process per stream.
#
processstreams(u: ref IcUi->Ui)
{
	i, now: int;

	if(u == nil || snext == nil)
		return;

	now = sys->millisec();

	for(i = 0; i < MaxStreams; i++){
		if(now >= snext[i])
			updatestream(u, i);
	}
}

#
# Compute the next wake-up delay for one stream.
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

	if(d < 16)
		d = 16;
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
	canvasid = makecanvasid();

	ui->setframestyle(u, IcPaint->FrameSingle);
	ui->setstatusrows(u, statusy0, statusy1);
	ui->sethelp(u, " Matrix | m mouse | + faster | - slower | c charset | t truecolor | h panel | Space pause | q/Esc quit ");

	ui->canvas(u, root, canvasid, 0, 0, cw, ch);

	ui->window(u, root, "win.panel", PanelX, PanelY, panelw(), panelh(), "Animation control (press `h` to hide)");
	ui->setframe(u, "win.panel", IcPaint->FrameDouble);
	ui->setcontent(u, "win.panel",
		"Sparse scheduled stream model. c cycles charset by terminal source policy. t toggles truecolor. Press m to toggle optional mouse wheel focus.");
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
	ui->bindkey(u, "m", "app", "app.mouse");
	ui->bindkey(u, "M", "app", "app.mouse");

	if(!panelvisible)
		ui->dispatch(u, msg->newmsg("matrix", "win.panel", IcMsg->KindCommand, "node.toggle"));

	ui->setfocus(u, "btn.pause");
	ui->setstatus(u, statusline());
}

#
# Rebuild the UI after a terminal size change.
#
# Do not call ui->close(old) while the raw input loop is active. Closing the
# old renderer during live input can disturb tty state. The old UI is detached
# from large buffers so the runtime can reclaim most memory.
#
rebuildui(u: ref IcUi->Ui, oldw, oldh: int): ref IcUi->Ui
{
	nu: ref IcUi->Ui;
	msgtext: string;

	if(u != nil && u.renderer != nil){
		u.renderer.front = nil;
		u.renderer.back = nil;
		u.renderer.out = nil;
	}
	if(u != nil)
		u.tree = nil;

	resizes++;
	initmatrix();

	nu = ui->new(out, cw, ch);
	if(nu == nil)
		return nil;

	build(nu);

	ui->canvasclear(nu, canvasid, " ", BgCode);

	msgtext = sys->sprint("resize %dx%d -> %dx%d | %s",
		oldw, oldh, cw, ch, statusline());

	ui->setstatus(nu, msgtext);
	fulldraw(nu);

	return nu;
}

#
# Check whether the host terminal size changed.
#
# If a resize is detected, the UI is rebuilt to match the new console
# dimensions. User-selected truecolor and charset mode are preserved.
#
checkresize(u: ref IcUi->Ui): ref IcUi->Ui
{
	oldw, oldh, keeptruecolor, keepcharset: int;

	oldw = cw;
	oldh = ch;
	keeptruecolor = truecolor;
	keepcharset = charsetmode;

	readconsoleparams();

	truecolor = keeptruecolor;
	charsetmode = keepcharset;
	setcharset();

	if(cw == oldw && ch == oldh)
		return u;

	return rebuildui(u, oldw, oldh);
}

#
# Throttled resize check.
#
# This avoids reading /dev/consinfo on every animation event.
#
maybecheckresize(u: ref IcUi->Ui): ref IcUi->Ui
{
	now: int;

	now = sys->millisec();

	if(lastresizecheck != 0 && now - lastresizecheck < ResizeCheckMs)
		return u;

	lastresizecheck = now;
	return checkresize(u);
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

	'm' =>
		togglemouse(u);
		return 1;

	'M' =>
		togglemouse(u);
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

	"app.mouse" =>
		togglemouse(u);
		return;

	* =>
		return;
	}
}

#
# Parse one integer at offset i.
#
# The mouse event file is simple text, so a local parser keeps this example
# independent from additional helper modules.
#
parseintat(s: string, i: int): (int, int, int)
{
	sign, v, ok: int;

	while(i < len s && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
		i++;

	sign = 1;
	if(i < len s && s[i] == '-'){
		sign = -1;
		i++;
	}

	v = 0;
	ok = 0;

	while(i < len s && s[i] >= '0' && s[i] <= '9'){
		v = v * 10 + int s[i] - int '0';
		i++;
		ok = 1;
	}

	if(!ok)
		return (0, i, 0);

	return (sign * v, i, 1);
}

#
# Open optional raw mouse input.
#
# Failure is not fatal. The demo remains fully keyboard-controllable.
#
openmouse(): int
{
	if(mousefd != nil)
		return 0;

	mousefd = sys->open(MousePath, Sys->OREAD);
	if(mousefd == nil){
		mouseopen = 0;
		return -1;
	}

	mouseopen = 1;
	return 0;
}

#
# Close optional raw mouse input.
#
closemouse()
{
	mousefd = nil;
	mouseopen = 0;
}

#
# Toggle optional mouse support.
#
# Enabling mouse may make the host console route wheel input to the application
# instead of its scrollbars. That is why mouse remains toggleable even though
# the demo enables it by default.
#
togglemouse(u: ref IcUi->Ui)
{
	if(mouseopen){
		closemouse();
		ui->setstatus(u, "mouse off | " + statusline());
		fulldraw(u);
		return;
	}

	if(openmouse() == 0){
		spawn mouseproc();
		ui->setstatus(u, "mouse on | " + statusline());
	}
	else
		ui->setstatus(u, "mouse unavailable | " + statusline());

	fulldraw(u);
}

#
# Handle one raw mouse event.
#
# Wheel events move focus by one item per delivered mouse record.
#
handlemouse(u: ref IcUi->Ui, raw: string): int
{
	i, ok, x, y, buttons, mods: int;
	id: string;

	x = 0;
	y = 0;
	mods = 0;

	if(u == nil || raw == "" || len raw < 2)
		return 0;

	if(raw[0] != 'm')
		return 0;

	i = 1;

	(x, i, ok) = parseintat(raw, i);
	if(!ok)
		return 0;

	(y, i, ok) = parseintat(raw, i);
	if(!ok)
		return 0;

	(buttons, i, ok) = parseintat(raw, i);
	if(!ok)
		return 0;

	(mods, i, ok) = parseintat(raw, i);
	if(!ok)
		mods = 0;

	if((buttons & MouseWheelUp) != 0){
		id = view->prevfocus(u.tree);
		if(id != ""){
			ui->setfocus(u, id);
			ui->setstatus(u, "wheel up focus " + id + " | " + statusline());
			fulldraw(u);
			return 1;
		}
	}

	if((buttons & MouseWheelDown) != 0){
		id = view->nextfocus(u.tree);
		if(id != ""){
			ui->setfocus(u, id);
			ui->setstatus(u, "wheel down focus " + id + " | " + statusline());
			fulldraw(u);
			return 1;
		}
	}

	x = x;
	y = y;
	mods = mods;

	return 0;
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
# Optional mouse reader process.
#
# It drops events when the channel is full. Mouse input is auxiliary, so it
# must never block shutdown or animation.
#
mouseproc()
{
	n: int;
	raw: string;

	for(;;){
		if(!running)
			return;

		if(mousefd == nil)
			return;

		n = sys->read(mousefd, mousebuf, len mousebuf);

		if(!running)
			return;

		if(n <= 0)
			return;

		raw = string mousebuf[0:n];

		alt {
		mousec <-= raw =>
			;

		* =>
			;
		}
	}
}

#
# Single animation timer process.
#
# It posts lightweight ticks. The main loop decides which streams are due.
#
animproc()
{
	for(;;){
		if(!running)
			return;

		sys->sleep(AnimTickMs);

		if(!running)
			return;

		alt {
		streamc <-= 1 =>
			;

		* =>
			;
		}
	}
}

#
# Clean up terminal, input, mouse, and renderer state.
#
cleanup(u: ref IcUi->Ui)
{
	running = 0;

	closemouse();
	ui->closeinput();

	if(u != nil)
		ui->close(u);

	restoreterminal();
	leaveappscreen();
}

#
# Program entry point.
#
# The overall application lifecycle is:
#
# 1. Load modules.
# 2. Enter the alternate terminal screen.
# 3. Read terminal capabilities.
# 4. Initialize model state.
# 5. Build the icurses UI tree.
# 6. Open keyboard and mouse input.
# 7. Spawn background processes.
# 8. Run the main event loop.
# 9. Close input/UI and restore the terminal cleanly.
#
init(nil: ref Draw->Context, nil: list of string)
{
	u: ref IcUi->Ui;
	k, tick, done: int;
	raw: string;
	m: IcMsg->Msg;

	u = nil;
	appscreen = 0;

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

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	ic->init();
	ui->init();
	msg->init();
	view->init();

	out = sys->fildes(1);

	enterappscreen();
	readconsoleparams();

	paused = 0;
	speedcoef = 1;
	charsetmode = defaultcharset();
	running = 0;
	lastkey = 0;
	panelvisible = 1;
	resizes = 0;
	mouseopen = 0;
	lastresizecheck = 0;

	mousefd = nil;
	mousebuf = array[128] of byte;

	setcharset();

	keyc = chan[16] of int;
	streamc = chan[16] of int;
	mousec = chan[16] of string;

	initmatrix();

	u = ui->new(out, cw, ch);
	if(u == nil){
		restoreterminal();
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	build(u);

	ui->canvasclear(u, canvasid, " ", BgCode);
	fulldraw(u);

	if(ui->openinput() < 0){
		ui->close(u);
		restoreterminal();
		leaveappscreen();
		sys->print("cannot open keyboard\n");
		return;
	}

	openmouse();

	ui->setstatus(u, statusline());
	fulldraw(u);

	running = 1;
	done = 0;

	spawn keyproc();
	spawn animproc();

	if(mouseopen)
		spawn mouseproc();

	#
	# Draw the first due stream updates immediately, before the first timer
	# tick arrives. Initial head depths are randomized, so this does not create
	# a synchronized all-column visible start.
	#
	processstreams(u);

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

		u = checkresize(u);
		if(u == nil){
			done = 1;
			break;
		}

		if(handleanimkey(u, k))
			break;

		m = ui->handlekey(u, k);
		fulldraw(u);
		appmsg(u, m);

		if(m.kind == IcMsg->KindNone){
			ui->setstatus(u, "raw key=" + sys->sprint("%d", k) + " | " + statusline());
			fulldraw(u);
		}

	raw = <-mousec =>
		u = maybecheckresize(u);
		if(u == nil){
			done = 1;
			break;
		}

		handlemouse(u, raw);

	tick = <-streamc =>
		tick = tick;

		u = maybecheckresize(u);
		if(u == nil){
			done = 1;
			break;
		}

		processstreams(u);
	}

	cleanup(u);

	sys->print("\nresult: ok\n");
}