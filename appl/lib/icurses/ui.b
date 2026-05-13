implement IcUi;

include "icurses/ui.m";

MousePath: con "/dev/emouse";

MKindNone:   con 0;
MKindMove:   con 1;
MKindDown:   con 2;
MKindUp:     con 3;
MKindDrag:   con 4;
MKindButton: con 5;

#
# Default UI-level quit hotkeys.
#
# These are fallback defaults used by IcUi->new().
# Applications can override them through IcUi->setquitkeys().
# Set a key to "" to disable that quit binding.
#
DefaultQuitKey1: con "q";
DefaultQuitKey2: con "Q";

EscapeKeyCode: con 27;

sys: Sys;
view: IcView;
paint: IcPaint;
msg: IcMsg;
keymap: IcKeymap;
ic: Icurses;

keyc: chan of int;
tickc: chan of int;
mousec: chan of string;

keypid: int;
mousepid: int;
tickpid: int;

keypidc: chan of int;
mousepidc: chan of int;
tickpidc: chan of int;

keydonec: chan of int;
mousedonec: chan of int;
tickdonec: chan of int;

inputrunning: int;
inputopened: int;
mouseenabled: int;
mouseopened: int;
activetickms: int;

mousefd: ref Sys->FD;
mousebuf: array of byte;

lastmouseok: int;
lastx: int;
lasty: int;
lastbuttons: int;
lastmods: int;

activeui: ref IcUi->Ui;

