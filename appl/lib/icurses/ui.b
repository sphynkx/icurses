implement IcUi;

include "icurses/ui.m";

sys: Sys;
view: IcView;
paint: IcPaint;
msg: IcMsg;
keymap: IcKeymap;
ic: Icurses;

pressnode: fn(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg;

hotkeymatch: fn(k: int, hotkey: string): int;
findhotkeynode: fn(u: ref IcUi->Ui, id: string, k: int): ref IcView->Node;
findhotkey: fn(u: ref IcUi->Ui, k: int): ref IcView->Node;
newstep: fn(kind, done, key, tick: int, m: IcMsg->Msg, status: string): IcUi->Step;
focusok: fn(u: ref IcUi->Ui, n: ref IcView->Node): int;
actionok: fn(u: ref IcUi->Ui, n: ref IcView->Node): int;
ensurefocus: fn(u: ref IcUi->Ui): ref IcView->Node;
keyproc: fn(u: ref IcUi->Ui);
tickproc: fn(u: ref IcUi->Ui);

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

	u.keyc = chan of int;
	u.tickc = chan of int;
	u.tickms = 100;
	u.ticks = 0;

	return u;
}

close(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	paint->close(u.renderer);
	u.running = 0;
}

settick(u: ref IcUi->Ui, ms: int)
{
	if(u == nil)
		return;

	if(ms <= 0)
		ms = 100;

	u.tickms = ms;
}

start(u: ref IcUi->Ui): int
{
	if(u == nil)
		return -1;

	if(u.running)
		return 0;

	u.running = 1;

	spawn keyproc(u);
	spawn tickproc(u);

	return 0;
}

stop(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	u.running = 0;
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

step(u: ref IcUi->Ui): IcUi->Step
{
	k, t: int;
	m: IcMsg->Msg;

	if(u == nil)
		return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), "nil ui");

	if(!u.running)
		return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), u.status);

	alt {
	k = <-u.keyc =>
		if(k < 0 || isquit(k)){
			u.running = 0;
			return newstep(IcUi->StepDone, 1, k, 0, msg->none(), "done");
		}

		m = handlekey(u, k);
		return newstep(IcUi->StepKey, 0, k, 0, m, u.status);

	t = <-u.tickc =>
		u.ticks = t;
		return newstep(IcUi->StepTick, 0, -1, t, msg->none(), u.status);
	}

	return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), u.status);
}

keyproc(u: ref IcUi->Ui)
{
	k: int;

	for(;;){
		if(u == nil || !u.running)
			return;

		k = readkey();

		if(u == nil || !u.running)
			return;

		u.keyc <-= k;

		if(k < 0)
			return;
	}
}

tickproc(u: ref IcUi->Ui)
{
	t: int;

	t = 0;

	for(;;){
		if(u == nil || !u.running)
			return;

		sys->sleep(u.tickms);

		if(u == nil || !u.running)
			return;

		t++;
		u.tickc <-= t;
	}
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
	if(k == 'q' || k == 'Q')
		return 1;

	if(ic->iscancel(k))
		return 1;

	return 0;
}

