implement IcHit;

include "icurses/hit.m";

sys: Sys;
view: IcView;
msg: IcMsg;

Expand: con 3;

none: fn(): IcMsg->Msg;

abshit: fn(t: ref IcView->Tree, n: ref IcView->Node): IcHit->Hit;
contains: fn(h: IcHit->Hit, x, y: int): int;
expandedcontains: fn(h: IcHit->Hit, x, y, expand: int): int;
distance: fn(h: IcHit->Hit, x, y: int): int;
absint: fn(v: int): int;
depth: fn(t: ref IcView->Tree, n: ref IcView->Node): int;
kindpriority: fn(n: ref IcView->Node): int;

flatnodeat: fn(t: ref IcView->Tree, x, y: int): ref IcView->Node;
expandednodeat: fn(t: ref IcView->Tree, x, y, expand: int): ref IcView->Node;
candidatebetter: fn(t: ref IcView->Tree, cur, next: ref IcView->Node, curscore, nextscore: int): int;
better: fn(t: ref IcView->Tree, a, b: ref IcView->Node): ref IcView->Node;
bestnode: fn(u: ref IcUi->Ui, x, y: int): ref IcView->Node;

focusmsg: fn(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg;
hitmsg: fn(n: ref IcView->Node, x, y, buttons: int): IcMsg->Msg;
actionmsg: fn(n: ref IcView->Node, x, y, buttons: int): IcMsg->Msg;

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

	view->init();
	msg->init();
}

none(): IcMsg->Msg
{
	return msg->none();
}

empty(): IcHit->Hit
{
	h: IcHit->Hit;

	h.ok = 0;
	h.id = "";
	h.kind = "";
	h.x = 0;
	h.y = 0;
	h.w = 0;
	h.h = 0;

	return h;
}

abshit(t: ref IcView->Tree, n: ref IcView->Node): IcHit->Hit
{
	h: IcHit->Hit;

	h = empty();

	if(t == nil || n == nil)
		return h;

	h.ok = 1;
	h.id = n.id;
	h.kind = n.kind;
	h.x = view->absx(t, n);
	h.y = view->absy(t, n);
	h.w = n.w;
	h.h = n.h;

	return h;
}

bounds(u: ref IcUi->Ui, id: string): IcHit->Hit
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || id == "")
		return empty();

	n = view->find(u.tree, id);
	if(n == nil)
		return empty();

	return abshit(u.tree, n);
}

contains(h: IcHit->Hit, x, y: int): int
{
	if(!h.ok)
		return 0;

	if(h.w <= 0 || h.h <= 0)
		return 0;

	if(x < h.x)
		return 0;

	if(y < h.y)
		return 0;

	if(x >= h.x + h.w)
		return 0;

	if(y >= h.y + h.h)
		return 0;

	return 1;
}

expandedcontains(h: IcHit->Hit, x, y, expand: int): int
{
	if(!h.ok)
		return 0;

	if(h.w <= 0 || h.h <= 0)
		return 0;

	if(expand < 0)
		expand = 0;

	if(x < h.x - expand)
		return 0;

	if(y < h.y - expand)
		return 0;

	if(x >= h.x + h.w + expand)
		return 0;

	if(y >= h.y + h.h + expand)
		return 0;

	return 1;
}

absint(v: int): int
{
	if(v < 0)
		return -v;

	return v;
}

distance(h: IcHit->Hit, x, y: int): int
{
	dx, dy: int;

	if(!h.ok)
		return 999999;

	dx = 0;
	if(x < h.x)
		dx = h.x - x;
	else if(x >= h.x + h.w)
		dx = x - (h.x + h.w - 1);

	dy = 0;
	if(y < h.y)
		dy = h.y - y;
	else if(y >= h.y + h.h)
		dy = y - (h.y + h.h - 1);

	return absint(dx) + absint(dy);
}

inside(u: ref IcUi->Ui, id: string, x, y: int): int
{
	return contains(bounds(u, id), x, y);
}

