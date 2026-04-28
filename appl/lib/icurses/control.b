implement IcControl;

include "icurses/control.m";

sys: Sys;
ui: IcUi;
view: IcView;
msg: IcMsg;
ic: Icurses;

DefaultCommand: con "control.change";
ControlMagic: con 17219;

findnode: fn(u: ref IcUi->Ui, id: string): ref IcView->Node;
iscontrolnode: fn(n: ref IcView->Node): int;
ensurewidth: fn(style: int, label: string, w: int): int;
rawlabel: fn(n: ref IcView->Node): string;
rendertext: fn(n: ref IcView->Node): string;
rendernode: fn(n: ref IcView->Node);
setrawchecked: fn(n: ref IcView->Node, checked: int);
makemsg: fn(n: ref IcView->Node): IcMsg->Msg;
samegroup: fn(n: ref IcView->Node, groupid: string): int;
clearradiogroup: fn(u: ref IcUi->Ui, groupid, exceptid: string);
setgroupselected: fn(u: ref IcUi->Ui, groupid, id: string);
hotkeymatch: fn(k: int, hotkey: string): int;
findcontrolhotkeynode: fn(u: ref IcUi->Ui, id: string, k: int): ref IcView->Node;
activate: fn(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg;

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

	#
	# IcControl uses IcUi helper constructors and IcView node operations.
	# Initialize the private module instances before calling them.
	#
	ui->init();
	view->init();
	msg->init();
	ic->init();
}

findnode(u: ref IcUi->Ui, id: string): ref IcView->Node
{
	if(u == nil || u.tree == nil || id == "")
		return nil;

	return view->find(u.tree, id);
}

iscontrolnode(n: ref IcView->Node): int
{
	if(n == nil)
		return 0;

	if(n.iarg2 != ControlMagic)
		return 0;

	if(n.iarg1 == IcControl->StyleCheckbox)
		return 1;

	if(n.iarg1 == IcControl->StyleRadio)
		return 1;

	if(n.iarg1 == IcControl->StyleSwitch)
		return 1;

	return 0;
}

ensurewidth(style: int, label: string, w: int): int
{
	n: int;

	if(w > 0)
		return w;

	n = len label;

	if(style == IcControl->StyleCheckbox)
		return n + 4;

	if(style == IcControl->StyleRadio)
		return n + 4;

	if(style == IcControl->StyleSwitch)
		return n + 8;

	return n;
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

	return n.id;
}

rendertext(n: ref IcView->Node): string
{
	label, s: string;
	on, style, enabled: int;

	if(n == nil)
		return "";

	label = rawlabel(n);
	on = n.iarg0 != 0;
	style = n.iarg1;
	enabled = view->isenabled(n);

	if(style == IcControl->StyleRadio){
		if(!enabled){
			if(on)
				s = "(-) " + label;
			else
				s = "( ) " + label;
			return s;
		}

		if(on)
			return "(*) " + label;

		return "( ) " + label;
	}

	if(style == IcControl->StyleSwitch){
		if(!enabled)
			return "[ ---] " + label;

		if(on)
			return "[ ON ] " + label;

		return "[ OFF] " + label;
	}

	if(!enabled){
		if(on)
			return "[-] " + label;

		return "[ ] " + label;
	}

	if(on)
		return "[x] " + label;

	return "[ ] " + label;
}

rendernode(n: ref IcView->Node)
{
	if(n == nil)
		return;

	view->settext(n, rendertext(n));
}

setrawchecked(n: ref IcView->Node, checked: int)
{
	if(n == nil)
		return;

	if(checked)
		n.iarg0 = 1;
	else
		n.iarg0 = 0;

	rendernode(n);
}

makemsg(n: ref IcView->Node): IcMsg->Msg
{
	m: IcMsg->Msg;
	dst, cmd: string;

	if(n == nil)
		return msg->none();

	dst = n.targetid;
	if(dst == "")
		dst = n.id;

	cmd = n.command;
	if(cmd == "")
		cmd = DefaultCommand;

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = n.sarg;
	m.iarg0 = n.iarg0;
	m.iarg1 = n.iarg1;
	m.iarg2 = 0;

	return m;
}

samegroup(n: ref IcView->Node, groupid: string): int
{
	if(!iscontrolnode(n))
		return 0;

	if(n.sarg != groupid)
		return 0;

	if(n.iarg1 != IcControl->StyleRadio)
		return 0;

	return 1;
}

clearradiogroup(u: ref IcUi->Ui, groupid, exceptid: string)
{
	g, n: ref IcView->Node;
	i, count: int;
	id: string;

	if(u == nil || u.tree == nil || groupid == "")
		return;

	g = view->find(u.tree, groupid);
	if(g == nil)
		return;

	count = view->childcount(g);

	for(i = 0; i < count; i++){
		id = view->childat(g, i);
		if(id == "" || id == exceptid)
			continue;

		n = view->find(u.tree, id);
		if(!samegroup(n, groupid))
			continue;

		setrawchecked(n, 0);
	}
}

