implement IcMenuNav;

include "icurses/menunav.m";

sys: Sys;
msg: IcMsg;
icmenu: IcMenu;

emptyitem: IcMenu->Item;

clamp: fn(v, lo, hi: int): int;
samekey: fn(k: int, hotkey: string): int;
findhotkey: fn(items: array of IcMenu->Item, k: int): int;

itemsfor: fn(m: ref IcMenuNav->Menu, active: int): array of IcMenu->Item;
countfor: fn(m: ref IcMenuNav->Menu, active: int): int;
selfor: fn(m: ref IcMenuNav->Menu, active: int): int;
setselfor: fn(m: ref IcMenuNav->Menu, active, sel: int);

activepath: fn(m: ref IcMenuNav->Menu): int;
makemsg: fn(m: ref IcMenuNav->Menu, cmd: string, it: IcMenu->Item): IcMsg->Msg;
setcheckedactive: fn(m: ref IcMenuNav->Menu, index, checked: int);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	icmenu = load IcMenu IcMenu->PATH;
	if(icmenu == nil)
		raise "fail:load icmenu";

	msg->init();
	icmenu->init();

	emptyitem = icmenu->newitem("", "", IcView->NoId, "");
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

samekey(k: int, hotkey: string): int
{
	c: int;

	if(hotkey == nil || hotkey == "")
		return 0;

	c = int hotkey[0];

	if(k == c)
		return 1;

	if(c >= 'A' && c <= 'Z' && k == c + 32)
		return 1;

	if(c >= 'a' && c <= 'z' && k == c - 32)
		return 1;

	return 0;
}

findhotkey(items: array of IcMenu->Item, k: int): int
{
	i: int;

	if(items == nil)
		return -1;

	for(i = 0; i < len items; i++){
		if(icmenu->separator(items[i]))
			continue;

		if(samekey(k, items[i].hotkey))
			return i;
	}

	return -1;
}

new(navid, popupid, actionid: int): ref IcMenuNav->Menu
{
	m: ref IcMenuNav->Menu;

	m = ref IcMenuNav->Menu;

	m.navid = navid;
	m.popupid = popupid;
	m.actionid = actionid;

	m.navitems = array[0] of IcMenu->Item;
	m.popupitems = array[0] of IcMenu->Item;
	m.actionitems = array[0] of IcMenu->Item;

	m.navsel = 0;
	m.popupsel = 0;
	m.actionsel = 0;

	m.active = IcMenuNav->ActiveNav;
	m.wrap = 1;

	return m;
}

setnav(m: ref IcMenuNav->Menu, id: int, items: array of IcMenu->Item, sel: int): int
{
	if(m == nil)
		return -1;

	m.navid = id;

	if(items == nil)
		items = array[0] of IcMenu->Item;

	m.navitems = items;
	m.navsel = sel;
	m.navsel = clamp(m.navsel, 0, len m.navitems - 1);

	return 0;
}

setpopup(m: ref IcMenuNav->Menu, id: int, items: array of IcMenu->Item, sel: int): int
{
	if(m == nil)
		return -1;

	m.popupid = id;

	if(items == nil)
		items = array[0] of IcMenu->Item;

	m.popupitems = items;
	m.popupsel = sel;
	m.popupsel = clamp(m.popupsel, 0, len m.popupitems - 1);

	return 0;
}

setaction(m: ref IcMenuNav->Menu, id: int, items: array of IcMenu->Item, sel: int): int
{
	if(m == nil)
		return -1;

	m.actionid = id;

	if(items == nil)
		items = array[0] of IcMenu->Item;

	m.actionitems = items;
	m.actionsel = sel;
	m.actionsel = clamp(m.actionsel, 0, len m.actionitems - 1);

	return 0;
}

setwrap(m: ref IcMenuNav->Menu, wrap: int): int
{
	if(m == nil)
		return -1;

	if(wrap)
		m.wrap = 1;
	else
		m.wrap = 0;

	return 0;
}

itemsfor(m: ref IcMenuNav->Menu, active: int): array of IcMenu->Item
{
	if(m == nil)
		return nil;

	if(active == IcMenuNav->ActiveNav)
		return m.navitems;

	if(active == IcMenuNav->ActivePopup)
		return m.popupitems;

	if(active == IcMenuNav->ActiveAction)
		return m.actionitems;

	return nil;
}

countfor(m: ref IcMenuNav->Menu, active: int): int
{
	items: array of IcMenu->Item;

	items = itemsfor(m, active);
	if(items == nil)
		return 0;

	return len items;
}

selfor(m: ref IcMenuNav->Menu, active: int): int
{
	if(m == nil)
		return 0;

	if(active == IcMenuNav->ActiveNav)
		return m.navsel;

	if(active == IcMenuNav->ActivePopup)
		return m.popupsel;

	if(active == IcMenuNav->ActiveAction)
		return m.actionsel;

	return 0;
}