depth(t: ref IcView->Tree, n: ref IcView->Node): int
{
	d, guard, limit: int;

	if(t == nil || n == nil)
		return 0;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	d = 0;
	guard = 0;

	while(n != nil && guard < limit){
		d++;
		if(n.parentid == "")
			break;
		n = view->find(t, n.parentid);
		guard++;
	}

	return d;
}

kindpriority(n: ref IcView->Node): int
{
	if(n == nil)
		return 0;

	if(n.kind == "button")
		return 100;

	if(n.kind == "label")
		return 90;

	if(n.kind == "canvas")
		return 80;

	if(n.kind == "hbar" || n.kind == "vbar" || n.kind == "progress" || n.kind == "spinner")
		return 70;

	if(n.kind == "group")
		return 20;

	if(n.kind == "window")
		return 10;

	return 50;
}

candidatebetter(t: ref IcView->Tree, cur, next: ref IcView->Node, curscore, nextscore: int): int
{
	curp, nextp, curd, nextd: int;

	if(next == nil)
		return 0;

	if(cur == nil)
		return 1;

	if(nextscore < curscore)
		return 1;

	if(nextscore > curscore)
		return 0;

	nextp = kindpriority(next);
	curp = kindpriority(cur);

	if(nextp > curp)
		return 1;

	if(nextp < curp)
		return 0;

	nextd = depth(t, next);
	curd = depth(t, cur);

	if(nextd > curd)
		return 1;

	return 0;
}

flatnodeat(t: ref IcView->Tree, x, y: int): ref IcView->Node
{
	i, score, bestscore: int;
	n, best: ref IcView->Node;
	h: IcHit->Hit;

	if(t == nil || t.nodes == nil)
		return nil;

	best = nil;
	bestscore = 0;

	for(i = len t.nodes - 1; i >= 0; i--){
		n = t.nodes[i];
		if(n == nil)
			continue;

		if(n.id == t.rootid)
			continue;

		if(!view->isvisibletree(t, n.id))
			continue;

		if(!view->isenabledtree(t, n.id))
			continue;

		h = abshit(t, n);
		if(!contains(h, x, y))
			continue;

		score = 0;
		if(candidatebetter(t, best, n, bestscore, score)){
			best = n;
			bestscore = score;
		}
	}

	return best;
}

expandednodeat(t: ref IcView->Tree, x, y, expand: int): ref IcView->Node
{
	i, score, bestscore: int;
	n, best: ref IcView->Node;
	h: IcHit->Hit;

	if(t == nil || t.nodes == nil)
		return nil;

	best = nil;
	bestscore = 999999;

	for(i = len t.nodes - 1; i >= 0; i--){
		n = t.nodes[i];
		if(n == nil)
			continue;

		if(n.id == t.rootid)
			continue;

		if(!view->isvisibletree(t, n.id))
			continue;

		if(!view->isenabledtree(t, n.id))
			continue;

		h = abshit(t, n);
		if(!expandedcontains(h, x, y, expand))
			continue;

		score = distance(h, x, y);

		if(candidatebetter(t, best, n, bestscore, score)){
			best = n;
			bestscore = score;
		}
	}

	return best;
}

better(t: ref IcView->Tree, a, b: ref IcView->Node): ref IcView->Node
{
	if(a == nil)
		return b;

	if(b == nil)
		return a;

	if(candidatebetter(t, a, b, 0, 0))
		return b;

	return a;
}

bestnode(u: ref IcUi->Ui, x, y: int): ref IcView->Node
{
	n, best, near: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return nil;

	best = flatnodeat(u.tree, x, y);

	if(x > 0){
		n = flatnodeat(u.tree, x - 1, y);
		best = better(u.tree, best, n);
	}

	if(y > 0){
		n = flatnodeat(u.tree, x, y - 1);
		best = better(u.tree, best, n);
	}

	if(x > 0 && y > 0){
		n = flatnodeat(u.tree, x - 1, y - 1);
		best = better(u.tree, best, n);
	}

	n = flatnodeat(u.tree, x + 1, y);
	best = better(u.tree, best, n);

	n = flatnodeat(u.tree, x, y + 1);
	best = better(u.tree, best, n);

	#
	# If exact/off-by-one probing only finds a low-priority container,
	# prefer a nearby leaf/control candidate.  This compensates for small
	# backend coordinate mismatches without making windows swallow labels.
	#
	near = expandednodeat(u.tree, x, y, Expand);
	if(near != nil){
		if(best == nil)
			best = near;
		else if(kindpriority(near) > kindpriority(best))
			best = near;
		else if(depth(u.tree, near) > depth(u.tree, best) && kindpriority(best) <= 20)
			best = near;
	}

	return best;
}

