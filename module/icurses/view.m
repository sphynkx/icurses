IcView: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	Node: adt
	{
		id:         string;
		kind:       string;
		parentid:   string;

		# Local-to-parent geometry.
		x:          int;
		y:          int;
		w:          int;
		h:          int;

		visible:    int;
		enabled:    int;
		focusable:  int;
		dirty:      int;

		# Ordered child list. Order is later useful for paint order,
		# tab order and simple z-order.
		children:   array of string;
	};

	Pos: adt
	{
		x: int;
		y: int;
	};

	Tree: adt
	{
		rootid:         string;
		nodes:          array of ref Node;

		# Reserved core context state for later framework layers.
		focusid:        string;
		activegroupid:  string;
		activewindowid: string;
	};

	init: fn();

	newroot: fn(): ref Node;
	newnode: fn(id, kind, parentid: string, x, y, w, h: int): ref Node;

	newtree: fn(): ref Tree;
	root: fn(t: ref Tree): ref Node;

	id: fn(v: ref Node): string;
	kind: fn(v: ref Node): string;
	parentid: fn(v: ref Node): string;

	setparent: fn(v: ref Node, parentid: string);
	setbounds: fn(v: ref Node, x, y, w, h: int);
	moveby: fn(v: ref Node, dx, dy: int);

	x: fn(v: ref Node): int;
	y: fn(v: ref Node): int;
	w: fn(v: ref Node): int;
	h: fn(v: ref Node): int;

	show: fn(v: ref Node);
	hide: fn(v: ref Node);
	isvisible: fn(v: ref Node): int;

	enable: fn(v: ref Node);
	disable: fn(v: ref Node);
	isenabled: fn(v: ref Node): int;

	setfocusable: fn(v: ref Node, focusable: int);
	isfocusable: fn(v: ref Node): int;

	setdirty: fn(v: ref Node, dirty: int);
	isdirty: fn(v: ref Node): int;

	addchild: fn(v: ref Node, childid: string);
	removechild: fn(v: ref Node, childid: string);
	childcount: fn(v: ref Node): int;
	childat: fn(v: ref Node, i: int): string;
	haschild: fn(v: ref Node, childid: string): int;

	find: fn(t: ref Tree, id: string): ref Node;
	addnode: fn(t: ref Tree, n: ref Node): int;
	addchildnode: fn(t: ref Tree, parentid: string, n: ref Node): int;
	reparent: fn(t: ref Tree, id, parentid: string): int;
	removetree: fn(t: ref Tree, id: string): int;

	absx: fn(t: ref Tree, n: ref Node): int;
	absy: fn(t: ref Tree, n: ref Node): int;
	abspos: fn(t: ref Tree, id: string): Pos;

	isvisibletree: fn(t: ref Tree, id: string): int;
	isenabledtree: fn(t: ref Tree, id: string): int;

	showtree: fn(t: ref Tree, id: string);
	hidetree: fn(t: ref Tree, id: string);
	enabletree: fn(t: ref Tree, id: string);
	disabletree: fn(t: ref Tree, id: string);

	# Move subtree logically: only the subtree root local position changes.
	# Descendant local coordinates stay unchanged; their absolute positions
	# change through parent-chain resolution.
	movetreeby: fn(t: ref Tree, id: string, dx, dy: int);

	subtreecount: fn(t: ref Tree, id: string): int;
};