pressnode: fn(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg;

hotkeymatch: fn(k: int, hotkey: string): int;
findhotkeynode: fn(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node;
findhotkey: fn(u: ref IcUi->Ui, k: int): ref IcView->Node;
newstep: fn(kind, done, key, tick: int, m: IcMsg->Msg, status: string): IcUi->Step;
quitkeymatch: fn(k: int, key: string): int;

parseintat: fn(s: string, i: int): (int, int, int);
encodemouse: fn(kind, x, y, buttons, oldbuttons, mods, dx, dy: int): string;
nonemouse: fn(): string;
resetmouse: fn();
openmouse: fn(): int;
closemouse: fn();
classifymouse: fn(x, y, buttons, mods: int): string;
parsemouse: fn(s: string): string;
readmouse: fn(): string;

focusok: fn(u: ref IcUi->Ui, n: ref IcView->Node): int;
actionok: fn(u: ref IcUi->Ui, n: ref IcView->Node): int;
ensurefocus: fn(u: ref IcUi->Ui): ref IcView->Node;

killpid: fn(pid: int);
wakeinputreaders: fn();
timeoutproc: fn(c: chan of int, ms: int);
waitdone: fn(c: chan of int, ms: int): int;

keyproc: fn();
mouseproc: fn();
tickproc: fn();

clamp: fn(v, lo, hi: int): int;
percenttext: fn(value, total: int): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	paint = load IcPaint IcPaint->PATH;
	if(paint == nil)
		raise "fail:load icpaint";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	keymap = load IcKeymap IcKeymap->PATH;
	if(keymap == nil)
		raise "fail:load ickeymap";

	ic->init();
	view->init();
	paint->init();
	msg->init();
	keymap->init();

	keyc = chan[16] of int;
	tickc = chan[4] of int;
	mousec = chan[64] of string;

	keypid = 0;
	mousepid = 0;
	tickpid = 0;

	keypidc = chan of int;
	mousepidc = chan of int;
	tickpidc = chan of int;

	keydonec = chan[1] of int;
	mousedonec = chan[1] of int;
	tickdonec = chan[1] of int;

	inputrunning = 0;
	inputopened = 0;
	mouseenabled = 0;
	mouseopened = 0;
	activetickms = 100;

	mousefd = nil;
	mousebuf = array[128] of byte;
	activeui = nil;
	resetmouse();
}

clamp(v, lo, hi: int): int
{
	if(v < lo)
		return lo;
	if(v > hi)
		return hi;
	return v;
}

percenttext(value, total: int): string
{
	p: int;

	if(total <= 0)
		total = 100;

	value = clamp(value, 0, total);

	p = (value * 100) / total;
	p = clamp(p, 0, 100);

	return sys->sprint("%d%%", p);
}

killpid(pid: int)
{
	fd: ref Sys->FD;

	if(pid <= 0)
		return;

	fd = sys->open("/prog/" + sys->sprint("%d", pid) + "/ctl", Sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "kill");
}

wakeinputreaders()
{
	fd: ref Sys->FD;

	fd = sys->open(Icurses->ConsctlPath, Sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "rawoff");
}

timeoutproc(c: chan of int, ms: int)
{
	if(ms > 0)
		sys->sleep(ms);

	c <-= 1;
}

waitdone(c: chan of int, ms: int): int
{
	tc: chan of int;
	v: int;

	if(c == nil)
		return 0;

	tc = chan[1] of int;
	spawn timeoutproc(tc, ms);

	alt {
	v = <-c =>
		return 1;

	v = <-tc =>
		return 0;
	}

	return 0;
}

parseintat(s: string, i: int): (int, int, int)
{
	sign, v, c, ok: int;

	while(i < len s && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
		i++;

	sign = 1;

	if(i < len s && s[i] == '-'){
		sign = -1;
		i++;
	}

	v = 0;
	ok = 0;

	while(i < len s){
		c = int s[i];

		if(c < '0' || c > '9')
			break;

		v = v * 10 + c - '0';
		ok = 1;
		i++;
	}

	if(!ok)
		return (0, i, 0);

	return (sign * v, i, 1);
}

encodemouse(kind, x, y, buttons, oldbuttons, mods, dx, dy: int): string
{
	return sys->sprint("%d %d %d %d %d %d %d %d",
		kind,
		x,
		y,
		buttons,
		oldbuttons,
		mods,
		dx,
		dy);
}

nonemouse(): string
{
	return encodemouse(MKindNone, 0, 0, 0, 0, 0, 0, 0);
}

resetmouse()
{
	lastmouseok = 0;
	lastx = 0;
	lasty = 0;
	lastbuttons = 0;
	lastmods = 0;
}

openmouse(): int
{
	if(mousefd != nil)
		return 0;

	mousefd = sys->open(MousePath, Sys->OREAD);
	if(mousefd == nil)
		return -1;

	resetmouse();
	return 0;
}

closemouse()
{
	mousefd = nil;
	resetmouse();
}

classifymouse(x, y, buttons, mods: int): string
{
	kind, oldbuttons, dx, dy: int;

	if(!lastmouseok){
		oldbuttons = 0;
		dx = 0;
		dy = 0;

		if(buttons != 0)
			kind = MKindDown;
		else
			kind = MKindMove;

		lastx = x;
		lasty = y;
		lastbuttons = buttons;
		lastmods = mods;
		lastmouseok = 1;

		return encodemouse(kind, x, y, buttons, oldbuttons, mods, dx, dy);
	}

	oldbuttons = lastbuttons;
	dx = x - lastx;
	dy = y - lasty;

	if(buttons != oldbuttons){
		if(oldbuttons == 0 && buttons != 0)
			kind = MKindDown;
		else if(oldbuttons != 0 && buttons == 0)
			kind = MKindUp;
		else
			kind = MKindButton;
	}
	else if(buttons != 0 && (dx != 0 || dy != 0))
		kind = MKindDrag;
	else if(dx != 0 || dy != 0)
		kind = MKindMove;
	else
		kind = MKindMove;

	lastx = x;
	lasty = y;
	lastbuttons = buttons;
	lastmods = mods;
	lastmouseok = 1;

	return encodemouse(kind, x, y, buttons, oldbuttons, mods, dx, dy);
}

parsemouse(s: string): string
{
	i, ok: int;
	x, y, buttons, mods: int;

	if(s == "" || len s < 2)
		return nonemouse();

	if(s[0] != 'm')
		return nonemouse();

	i = 1;

	(x, i, ok) = parseintat(s, i);
	if(!ok)
		return nonemouse();

	(y, i, ok) = parseintat(s, i);
	if(!ok)
		return nonemouse();

	(buttons, i, ok) = parseintat(s, i);
	if(!ok)
		return nonemouse();

	(mods, i, ok) = parseintat(s, i);
	if(!ok)
		mods = 0;

	return classifymouse(x, y, buttons, mods);
}

readmouse(): string
{
	n: int;
	s: string;

	if(mousefd == nil)
		return nonemouse();

	n = sys->read(mousefd, mousebuf, len mousebuf);
	if(n <= 0)
		return nonemouse();

	s = string mousebuf[0:n];

	return parsemouse(s);
}

new(out: ref Sys->FD, w, h: int): ref IcUi->Ui
{
	u: ref IcUi->Ui;

	u = ref IcUi->Ui;
	u.tree = view->newtree();
	u.renderer = paint->new(out, w, h);
	u.keymap = keymap->new();

	u.status = "ready";
	u.help = "";
	u.helprow = h - 2;
	u.statusrow = h - 1;

	u.lastmsg = msg->none();
	u.running = 0;

	u.keyc = chan[16] of int;
	u.tickc = chan[4] of int;
	u.tickms = 100;
	u.ticks = 0;

	#
	# Default quit keys can be overridden by the application.
	# Set a key to "" to disable it.
	#
	u.quitkey1 = DefaultQuitKey1;
	u.quitkey2 = DefaultQuitKey2;

	return u;
}

close(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	stop(u);
	paint->close(u.renderer);

	if(activeui == u)
		activeui = nil;
}

settick(u: ref IcUi->Ui, ms: int)
{
	if(u == nil)
		return;

	if(ms <= 0)
		ms = 100;

	u.tickms = ms;
}

setquitkeys(u: ref IcUi->Ui, key1, key2: string)
{
	if(u == nil)
		return;

	u.quitkey1 = key1;
	u.quitkey2 = key2;
}

enablemouse(u: ref IcUi->Ui, enabled: int): int
{
	if(u == nil)
		return -1;

	if(u.running)
		return -1;

	mouseenabled = enabled != 0;

	return 0;
}

ismouseenabled(u: ref IcUi->Ui): int
{
	u = u;
	return mouseenabled;
}

ismouseopen(u: ref IcUi->Ui): int
{
	u = u;
	return mouseopened;
}

start(u: ref IcUi->Ui): int
{
	if(u == nil)
		return -1;

	if(u.running)
		return 0;

	keyc = chan[16] of int;
	tickc = chan[4] of int;
	mousec = chan[64] of string;

	u.keyc = keyc;
	u.tickc = tickc;

	keypidc = chan of int;
	mousepidc = chan of int;
	tickpidc = chan of int;

	keydonec = chan[1] of int;
	mousedonec = chan[1] of int;
	tickdonec = chan[1] of int;

	keypid = 0;
	mousepid = 0;
	tickpid = 0;

	inputopened = 0;
	mouseopened = 0;
	inputrunning = 0;

	activetickms = u.tickms;
	if(activetickms <= 0)
		activetickms = 100;

	if(ic->openkbd() < 0)
		return -1;

	inputopened = 1;

	if(mouseenabled){
		if(openmouse() < 0){
			ic->closekbd();
			inputopened = 0;
			mouseopened = 0;
			return -1;
		}

		mouseopened = 1;
	}
	else
		mouseopened = 0;

	u.running = 1;
	inputrunning = 1;
	activeui = u;

	spawn keyproc();
	keypid = <-keypidc;

	if(mouseopened){
		spawn mouseproc();
		mousepid = <-mousepidc;
	}

	spawn tickproc();
	tickpid = <-tickpidc;

	return 0;
}

stop(u: ref IcUi->Ui)
{
	keyok, mouseok, tickok: int;

	if(u == nil)
		return;

	if(!u.running && !inputopened && !mouseopened && !inputrunning)
		return;

	u.running = 0;
	inputrunning = 0;

	wakeinputreaders();

	keyok = 1;
	mouseok = 1;
	tickok = 1;

	if(keypid > 0)
		keyok = waitdone(keydonec, 700);

	if(mousepid > 0)
		mouseok = waitdone(mousedonec, 700);

	if(tickpid > 0)
		tickok = waitdone(tickdonec, activetickms + 200);

	if(keypid > 0){
		if(!keyok)
			killpid(keypid);
		keypid = 0;
	}

	if(mousepid > 0){
		if(!mouseok)
			killpid(mousepid);
		mousepid = 0;
	}

	if(tickpid > 0){
		if(!tickok)
			killpid(tickpid);
		tickpid = 0;
	}

	if(mouseopened){
		closemouse();
		mouseopened = 0;
	}

	if(inputopened){
		ic->closekbd();
		inputopened = 0;
	}

	if(activeui == u)
		activeui = nil;
}

newstep(kind, done, key, tick: int, m: IcMsg->Msg, status: string): IcUi->Step
{
	s: IcUi->Step;

	s.kind = kind;
	s.done = done;
	s.key = key;
	s.tick = tick;
	s.msg = m;
	s.status = status;

	return s;
}

quitkeymatch(k: int, key: string): int
{
	if(key == "")
		return 0;

	if(len key == 1)
		return k == key[0];

	return ic->keyname(k) == key;
}

step(u: ref IcUi->Ui): IcUi->Step
{
	k, t, mk, i, ok: int;
	m: IcMsg->Msg;
	raw: string;

	if(u == nil)
		return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), "nil ui");

	if(!u.running)
		return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), u.status);

	alt {
	k = <-keyc =>
		if(k < 0 || isquit(k)){
			stop(u);
			return newstep(IcUi->StepDone, 1, k, 0, msg->none(), "done");
		}

		m = handlekey(u, k);
		return newstep(IcUi->StepKey, 0, k, 0, m, u.status);

	raw = <-mousec =>
		i = 0;
		(mk, i, ok) = parseintat(raw, i);
		if(!ok || mk == MKindNone){
			stop(u);
			return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), "mouse closed");
		}

		return newstep(IcUi->StepMouse, 0, -1, 0, msg->none(), raw);

	t = <-tickc =>
		u.ticks = t;
		return newstep(IcUi->StepTick, 0, -1, t, msg->none(), u.status);
	}

	return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), u.status);
}

