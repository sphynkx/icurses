implement IcHistory;

include "icurses/history.m";

sys: Sys;
input: IcInput;
view: IcView;
msg: IcMsg;
ic: Icurses;

DefaultMaxItems: con 32;

none: fn(): IcMsg->Msg;
focusedid: fn(u: ref IcUi->Ui): string;
matchesfocusedinput: fn(u: ref IcUi->Ui, h: ref IcHistory->History): int;

removeitem: fn(a: array of string, s: string): array of string;
prependitem: fn(a: array of string, s: string): array of string;
truncateitems: fn(a: array of string, maxitems: int): array of string;

historymsg: fn(h: ref IcHistory->History, cmd, value: string): IcMsg->Msg;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	input = load IcInput IcInput->PATH;
	if(input == nil)
		raise "fail:load icinput";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	input->init();
	view->init();
	msg->init();
	ic->init();
}

none(): IcMsg->Msg
{
	return msg->none();
}

new(inputid: string, maxitems: int): ref IcHistory->History
{
	h: ref IcHistory->History;

	if(maxitems <= 0)
		maxitems = DefaultMaxItems;

	h = ref IcHistory->History;
	h.inputid = inputid;
	h.items = array[0] of string;
	h.sel = -1;
	h.maxitems = maxitems;
	h.wrap = 1;

	return h;
}

clear(h: ref IcHistory->History)
{
	if(h == nil)
		return;

	h.items = array[0] of string;
	h.sel = -1;
}

removeitem(a: array of string, s: string): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		return array[0] of string;

	n = 0;
	for(i = 0; i < len a; i++){
		if(a[i] != s)
			n++;
	}

	r = array[n] of string;
	n = 0;

	for(i = 0; i < len a; i++){
		if(a[i] != s){
			r[n] = a[i];
			n++;
		}
	}

	return r;
}

prependitem(a: array of string, s: string): array of string
{
	r: array of string;
	i: int;

	if(a == nil)
		a = array[0] of string;

	r = array[len a + 1] of string;
	r[0] = s;

	for(i = 0; i < len a; i++)
		r[i + 1] = a[i];

	return r;
}

truncateitems(a: array of string, maxitems: int): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		return array[0] of string;

	if(maxitems <= 0)
		maxitems = DefaultMaxItems;

	if(len a <= maxitems)
		return a;

	n = maxitems;
	r = array[n] of string;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	return r;
}

add(h: ref IcHistory->History, text: string): int
{
	if(h == nil)
		return -1;

	if(text == "")
		return 0;

	h.items = removeitem(h.items, text);
	h.items = prependitem(h.items, text);
	h.items = truncateitems(h.items, h.maxitems);
	h.sel = -1;

	return 0;
}

count(h: ref IcHistory->History): int
{
	if(h == nil || h.items == nil)
		return 0;

	return len h.items;
}

current(h: ref IcHistory->History): string
{
	if(h == nil || h.items == nil)
		return "";

	if(h.sel < 0 || h.sel >= len h.items)
		return "";

	return h.items[h.sel];
}

summary(h: ref IcHistory->History): string
{
	s: string;
	i: int;

	if(h == nil)
		return "history: nil";

	if(h.items == nil || len h.items == 0)
		return "history: empty";

	s = "history:";

	for(i = 0; i < len h.items; i++){
		if(i == h.sel)
			s += " {" + h.items[i] + "}";
		else
			s += " " + h.items[i];

		if(i + 1 < len h.items)
			s += " | ";
	}

	return s;
}

prev(h: ref IcHistory->History): string
{
	if(h == nil || h.items == nil || len h.items == 0)
		return "";

	if(h.sel < 0)
		h.sel = 0;
	else if(h.sel + 1 < len h.items)
		h.sel++;
	else if(h.wrap)
		h.sel = 0;

	return current(h);
}

next(h: ref IcHistory->History): string
{
	if(h == nil || h.items == nil || len h.items == 0)
		return "";

	if(h.sel < 0)
		h.sel = 0;
	else if(h.sel > 0)
		h.sel--;
	else if(h.wrap)
		h.sel = len h.items - 1;

	return current(h);
}

focusedid(u: ref IcUi->Ui): string
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return "";

	n = view->focusnode(u.tree);
	if(n == nil)
		return "";

	return n.id;
}

matchesfocusedinput(u: ref IcUi->Ui, h: ref IcHistory->History): int
{
	if(u == nil || h == nil)
		return 0;

	if(h.inputid == "")
		return 0;

	if(focusedid(u) != h.inputid)
		return 0;

	return 1;
}

historymsg(h: ref IcHistory->History, cmd, value: string): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(h == nil)
		return none();

	m = msg->newmsg("history", h.inputid, IcMsg->KindInput, cmd);
	m.sarg = value;
	m.iarg0 = h.sel;
	m.iarg1 = count(h);
	m.iarg2 = h.maxitems;
	m.handled = 1;

	return m;
}

apply(u: ref IcUi->Ui, h: ref IcHistory->History): IcMsg->Msg
{
	value: string;
	m: IcMsg->Msg;

	if(u == nil || h == nil)
		return none();

	value = current(h);
	if(value == "")
		return none();

	m = input->settext(u, h.inputid, value);
	input->setcursor(u, h.inputid, len value);

	m.src = "history";
	m.dst = h.inputid;
	m.cmd = "history.apply";
	m.sarg = value;
	m.iarg0 = h.sel;
	m.iarg1 = count(h);
	m.iarg2 = h.maxitems;
	m.handled = 1;

	return m;
}

submit(u: ref IcUi->Ui, h: ref IcHistory->History): IcMsg->Msg
{
	m: IcMsg->Msg;
	value: string;

	if(u == nil || h == nil)
		return none();

	m = input->submit(u, h.inputid);
	if(m.kind == IcMsg->KindNone)
		return m;

	value = m.sarg;
	add(h, value);

	return m;
}

handlekey(u: ref IcUi->Ui, h: ref IcHistory->History, k: int): IcMsg->Msg
{
	value: string;

	if(u == nil || h == nil)
		return none();

	if(!matchesfocusedinput(u, h))
		return none();

	if(k == Icurses->Kup){
		value = prev(h);
		if(value == "")
			return none();

		return apply(u, h);
	}

	if(k == Icurses->Kdown){
		value = next(h);
		if(value == "")
			return none();

		return apply(u, h);
	}

	if(ic->isconfirm(k))
		return submit(u, h);

	return none();
}