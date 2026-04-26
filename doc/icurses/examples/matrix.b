implement Matrix;

include "draw.m";
include "icurses/icurses.m";

Matrix: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ui: IcUi;
ic: Icurses;
msg: IcMsg;

out: ref Sys->FD;

DefaultW: con 80;
DefaultH: con 24;

cw: int;
ch: int;
statusy0: int;
statusy1: int;

CanvasId: con "canvas.matrix";

AsciiChars: con "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
CyrillicChars: con "АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЭЮЯабвгдежзиклмнопрстуфхцчшэюя";
CjkChars: con "日月火水木金土天地山川森林雨風雷電光闇龍鳥魚人心夢影空海石花竹門道星";

CharsetAscii: con 0;
CharsetCyrillic: con 1;
CharsetCjk: con 2;

PanelX: con 2;
PanelY: con 2;
PanelW: con 58;
PanelH: con 8;

## For recalc. the number of columns - see spacing in init()
MaxStreams: con 20;

chars: string;
seed: int;

paused: int;
speedcoef: int;
charsetmode: int;
running: int;
lastkey: int;
panelvisible: int;

colors: int;
truecolor: int;
conssource: string;

keyc: chan of int;
streamc: chan of int;

sx: array of int;
shead: array of int;
soldhead: array of int;
stail: array of int;
sbasedelay: array of int;
sdrift: array of int;
sphase: array of int;

build: fn(u: ref IcUi->Ui);

parseintat: fn(s: string, i: int): (int, int, int);
paramint: fn(s, key: string, def: int): int;
paramstr: fn(s, key, def: string): string;
readconsoleparams: fn();

setcharset: fn();
nextcharset: fn();
charsetname: fn(): string;
statusline: fn(): string;
setspeed: fn(u: ref IcUi->Ui, speed: int);

rand: fn(n: int): int;
rndchar: fn(): string;

initmatrix: fn();
resetmatrix: fn(u: ref IcUi->Ui);
resetstream: fn(i: int);

streamtop: fn(head, tail: int): int;
streambottom: fn(head: int): int;

updatestream: fn(u: ref IcUi->Ui, i: int);
drawstream: fn(u: ref IcUi->Ui, i: int, oldhead, newhead: int);
clearstream: fn(u: ref IcUi->Ui, i: int, oldhead: int);

fadecode: fn(v: int): string;
streamvalue: fn(pos, tail: int): int;
putcell: fn(u: ref IcUi->Ui, x, y: int, ch, code: string);
covered: fn(x, y: int): int;

invalidateui: fn(u: ref IcUi->Ui);
fulldraw: fn(u: ref IcUi->Ui);
resyncmatrix: fn(u: ref IcUi->Ui);

handleanimkey: fn(u: ref IcUi->Ui, k: int): int;
appmsg: fn(u: ref IcUi->Ui, m: IcMsg->Msg);

keyproc: fn();
streamproc: fn(i: int);
streamdelay: fn(i: int): int;

parseintat(s: string, i: int): (int, int, int)
{
	v, ok: int;

	v = 0;
	ok = 0;

	while(i < len s && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
		i++;

	while(i < len s && s[i] >= '0' && s[i] <= '9'){
		v = v * 10 + int s[i] - int '0';
		i++;
		ok = 1;
	}

	return (v, i, ok);
}

paramint(s, key: string, def: int): int
{
	i, j, v, ok: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		(v, j, ok) = parseintat(s, j);
		if(ok)
			return v;

		return def;
	}

	return def;
}

paramstr(s, key, def: string): string
{
	i, j: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		while(j < len s && s[j] != '\n' && s[j] != '\r')
			j++;

		if(j > i + len prefix)
			return s[i + len prefix:j];

		return def;
	}

	return def;
}

readconsoleparams()
{
	fd: ref Sys->FD;
	buf: array of byte;
	n, i, ok: int;
	s: string;

	cw = DefaultW;
	ch = DefaultH;
	statusy0 = ch - 2;
	statusy1 = ch - 1;

	colors = 16;
	truecolor = 0;
	conssource = "default";

	fd = sys->open("/dev/conssize", Sys->OREAD);
	if(fd == nil)
		return;

	buf = array[1024] of byte;
	n = sys->read(fd, buf, len buf);
	if(n <= 0)
		return;

	s = string buf[0:n];

	i = 0;
	(cw, i, ok) = parseintat(s, i);
	if(!ok)
		cw = paramint(s, "cols", DefaultW);

	(ch, i, ok) = parseintat(s, i);
	if(!ok)
		ch = paramint(s, "rows", DefaultH);

	if(cw < 40)
		cw = DefaultW;
	if(ch < 15)
		ch = DefaultH;

	colors = paramint(s, "colors", 16);
	truecolor = paramint(s, "truecolor", 0);
	conssource = paramstr(s, "source", "unknown");

	statusy0 = ch - 2;
	statusy1 = ch - 1;
}

setcharset()
{
	if(charsetmode == CharsetCjk)
		chars = CjkChars;
	else if(charsetmode == CharsetCyrillic)
		chars = CyrillicChars;
	else
		chars = AsciiChars;

	if(chars == "")
		chars = AsciiChars;
}