keyproc()
{
	k: int;

	keypidc <-= sys->pctl(0, nil);

	for(;;){
		if(!inputrunning)
			break;

		k = ic->readkey();

		if(!inputrunning)
			break;

		keyc <-= k;

		if(k < 0)
			break;
	}

	if(keydonec != nil)
		keydonec <-= 1;
}

mouseproc()
{
	raw: string;

	mousepidc <-= sys->pctl(0, nil);

	for(;;){
		if(!inputrunning)
			break;

		raw = readmouse();

		if(!inputrunning)
			break;

		mousec <-= raw;

		if(raw == nonemouse())
			break;
	}

	if(mousedonec != nil)
		mousedonec <-= 1;
}

tickproc()
{
	t: int;

	tickpidc <-= sys->pctl(0, nil);

	t = 0;

	for(;;){
		if(!inputrunning)
			break;

		sys->sleep(activetickms);

		if(!inputrunning)
			break;

		t++;
		tickc <-= t;
	}

	if(tickdonec != nil)
		tickdonec <-= 1;
}

openinput(): int
{
	return ic->openkbd();
}

closeinput()
{
	ic->closekbd();
}

readkey(): int
{
	return ic->readkey();
}

isquit(k: int): int
{
	u: ref IcUi->Ui;

	if(k == EscapeKeyCode)
		return 1;

	u = activeui;
	if(u == nil)
		return 0;

	if(quitkeymatch(k, u.quitkey1))
		return 1;

	if(quitkeymatch(k, u.quitkey2))
		return 1;

	return 0;
}