setgroupselected(u: ref IcUi->Ui, groupid, id: string)
{
	g: ref IcView->Node;

	if(u == nil || u.tree == nil || groupid == "")
		return;

	g = view->find(u.tree, groupid);
	if(g == nil)
		return;

	view->setargs(g, id, g.iarg0, g.iarg1, g.iarg2);
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

findcontrolhotkeynode(u: ref IcUi->Ui, id: string, k: int): ref IcView->Node
{
	n, c, r: ref IcView->Node;
	i: int;

	if(u == nil || u.tree == nil || id == "")
		return nil;

	n = view->find(u.tree, id);
	if(n == nil)
		return nil;

	if(iscontrolnode(n) && view->isvisibletree(u.tree, n.id) && view->isenabledtree(u.tree, n.id)){
		if(hotkeymatch(k, view->gethotkey(n)))
			return n;
	}

	for(i = 0; i < view->childcount(n); i++){
		c = view->find(u.tree, view->childat(n, i));
		if(c == nil)
			continue;

		r = findcontrolhotkeynode(u, c.id, k);
		if(r != nil)
			return r;
	}

	return nil;
}

activate(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg
{
	if(u == nil || u.tree == nil)
		return msg->none();

	if(!iscontrolnode(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	if(n.iarg1 == IcControl->StyleRadio)
		return selectradio(u, n.id);

	return toggle(u, n.id);
}

group(u: ref IcUi->Ui, parentid, id: string, x, y, w, h: int, mode: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = 1;
	if(h <= 0)
		h = 1;

	if(ui->group(u, parentid, id, x, y, w, h) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setargs(n, "", mode, 0, 0);
	return 0;
}

checkbox(u: ref IcUi->Ui, parentid, id: string,
	x, y, w: int,
	label, hotkey, targetid, command: string,
	checked: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	w = ensurewidth(IcControl->StyleCheckbox, label, w);

	if(ui->button(u, parentid, id, x, y, w, 1, label, hotkey, targetid, command) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, label);
	view->setargs(n, "", checked != 0, IcControl->StyleCheckbox, ControlMagic);
	rendernode(n);

	return 0;
}

radio(u: ref IcUi->Ui, groupid, id: string,
	x, y, w: int,
	label, hotkey, targetid, command: string,
	checked: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(groupid == "")
		return -1;

	w = ensurewidth(IcControl->StyleRadio, label, w);

	if(ui->button(u, groupid, id, x, y, w, 1, label, hotkey, targetid, command) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, label);
	view->setargs(n, groupid, 0, IcControl->StyleRadio, ControlMagic);
	rendernode(n);

	if(checked)
		setchecked(u, id, 1);

	return 0;
}

switchbox(u: ref IcUi->Ui, parentid, id: string,
	x, y, w: int,
	label, hotkey, targetid, command: string,
	on: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	w = ensurewidth(IcControl->StyleSwitch, label, w);

	if(ui->button(u, parentid, id, x, y, w, 1, label, hotkey, targetid, command) < 0)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	view->setcontent(n, label);
	view->setargs(n, "", on != 0, IcControl->StyleSwitch, ControlMagic);
	rendernode(n);

	return 0;
}

checked(u: ref IcUi->Ui, id: string): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(!iscontrolnode(n))
		return 0;

	return n.iarg0 != 0;
}

setchecked(u: ref IcUi->Ui, id: string, checked: int): int
{
	n: ref IcView->Node;
	groupid: string;

	n = findnode(u, id);
	if(!iscontrolnode(n))
		return -1;

	if(n.iarg1 == IcControl->StyleRadio && checked){
		groupid = n.sarg;
		if(groupid != "")
			clearradiogroup(u, groupid, id);
		setrawchecked(n, 1);
		if(groupid != "")
			setgroupselected(u, groupid, id);
		return 0;
	}

	setrawchecked(n, checked != 0);

	if(n.iarg1 == IcControl->StyleRadio && !checked && n.sarg != ""){
		if(selected(u, n.sarg) == id)
			setgroupselected(u, n.sarg, "");
	}

	return 0;
}

toggle(u: ref IcUi->Ui, id: string): IcMsg->Msg
{
	n: ref IcView->Node;
	v: int;

	n = findnode(u, id);
	if(!iscontrolnode(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	if(n.iarg1 == IcControl->StyleRadio)
		return selectradio(u, id);

	v = 0;
	if(n.iarg0 == 0)
		v = 1;

	setrawchecked(n, v);
	return makemsg(n);
}

selectradio(u: ref IcUi->Ui, id: string): IcMsg->Msg
{
	n: ref IcView->Node;
	groupid: string;

	n = findnode(u, id);
	if(!iscontrolnode(n))
		return msg->none();

	if(!view->isenabledtree(u.tree, n.id))
		return msg->none();

	if(n.iarg1 != IcControl->StyleRadio)
		return msg->none();

	groupid = n.sarg;
	if(groupid != "")
		clearradiogroup(u, groupid, id);

	setrawchecked(n, 1);

	if(groupid != "")
		setgroupselected(u, groupid, id);

	return makemsg(n);
}

selected(u: ref IcUi->Ui, groupid: string): string
{
	g: ref IcView->Node;

	g = findnode(u, groupid);
	if(g == nil)
		return "";

	return g.sarg;
}

setenabled(u: ref IcUi->Ui, id: string, enabled: int): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(n == nil)
		return -1;

	if(enabled)
		view->enable(n);
	else
		view->disable(n);

	if(iscontrolnode(n))
		rendernode(n);

	return 0;
}

activatefocused(u: ref IcUi->Ui): IcMsg->Msg
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return msg->none();

	n = view->focusnode(u.tree);
	return activate(u, n);
}

handlekey(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return msg->none();

	n = findcontrolhotkeynode(u, u.tree.rootid, k);
	if(n != nil)
		return activate(u, n);

	if(k == ' ')
		return activatefocused(u);

	if(ic->isconfirm(k))
		return activatefocused(u);

	return msg->none();
}