implement IcSlider;

include "icurses/slider.m";

sys: Sys;
ui: IcUi;
view: IcView;
msg: IcMsg;
ic: Icurses;

SliderTag: con "ic.slider";
DefaultCommand: con "slider.change";
DefaultWidth: con 32;
DefaultStep: con 1;
DefaultPageStep: con 10;

findnode: fn(u: ref IcUi->Ui, id: int): ref IcView->Node;
isslider: fn(n: ref IcView->Node): int;
clamp: fn(v, lo, hi: int): int;
barwidth: fn(n: ref IcView->Node): int;
percent: fn(value, min, max: int): int;
rawlabel: fn(n: ref IcView->Node): string;
rendertext: fn(n: ref IcView->Node): string;
rendernode: fn(n: ref IcView->Node);
makemsg: fn(n: ref IcView->Node): IcMsg->Msg;
setrawvalue: fn(n: ref IcView->Node, value: int);
hotkeymatch: fn(k: int, hotkey: string): int;
findsliderhotkeynode: fn(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node;
focusedslider: fn(u: ref IcUi->Ui): ref IcView->Node;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ui->init();
	view->init();
	msg->init();
	ic->init();
}

findnode(u: ref IcUi->Ui, id: int): ref IcView->Node
{
	if(u == nil || u.tree == nil || id < 0)
		return nil;

	return view->find(u.tree, id);
}

isslider(n: ref IcView->Node): int
{
	if(n == nil)
		return 0;

	if(n.sarg != SliderTag)
		return 0;

	return 1;
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

barwidth(n: ref IcView->Node): int
{
	label: string;
	w: int;

	if(n == nil)
		return 8;

	label = rawlabel(n);

	w = n.w - len label - 9;
	if(w < 6)
		w = 6;

	return w;
}

percent(value, min, max: int): int
{
	if(max <= min)
		return 0;

	value = clamp(value, min, max);

	return ((value - min) * 100) / (max - min);
}

rawlabel(n: ref IcView->Node): string
{
	s: string;

	if(n == nil)
		return "";

	s = view->getcontent(n);
	if(s != "")
		return s;

	s = view->gettext(n);
	if(s != "")
		return s;

	return sys->sprint("%d", n.id);
}

rendertext(n: ref IcView->Node): string
{
	label, s: string;
	value, min, max, bw, fill, i, pct: int;

	if(n == nil)
		return "";

	label = rawlabel(n);

	value = n.iarg0;
	min = n.iarg1;
	max = n.iarg2;

	if(max < min)
		max = min;

	value = clamp(value, min, max);
	bw = barwidth(n);
	pct = percent(value, min, max);

	if(max == min)
		fill = 0;
	else
		fill = ((value - min) * (bw - 1)) / (max - min);

	if(fill < 0)
		fill = 0;
	if(fill >= bw)
		fill = bw - 1;

	s = label + " [";

	for(i = 0; i < bw; i++){
		if(i == fill)
			s += "#";
		else
			s += "-";
	}

	s += "] " + sys->sprint("%d", pct) + "%";

	if(!view->isenabled(n))
		s = "(" + s + ")";

	return s;
}

rendernode(n: ref IcView->Node)
{
	if(n == nil)
		return;

	view->settext(n, rendertext(n));
}

makemsg(n: ref IcView->Node): IcMsg->Msg
{
	m: IcMsg->Msg;
	dst: int;
	cmd: string;

	if(n == nil)
		return msg->none();

	dst = n.targetid;
	if(dst == IcView->NoId)
		dst = n.id;

	cmd = n.command;
	if(cmd == "")
		cmd = DefaultCommand;

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = rawlabel(n);
	m.iarg0 = n.iarg0;
	m.iarg1 = n.iarg1;
	m.iarg2 = n.iarg2;

	return m;
}

setrawvalue(n: ref IcView->Node, value: int)
{
	if(n == nil)
		return;

	value = clamp(value, n.iarg1, n.iarg2);
	n.iarg0 = value;

	rendernode(n);
}

hotkeymatch(k: int, hotkey: string): int
{
	h: int;
	kn: string;

	if(hotkey == "")
		return 0;

	kn = ic->keyname(k);
	if(kn == hotkey)
		return 1;

	if(len hotkey != 1)
		return 0;

	h = int hotkey[0];

	if(k == h)
		return 1;

	if(k >= 'a' && k <= 'z' && h >= 'A' && h <= 'Z'){
		if(k - 'a' + 'A' == h)
			return 1;
	}

	if(k >= 'A' && k <= 'Z' && h >= 'a' && h <= 'z'){
		if(k - 'A' + 'a' == h)
			return 1;
	}

	return 0;
}

findsliderhotkeynode(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node
{
	n, c, r: ref IcView->Node;
	i: int;

	if(u == nil || u.tree == nil || id < 0)
		return nil;

	n = view->find(u.tree, id);
	if(n == nil)
		return nil;

	if(isslider(n) && view->isvisibletree(u.tree, n.id) && view->isenabledtree(u.tree, n.id)){
		if(hotkeymatch(k, view->gethotkey(n)))
			return n;
	}

	for(i = 0; i < view->childcount(n); i++){
		c = view->find(u.tree, view->childat(n, i));
		if(c == nil)
			continue;

		r = findsliderhotkeynode(u, c.id, k);
		if(r != nil)
			return r;
	}

	return nil;
}

focusedslider(u: ref IcUi->Ui): ref IcView->Node
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->focusnode(u.tree);
	if(!isslider(n))
		return nil;

	if(!view->isenabledtree(u.tree, n.id))
		return nil;

	return n;
}

slider(u: ref IcUi->Ui, parentid, id: int,
	x, y, w: int,
	label, hotkey: string, targetid: int, command: string,
	value, min, max: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = DefaultWidth;

	if(max < min)
		max = min;

	value = clamp(value, min, max);

	if(ui->button(u, parentid, id, x, y, w, 1, label, hotkey, targetid, command) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, label);
	view->setargs(n, SliderTag, value, min, max);
	rendernode(n);

	return 0;
}

value(u: ref IcUi->Ui, id: int): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return 0;

	return n.iarg0;
}