rootid(u: ref IcUi->Ui): int
{
	if(u == nil || u.tree == nil)
		return IcView->NoId;
	return u.tree.rootid;
}

setframestyle(u: ref IcUi->Ui, style: int)
{
	if(u == nil)
		return;
	paint->setframestyle(u.renderer, style);
}

sethelp(u: ref IcUi->Ui, help: string)
{
	if(u == nil)
		return;
	u.help = help;
}

setstatus(u: ref IcUi->Ui, status: string)
{
	if(u == nil)
		return;
	u.status = status;
}

setstatusrows(u: ref IcUi->Ui, helprow, statusrow: int)
{
	if(u == nil)
		return;

	u.helprow = helprow;
	u.statusrow = statusrow;
}

node(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, kind, IcView->NoId, x, y, w, h);

	return view->addchildnode(u.tree, parentid, n);
}

group(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int
{
	return node(u, parentid, id, "group", x, y, w, h);
}

label(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = len text;
	if(w <= 0)
		w = 1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "label", IcView->NoId, x, y, w, 1);
	view->settext(n, text);

	return view->addchildnode(u.tree, parentid, n);
}

window(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, title: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "window", IcView->NoId, x, y, w, h);
	view->settext(n, title);

	return view->addchildnode(u.tree, parentid, n);
}

shadowwindow(u: ref IcUi->Ui, parentid, shadowid, id: int, x, y, w, h: int, title: string, dx, dy: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(w < 4)
		w = 4;
	if(h < 3)
		h = 3;

	if(dx != 0 || dy != 0){
		if(shadowid == IcView->NoId)
			shadowid = view->allocid(u.tree);

		if(node(u, parentid, shadowid, "shadow", x + dx, y + dy, w, h) < 0)
			return -1;
	}

	return window(u, parentid, id, x, y, w, h, title);
}