nextcharset()
{
	charsetmode++;
	if(charsetmode > CharsetCjk)
		charsetmode = CharsetAscii;

	setcharset();
}

charsetname(): string
{
	if(charsetmode == CharsetCjk)
		return "cjk";
	if(charsetmode == CharsetCyrillic)
		return "cyrillic";
	return "ascii";
}

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
		" | truecolor=" + string truecolor +
		" | colors=" + string colors +
		" | size=" + string cw + "x" + string ch +
		" | " + conssource;
}

setspeed(u: ref IcUi->Ui, speed: int)
{
	if(speed < 1)
		speed = 1;
	if(speed > 8)
		speed = 8;

	speedcoef = speed;
	ui->setstatus(u, statusline());
}

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

fadecode(v: int): string
{
	#
	# Truecolor palette: no yellow, only white/green shades.
	#
	if(truecolor){
		if(v >= 6)
			return "38;2;220;255;220;40";
		if(v == 5)
			return "38;2;100;255;140;40";
		if(v == 4)
			return "38;2;0;230;80;40";
		if(v == 3)
			return "38;2;0;155;50;40";
		if(v == 2)
			return "38;2;0;85;28;40";
		if(v == 1)
			return "38;2;0;30;10;40";
		return "0;30;40";
	}

	#
	# 16-color fallback palette.
	#
	if(v >= 6)
		return "1;37;40";
	if(v == 5)
		return "1;32;40";
	if(v == 4)
		return "1;32;40";
	if(v == 3)
		return "0;32;40";
	if(v == 2)
		return "0;32;40";
	if(v == 1)
		return "0;30;40";
	return "0;30;40";
}

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

streamtop(head, tail: int): int
{
	return head - tail + 1;
}

streambottom(head: int): int
{
	return head;
}

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

resetstream(i: int)
{
	if(i < 0 || i >= MaxStreams)
		return;

	shead[i] = -rand(ch);
	soldhead[i] = shead[i];

	#
	# Random immutable length until stream restart.
	#
	stail[i] = 6 + rand(18);

	#
	# Sparse mode delays: this is the visually good version.
	#
	sbasedelay[i] = 45 + rand(160);

	#
	# Drift slowly changes while the stream falls.
	#
	sdrift[i] = rand(41) - 20;
	sphase[i] = rand(1000);
}

resetmatrix(u: ref IcUi->Ui)
{
	initmatrix();
	ui->canvasclear(u, CanvasId, " ", "0;30;40");
	resyncmatrix(u);
}

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

updatestream(u: ref IcUi->Ui, i: int)
{
	old, step: int;

	if(i < 0 || i >= MaxStreams)
		return;

	if(paused)
		return;

	old = shead[i];

	#
	# Small drift; speedcoef changes probability of extra row steps,
	# but keeps jumps small enough to avoid empty-screen artifacts.
	#
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

resyncmatrix(u: ref IcUi->Ui)
{
	i, old: int;

	for(i = 0; i < MaxStreams; i++){
		old = shead[i];
		drawstream(u, i, old - stail[i] - 1, old);
	}
}

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

fulldraw(u: ref IcUi->Ui)
{
	invalidateui(u);
	ui->draw(u);
	resyncmatrix(u);
}

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
		"Sparse async stream model. Console params are read from /dev/conssize. c cycles ASCII/Cyrillic/CJK. t toggles truecolor.");
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

handleanimkey(u: ref IcUi->Ui, k: int): int
{
	lastkey = k;

	if(k == ' '){
		paused = !paused;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return 1;
	}

	if(k == '+' || k == '='){
		setspeed(u, speedcoef + 1);
		fulldraw(u);
		return 1;
	}

	if(k == '-' || k == '_'){
		setspeed(u, speedcoef - 1);
		fulldraw(u);
		return 1;
	}

	if(k == 'c' || k == 'C'){
		nextcharset();
		ui->setstatus(u, "charset switch | " + statusline());
		fulldraw(u);
		return 1;
	}

	if(k == 't' || k == 'T'){
		truecolor = !truecolor;
		ui->setstatus(u, "truecolor toggle | " + statusline());
		fulldraw(u);
		return 1;
	}

	if(k == 'h' || k == 'H'){
		ui->dispatch(u, msg->newmsg("anim", "win.panel", IcMsg->KindCommand, "node.toggle"));
		panelvisible = !panelvisible;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return 1;
	}

	return 0;
}

appmsg(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	if(m.handled)
		return;

	if(m.kind != IcMsg->KindCommand)
		return;

	if(m.cmd == "app.pause"){
		paused = !paused;
		ui->setstatus(u, statusline());
		fulldraw(u);
		return;
	}

	if(m.cmd == "app.fast"){
		setspeed(u, speedcoef + 1);
		fulldraw(u);
		return;
	}

	if(m.cmd == "app.slow"){
		setspeed(u, speedcoef - 1);
		fulldraw(u);
		return;
	}

	if(m.cmd == "app.charset"){
		nextcharset();
		ui->setstatus(u, "charset switch | " + statusline());
		fulldraw(u);
		return;
	}

	if(m.cmd == "app.truecolor"){
		truecolor = !truecolor;
		ui->setstatus(u, "truecolor toggle | " + statusline());
		fulldraw(u);
		return;
	}
}

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
	charsetmode = CharsetAscii;
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