implement IcControl;

include "icurses/control.m";

sys: Sys;
ui: IcUi;
view: IcView;
msg: IcMsg;

DefaultCommand: con "control.change";

findnode: fn(u: ref IcUi->Ui, id: string): ref IcView->Node;
ensurewidth: fn(style: int, label: string, w: int): int;
rawlabel: fn(n: ref IcView->Node): string;
rendertext: fn(n: ref IcView->Node): string;
rendernode: fn(n: ref IcView->Node);
setrawchecked: fn(n: ref IcView->Node, checked: int);
makemsg: fn(n: ref IcView->Node): IcMsg->Msg;
samegroup: fn(n: ref IcView->Node, groupid: string): int;
clearradiogroup: fn(u: ref IcUi->Ui, groupid, exceptid: string);
setgroupselected: fn(u: ref IcUi->Ui, groupid, id: string);

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

	#
	# IcControl uses IcUi helper constructors and IcView node operations.
	# Initialize the private module instances before calling them.
	#
	ui->init();
	view->init();
	msg->init();
}

findnode(u: ref IcUi->Ui, id: string): ref IcView->Node
{
	if(u == nil || u.tree == nil || id == "")
		return nil;

	return view->find(u.tree, id);
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
	m.iarg2 = n.iarg2;

	return m;
}

samegroup(n: ref IcView->Node, groupid: string): int
{
	if(n == nil)
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
	view->setargs(n, "", checked != 0, IcControl->StyleCheckbox, 0);
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
	view->setargs(n, groupid, 0, IcControl->StyleRadio, 0);
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
	view->setargs(n, "", on != 0, IcControl->StyleSwitch, 0);
	rendernode(n);

	return 0;
}

checked(u: ref IcUi->Ui, id: string): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(n == nil)
		return 0;

	return n.iarg0 != 0;
}

setchecked(u: ref IcUi->Ui, id: string, checked: int): int
{
	n: ref IcView->Node;
	groupid: string;

	n = findnode(u, id);
	if(n == nil)
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
	if(n == nil)
		return msg->none();

	if(!view->isenabled(n))
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
	if(n == nil)
		return msg->none();

	if(!view->isenabled(n))
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

	rendernode(n);
	return 0;
}