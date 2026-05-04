implement IcInput;

include "icurses/input.m";

sys: Sys;
ui: IcUi;
view: IcView;
msg: IcMsg;
ic: Icurses;

InputMagic: con 26017;
DefaultCommand: con "input.submit";
DefaultWidth: con 32;

findnode: fn(u: ref IcUi->Ui, id: int): ref IcView->Node;
isinput: fn(n: ref IcView->Node): int;
clamp: fn(v, lo, hi: int): int;
limittext: fn(s: string, maxlen: int): string;
rawtext: fn(n: ref IcView->Node): string;
rawlabel: fn(n: ref IcView->Node): string;
fieldwidth: fn(n: ref IcView->Node): int;
renderfield: fn(n: ref IcView->Node): string;
rendertext: fn(n: ref IcView->Node): string;
rendernode: fn(n: ref IcView->Node);
setrawtext: fn(n: ref IcView->Node, s: string);
setrawcursor: fn(n: ref IcView->Node, cursor: int);
editmsg: fn(n: ref IcView->Node, cmd: string): IcMsg->Msg;
submitmsg: fn(n: ref IcView->Node): IcMsg->Msg;
hotkeymatch: fn(k: int, hotkey: string): int;
findinputhotkeynode: fn(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node;
focusedinput: fn(u: ref IcUi->Ui): ref IcView->Node;
isprintable: fn(k: int): int;
keychar: fn(k: int): string;

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

isinput(n: ref IcView->Node): int
{
	if(n == nil)
		return 0;

	if(n.iarg2 != InputMagic)
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

limittext(s: string, maxlen: int): string
{
	if(maxlen <= 0)
		return s;

	if(len s <= maxlen)
		return s;

	return s[0:maxlen];
}

rawtext(n: ref IcView->Node): string
{
	if(n == nil)
		return "";

	return view->getcontent(n);
}

rawlabel(n: ref IcView->Node): string
{
	if(n == nil)
		return "";

	return n.sarg;
}

fieldwidth(n: ref IcView->Node): int
{
	label: string;
	prefix: string;
	w: int;

	if(n == nil)
		return 8;

	label = rawlabel(n);
	prefix = "";
	if(label != "")
		prefix = label + " ";

	w = n.w - len prefix - 2;
	if(w < 4)
		w = 4;

	return w;
}

renderfield(n: ref IcView->Node): string
{
	s, logical, out: string;
	cur, maxlen, fw, start, i, end: int;

	if(n == nil)
		return "";

	s = rawtext(n);
	maxlen = n.iarg1;
	s = limittext(s, maxlen);

	cur = clamp(n.iarg0, 0, len s);
	fw = fieldwidth(n);

	if(view->isenabled(n))
		logical = s[0:cur] + "|" + s[cur:];
	else
		logical = s;

	start = 0;

	if(view->isenabled(n)){
		if(cur >= fw)
			start = cur - fw + 1;
	}else{
		if(len logical > fw)
			start = len logical - fw;
	}

	if(start < 0)
		start = 0;

	end = start + fw;
	if(end > len logical)
		end = len logical;

	out = logical[start:end];

	for(i = len out; i < fw; i++)
		out += "_";

	return out;
}

rendertext(n: ref IcView->Node): string
{
	label, prefix, s: string;

	if(n == nil)
		return "";

	label = rawlabel(n);
	prefix = "";
	if(label != "")
		prefix = label + " ";

	s = prefix + "[" + renderfield(n) + "]";

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

setrawtext(n: ref IcView->Node, s: string)
{
	if(n == nil)
		return;

	s = limittext(s, n.iarg1);
	view->setcontent(n, s);

	if(n.iarg0 > len s)
		n.iarg0 = len s;
	if(n.iarg0 < 0)
		n.iarg0 = 0;

	rendernode(n);
}

setrawcursor(n: ref IcView->Node, cursor: int)
{
	s: string;

	if(n == nil)
		return;

	s = rawtext(n);
	n.iarg0 = clamp(cursor, 0, len s);

	rendernode(n);
}

editmsg(n: ref IcView->Node, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;
	s: string;

	if(n == nil)
		return msg->none();

	s = rawtext(n);

	m = msg->newmsg(n.id, n.id, IcMsg->KindInput, cmd);
	m.sarg = s;
	m.iarg0 = n.iarg0;
	m.iarg1 = len s;
	m.iarg2 = n.iarg1;
	m.handled = 1;

	return m;
}

submitmsg(n: ref IcView->Node): IcMsg->Msg
{
	m: IcMsg->Msg;
	dst: int;
	cmd, s: string;

	if(n == nil)
		return msg->none();

	dst = n.targetid;
	if(dst == IcView->NoId)
		dst = n.id;

	cmd = n.command;
	if(cmd == "")
		cmd = DefaultCommand;

	s = rawtext(n);

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = s;
	m.iarg0 = n.iarg0;
	m.iarg1 = len s;
	m.iarg2 = n.iarg1;

	return m;
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

findinputhotkeynode(u: ref IcUi->Ui, id: int, k: int): ref IcView->Node
{
	n, c, r: ref IcView->Node;
	i: int;

	if(u == nil || u.tree == nil || id < 0)
		return nil;

	n = view->find(u.tree, id);
	if(n == nil)
		return nil;

	if(isinput(n) && view->isvisibletree(u.tree, n.id) && view->isenabledtree(u.tree, n.id)){
		if(hotkeymatch(k, view->gethotkey(n)))
			return n;
	}

	for(i = 0; i < view->childcount(n); i++){
		c = view->find(u.tree, view->childat(n, i));
		if(c == nil)
			continue;

		r = findinputhotkeynode(u, c.id, k);
		if(r != nil)
			return r;
	}

	return nil;
}

focusedinput(u: ref IcUi->Ui): ref IcView->Node
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return nil;

	n = view->focusnode(u.tree);
	if(!isinput(n))
		return nil;

	if(!view->isenabledtree(u.tree, n.id))
		return nil;

	return n;
}

isprintable(k: int): int
{
	#
	# Printable input can be ASCII or a Unicode/rune codepoint delivered by
	# /dev/ekeyboard.  Do not restrict this to 7-bit ASCII: Cyrillic, Greek,
	# accented Latin, etc. arrive as values above 127.
	#
	# Keep Inferno's special keyboard constants out of text input. They live
	# in the private-use range around Khome..Kdel.
	#
	if(k < 32)
		return 0;

	if(k >= Icurses->Khome && k <= Icurses->Kdel)
		return 0;

	return 1;
}

keychar(k: int): string
{
	return sys->sprint("%c", k);
}

input(u: ref IcUi->Ui, parentid, id: int,
	x, y, w: int,
	label, hotkey: string, targetid: int, command, text: string,
	maxlen: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = DefaultWidth;

	if(maxlen < 0)
		maxlen = 0;

	text = limittext(text, maxlen);

	if(ui->button(u, parentid, id, x, y, w, 1, label, hotkey, targetid, command) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, text);
	view->setargs(n, label, len text, maxlen, InputMagic);
	rendernode(n);

	return 0;
}

text(u: ref IcUi->Ui, id: int): string
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isinput(n))
		return "";

	return rawtext(n);
}

settext(u: ref IcUi->Ui, id: int, text: string): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isinput(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	setrawtext(n, text);
	return editmsg(n, "input.edit");
}

setcursor(u: ref IcUi->Ui, id: int, cursor: int): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isinput(n))
		return -1;

	setrawcursor(n, cursor);
	return 0;
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

	if(isinput(n))
		rendernode(n);

	return 0;
}