button(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, label, hotkey: string, targetid: int, command: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "button", IcView->NoId, x, y, w, h);
	view->settext(n, label);
	view->sethotkey(n, hotkey);
	view->setaction(n, targetid, command);
	view->setfocusable(n, 1);

	return view->addchildnode(u.tree, parentid, n);
}

canvas(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int
{
	if(id == IcView->NoId && u != nil && u.tree != nil)
		id = view->allocid(u.tree);

	if(node(u, parentid, id, "canvas", x, y, w, h) < 0)
		return -1;

	return paint->canvasnew(id, w, h);
}

hbar(u: ref IcUi->Ui, parentid, id: int, x, y, w, value, total: int): int
{
	if(node(u, parentid, id, "hbar", x, y, w, 1) < 0)
		return -1;

	return setbar(u, id, value, total);
}

vbar(u: ref IcUi->Ui, parentid, id: int, x, y, h, value, total: int): int
{
	if(node(u, parentid, id, "vbar", x, y, 1, h) < 0)
		return -1;

	return setbar(u, id, value, total);
}

setbar(u: ref IcUi->Ui, id: int, value, total: int): int
{
	n: ref IcView->Node;
	style: int;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	if(total <= 0)
		total = 100;

	if(value < 0)
		value = 0;
	if(value > total)
		value = total;

	style = n.iarg2;

	view->setargs(n, "", value, total, style);
	return 0;
}

progress(u: ref IcUi->Ui, parentid, id: int, x, y, w, value, total: int): int
{
	if(w < 3)
		w = 3;

	if(node(u, parentid, id, "progress", x, y, w, 1) < 0)
		return -1;

	return setprogress(u, id, value, total);
}

setprogress(u: ref IcUi->Ui, id: int, value, total: int): int
{
	return setbar(u, id, value, total);
}

progressstyle(u: ref IcUi->Ui, id: int, style: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setargs(n, n.sarg, n.iarg0, n.iarg1, style);
	return 0;
}

spinner(u: ref IcUi->Ui, parentid, id: int, x, y, style: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "spinner", IcView->NoId, x, y, 1, 1);
	view->setargs(n, "", 0, style, 0);

	return view->addchildnode(u.tree, parentid, n);
}

setspinner(u: ref IcUi->Ui, id: int, frame: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setargs(n, n.sarg, frame, n.iarg1, n.iarg2);
	return 0;
}

tickspinner(u: ref IcUi->Ui, id: int): int
{
	n: ref IcView->Node;
	frame, style: int;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	frame = n.iarg0 + 1;
	style = n.iarg1;

	if(style < 0)
		style = 0;

	if(style == 0){
		if(frame > 3)
			frame = 0;
	}
	else{
		if(frame > 7)
			frame = 0;
	}

	view->setargs(n, n.sarg, frame, n.iarg1, n.iarg2);
	return 0;
}

listbox(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, title: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "listbox", IcView->NoId, x, y, w, h);
	view->settext(n, title);
	view->setfocusable(n, 1);

	return view->addchildnode(u.tree, parentid, n);
}

setlistbox(u: ref IcUi->Ui, id: int, items: array of string, top, sel: int): int
{
	n: ref IcView->Node;
	s: string;
	i: int;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	s = "";
	for(i = 0; i < len items; i++){
		if(i > 0)
			s += "\n";
		s += items[i];
	}

	view->setcontent(n, s);
	view->setargs(n, "", top, sel, 0);
	return 0;
}

taskdialog(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, title: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w < 20)
		w = 20;

	if(id == IcView->NoId)
		id = view->allocid(u.tree);

	n = view->newnode(id, "taskdialog", IcView->NoId, x, y, w, 6);
	view->settext(n, title);

	return view->addchildnode(u.tree, parentid, n);
}

settaskdialog(u: ref IcUi->Ui, id: int, phase, src, dst, item: string, itemvalue, totalvalue, meter: int): int
{
	n: ref IcView->Node;
	s: string;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	s =
		phase + "\n" +
		src + "\n" +
		dst + "\n" +
		item;

	view->setcontent(n, s);
	view->setargs(n, "", itemvalue, totalvalue, meter);
	return 0;
}