setvalue(u: ref IcUi->Ui, id: int, value: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	setrawvalue(n, value);
	return makemsg(n);
}

inc(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg0 + DefaultStep);
}

dec(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg0 - DefaultStep);
}

pageup(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg0 + DefaultPageStep);
}

pagedown(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg0 - DefaultPageStep);
}

home(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg1);
}

end(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isslider(n))
		return msg->none();

	return setvalue(u, id, n.iarg2);
}

setenabled(u: ref IcUi->Ui, id: int, enabled: int): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(n == nil)
		return -1;

	if(enabled)
		view->enable(n);
	else
		view->disable(n);

	if(isslider(n))
		rendernode(n);

	return 0;
}

activatefocused(u: ref IcUi->Ui): IcMsg->Msg
{
	n: ref IcView->Node;

	n = focusedslider(u);
	if(n == nil)
		return msg->none();

	return makemsg(n);
}

handlekey(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return msg->none();

	n = findsliderhotkeynode(u, u.tree.rootid, k);
	if(n != nil){
		if(view->setfocus(u.tree, n.id) == 0)
			u.status = "focus " + sys->sprint("%d", n.id);
		return makemsg(n);
	}

	n = focusedslider(u);
	if(n == nil)
		return msg->none();

	if(k == Icurses->Kright || k == Icurses->Kup)
		return inc(u, n.id);

	if(k == Icurses->Kleft || k == Icurses->Kdown)
		return dec(u, n.id);

	if(k == Icurses->Kpgup)
		return pageup(u, n.id);

	if(k == Icurses->Kpgdown)
		return pagedown(u, n.id);

	if(k == Icurses->Khome)
		return home(u, n.id);

	if(k == Icurses->Kend)
		return end(u, n.id);

	if(k == ' ')
		return activatefocused(u);

	if(ic->isconfirm(k))
		return activatefocused(u);

	return msg->none();
}