setselfor(m: ref IcMenuNav->Menu, active, sel: int)
{
	n: int;

	if(m == nil)
		return;

	n = countfor(m, active);
	if(n <= 0)
		sel = 0;
	else
		sel = clamp(sel, 0, n - 1);

	if(active == IcMenuNav->ActiveNav)
		m.navsel = sel;
	else if(active == IcMenuNav->ActivePopup)
		m.popupsel = sel;
	else if(active == IcMenuNav->ActiveAction)
		m.actionsel = sel;
}

setactive(u: ref IcUi->Ui, m: ref IcMenuNav->Menu, active: int): IcMsg->Msg
{
	if(m == nil)
		return msg->none();

	if(active < IcMenuNav->ActiveNav || active > IcMenuNav->ActiveAction)
		active = IcMenuNav->ActiveNav;

	m.active = active;

	render(u, m);

	return makemsg(m, "menu.active", activeitem(m));
}

activeid(m: ref IcMenuNav->Menu): string
{
	if(m == nil)
		return "";

	if(m.active == IcMenuNav->ActiveNav)
		return "navbar";

	if(m.active == IcMenuNav->ActivePopup)
		return "popup";

	if(m.active == IcMenuNav->ActiveAction)
		return "actionbar";

	return "unknown";
}

activepath(m: ref IcMenuNav->Menu): int
{
	if(m == nil)
		return IcView->NoId;

	if(m.active == IcMenuNav->ActiveNav)
		return m.navid;

	if(m.active == IcMenuNav->ActivePopup)
		return m.popupid;

	if(m.active == IcMenuNav->ActiveAction)
		return m.actionid;

	return IcView->NoId;
}

activeindex(m: ref IcMenuNav->Menu): int
{
	if(m == nil)
		return 0;

	return selfor(m, m.active);
}

activecount(m: ref IcMenuNav->Menu): int
{
	if(m == nil)
		return 0;

	return countfor(m, m.active);
}

activeitem(m: ref IcMenuNav->Menu): IcMenu->Item
{
	items: array of IcMenu->Item;
	i: int;

	if(m == nil)
		return emptyitem;

	items = itemsfor(m, m.active);
	if(items == nil)
		return emptyitem;

	i = selfor(m, m.active);

	if(i < 0 || i >= len items)
		return emptyitem;

	return items[i];
}

render(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): int
{
	if(u == nil || m == nil)
		return -1;

	if(m.navid != IcView->NoId)
		icmenu->setnavbar(u, m.navid, m.navitems, m.navsel);

	if(m.popupid != IcView->NoId)
		icmenu->setpopupmenu(u, m.popupid, m.popupitems, m.popupsel);

	if(m.actionid != IcView->NoId)
		icmenu->setactionbar(u, m.actionid, m.actionitems, m.actionsel);

	return 0;
}

makemsg(m: ref IcMenuNav->Menu, cmd: string, it: IcMenu->Item): IcMsg->Msg
{
	r: IcMsg->Msg;
	dst, src: int;

	if(m == nil)
		return msg->none();

	dst = it.targetid;
	if(dst == IcView->NoId)
		dst = activepath(m);

	src = activepath(m);
	if(src == IcView->NoId)
		src = IcMsg->MsgNoNode;

	r = msg->newmsg(src, dst, IcMsg->KindCommand, cmd);
	r.sarg = it.label;
	r.iarg0 = m.active;
	r.iarg1 = activeindex(m);
	r.iarg2 = activecount(m);

	if(cmd == "menu.activate" && it.command != "")
		r.cmd = it.command;

	return r;
}

select(u: ref IcUi->Ui, m: ref IcMenuNav->Menu, index: int): IcMsg->Msg
{
	if(m == nil)
		return msg->none();

	setselfor(m, m.active, index);
	render(u, m);

	return makemsg(m, "menu.select", activeitem(m));
}

next(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	i, n: int;

	if(m == nil)
		return msg->none();

	n = activecount(m);
	if(n <= 0)
		return msg->none();

	i = activeindex(m) + 1;

	if(i >= n){
		if(m.wrap)
			i = 0;
		else
			i = n - 1;
	}

	return select(u, m, i);
}

prev(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	i, n: int;

	if(m == nil)
		return msg->none();

	n = activecount(m);
	if(n <= 0)
		return msg->none();

	i = activeindex(m) - 1;

	if(i < 0){
		if(m.wrap)
			i = n - 1;
		else
			i = 0;
	}

	return select(u, m, i);
}

home(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	return select(u, m, 0);
}

end(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	return select(u, m, activecount(m) - 1);
}

