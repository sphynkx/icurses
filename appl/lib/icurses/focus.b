implement IcFocus;

include "icurses/focus.m";

sys: Sys;
view: IcView;
msg: IcMsg;
ic: Icurses;

focusmsg: fn(u: ref IcUi->Ui, id: int): IcMsg->Msg;

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

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	view->init();
	msg->init();
	ic->init();
}

focusmsg(u: ref IcUi->Ui, id: int): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(u == nil || id < 0)
		return msg->none();

	u.status = "focus " + sys->sprint("%d", id);

	m = msg->newmsg(IcMsg->MsgNoNode, id, IcMsg->KindFocus, "focus.set");
	m.sarg = sys->sprint("%d", id);
	m.iarg0 = 0;
	m.iarg1 = 0;
	m.iarg2 = 0;
	m.handled = 1;

	return m;
}

focusid(u: ref IcUi->Ui): int
{
	if(u == nil || u.tree == nil)
		return IcView->NoId;

	return view->focusid(u.tree);
}

first(u: ref IcUi->Ui): int
{
	id: int;

	if(u == nil || u.tree == nil)
		return IcView->NoId;

	view->clearfocus(u.tree);
	id = view->nextfocus(u.tree);

	if(id != IcView->NoId)
		u.status = "focus " + sys->sprint("%d", id);

	return id;
}

next(u: ref IcUi->Ui): int
{
	id: int;

	if(u == nil || u.tree == nil)
		return IcView->NoId;

	id = view->nextfocus(u.tree);

	if(id != IcView->NoId)
		u.status = "focus " + sys->sprint("%d", id);

	return id;
}

prev(u: ref IcUi->Ui): int
{
	id: int;

	if(u == nil || u.tree == nil)
		return IcView->NoId;

	id = view->prevfocus(u.tree);

	if(id != IcView->NoId)
		u.status = "focus " + sys->sprint("%d", id);

	return id;
}

set(u: ref IcUi->Ui, id: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(view->setfocus(u.tree, id) < 0)
		return -1;

	u.status = "focus " + sys->sprint("%d", id);
	return 0;
}

clear(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	view->clearfocus(u.tree);
	u.status = "focus cleared";
}

handlekey(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	nav: int;
	id: int;

	if(u == nil || u.tree == nil)
		return msg->none();

	#
	# Handle Tab and BackTab explicitly first. Some environments report
	# Tab as raw code 9, and relying only on navkind() makes debugging
	# focus traversal harder.
	#
	if(k == 9){
		id = next(u);
		if(id != IcView->NoId)
			return focusmsg(u, id);
		return msg->none();
	}

	if(k == Icurses->Kbacktab){
		id = prev(u);
		if(id != IcView->NoId)
			return focusmsg(u, id);
		return msg->none();
	}

	nav = ic->navkind(k);

	if(nav == Icurses->NavNext || nav == Icurses->NavRight || nav == Icurses->NavDown){
		id = next(u);
		if(id != IcView->NoId)
			return focusmsg(u, id);
		return msg->none();
	}

	if(nav == Icurses->NavPrev || nav == Icurses->NavLeft || nav == Icurses->NavUp){
		id = prev(u);
		if(id != IcView->NoId)
			return focusmsg(u, id);
		return msg->none();
	}

	if(nav == Icurses->NavHome){
		id = first(u);
		if(id != IcView->NoId)
			return focusmsg(u, id);
		return msg->none();
	}

	return msg->none();
}