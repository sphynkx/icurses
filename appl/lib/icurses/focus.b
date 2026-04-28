implement IcFocus;

include "icurses/focus.m";

sys: Sys;
view: IcView;
msg: IcMsg;
ic: Icurses;

focusmsg: fn(u: ref IcUi->Ui, id: string): IcMsg->Msg;

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

focusmsg(u: ref IcUi->Ui, id: string): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(u == nil || id == "")
		return msg->none();

	u.status = "focus " + id;

	m = msg->newmsg("focus", id, IcMsg->KindFocus, "focus.set");
	m.sarg = id;
	m.iarg0 = 0;
	m.iarg1 = 0;
	m.iarg2 = 0;
	m.handled = 1;

	return m;
}

focusid(u: ref IcUi->Ui): string
{
	if(u == nil || u.tree == nil)
		return "";

	return view->focusid(u.tree);
}

first(u: ref IcUi->Ui): string
{
	id: string;

	if(u == nil || u.tree == nil)
		return "";

	view->clearfocus(u.tree);
	id = view->nextfocus(u.tree);

	if(id != "")
		u.status = "focus " + id;

	return id;
}

next(u: ref IcUi->Ui): string
{
	id: string;

	if(u == nil || u.tree == nil)
		return "";

	id = view->nextfocus(u.tree);

	if(id != "")
		u.status = "focus " + id;

	return id;
}

prev(u: ref IcUi->Ui): string
{
	id: string;

	if(u == nil || u.tree == nil)
		return "";

	id = view->prevfocus(u.tree);

	if(id != "")
		u.status = "focus " + id;

	return id;
}

set(u: ref IcUi->Ui, id: string): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(view->setfocus(u.tree, id) < 0)
		return -1;

	u.status = "focus " + id;
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
	id: string;

	if(u == nil || u.tree == nil)
		return msg->none();

	nav = ic->navkind(k);

	if(nav == Icurses->NavNext || nav == Icurses->NavRight || nav == Icurses->NavDown){
		id = next(u);
		if(id != "")
			return focusmsg(u, id);
		return msg->none();
	}

	if(nav == Icurses->NavPrev || nav == Icurses->NavLeft || nav == Icurses->NavUp){
		id = prev(u);
		if(id != "")
			return focusmsg(u, id);
		return msg->none();
	}

	if(nav == Icurses->NavHome){
		id = first(u);
		if(id != "")
			return focusmsg(u, id);
		return msg->none();
	}

	return msg->none();
}