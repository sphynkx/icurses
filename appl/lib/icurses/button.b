implement IcButton;

include "icurses/button.m";

sys: Sys;
view: IcView;
msg: IcMsg;
ui: IcUi;

DefaultPressMs: con 90;

findnode: fn(u: ref IcUi->Ui, id: string): ref IcView->Node;
pressedtext: fn(s: string): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	view->init();
	msg->init();
	ui->init();
}

findnode(u: ref IcUi->Ui, id: string): ref IcView->Node
{
	if(u == nil || u.tree == nil || id == "")
		return nil;

	return view->find(u.tree, id);
}

pressedtext(s: string): string
{
	if(s == "")
		return "> <";

	return "> " + s + " <";
}

presslabel(u: ref IcUi->Ui, id, pressed: string, ms: int): int
{
	n: ref IcView->Node;
	normal: string;

	n = findnode(u, id);
	if(n == nil)
		return -1;

	if(ms <= 0)
		ms = DefaultPressMs;

	normal = view->gettext(n);

	view->settext(n, pressed);
	ui->draw(u);

	sys->sleep(ms);

	view->settext(n, normal);
	ui->draw(u);

	return 0;
}

press(u: ref IcUi->Ui, id: string, ms: int): int
{
	n: ref IcView->Node;

	n = findnode(u, id);
	if(n == nil)
		return -1;

	return presslabel(u, id, pressedtext(view->gettext(n)), ms);
}

click(u: ref IcUi->Ui, id: string): IcMsg->Msg
{
	n: ref IcView->Node;
	m: IcMsg->Msg;
	dst, cmd: string;

	n = findnode(u, id);
	if(n == nil)
		return msg->none();

	if(!view->isenabled(n))
		return msg->none();

	dst = n.targetid;
	if(dst == "")
		dst = n.id;

	cmd = n.command;
	if(cmd == "")
		cmd = "button.click";

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = n.sarg;
	m.iarg0 = n.iarg0;
	m.iarg1 = n.iarg1;
	m.iarg2 = n.iarg2;

	return ui->dispatch(u, m);
}

activate(u: ref IcUi->Ui, id: string, ms: int): IcMsg->Msg
{
	if(press(u, id, ms) < 0)
		return msg->none();

	return click(u, id);
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

	return 0;
}