rootid(u: ref IcUi->Ui): string
{
	if(u == nil || u.tree == nil)
		return "";
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

node(u: ref IcUi->Ui, parentid, id, kind: string, x, y, w, h: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->newnode(id, kind, "", x, y, w, h);

	return view->addchildnode(u.tree, parentid, n);
}

group(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int): int
{
	return node(u, parentid, id, "group", x, y, w, h);
}

label(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, text: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = len text;
	if(w <= 0)
		w = 1;

	n = view->newnode(id, "label", "", x, y, w, 1);
	view->settext(n, text);

	return view->addchildnode(u.tree, parentid, n);
}

window(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int, title: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->newnode(id, "window", "", x, y, w, h);
	view->settext(n, title);

	return view->addchildnode(u.tree, parentid, n);
}

shadowwindow(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int, title: string, dx, dy: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(w < 4)
		w = 4;
	if(h < 3)
		h = 3;

	if(dx != 0 || dy != 0){
		if(node(u, parentid, id + ".shadow", "shadow", x + dx, y + dy, w, h) < 0)
			return -1;
	}

	return window(u, parentid, id, x, y, w, h, title);
}

button(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int, label, hotkey, targetid, command: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->newnode(id, "button", "", x, y, w, h);
	view->settext(n, label);
	view->sethotkey(n, hotkey);
	view->setaction(n, targetid, command);
	view->setfocusable(n, 1);

	return view->addchildnode(u.tree, parentid, n);
}

canvas(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int): int
{
	if(node(u, parentid, id, "canvas", x, y, w, h) < 0)
		return -1;

	return paint->canvasnew(id, w, h);
}

hbar(u: ref IcUi->Ui, parentid, id: string, x, y, w, value, total: int): int
{
	if(node(u, parentid, id, "hbar", x, y, w, 1) < 0)
		return -1;

	return setbar(u, id, value, total);
}

vbar(u: ref IcUi->Ui, parentid, id: string, x, y, h, value, total: int): int
{
	if(node(u, parentid, id, "vbar", x, y, 1, h) < 0)
		return -1;

	return setbar(u, id, value, total);
}

setbar(u: ref IcUi->Ui, id: string, value, total: int): int
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

progress(u: ref IcUi->Ui, parentid, id: string, x, y, w, value, total: int): int
{
	if(w < 3)
		w = 3;

	if(node(u, parentid, id, "progress", x, y, w, 1) < 0)
		return -1;

	return setprogress(u, id, value, total);
}

setprogress(u: ref IcUi->Ui, id: string, value, total: int): int
{
	return setbar(u, id, value, total);
}

progressstyle(u: ref IcUi->Ui, id: string, style: int): int
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

spinner(u: ref IcUi->Ui, parentid, id: string, x, y, style: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->newnode(id, "spinner", "", x, y, 1, 1);
	view->setargs(n, "", 0, style, 0);

	return view->addchildnode(u.tree, parentid, n);
}

setspinner(u: ref IcUi->Ui, id: string, frame: int): int
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

tickspinner(u: ref IcUi->Ui, id: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setargs(n, n.sarg, n.iarg0 + 1, n.iarg1, n.iarg2);
	return 0;
}

listbox(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int, title: string): int
{
	if(u == nil)
		return -1;

	if(w < 12)
		w = 12;
	if(h < 4)
		h = 4;

	if(window(u, parentid, id, x, y, w, h, title) < 0)
		return -1;

	if(canvas(u, id, id + ".cv", 1, 1, w - 2, h - 2) < 0)
		return -1;

	return 0;
}

setlistbox(u: ref IcUi->Ui, id: string, items: array of string, top, sel: int): int
{
	n: ref IcView->Node;
	cv, line, prefix: string;
	rows, cols, r, i, count, thumb: int;

	if(u == nil || u.tree == nil || items == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	cv = id + ".cv";
	rows = n.h - 2;
	cols = n.w - 2;

	if(rows <= 0 || cols <= 0)
		return -1;

	count = len items;

	if(canvasclear(u, cv, " ", "") < 0)
		return -1;

	if(count <= 0){
		canvasputs(u, cv, 0, 0, "(empty)", "");
		view->setargs(n, "", 0, -1, 0);
		return 0;
	}

	sel = clamp(sel, 0, count - 1);

	if(count <= rows)
		top = 0;
	else
		top = clamp(top, 0, count - rows);

	for(r = 0; r < rows; r++){
		i = top + r;
		if(i >= count)
			break;

		if(i == sel)
			prefix = "> ";
		else
			prefix = "  ";

		line = prefix + items[i];
		canvasputs(u, cv, 0, r, line, "");
	}

	if(count > rows){
		canvasfill(u, cv, cols - 1, 0, 1, rows, "|", "");

		thumb = (top * rows) / count;
		thumb = clamp(thumb, 0, rows - 1);

		canvasputc(u, cv, cols - 1, thumb, "#", "");
	}

	view->setargs(n, "", top, sel, count);
	return 0;
}

taskdialog(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, title: string): int
{
	if(u == nil)
		return -1;

	if(w < 50)
		w = 50;

	if(window(u, parentid, id, x, y, w, 13, title) < 0)
		return -1;

	if(spinner(u, id, id + ".spin", 2, 1, IcPaint->SpinnerAscii) < 0)
		return -1;

	if(label(u, id, id + ".phase", 4, 1, w - 8, "Preparing...") < 0)
		return -1;

	if(label(u, id, id + ".src", 2, 3, w - 6, "from:") < 0)
		return -1;

	if(label(u, id, id + ".dst", 2, 4, w - 6, "to:") < 0)
		return -1;

	if(label(u, id, id + ".item", 2, 6, w - 20, "item:") < 0)
		return -1;

	if(label(u, id, id + ".itempct", w - 16, 6, 6, "0%") < 0)
		return -1;

	if(progress(u, id, id + ".itembar", 2, 7, w - 20, 0, 100) < 0)
		return -1;

	if(progressstyle(u, id + ".itembar", IcPaint->ProgressPercent) < 0)
		return -1;

	if(label(u, id, id + ".total", 2, 9, w - 20, "total:") < 0)
		return -1;

	if(label(u, id, id + ".totalpct", w - 16, 9, 6, "0%") < 0)
		return -1;

	if(progress(u, id, id + ".totalbar", 2, 10, w - 20, 0, 100) < 0)
		return -1;

	if(progressstyle(u, id + ".totalbar", IcPaint->ProgressTail) < 0)
		return -1;

	if(label(u, id, id + ".meterlbl", w - 8, 6, 5, "I/O") < 0)
		return -1;

	if(vbar(u, id, id + ".meter", w - 7, 7, 4, 0, 100) < 0)
		return -1;

	if(label(u, id, id + ".hint", 2, 11, w - 6, "task dialog") < 0)
		return -1;

	return 0;
}

settaskdialog(u: ref IcUi->Ui, id, phase, src, dst, item: string, itemvalue, totalvalue, meter: int): int
{
	itemp, totalp: string;

	if(u == nil)
		return -1;

	itemvalue = clamp(itemvalue, 0, 100);
	totalvalue = clamp(totalvalue, 0, 100);
	meter = clamp(meter, 0, 100);

	itemp = percenttext(itemvalue, 100);
	totalp = percenttext(totalvalue, 100);

	if(settext(u, id + ".phase", phase) < 0)
		return -1;

	if(settext(u, id + ".src", "from: " + src) < 0)
		return -1;

	if(settext(u, id + ".dst", "to:   " + dst) < 0)
		return -1;

	if(settext(u, id + ".item", "item: " + item) < 0)
		return -1;

	if(settext(u, id + ".itempct", itemp) < 0)
		return -1;

	if(settext(u, id + ".total", "total: " + totalp) < 0)
		return -1;

	if(settext(u, id + ".totalpct", totalp) < 0)
		return -1;

	if(setprogress(u, id + ".itembar", itemvalue, 100) < 0)
		return -1;

	if(setprogress(u, id + ".totalbar", totalvalue, 100) < 0)
		return -1;

	if(setbar(u, id + ".meter", meter, 100) < 0)
		return -1;

	return 0;
}

ticktaskdialog(u: ref IcUi->Ui, id: string): int
{
	if(u == nil)
		return -1;

	return tickspinner(u, id + ".spin");
}

bindkey(u: ref IcUi->Ui, key, targetid, command: string): int
{
	if(u == nil || u.keymap == nil)
		return -1;

	return keymap->bind(u.keymap, key, targetid, command);
}

bindkeyargs(u: ref IcUi->Ui, key, targetid, command, sarg: string, iarg0, iarg1, iarg2: int): int
{
	if(u == nil || u.keymap == nil)
		return -1;

	return keymap->bindargs(u.keymap, key, targetid, command, sarg, iarg0, iarg1, iarg2);
}

settext(u: ref IcUi->Ui, id, text: string): int
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

setcontent(u: ref IcUi->Ui, id, content: string): int
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

setscroll(u: ref IcUi->Ui, id: string, scroll, scrollpos: int): int
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

setframe(u: ref IcUi->Ui, id: string, frame: int): int
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

setargs(u: ref IcUi->Ui, id, sarg: string, iarg0, iarg1, iarg2: int): int
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

setfocus(u: ref IcUi->Ui, id: string): int
{
	if(u == nil || u.tree == nil)
		return -1;

	return view->setfocus(u.tree, id);
}

canvasclear(u: ref IcUi->Ui, id, ch, code: string): int
{
	u = u;
	return paint->canvasclear(id, ch, code);
}

canvasfill(u: ref IcUi->Ui, id: string, x, y, w, h: int, ch, code: string): int
{
	u = u;
	return paint->canvasfill(id, x, y, w, h, ch, code);
}

canvasputc(u: ref IcUi->Ui, id: string, x, y: int, ch, code: string): int
{
	u = u;
	return paint->canvasputc(id, x, y, ch, code);
}

canvasputs(u: ref IcUi->Ui, id: string, x, y: int, text, code: string): int
{
	u = u;
	return paint->canvasputs(id, x, y, text, code);
}

draw(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	paint->clear(u.renderer);
	paint->drawtree(u.renderer, u.tree);

	if(u.help != "" && u.helprow >= 0)
		paint->status(u.renderer, u.helprow, u.help);

	if(u.status != "" && u.statusrow >= 0)
		paint->status(u.renderer, u.statusrow, u.status);

	paint->flush(u.renderer);
}

focusok(u: ref IcUi->Ui, n: ref IcView->Node): int
{
	if(u == nil || u.tree == nil || n == nil)
		return 0;

	if(!view->isfocusable(n))
		return 0;

	if(!view->isvisibletree(u.tree, n.id))
		return 0;

	if(!view->isenabledtree(u.tree, n.id))
		return 0;

	return 1;
}

actionok(u: ref IcUi->Ui, n: ref IcView->Node): int
{
	if(u == nil || u.tree == nil || n == nil)
		return 0;

	if(!view->isenabledtree(u.tree, n.id))
		return 0;

	if(!view->isvisibletree(u.tree, n.id))
		return 0;

	return 1;
}

ensurefocus(u: ref IcUi->Ui): ref IcView->Node
{
	n: ref IcView->Node;
	id: string;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->focusnode(u.tree);
	if(focusok(u, n))
		return n;

	id = view->nextfocus(u.tree);
	if(id != ""){
		view->setfocus(u.tree, id);
		return view->focusnode(u.tree);
	}

	view->clearfocus(u.tree);
	return nil;
}

hotkeymatch(k: int, hotkey: string): int
{
	if(hotkey == "")
		return 0;

	if(len hotkey != 1)
		return 0;

	if(k == int hotkey[0])
		return 1;

	return 0;
}

findhotkeynode(u: ref IcUi->Ui, id: string, k: int): ref IcView->Node
{
	n, c, r: ref IcView->Node;
	i: int;

	if(u == nil || u.tree == nil || id == "")
		return nil;

	n = view->find(u.tree, id);
	if(n == nil)
		return nil;

	if(hotkeymatch(k, n.hotkey) && actionok(u, n))
		return n;

	for(i = 0; i < len n.children; i++){
		c = view->find(u.tree, n.children[i]);
		if(c != nil){
			r = findhotkeynode(u, c.id, k);
			if(r != nil)
				return r;
		}
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
	dst, cmd: string;

	if(u == nil || n == nil)
		return msg->none();

	dst = n.targetid;
	cmd = n.command;

	if(dst == "")
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
	id: string;

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
		if(id != ""){
			view->setfocus(u.tree, id);
			u.status = "focus " + id;
			return msg->newmsg("ui", id, IcMsg->KindFocus, "focus.set");
		}
	}

	if(nav == Icurses->NavPrev || nav == Icurses->NavLeft || nav == Icurses->NavUp){
		id = view->prevfocus(u.tree);
		if(id != ""){
			view->setfocus(u.tree, id);
			u.status = "focus " + id;
			return msg->newmsg("ui", id, IcMsg->KindFocus, "focus.set");
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
		u.status = "button.click src=" + m.src + " dst=" + m.dst;
		m.handled = 1;
		return m;
	}

	if(m.cmd == "node.show"){
		if(n != nil){
			view->show(n);
			ensurefocus(u);
			u.status = "node.show dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.hide"){
		if(n != nil){
			view->hide(n);
			ensurefocus(u);
			u.status = "node.hide dst=" + m.dst;
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
			u.status = "node.toggle dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.enable"){
		if(n != nil){
			view->enable(n);
			ensurefocus(u);
			u.status = "node.enable dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.disable"){
		if(n != nil){
			view->disable(n);
			ensurefocus(u);
			u.status = "node.disable dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "node.move"){
		if(n != nil){
			view->moveby(n, m.iarg0, m.iarg1);
			u.status = "node.move dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "text.label"){
		if(n != nil){
			view->settext(n, m.sarg);
			u.status = "text.label dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "text.set"){
		if(n != nil){
			view->setcontent(n, m.sarg);
			u.status = "text.set src=" + m.src + " dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "text.append"){
		if(n != nil){
			old = view->getcontent(n);
			view->setcontent(n, old + m.sarg);
			u.status = "text.append dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "scroll.down"){
		if(n != nil){
			view->setscrollpos(n, n.scrollpos + 1);
			u.status = "scroll.down dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "scroll.up"){
		if(n != nil){
			view->setscrollpos(n, n.scrollpos - 1);
			u.status = "scroll.up dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "scroll.home"){
		if(n != nil){
			view->setscrollpos(n, 0);
			u.status = "scroll.home dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "scroll.set"){
		if(n != nil){
			view->setscrollpos(n, m.iarg0);
			u.status = "scroll.set dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "bar.set"){
		if(n != nil){
			if(m.iarg1 <= 0)
				m.iarg1 = 100;

			if(m.iarg0 < 0)
				m.iarg0 = 0;
			if(m.iarg0 > m.iarg1)
				m.iarg0 = m.iarg1;

			view->setargs(n, "", m.iarg0, m.iarg1, n.iarg2);
			u.status = "bar.set dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "progress.set"){
		if(n != nil){
			if(m.iarg1 <= 0)
				m.iarg1 = 100;

			if(m.iarg0 < 0)
				m.iarg0 = 0;
			if(m.iarg0 > m.iarg1)
				m.iarg0 = m.iarg1;

			view->setargs(n, "", m.iarg0, m.iarg1, n.iarg2);
			u.status = "progress.set dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "progress.style"){
		if(n != nil){
			view->setargs(n, n.sarg, n.iarg0, n.iarg1, m.iarg0);
			u.status = "progress.style dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "spinner.tick"){
		if(n != nil){
			view->setargs(n, n.sarg, n.iarg0 + 1, n.iarg1, n.iarg2);
			u.status = "spinner.tick dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "spinner.set"){
		if(n != nil){
			view->setargs(n, n.sarg, m.iarg0, n.iarg1, n.iarg2);
			u.status = "spinner.set dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "listbox.select"){
		if(n != nil){
			view->setargs(n, n.sarg, m.iarg0, m.iarg1, n.iarg2);
			u.status = "listbox.select dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "status.set"){
		u.status = m.sarg;
		m.handled = 1;
		return m;
	}

	if(m.cmd == "help.set"){
		u.help = m.sarg;
		u.status = "help.set";
		m.handled = 1;
		return m;
	}

	if(m.cmd == "ui.quit"){
		u.status = "ui.quit";
		u.running = 0;
		m.handled = 1;
		return m;
	}

	u.status = "unhandled cmd=" + m.cmd + " dst=" + m.dst;
	return m;
}