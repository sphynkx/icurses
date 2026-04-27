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

	if(openinput() < 0){
		u.status = "cannot open keyboard";
		u.running = 0;
		return -1;
	}

	u.running = 1;

	spawn keyproc(u);
	spawn tickproc(u);

	draw(u);

	return 0;
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
	m: IcMsg->Msg;

	if(u == nil)
		return newstep(IcUi->StepDone, 1, -1, 0, msg->none(), "");

	if(!u.running)
		return newstep(IcUi->StepDone, 1, -1, u.ticks, msg->none(), u.status);

	alt {
	k := <-u.keyc =>
		if(k < 0){
			u.running = 0;
			return newstep(IcUi->StepDone, 1, k, u.ticks, msg->none(), u.status);
		}

		if(isquit(k)){
			u.running = 0;
			return newstep(IcUi->StepDone, 1, k, u.ticks, msg->none(), u.status);
		}

		m = handlekey(u, k);
		draw(u);

		if(!u.running)
			return newstep(IcUi->StepDone, 1, k, u.ticks, m, u.status);

		return newstep(IcUi->StepKey, 0, k, u.ticks, m, u.status);

	t := <-u.tickc =>
		u.ticks = t;
		return newstep(IcUi->StepTick, 0, -1, t, msg->none(), u.status);
	}
}

stop(u: ref IcUi->Ui)
{
	if(u == nil)
		return;

	u.running = 0;
	closeinput();
	close(u);
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
	return ic->iscancel(k);
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

	view->setargs(n, "", value, total, 0);
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

	if(!view->isvisibletree(u.tree, n.id))
		return 0;

	if(!view->isenabledtree(u.tree, n.id))
		return 0;

	return 1;
}

ensurefocus(u: ref IcUi->Ui): ref IcView->Node
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->focusnode(u.tree);
	if(focusok(u, n))
		return n;

	view->nextfocus(u.tree);
	n = view->focusnode(u.tree);

	if(focusok(u, n))
		return n;

	view->clearfocus(u.tree);
	return nil;
}

hotkeymatch(k: int, hotkey: string): int
{
	c, kk: int;

	if(hotkey == "")
		return 0;

	c = int hotkey[0];
	kk = k;

	if(c >= 'A' && c <= 'Z')
		c = c + ('a' - 'A');

	if(kk >= 'A' && kk <= 'Z')
		kk = kk + ('a' - 'A');

	return c == kk;
}

findhotkeynode(u: ref IcUi->Ui, id: string, k: int): ref IcView->Node
{
	n, r: ref IcView->Node;
	i: int;

	if(u == nil || u.tree == nil || id == "")
		return nil;

	n = view->find(u.tree, id);
	if(n == nil)
		return nil;

	for(i = len n.children - 1; i >= 0; i--){
		r = findhotkeynode(u, n.children[i], k);
		if(r != nil)
			return r;
	}

	if(hotkeymatch(k, n.hotkey) && actionok(u, n))
		return n;

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

	if(!actionok(u, n))
		return msg->none();

	dst = n.targetid;
	if(dst == "")
		dst = n.parentid;

	cmd = n.command;
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
	fid: string;
	m: IcMsg->Msg;

	if(u == nil || u.tree == nil)
		return msg->none();

	if(k == 9 || k == Icurses->Kright || k == Icurses->Kdown){
		fid = view->nextfocus(u.tree);
		u.status = "focus: " + fid;
		return msg->none();
	}

	if(k == Icurses->Kbacktab || k == Icurses->Kleft || k == Icurses->Kup){
		fid = view->prevfocus(u.tree);
		u.status = "focus: " + fid;
		return msg->none();
	}

	if(k == 10 || k == 13){
		n = ensurefocus(u);
		return pressnode(u, n);
	}

	n = findhotkey(u, k);
	if(n != nil){
		if(n.focusable)
			view->setfocus(u.tree, n.id);
		return pressnode(u, n);
	}

	m = keymap->find(u.keymap, k);
	if(!msg->isnone(m))
		return dispatch(u, m);

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
		u.status = "msg seq=" + string m.seq + " ignored";
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
			view->movetreeby(u.tree, n.id, m.iarg0, m.iarg1);
			u.status = "node.move dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "window.activate" || m.cmd == "window.front"){
		if(n != nil){
			view->activatewindow(u.tree, n.id);
			u.status = m.cmd + " dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "window.back"){
		if(n != nil){
			view->sendtoback(u.tree, n.id);
			u.status = "window.back dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "window.toggle"){
		if(n != nil){
			if(view->isvisible(n))
				view->hide(n);
			else
				view->show(n);

			ensurefocus(u);

			u.status = "window.toggle src=" + m.src + " dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "window.move"){
		if(n != nil){
			view->movetreeby(u.tree, n.id, m.iarg0, m.iarg1);
			u.status = "window.move src=" + m.src + " dst=" + m.dst;
			m.handled = 1;
		}
		return m;
	}

	if(m.cmd == "focus.next"){
		view->nextfocus(u.tree);
		u.status = "focus.next";
		m.handled = 1;
		return m;
	}

	if(m.cmd == "focus.prev"){
		view->prevfocus(u.tree);
		u.status = "focus.prev";
		m.handled = 1;
		return m;
	}

	if(m.cmd == "focus.set"){
		if(n != nil && view->setfocus(u.tree, n.id) == 0){
			u.status = "focus.set dst=" + m.dst;
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

			view->setargs(n, "", m.iarg0, m.iarg1, 0);
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

			view->setargs(n, "", m.iarg0, m.iarg1, 0);
			u.status = "progress.set dst=" + m.dst;
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

	u.status = "unhandled msg src=" + m.src + " dst=" + m.dst + " cmd=" + m.cmd;
	return m;
}