insert(u: ref IcUi->Ui, id: int, s: string): IcMsg->Msg
{
	n: ref IcView->Node;
	t: string;
	cur, maxlen: int;

	n = findnode(u, id);
	if(!isinput(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	if(s == "")
		return msg->none();

	t = rawtext(n);
	cur = clamp(n.iarg0, 0, len t);
	maxlen = n.iarg1;

	if(maxlen > 0 && len t >= maxlen)
		return msg->none();

	if(maxlen > 0 && len t + len s > maxlen)
		s = s[0:maxlen - len t];

	t = t[0:cur] + s + t[cur:];
	view->setcontent(n, t);
	n.iarg0 = cur + len s;

	rendernode(n);
	return editmsg(n, "input.edit");
}

backspace(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;
	t: string;
	cur: int;

	n = findnode(u, id);
	if(!isinput(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	t = rawtext(n);
	cur = clamp(n.iarg0, 0, len t);

	if(cur <= 0)
		return msg->none();

	t = t[0:cur - 1] + t[cur:];
	view->setcontent(n, t);
	n.iarg0 = cur - 1;

	rendernode(n);
	return editmsg(n, "input.edit");
}

delchar(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;
	t: string;
	cur: int;

	n = findnode(u, id);
	if(!isinput(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	t = rawtext(n);
	cur = clamp(n.iarg0, 0, len t);

	if(cur >= len t)
		return msg->none();

	t = t[0:cur] + t[cur + 1:];
	view->setcontent(n, t);

	rendernode(n);
	return editmsg(n, "input.edit");
}

submit(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!isinput(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	return submitmsg(n);
}

activatefocused(u: ref IcUi->Ui): IcMsg->Msg
{
	n: ref IcView->Node;

	n = focusedinput(u);
	if(n == nil)
		return msg->none();

	return submitmsg(n);
}

handlekey(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	n: ref IcView->Node;
	id: int;
	m: IcMsg->Msg;

	if(u == nil || u.tree == nil)
		return msg->none();

	n = findinputhotkeynode(u, u.tree.rootid, k);
	if(n != nil){
		if(view->setfocus(u.tree, n.id) == 0)
			u.status = "focus " + sys->sprint("%d", n.id);
		m = msg->newmsg(IcMsg->MsgNoNode, n.id, IcMsg->KindFocus, "focus.set");
		m.sarg = sys->sprint("%d", n.id);
		m.handled = 1;
		return m;
	}

	n = focusedinput(u);
	if(n == nil)
		return msg->none();

	id = n.id;

	if(k == Icurses->Kleft){
		setrawcursor(n, n.iarg0 - 1);
		return editmsg(n, "input.cursor");
	}

	if(k == Icurses->Kright){
		setrawcursor(n, n.iarg0 + 1);
		return editmsg(n, "input.cursor");
	}

	if(k == Icurses->Khome){
		setrawcursor(n, 0);
		return editmsg(n, "input.cursor");
	}

	if(k == Icurses->Kend){
		setrawcursor(n, len rawtext(n));
		return editmsg(n, "input.cursor");
	}

	if(k == Icurses->Kdel)
		return delchar(u, id);

	if(k == 8 || k == 127)
		return backspace(u, id);

	if(ic->isconfirm(k))
		return submit(u, id);

	if(isprintable(k))
		return insert(u, id, keychar(k));

	return msg->none();
}