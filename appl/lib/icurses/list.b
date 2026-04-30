implement IcList;

include "icurses/list.m";

sys: Sys;
msg: IcMsg;
ic: Icurses;
ui: IcUi;
view: IcView;

clamp: fn(v, lo, hi: int): int;
fix: fn(l: ref IcList->List);
makemsg: fn(l: ref IcList->List, cmd: string): IcMsg->Msg;

spaces: fn(n: int): string;
clip: fn(s: string, w: int): string;
padright: fn(s: string, w: int): string;
rowid: fn(l: ref IcList->List, row: int): string;
rowtext: fn(l: ref IcList->List, index, w: int): string;
ensurelabel: fn(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, text: string): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	msg->init();
	ic->init();
	ui->init();
	view->init();
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

spaces(n: int): string
{
	s: string;
	i: int;

	s = "";

	for(i = 0; i < n; i++)
		s += " ";

	return s;
}

clip(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s <= w)
		return s;

	return s[0:w];
}

padright(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s >= w)
		return s[0:w];

	return s + spaces(w - len s);
}

rowid(l: ref IcList->List, row: int): string
{
	if(l == nil)
		return "";

	return l.id + ".iclist.row." + sys->sprint("%d", row);
}

rowtext(l: ref IcList->List, index, w: int): string
{
	s, prefix: string;

	if(l == nil || l.items == nil || index < 0 || index >= len l.items)
		return spaces(w);

	if(index == l.sel)
		prefix = "> ";
	else
		prefix = "  ";

	s = prefix + l.items[index];

	return padright(clip(s, w), w);
}

ensurelabel(u: ref IcUi->Ui, parentid, id: string, x, y, w: int, text: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || parentid == "" || id == "")
		return -1;

	if(w <= 0)
		w = 1;

	n = view->find(u.tree, id);
	if(n == nil)
		return ui->label(u, parentid, id, x, y, w, text);

	view->setbounds(n, x, y, w, 1);
	view->settext(n, text);
	view->show(n);

	return 0;
}

new(id: string, rows: int): ref IcList->List
{
	l: ref IcList->List;

	l = ref IcList->List;

	l.id = id;
	l.items = array[0] of string;

	l.top = 0;
	l.sel = 0;

	if(rows <= 0)
		rows = 1;

	l.rows = rows;
	l.wrap = 1;

	return l;
}

clear(l: ref IcList->List)
{
	if(l == nil)
		return;

	l.items = array[0] of string;
	l.top = 0;
	l.sel = 0;
}

setitems(l: ref IcList->List, items: array of string): int
{
	if(l == nil)
		return -1;

	if(items == nil)
		items = array[0] of string;

	l.items = items;
	fix(l);

	return 0;
}

setrows(l: ref IcList->List, rows: int): int
{
	if(l == nil)
		return -1;

	if(rows <= 0)
		rows = 1;

	l.rows = rows;
	fix(l);

	return 0;
}

setwrap(l: ref IcList->List, wrap: int): int
{
	if(l == nil)
		return -1;

	if(wrap)
		l.wrap = 1;
	else
		l.wrap = 0;

	fix(l);

	return 0;
}

count(l: ref IcList->List): int
{
	if(l == nil || l.items == nil)
		return 0;

	return len l.items;
}

selected(l: ref IcList->List): int
{
	if(l == nil)
		return 0;

	return l.sel;
}

topindex(l: ref IcList->List): int
{
	if(l == nil)
		return 0;

	return l.top;
}

current(l: ref IcList->List): string
{
	if(l == nil || l.items == nil)
		return "";

	if(len l.items <= 0)
		return "";

	if(l.sel < 0 || l.sel >= len l.items)
		return "";

	return l.items[l.sel];
}

fix(l: ref IcList->List)
{
	n, maxtop: int;

	if(l == nil)
		return;

	if(l.rows <= 0)
		l.rows = 1;

	n = count(l);

	if(n <= 0){
		l.top = 0;
		l.sel = 0;
		return;
	}

	l.sel = clamp(l.sel, 0, n - 1);

	if(l.sel < l.top)
		l.top = l.sel;

	if(l.sel >= l.top + l.rows)
		l.top = l.sel - l.rows + 1;

	maxtop = n - l.rows;
	if(maxtop < 0)
		maxtop = 0;

	l.top = clamp(l.top, 0, maxtop);
}

