implement IcMenu;

include "icurses/menu.m";

sys: Sys;
ui: IcUi;
view: IcView;

setflag: fn(it: IcMenu->Item, flag, on: int): IcMenu->Item;
hasflag: fn(it: IcMenu->Item, flag: int): int;

spaces: fn(n: int): string;
repeat: fn(ch: string, n: int): string;
clip: fn(s: string, w: int): string;
padright: fn(s: string, w: int): string;

itemcount: fn(items: array of IcMenu->Item): int;
itemwidth: fn(it: IcMenu->Item): int;
popupitemline: fn(it: IcMenu->Item, w, selected: int): string;
baritemtext: fn(it: IcMenu->Item, selected: int): string;

ensurelabel: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
hidelabel: fn(u: ref IcUi->Ui, id: int);
drawbar: fn(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int, action: int): int;

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

	#
	# IcMenu calls IcUi helper functions. Its private IcUi module instance
	# must be initialized before use.
	#
	ui->init();

	#
	# IcMenu also manipulates nodes directly through IcView helpers.
	#
	view->init();
}

newitem(label, hotkey: string, targetid: int, command: string): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindCommand;
	it.flags = 0;

	it.label = label;
	it.hotkey = hotkey;

	it.targetid = targetid;
	it.command = command;

	it.submenuid = IcView->NoId;
	it.status = "";

	return it;
}

newseparator(): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindSeparator;
	it.flags = IcMenu->FlagDisabled;

	it.label = "";
	it.hotkey = "";

	it.targetid = IcView->NoId;
	it.command = "";

	it.submenuid = IcView->NoId;
	it.status = "";

	return it;
}

newsubmenu(label, hotkey: string, submenuid: int): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindSubmenu;
	it.flags = 0;

	it.label = label;
	it.hotkey = hotkey;

	it.targetid = IcView->NoId;
	it.command = "";

	it.submenuid = submenuid;
	it.status = "";

	return it;
}

setflag(it: IcMenu->Item, flag, on: int): IcMenu->Item
{
	if(on)
		it.flags |= flag;
	else
		it.flags &= ~flag;

	return it;
}

hasflag(it: IcMenu->Item, flag: int): int
{
	if((it.flags & flag) != 0)
		return 1;

	return 0;
}

setdisabled(it: IcMenu->Item, disabled: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagDisabled, disabled);
}

setchecked(it: IcMenu->Item, checked: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagChecked, checked);
}

setradio(it: IcMenu->Item, radio: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagRadio, radio);
}

setstatus(it: IcMenu->Item, status: string): IcMenu->Item
{
	it.status = status;
	return it;
}

enabled(it: IcMenu->Item): int
{
	if(separator(it))
		return 0;

	if(hasflag(it, IcMenu->FlagDisabled))
		return 0;

	return 1;
}

checked(it: IcMenu->Item): int
{
	return hasflag(it, IcMenu->FlagChecked);
}

radio(it: IcMenu->Item): int
{
	return hasflag(it, IcMenu->FlagRadio);
}

separator(it: IcMenu->Item): int
{
	if(it.kind == IcMenu->KindSeparator)
		return 1;

	return 0;
}