ticktaskdialog(u: ref IcUi->Ui, id: int): int
{
	n: ref IcView->Node;
	itemvalue, totalvalue: int;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	itemvalue = n.iarg0 + 1;
	totalvalue = n.iarg1;
	if(totalvalue <= 0)
		totalvalue = 100;
	if(itemvalue > totalvalue)
		itemvalue = totalvalue;

	view->setargs(n, n.sarg, itemvalue, totalvalue, n.iarg2);
	return 0;
}

bindkey(u: ref IcUi->Ui, key: string, targetid: int, command: string): int
{
	if(u == nil || u.keymap == nil)
		return -1;

	return keymap->bind(u.keymap, key, targetid, command);
}

bindkeyargs(u: ref IcUi->Ui, key: string, targetid: int, command, sarg: string, iarg0, iarg1, iarg2: int): int
{
	if(u == nil || u.keymap == nil)
		return -1;

	return keymap->bindargs(u.keymap, key, targetid, command, sarg, iarg0, iarg1, iarg2);
}

settext(u: ref IcUi->Ui, id: int, text: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->settext(n, text);
	return 0;
}

setcontent(u: ref IcUi->Ui, id: int, content: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, content);
	return 0;
}

setscroll(u: ref IcUi->Ui, id: int, scroll, scrollpos: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setscroll(n, scroll);
	view->setscrollpos(n, scrollpos);
	return 0;
}

setframe(u: ref IcUi->Ui, id: int, frame: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setframe(n, frame);
	return 0;
}

setargs(u: ref IcUi->Ui, id: int, sarg: string, iarg0, iarg1, iarg2: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setargs(n, sarg, iarg0, iarg1, iarg2);
	return 0;
}

setfocus(u: ref IcUi->Ui, id: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(view->setfocus(u.tree, id) < 0)
		return -1;

	u.status = "focus " + sys->sprint("%d", id);
	return 0;
}

canvasclear(u: ref IcUi->Ui, id: int, ch, code: string): int
{
	u = u;
	return paint->canvasclear(id, ch, code);
}

canvasfill(u: ref IcUi->Ui, id: int, x, y, w, h: int, ch, code: string): int
{
	u = u;
	return paint->canvasfill(id, x, y, w, h, ch, code);
}

canvasputc(u: ref IcUi->Ui, id: int, x, y: int, ch, code: string): int
{
	u = u;
	return paint->canvasputc(id, x, y, ch, code);
}

canvasputs(u: ref IcUi->Ui, id: int, x, y: int, text, code: string): int
{
	u = u;
	return paint->canvasputs(id, x, y, text, code);
}

draw(u: ref IcUi->Ui)
{
	if(u == nil || u.renderer == nil || u.tree == nil)
		return;

	paint->clear(u.renderer);
	paint->drawtree(u.renderer, u.tree);

	if(u.helprow >= 0)
		paint->status(u.renderer, u.helprow, u.help);

	if(u.statusrow >= 0)
		paint->status(u.renderer, u.statusrow, u.status);

	paint->flush(u.renderer);
}

focusok(u: ref IcUi->Ui, n: ref IcView->Node): int
{
	u = u;

	if(n == nil)
		return 0;

	if(!view->isvisible(n))
		return 0;

	if(!view->isenabled(n))
		return 0;

	if(!view->isfocusable(n))
		return 0;

	return 1;
}

actionok(u: ref IcUi->Ui, n: ref IcView->Node): int
{
	u = u;

	if(n == nil)
		return 0;

	if(!view->isvisible(n))
		return 0;

	if(!view->isenabled(n))
		return 0;

	return 1;
}

ensurefocus(u: ref IcUi->Ui): ref IcView->Node
{
	n: ref IcView->Node;
	id: int;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->focusnode(u.tree);
	if(focusok(u, n))
		return n;

	id = view->nextfocus(u.tree);
	if(id == IcView->NoId)
		return nil;

	view->setfocus(u.tree, id);
	return view->find(u.tree, id);
}

hotkeymatch(k: int, hotkey: string): int
{
	if(hotkey == "")
		return 0;

	if(len hotkey == 1){
		if(k == hotkey[0])
			return 1;

		if(k >= 'A' && k <= 'Z' && hotkey[0] >= 'a' && hotkey[0] <= 'z')
			return k - 'A' + 'a' == hotkey[0];

		if(k >= 'a' && k <= 'z' && hotkey[0] >= 'A' && hotkey[0] <= 'Z')
			return k - 'a' + 'A' == hotkey[0];

		return 0;
	}

	return ic->keyname(k) == hotkey;
}