node(u: ref IcUi->Ui, x, y: int): ref IcView->Node
{
	return bestnode(u, x, y);
}

info(u: ref IcUi->Ui, x, y: int): IcHit->Hit
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return empty();

	n = node(u, x, y);
	if(n == nil)
		return empty();

	return abshit(u.tree, n);
}

id(u: ref IcUi->Ui, x, y: int): string
{
	n: ref IcView->Node;

	n = node(u, x, y);
	if(n == nil)
		return "";

	return n.id;
}

focusmsg(u: ref IcUi->Ui, n: ref IcView->Node): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(u == nil || u.tree == nil || n == nil)
		return none();

	if(!view->isfocusable(n))
		return none();

	if(!view->isvisibletree(u.tree, n.id))
		return none();

	if(!view->isenabledtree(u.tree, n.id))
		return none();

	if(view->setfocus(u.tree, n.id) < 0)
		return none();

	u.status = "mouse focus " + n.id;

	m = msg->newmsg("hit", n.id, IcMsg->KindFocus, "focus.set");
	m.sarg = n.id;
	m.iarg0 = n.x;
	m.iarg1 = n.y;
	m.iarg2 = 0;
	m.handled = 1;

	return m;
}

focus(u: ref IcUi->Ui, x, y: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = node(u, x, y);
	return focusmsg(u, n);
}

hitmsg(n: ref IcView->Node, x, y, buttons: int): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(n == nil)
		return none();

	m = msg->newmsg("hit", n.id, IcMsg->KindNotify, "mouse.hit");
	m.sarg = n.kind;
	m.iarg0 = x;
	m.iarg1 = y;
	m.iarg2 = buttons;
	m.handled = 1;

	return m;
}

message(u: ref IcUi->Ui, x, y, buttons: int): IcMsg->Msg
{
	n: ref IcView->Node;

	n = node(u, x, y);
	if(n == nil)
		return none();

	return hitmsg(n, x, y, buttons);
}

actionmsg(n: ref IcView->Node, x, y, buttons: int): IcMsg->Msg
{
	m: IcMsg->Msg;
	dst, cmd: string;

	if(n == nil)
		return none();

	cmd = n.command;
	if(cmd == "")
		return none();

	dst = n.targetid;
	if(dst == "")
		dst = n.id;

	m = msg->newmsg(n.id, dst, IcMsg->KindCommand, cmd);
	m.sarg = n.sarg;
	m.iarg0 = x;
	m.iarg1 = y;
	m.iarg2 = buttons;

	return m;
}

activate(u: ref IcUi->Ui, x, y, buttons: int): IcMsg->Msg
{
	n: ref IcView->Node;
	m, fm: IcMsg->Msg;

	if(u == nil || u.tree == nil)
		return none();

	if((buttons & IcHit->ButtonLeft) == 0)
		return none();

	n = node(u, x, y);
	if(n == nil)
		return none();

	fm = focusmsg(u, n);

	m = actionmsg(n, x, y, buttons);
	if(m.kind != IcMsg->KindNone){
		u.status = "mouse action " + n.id + " -> " + m.cmd;
		return m;
	}

	if(fm.kind != IcMsg->KindNone)
		return fm;

	u.status = "mouse hit " + n.id;
	return hitmsg(n, x, y, buttons);
}

describe(h: IcHit->Hit): string
{
	if(!h.ok)
		return "hit: none";

	return "hit: " +
		h.id +
		" kind=" +
		h.kind +
		" x=" +
		sys->sprint("%d", h.x) +
		" y=" +
		sys->sprint("%d", h.y) +
		" w=" +
		sys->sprint("%d", h.w) +
		" h=" +
		sys->sprint("%d", h.h);
}