submenu(it: IcMenu->Item): int
{
	if(it.kind == IcMenu->KindSubmenu)
		return 1;

	return 0;
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

repeat(ch: string, n: int): string
{
	s: string;
	i: int;

	s = "";

	if(ch == "")
		ch = " ";

	for(i = 0; i < n; i++)
		s += ch;

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

itemcount(items: array of IcMenu->Item): int
{
	if(items == nil)
		return 0;

	return len items;
}

itemwidth(it: IcMenu->Item): int
{
	n: int;

	if(separator(it))
		return 3;

	n = 2;		# selected marker
	n += 4;		# check/radio marker
	n += len it.label;

	if(it.hotkey != "")
		n += 1 + len it.hotkey;

	if(submenu(it))
		n += 2;

	return n;
}

popupwidth(items: array of IcMenu->Item): int
{
	i, n, w: int;

	w = 12;
	n = itemcount(items);

	for(i = 0; i < n; i++){
		if(itemwidth(items[i]) + 2 > w)
			w = itemwidth(items[i]) + 2;
	}

	return w;
}

popupitemline(it: IcMenu->Item, w, selected: int): string
{
	prefix, mark, tail, s: string;
	bodyw: int;

	if(w <= 0)
		return "";

	if(separator(it))
		return repeat("-", w);

	if(selected)
		prefix = "> ";
	else
		prefix = "  ";

	if(checked(it)){
		if(radio(it))
			mark = "(*) ";
		else
			mark = "[x] ";
	}else{
		if(radio(it))
			mark = "( ) ";
		else
			mark = "    ";
	}

	tail = "";
	if(submenu(it))
		tail = " >";
	else if(it.hotkey != "")
		tail = " " + it.hotkey;

	bodyw = w - len prefix - len mark - len tail;
	if(bodyw < 0)
		bodyw = 0;

	if(!enabled(it) && !separator(it))
		s = prefix + mark + padright("(" + it.label + ")", bodyw) + tail;
	else
		s = prefix + mark + padright(it.label, bodyw) + tail;

	return clip(s, w);
}

baritemtext(it: IcMenu->Item, selected: int): string
{
	s: string;

	if(it.hotkey != "")
		s = it.hotkey + " " + it.label;
	else
		s = it.label;

	if(selected)
		return ">" + s + "<";

	return " " + s + " ";
}

ensurelabel(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = 1;

	n = view->find(u.tree, id);
	if(n == nil)
		return ui->label(u, parentid, id, x, y, w, text);

	view->settext(n, text);
	view->setbounds(n, x, y, w, 1);
	view->show(n);

	return 0;
}

hidelabel(u: ref IcUi->Ui, id: int)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->settext(n, "");
	view->hide(n);
}

popupmenu(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, title: string, items: array of IcMenu->Item, sel: int): int
{
	h, rows: int;
	shadowid: int;

	if(u == nil)
		return -1;

	rows = itemcount(items);
	if(rows <= 0)
		rows = 1;

	if(w <= 0)
		w = popupwidth(items);

	if(w < 12)
		w = 12;

	h = rows + 2;
	if(h < 3)
		h = 3;

	shadowid = view->allocid(u.tree);

	if(ui->shadowwindow(u, parentid, shadowid, id, x, y, w, h, title, 2, 1) < 0)
		return -1;

	return setpopupmenu(u, id, items, sel);
}

setpopupmenu(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	n: ref IcView->Node;
	line: string;
	rows, cols, i, count, oldcount, maxold, rowid: int;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	rows = n.h - 2;
	cols = n.w - 2;

	if(rows <= 0 || cols <= 0)
		return -1;

	count = itemcount(items);
	oldcount = n.iarg2;
	maxold = oldcount;
	if(maxold < rows)
		maxold = rows;
	if(maxold < count)
		maxold = count;

	for(i = 0; i < maxold; i++){
		if(i < view->childcount(n))
			rowid = view->childat(n, i);
		else
			rowid = IcView->NoId;

		if(rowid == IcView->NoId)
			continue;

		if(i >= rows || i >= count)
			hidelabel(u, rowid);
	}

	if(count <= 0){
		if(view->childcount(n) <= 0)
			return -1;

		rowid = view->childat(n, 0);
		ensurelabel(u, id, rowid, 1, 1, cols, padright("(empty)", cols));
		view->setargs(n, "", 0, -1, 0);
		return 0;
	}

	if(sel < 0)
		sel = 0;
	if(sel >= count)
		sel = count - 1;

	for(i = 0; i < rows && i < count; i++){
		if(i < view->childcount(n))
			rowid = view->childat(n, i);
		else{
			rowid = view->allocid(u.tree);
			if(ui->label(u, id, rowid, 1, 1 + i, cols, "") < 0)
				return -1;
		}

		line = popupitemline(items[i], cols, i == sel);
		ensurelabel(u, id, rowid, 1, 1 + i, cols, line);
	}

	view->setargs(n, "", 0, sel, count);
	return 0;
}

navbar(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of IcMenu->Item, sel: int): int
{
	if(u == nil)
		return -1;

	if(w <= 0)
		w = 1;

	if(ui->group(u, parentid, id, x, y, w, 1) < 0)
		return -1;

	return setnavbar(u, id, items, sel);
}

setnavbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	return drawbar(u, id, items, sel, 0);
}

actionbar(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of IcMenu->Item, sel: int): int
{
	if(u == nil)
		return -1;

	if(w <= 0)
		w = 1;

	if(ui->group(u, parentid, id, x, y, w, 1) < 0)
		return -1;

	return setactionbar(u, id, items, sel);
}

setactionbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	return drawbar(u, id, items, sel, 1);
}

drawbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int, action: int): int
{
	n: ref IcView->Node;
	i, x, w, count, oldcount, maxold, itemid: int;
	s: string;

	action = action;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	w = n.w;
	if(w <= 0)
		return -1;

	count = itemcount(items);
	oldcount = n.iarg2;
	maxold = oldcount;
	if(maxold < count)
		maxold = count;

	for(i = 0; i < maxold; i++){
		if(i < view->childcount(n))
			itemid = view->childat(n, i);
		else
			itemid = IcView->NoId;

		if(itemid == IcView->NoId)
			continue;

		if(i >= count)
			hidelabel(u, itemid);
	}

	if(count <= 0){
		view->setargs(n, "", sel, action, 0);
		return 0;
	}

	if(sel < 0)
		sel = 0;
	if(sel >= count)
		sel = count - 1;

	x = 0;

	for(i = 0; i < count; i++){
		if(i < view->childcount(n))
			itemid = view->childat(n, i);
		else{
			itemid = view->allocid(u.tree);
			if(ui->label(u, id, itemid, 0, 0, 1, "") < 0)
				return -1;
		}

		if(separator(items[i])){
			hidelabel(u, itemid);
			continue;
		}

		s = baritemtext(items[i], i == sel);

		if(x >= w){
			hidelabel(u, itemid);
			continue;
		}

		if(x + len s > w)
			s = clip(s, w - x);

		ensurelabel(u, id, itemid, x, 0, len s, s);
		x += len s;
	}

	view->setargs(n, "", sel, action, count);
	return 0;
}