findhotkeynode(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node
{
	n, c: ref IcView->Node;
	i, cid: int;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->find(u.tree, id);
	if(n == nil || !actionok(u, n))
		return nil;

	if(hotkeymatch(k, n.hotkey))
		return n;

	for(i = 0; i < view->childcount(n); i++){
		cid = view->childat(n, i);
		c = findhotkeynode(u, cid, k);
		if(c != nil)
			return c;
	}

	return nil;
}

findhotkey(u: ref IcUi->Ui, k: int): ref IcView->Node
{
	if(u == nil || u.tree == nil)
		return nil;

	return findhotkeynode(u, u.tree.rootid, k);
}

pressnode(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg
{
	m: IcMsg->Msg;
	dst: int;
	cmd: string;

	if(u == nil || n == nil)
		return msg->none();

	dst = n.targetid;
	cmd = n.command;

	if(dst == IcView->NoId)
		dst = n.id;

	if(cmd == "")
		cmd = "button.click";

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = n.sarg;
	m.iarg0 = n.iarg0;
	m.iarg1 = n.iarg1;
	m.iarg2 = n.iarg2;

	return dispatch(u, m);
}

handlekey(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	n: ref IcView->Node;
	m: IcMsg->Msg;
	nav: int;
	id: int;

	if(u == nil || u.tree == nil)
		return msg->none();

	m = keymap->find(u.keymap, k);
	if(!msg->isnone(m))
		return dispatch(u, m);

	n = findhotkey(u, k);
	if(n != nil)
		return pressnode(u, n);

	if(ic->isconfirm(k)){
		n = view->focusnode(u.tree);
		if(n != nil)
			return pressnode(u, n);
	}

	nav = ic->navkind(k);

	if(nav == Icurses->NavNext || nav == Icurses->NavRight || nav == Icurses->NavDown){
		id = view->nextfocus(u.tree);
		if(id != IcView->NoId){
			view->setfocus(u.tree, id);
			u.status = "focus " + sys->sprint("%d", id);
			return msg->newmsg(IcMsg->MsgNoNode, id, IcMsg->KindFocus, "focus.set");
		}
	}

	if(nav == Icurses->NavPrev || nav == Icurses->NavLeft || nav == Icurses->NavUp){
		id = view->prevfocus(u.tree);
		if(id != IcView->NoId){
			view->setfocus(u.tree, id);
			u.status = "focus " + sys->sprint("%d", id);
			return msg->newmsg(IcMsg->MsgNoNode, id, IcMsg->KindFocus, "focus.set");
		}
	}

	return msg->none();
}

dispatch(u: ref IcUi->Ui, m: IcMsg->Msg): IcMsg->Msg
{
	n: ref IcView->Node;
	old: string;

	if(u == nil || u.tree == nil)
		return m;

	u.lastmsg = m;

	if(m.kind != IcMsg->KindCommand){
		u.status = "msg seq=" + sys->sprint("%d", m.seq) + " ignored";
		return m;
	}

	n = view->find(u.tree, m.dst);

	if(m.cmd == "button.click"){
		u.status = "button.click src=" +
			sys->sprint("%d", m.src) +
			" dst=" +
			sys->sprint("%d", m.dst);
		m.handled = 1;
		return m;
	}

	if(m.cmd == "node.show"){
		if(n != nil){
			view->show(n);
			ensurefocus(u);
			u.status = "node.show dst=" + sys->sprint("%d", m.dst);
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.hide"){
		if(n != nil){
			view->hide(n);
			ensurefocus(u);
			u.status = "node.hide dst=" + sys->sprint("%d", m.dst);
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.toggle"){
		if(n != nil){
			if(view->isvisible(n))
				view->hide(n);
			else
				view->show(n);

			ensurefocus(u);
			u.status = "node.toggle dst=" + sys->sprint("%d", m.dst);
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "focus.set"){
		if(n != nil){
			view->setfocus(u.tree, n.id);
			u.status = "focus.set dst=" + sys->sprint("%d", m.dst);
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "status.set"){
		old = u.status;
		u.status = m.sarg;
		if(u.status == "")
			u.status = old;
		m.handled = 1;
		return m;
	}

	return m;
}