render(u: ref IcUi->Ui, l: ref IcList->List): int
{
	n: ref IcView->Node;
	innerw, innerh, rows, r, index: int;
	id, s: string;

	if(u == nil || u.tree == nil || l == nil || l.id == "")
		return -1;

	fix(l);

	n = view->find(u.tree, l.id);
	if(n == nil)
		return -1;

	innerw = n.w - 2;
	innerh = n.h - 2;

	if(innerw <= 0)
		innerw = 1;

	if(innerh <= 0)
		innerh = l.rows;

	if(innerh <= 0)
		innerh = 1;

	rows = l.rows;
	if(rows <= 0)
		rows = innerh;

	if(rows > innerh)
		rows = innerh;

	for(r = 0; r < rows; r++){
		index = l.top + r;
		id = rowid(l, r);
		s = rowtext(l, index, innerw);

		if(ensurelabel(u, l.id, id, 1, 1 + r, innerw, s) < 0)
			return -1;
	}

	#
	# Clear any remaining visible inner rows so old text does not leak
	# when the list shrinks or when rows < innerh.
	#
	for(; r < innerh; r++){
		id = rowid(l, r);
		s = spaces(innerw);

		if(ensurelabel(u, l.id, id, 1, 1 + r, innerw, s) < 0)
			return -1;
	}

	return 0;
}

makemsg(l: ref IcList->List, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(l == nil)
		return msg->none();

	m = msg->newmsg(l.id, l.id, IcMsg->KindCommand, cmd);
	m.sarg = current(l);
	m.iarg0 = l.top;
	m.iarg1 = l.sel;
	m.iarg2 = count(l);

	return m;
}

select(u: ref IcUi->Ui, l: ref IcList->List, sel: int): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	l.sel = sel;
	fix(l);
	render(u, l);

	return makemsg(l, "list.select");
}

next(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	n: int;

	if(l == nil)
		return msg->none();

	n = count(l);
	if(n <= 0)
		return msg->none();

	if(l.sel + 1 >= n){
		if(l.wrap)
			l.sel = 0;
		else
			l.sel = n - 1;
	}
	else
		l.sel++;

	fix(l);
	render(u, l);

	return makemsg(l, "list.next");
}

prev(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	n: int;

	if(l == nil)
		return msg->none();

	n = count(l);
	if(n <= 0)
		return msg->none();

	if(l.sel <= 0){
		if(l.wrap)
			l.sel = n - 1;
		else
			l.sel = 0;
	}
	else
		l.sel--;

	fix(l);
	render(u, l);

	return makemsg(l, "list.prev");
}

pageup(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	l.sel -= l.rows;
	fix(l);
	render(u, l);

	return makemsg(l, "list.pageup");
}

pagedown(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	l.sel += l.rows;
	fix(l);
	render(u, l);

	return makemsg(l, "list.pagedown");
}

home(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	l.sel = 0;
	fix(l);
	render(u, l);

	return makemsg(l, "list.home");
}

end(u: ref IcUi->Ui, l: ref IcList->List): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	l.sel = count(l) - 1;
	fix(l);
	render(u, l);

	return makemsg(l, "list.end");
}

handlekey(u: ref IcUi->Ui, l: ref IcList->List, k: int): IcMsg->Msg
{
	if(l == nil)
		return msg->none();

	if(k == Icurses->Kdown || k == Icurses->Kright)
		return next(u, l);

	if(k == Icurses->Kup || k == Icurses->Kleft)
		return prev(u, l);

	if(k == Icurses->Kpgup)
		return pageup(u, l);

	if(k == Icurses->Kpgdown)
		return pagedown(u, l);

	if(k == Icurses->Khome)
		return home(u, l);

	if(k == Icurses->Kend)
		return end(u, l);

	return msg->none();
}