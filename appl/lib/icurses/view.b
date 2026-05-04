implement IcView;

include "icurses/view.m";

appendchild: fn(a: array of int, s: int): array of int;
prependchild: fn(a: array of int, s: int): array of int;
removechildid: fn(a: array of int, s: int): array of int;

appendnode: fn(a: array of ref IcView->Node, n: ref IcView->Node): array of ref IcView->Node;
removenodeid: fn(a: array of ref IcView->Node, id: int): array of ref IcView->Node;

showhidekids: fn(t: ref IcView->Tree, id: int, visible: int);
enablekids: fn(t: ref IcView->Tree, id: int, enabled: int);
countkids: fn(t: ref IcView->Tree, id: int): int;
dropnode: fn(t: ref IcView->Tree, n: ref IcView->Node);

isdescendant: fn(t: ref IcView->Tree, id, ancestorid: int): int;

collectfocus: fn(t: ref IcView->Tree, id: int, a: array of int): array of int;
focusableok: fn(t: ref IcView->Tree, n: ref IcView->Node): int;
focuslist: fn(t: ref IcView->Tree): array of int;

findhotkeynode: fn(t: ref IcView->Tree, id: int, hotkey: string): ref IcView->Node;

init()
{
}

appendchild(a: array of int, s: int): array of int
{
	n, i: int;
	b: array of int;

	if(s < 0)
		return a;

	if(a == nil){
		b = array[1] of int;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of int;
	for(i = 0; i < n; i++)
		b[i] = a[i];
	b[n] = s;
	return b;
}

prependchild(a: array of int, s: int): array of int
{
	n, i: int;
	b: array of int;

	if(s < 0)
		return a;

	if(a == nil){
		b = array[1] of int;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of int;
	b[0] = s;
	for(i = 0; i < n; i++)
		b[i + 1] = a[i];

	return b;
}

removechildid(a: array of int, s: int): array of int
{
	i, n, k: int;
	b: array of int;

	if(a == nil)
		return nil;

	n = 0;
	for(i = 0; i < len a; i++)
		if(a[i] != s)
			n++;

	if(n == len a)
		return a;

	if(n == 0)
		return array[0] of int;

	b = array[n] of int;
	k = 0;
	for(i = 0; i < len a; i++){
		if(a[i] == s)
			continue;
		b[k] = a[i];
		k++;
	}
	return b;
}

appendnode(a: array of ref IcView->Node, n: ref IcView->Node): array of ref IcView->Node
{
	i, m: int;
	b: array of ref IcView->Node;

	if(a == nil){
		b = array[1] of ref IcView->Node;
		b[0] = n;
		return b;
	}

	m = len a;
	b = array[m + 1] of ref IcView->Node;
	for(i = 0; i < m; i++)
		b[i] = a[i];
	b[m] = n;
	return b;
}

removenodeid(a: array of ref IcView->Node, id: int): array of ref IcView->Node
{
	i, n, k: int;
	b: array of ref IcView->Node;

	if(a == nil || id < 0)
		return a;

	n = 0;
	for(i = 0; i < len a; i++){
		if(a[i] != nil && a[i].id == id)
			continue;
		n++;
	}

	if(n == len a)
		return a;

	if(n == 0)
		return array[0] of ref IcView->Node;

	b = array[n] of ref IcView->Node;
	k = 0;
	for(i = 0; i < len a; i++){
		if(a[i] != nil && a[i].id == id)
			continue;
		b[k] = a[i];
		k++;
	}

	return b;
}

newroot(): ref IcView->Node
{
	v: ref IcView->Node;

	v = ref IcView->Node;
	v.id = IcView->RootId;
	v.kind = "root";
	v.parentid = IcView->NoId;
	v.text = "";
	v.content = "";
	v.hotkey = "";
	v.targetid = IcView->NoId;
	v.command = "";
	v.sarg = "";
	v.iarg0 = 0;
	v.iarg1 = 0;
	v.iarg2 = 0;
	v.frame = IcView->FrameDefault;
	v.scroll = IcView->ScrollClip;
	v.scrollpos = 0;
	v.x = 0;
	v.y = 0;
	v.w = 0;
	v.h = 0;
	v.visible = 1;
	v.enabled = 1;
	v.focusable = 0;
	v.dirty = 0;
	v.children = array[0] of int;
	return v;
}

newnode(id: int, kind: string, parentid: int, x, y, w, h: int): ref IcView->Node
{
	v: ref IcView->Node;

	v = ref IcView->Node;
	v.id = id;
	v.kind = kind;
	v.parentid = parentid;
	v.text = "";
	v.content = "";
	v.hotkey = "";
	v.targetid = IcView->NoId;
	v.command = "";
	v.sarg = "";
	v.iarg0 = 0;
	v.iarg1 = 0;
	v.iarg2 = 0;
	v.frame = IcView->FrameDefault;
	v.scroll = IcView->ScrollClip;
	v.scrollpos = 0;
	v.x = x;
	v.y = y;
	v.w = w;
	v.h = h;
	v.visible = 1;
	v.enabled = 1;
	v.focusable = 0;
	v.dirty = 0;
	v.children = array[0] of int;
	return v;
}

allocid(t: ref IcView->Tree): int
{
	id: int;

	if(t == nil)
		return IcView->NoId;

	id = t.nextid;
	if(id <= IcView->RootId)
		id = IcView->RootId + 1;

	t.nextid = id + 1;
	return id;
}

newtree(): ref IcView->Tree
{
	t: ref IcView->Tree;
	r: ref IcView->Node;

	t = ref IcView->Tree;
	r = newroot();

	t.rootid = r.id;
	t.nodes = array[1] of ref IcView->Node;
	t.nodes[0] = r;

	t.focusid = IcView->NoId;
	t.activegroupid = IcView->NoId;
	t.activewindowid = IcView->NoId;
	t.nextid = IcView->RootId + 1;

	return t;
}

root(t: ref IcView->Tree): ref IcView->Node
{
	if(t == nil)
		return nil;
	return find(t, t.rootid);
}

id(v: ref IcView->Node): int
{
	if(v == nil)
		return IcView->NoId;
	return v.id;
}

kind(v: ref IcView->Node): string
{
	if(v == nil)
		return "";
	return v.kind;
}

parentid(v: ref IcView->Node): int
{
	if(v == nil)
		return IcView->NoId;
	return v.parentid;
}

settext(v: ref IcView->Node, text: string)
{
	if(v == nil)
		return;
	v.text = text;
	v.dirty = 1;
}

gettext(v: ref IcView->Node): string
{
	if(v == nil)
		return "";
	return v.text;
}

setcontent(v: ref IcView->Node, content: string)
{
	if(v == nil)
		return;
	v.content = content;
	v.dirty = 1;
}

getcontent(v: ref IcView->Node): string
{
	if(v == nil)
		return "";
	return v.content;
}

sethotkey(v: ref IcView->Node, hotkey: string)
{
	if(v == nil)
		return;
	v.hotkey = hotkey;
}

gethotkey(v: ref IcView->Node): string
{
	if(v == nil)
		return "";
	return v.hotkey;
}

setaction(v: ref IcView->Node, targetid: int, command: string)
{
	if(v == nil)
		return;
	v.targetid = targetid;
	v.command = command;
}

setargs(v: ref IcView->Node, sarg: string, iarg0, iarg1, iarg2: int)
{
	if(v == nil)
		return;
	v.sarg = sarg;
	v.iarg0 = iarg0;
	v.iarg1 = iarg1;
	v.iarg2 = iarg2;
}

setframe(v: ref IcView->Node, frame: int)
{
	if(v == nil)
		return;
	v.frame = frame;
	v.dirty = 1;
}

getframe(v: ref IcView->Node): int
{
	if(v == nil)
		return IcView->FrameDefault;
	return v.frame;
}

setscroll(v: ref IcView->Node, scroll: int)
{
	if(v == nil)
		return;
	v.scroll = scroll;
	v.dirty = 1;
}

getscroll(v: ref IcView->Node): int
{
	if(v == nil)
		return IcView->ScrollClip;
	return v.scroll;
}

setscrollpos(v: ref IcView->Node, scrollpos: int)
{
	if(v == nil)
		return;
	if(scrollpos < 0)
		scrollpos = 0;
	v.scrollpos = scrollpos;
	v.dirty = 1;
}

getscrollpos(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.scrollpos;
}

setparent(v: ref IcView->Node, parentid: int)
{
	if(v == nil)
		return;
	v.parentid = parentid;
	v.dirty = 1;
}

setbounds(v: ref IcView->Node, x, y, w, h: int)
{
	if(v == nil)
		return;
	v.x = x;
	v.y = y;
	v.w = w;
	v.h = h;
	v.dirty = 1;
}

moveby(v: ref IcView->Node, dx, dy: int)
{
	if(v == nil)
		return;
	v.x += dx;
	v.y += dy;
	v.dirty = 1;
}

x(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.x;
}

y(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.y;
}

w(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.w;
}

h(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.h;
}

show(v: ref IcView->Node)
{
	if(v == nil)
		return;
	v.visible = 1;
	v.dirty = 1;
}

hide(v: ref IcView->Node)
{
	if(v == nil)
		return;
	v.visible = 0;
	v.dirty = 1;
}

isvisible(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.visible;
}

enable(v: ref IcView->Node)
{
	if(v == nil)
		return;
	v.enabled = 1;
	v.dirty = 1;
}

disable(v: ref IcView->Node)
{
	if(v == nil)
		return;
	v.enabled = 0;
	v.dirty = 1;
}

isenabled(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.enabled;
}

setfocusable(v: ref IcView->Node, focusable: int)
{
	if(v == nil)
		return;
	v.focusable = focusable;
	v.dirty = 1;
}

isfocusable(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.focusable;
}

setdirty(v: ref IcView->Node, dirty: int)
{
	if(v == nil)
		return;
	v.dirty = dirty;
}

isdirty(v: ref IcView->Node): int
{
	if(v == nil)
		return 0;
	return v.dirty;
}

addchild(v: ref IcView->Node, childid: int)
{
	if(v == nil)
		return;
	if(childid < 0)
		return;
	if(haschild(v, childid))
		return;
	v.children = appendchild(v.children, childid);
	v.dirty = 1;
}

removechild(v: ref IcView->Node, childid: int)
{
	if(v == nil)
		return;
	if(childid < 0)
		return;
	v.children = removechildid(v.children, childid);
	v.dirty = 1;
}

childcount(v: ref IcView->Node): int
{
	if(v == nil || v.children == nil)
		return 0;
	return len v.children;
}

childat(v: ref IcView->Node, i: int): int
{
	if(v == nil || v.children == nil)
		return IcView->NoId;
	if(i < 0 || i >= len v.children)
		return IcView->NoId;
	return v.children[i];
}

haschild(v: ref IcView->Node, childid: int): int
{
	i: int;

	if(v == nil || v.children == nil)
		return 0;

	for(i = 0; i < len v.children; i++){
		if(v.children[i] == childid)
			return 1;
	}
	return 0;
}

find(t: ref IcView->Tree, id: int): ref IcView->Node
{
	i: int;

	if(t == nil || id < 0 || t.nodes == nil)
		return nil;

	for(i = 0; i < len t.nodes; i++){
		if(t.nodes[i] != nil && t.nodes[i].id == id)
			return t.nodes[i];
	}
	return nil;
}

addnode(t: ref IcView->Tree, n: ref IcView->Node): int
{
	if(t == nil || n == nil || n.id < 0)
		return -1;

	if(find(t, n.id) != nil)
		return -1;

	if(n.children == nil)
		n.children = array[0] of int;

	t.nodes = appendnode(t.nodes, n);

	if(n.id >= t.nextid)
		t.nextid = n.id + 1;

	return 0;
}

addchildnode(t: ref IcView->Tree, parentid: int, n: ref IcView->Node): int
{
	p: ref IcView->Node;

	if(t == nil || n == nil || parentid < 0)
		return -1;

	if(n.id < 0)
		return -1;

	if(find(t, n.id) != nil)
		return -1;

	p = find(t, parentid);
	if(p == nil)
		return -1;

	n.parentid = parentid;
	if(n.children == nil)
		n.children = array[0] of int;

	t.nodes = appendnode(t.nodes, n);
	addchild(p, n.id);

	if(n.id >= t.nextid)
		t.nextid = n.id + 1;

	return 0;
}

isdescendant(t: ref IcView->Tree, id, ancestorid: int): int
{
	n: ref IcView->Node;
	guard, limit: int;

	if(t == nil || id < 0 || ancestorid < 0)
		return 0;

	n = find(t, id);
	if(n == nil)
		return 0;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	guard = 0;
	while(n != nil && guard < limit){
		if(n.parentid == ancestorid)
			return 1;
		if(n.parentid == IcView->NoId)
			return 0;
		n = find(t, n.parentid);
		guard++;
	}

	return 0;
}

reparent(t: ref IcView->Tree, id, parentid: int): int
{
	n, oldp, newp: ref IcView->Node;

	if(t == nil || id < 0 || parentid < 0)
		return -1;

	if(id == t.rootid)
		return -1;

	if(id == parentid)
		return -1;

	n = find(t, id);
	if(n == nil)
		return -1;

	newp = find(t, parentid);
	if(newp == nil)
		return -1;

	if(isdescendant(t, parentid, id))
		return -1;

	oldp = find(t, n.parentid);
	if(oldp != nil)
		removechild(oldp, id);

	n.parentid = parentid;
	addchild(newp, id);

	n.dirty = 1;
	newp.dirty = 1;

	return 0;
}

dropnode(t: ref IcView->Tree, n: ref IcView->Node)
{
	i: int;
	cid: int;
	c: ref IcView->Node;

	if(t == nil || n == nil)
		return;

	for(i = 0; i < len n.children; i++){
		cid = n.children[i];
		c = find(t, cid);
		dropnode(t, c);
	}

	t.nodes = removenodeid(t.nodes, n.id);
}

removetree(t: ref IcView->Tree, id: int): int
{
	n, p: ref IcView->Node;

	if(t == nil || id < 0)
		return -1;

	if(id == t.rootid)
		return -1;

	n = find(t, id);
	if(n == nil)
		return -1;

	p = find(t, n.parentid);
	if(p != nil)
		removechild(p, id);

	if(t.focusid == id || isdescendant(t, t.focusid, id))
		t.focusid = IcView->NoId;
	if(t.activegroupid == id || isdescendant(t, t.activegroupid, id))
		t.activegroupid = IcView->NoId;
	if(t.activewindowid == id || isdescendant(t, t.activewindowid, id))
		t.activewindowid = IcView->NoId;

	dropnode(t, n);

	return 0;
}

bringtofront(t: ref IcView->Tree, id: int): int
{
	n, p: ref IcView->Node;

	n = find(t, id);
	if(n == nil)
		return -1;

	p = find(t, n.parentid);
	if(p == nil)
		return -1;

	p.children = removechildid(p.children, id);
	p.children = appendchild(p.children, id);
	p.dirty = 1;
	n.dirty = 1;

	return 0;
}

sendtoback(t: ref IcView->Tree, id: int): int
{
	n, p: ref IcView->Node;

	n = find(t, id);
	if(n == nil)
		return -1;

	p = find(t, n.parentid);
	if(p == nil)
		return -1;

	p.children = removechildid(p.children, id);
	p.children = prependchild(p.children, id);
	p.dirty = 1;
	n.dirty = 1;

	return 0;
}

activatewindow(t: ref IcView->Tree, id: int): int
{
	n: ref IcView->Node;

	if(t == nil || id < 0)
		return -1;

	n = find(t, id);
	if(n == nil)
		return -1;

	t.activewindowid = id;
	return bringtofront(t, id);
}

absx(t: ref IcView->Tree, n: ref IcView->Node): int
{
	p: ref IcView->Node;
	ax, guard, limit: int;

	if(t == nil || n == nil)
		return 0;

	ax = n.x;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	p = find(t, n.parentid);
	guard = 0;
	while(p != nil && guard < limit){
		ax += p.x;
		p = find(t, p.parentid);
		guard++;
	}

	return ax;
}

absy(t: ref IcView->Tree, n: ref IcView->Node): int
{
	p: ref IcView->Node;
	ay, guard, limit: int;

	if(t == nil || n == nil)
		return 0;

	ay = n.y;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	p = find(t, n.parentid);
	guard = 0;
	while(p != nil && guard < limit){
		ay += p.y;
		p = find(t, p.parentid);
		guard++;
	}

	return ay;
}

abspos(t: ref IcView->Tree, id: int): IcView->Pos
{
	pos: IcView->Pos;
	n: ref IcView->Node;

	pos.x = 0;
	pos.y = 0;

	n = find(t, id);
	if(n == nil)
		return pos;

	pos.x = absx(t, n);
	pos.y = absy(t, n);

	return pos;
}

isvisibletree(t: ref IcView->Tree, id: int): int
{
	n: ref IcView->Node;
	guard, limit: int;

	if(t == nil || id < 0)
		return 0;

	n = find(t, id);
	if(n == nil)
		return 0;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	guard = 0;
	while(n != nil && guard < limit){
		if(!n.visible)
			return 0;
		if(n.parentid == IcView->NoId)
			return 1;
		n = find(t, n.parentid);
		guard++;
	}

	return 0;
}

isenabledtree(t: ref IcView->Tree, id: int): int
{
	n: ref IcView->Node;
	guard, limit: int;

	if(t == nil || id < 0)
		return 0;

	n = find(t, id);
	if(n == nil)
		return 0;

	limit = 1;
	if(t.nodes != nil)
		limit = len t.nodes + 1;

	guard = 0;
	while(n != nil && guard < limit){
		if(!n.enabled)
			return 0;
		if(n.parentid == IcView->NoId)
			return 1;
		n = find(t, n.parentid);
		guard++;
	}

	return 0;
}

showhidekids(t: ref IcView->Tree, id: int, visible: int)
{
	n: ref IcView->Node;
	i: int;
	cid: int;

	n = find(t, id);
	if(n == nil)
		return;

	n.visible = visible;
	n.dirty = 1;

	for(i = 0; i < len n.children; i++){
		cid = n.children[i];
		showhidekids(t, cid, visible);
	}
}

enablekids(t: ref IcView->Tree, id: int, enabled: int)
{
	n: ref IcView->Node;
	i: int;
	cid: int;

	n = find(t, id);
	if(n == nil)
		return;

	n.enabled = enabled;
	n.dirty = 1;

	for(i = 0; i < len n.children; i++){
		cid = n.children[i];
		enablekids(t, cid, enabled);
	}
}

showtree(t: ref IcView->Tree, id: int)
{
	showhidekids(t, id, 1);
}

hidetree(t: ref IcView->Tree, id: int)
{
	showhidekids(t, id, 0);
}

enabletree(t: ref IcView->Tree, id: int)
{
	enablekids(t, id, 1);
}

disabletree(t: ref IcView->Tree, id: int)
{
	enablekids(t, id, 0);
}

movetreeby(t: ref IcView->Tree, id: int, dx, dy: int)
{
	n: ref IcView->Node;

	n = find(t, id);
	if(n == nil)
		return;

	moveby(n, dx, dy);
}

countkids(t: ref IcView->Tree, id: int): int
{
	n: ref IcView->Node;
	i, total: int;

	n = find(t, id);
	if(n == nil)
		return 0;

	total = 1;
	for(i = 0; i < len n.children; i++)
		total += countkids(t, n.children[i]);

	return total;
}

subtreecount(t: ref IcView->Tree, id: int): int
{
	return countkids(t, id);
}

focusableok(t: ref IcView->Tree, n: ref IcView->Node): int
{
	if(t == nil || n == nil)
		return 0;

	if(!n.focusable)
		return 0;

	if(!isvisibletree(t, n.id))
		return 0;

	if(!isenabledtree(t, n.id))
		return 0;

	return 1;
}

collectfocus(t: ref IcView->Tree, id: int, a: array of int): array of int
{
	n, c: ref IcView->Node;
	i: int;

	n = find(t, id);
	if(n == nil)
		return a;

	if(focusableok(t, n))
		a = appendchild(a, n.id);

	for(i = 0; i < len n.children; i++){
		c = find(t, n.children[i]);
		if(c != nil)
			a = collectfocus(t, c.id, a);
	}

	return a;
}

focuslist(t: ref IcView->Tree): array of int
{
	if(t == nil)
		return array[0] of int;

	return collectfocus(t, t.rootid, array[0] of int);
}

setfocus(t: ref IcView->Tree, id: int): int
{
	n: ref IcView->Node;

	if(t == nil)
		return -1;

	n = find(t, id);
	if(!focusableok(t, n))
		return -1;

	t.focusid = id;

	n = find(t, n.parentid);
	while(n != nil){
		if(n.kind == "window"){
			activatewindow(t, n.id);
			break;
		}
		n = find(t, n.parentid);
	}

	return 0;
}

clearfocus(t: ref IcView->Tree)
{
	if(t == nil)
		return;
	t.focusid = IcView->NoId;
}

focusid(t: ref IcView->Tree): int
{
	if(t == nil)
		return IcView->NoId;
	return t.focusid;
}

focusnode(t: ref IcView->Tree): ref IcView->Node
{
	if(t == nil)
		return nil;
	return find(t, t.focusid);
}

nextfocus(t: ref IcView->Tree): int
{
	a: array of int;
	i, n, cur: int;

	if(t == nil)
		return IcView->NoId;

	a = focuslist(t);
	if(a == nil || len a == 0){
		t.focusid = IcView->NoId;
		return IcView->NoId;
	}

	n = len a;
	cur = -1;

	for(i = 0; i < n; i++){
		if(a[i] == t.focusid){
			cur = i;
			break;
		}
	}

	if(cur < 0)
		setfocus(t, a[0]);
	else
		setfocus(t, a[(cur + 1) % n]);

	return t.focusid;
}

prevfocus(t: ref IcView->Tree): int
{
	a: array of int;
	i, n, cur: int;

	if(t == nil)
		return IcView->NoId;

	a = focuslist(t);
	if(a == nil || len a == 0){
		t.focusid = IcView->NoId;
		return IcView->NoId;
	}

	n = len a;
	cur = -1;

	for(i = 0; i < n; i++){
		if(a[i] == t.focusid){
			cur = i;
			break;
		}
	}

	if(cur < 0)
		setfocus(t, a[0]);
	else if(cur == 0)
		setfocus(t, a[n - 1]);
	else
		setfocus(t, a[cur - 1]);

	return t.focusid;
}

findhotkeynode(t: ref IcView->Tree, id: int, hotkey: string): ref IcView->Node
{
	n, r: ref IcView->Node;
	i: int;

	n = find(t, id);
	if(n == nil)
		return nil;

	for(i = len n.children - 1; i >= 0; i--){
		r = findhotkeynode(t, n.children[i], hotkey);
		if(r != nil)
			return r;
	}

	if(n.hotkey == hotkey && isvisibletree(t, n.id) && isenabledtree(t, n.id))
		return n;

	return nil;
}

findhotkey(t: ref IcView->Tree, hotkey: string): ref IcView->Node
{
	if(t == nil || hotkey == "")
		return nil;

	return findhotkeynode(t, t.rootid, hotkey);
}