hotkey(u: ref IcUi->Ui, m: ref IcMenuNav->Menu, k: int): IcMsg->Msg
{
	i: int;

	if(m == nil)
		return msg->none();

	#
	# Active area wins. This deliberately supports duplicate hotkeys
	# such as File/Fast mode.
	#
	i = findhotkey(itemsfor(m, m.active), k);
	if(i >= 0)
		return select(u, m, i);

	i = findhotkey(m.navitems, k);
	if(i >= 0){
		m.active = IcMenuNav->ActiveNav;
		return select(u, m, i);
	}

	i = findhotkey(m.popupitems, k);
	if(i >= 0){
		m.active = IcMenuNav->ActivePopup;
		return select(u, m, i);
	}

	i = findhotkey(m.actionitems, k);
	if(i >= 0){
		m.active = IcMenuNav->ActiveAction;
		return select(u, m, i);
	}

	return msg->none();
}

setcheckedactive(m: ref IcMenuNav->Menu, index, checked: int)
{
	if(m == nil)
		return;

	if(m.active == IcMenuNav->ActiveNav){
		if(index >= 0 && index < len m.navitems)
			m.navitems[index] = icmenu->setchecked(m.navitems[index], checked);
	}
	else if(m.active == IcMenuNav->ActivePopup){
		if(index >= 0 && index < len m.popupitems)
			m.popupitems[index] = icmenu->setchecked(m.popupitems[index], checked);
	}
	else if(m.active == IcMenuNav->ActiveAction){
		if(index >= 0 && index < len m.actionitems)
			m.actionitems[index] = icmenu->setchecked(m.actionitems[index], checked);
	}
}

togglechecked(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	it: IcMenu->Item;
	i: int;

	if(m == nil)
		return msg->none();

	i = activeindex(m);
	it = activeitem(m);

	if(icmenu->separator(it))
		return makemsg(m, "menu.ignore", it);

	if(!icmenu->enabled(it))
		return makemsg(m, "menu.disabled", it);

	if(icmenu->submenu(it))
		return makemsg(m, "menu.submenu", it);

	setcheckedactive(m, i, !icmenu->checked(it));
	render(u, m);

	return makemsg(m, "menu.toggle", activeitem(m));
}

activate(u: ref IcUi->Ui, m: ref IcMenuNav->Menu): IcMsg->Msg
{
	it: IcMenu->Item;
	i, j: int;

	if(m == nil)
		return msg->none();

	i = activeindex(m);
	it = activeitem(m);

	if(icmenu->separator(it))
		return makemsg(m, "menu.ignore", it);

	if(!icmenu->enabled(it))
		return makemsg(m, "menu.disabled", it);

	if(icmenu->submenu(it))
		return makemsg(m, "menu.submenu", it);

	if(icmenu->radio(it)){
		if(m.active == IcMenuNav->ActivePopup){
			for(j = 0; j < len m.popupitems; j++){
				if(icmenu->radio(m.popupitems[j]))
					m.popupitems[j] = icmenu->setchecked(m.popupitems[j], 0);
			}

			m.popupitems[i] = icmenu->setchecked(m.popupitems[i], 1);
		}
		else if(m.active == IcMenuNav->ActiveAction){
			for(j = 0; j < len m.actionitems; j++){
				if(icmenu->radio(m.actionitems[j]))
					m.actionitems[j] = icmenu->setchecked(m.actionitems[j], 0);
			}

			m.actionitems[i] = icmenu->setchecked(m.actionitems[i], 1);
		}
		else if(m.active == IcMenuNav->ActiveNav){
			for(j = 0; j < len m.navitems; j++){
				if(icmenu->radio(m.navitems[j]))
					m.navitems[j] = icmenu->setchecked(m.navitems[j], 0);
			}

			m.navitems[i] = icmenu->setchecked(m.navitems[i], 1);
		}
	}

	render(u, m);

	return makemsg(m, "menu.activate", activeitem(m));
}

summary(m: ref IcMenuNav->Menu): string
{
	it: IcMenu->Item;
	s: string;

	if(m == nil)
		return "menu: nil";

	it = activeitem(m);

	s = "menu active=" +
		activeid(m) +
		" index=" +
		sys->sprint("%d", activeindex(m)) +
		" count=" +
		sys->sprint("%d", activecount(m));

	if(it.label != "")
		s += " item=" + it.label;

	if(it.hotkey != "")
		s += " hotkey=" + it.hotkey;

	if(it.command != "")
		s += " command=" + it.command;

	if(!icmenu->enabled(it))
		s += " disabled";

	if(icmenu->checked(it))
		s += " checked";

	if(icmenu->radio(it))
		s += " radio";

	if(icmenu->submenu(it))
		s += " submenu=" + sys->sprint("%d", it.submenuid);

	return s;
}