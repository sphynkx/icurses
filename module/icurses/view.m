IcView: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	ScrollClip: con 0;
	ScrollNoBar: con 1;
	ScrollBar: con 2;

	FrameDefault: con -1;

	NoId: con -1;
	RootId: con 0;

	Node: adt
	{
		id:         int;
		kind:       string;
		parentid:   int;

		text:       string;
		content:    string;

		hotkey:     string;
		targetid:   int;
		command:    string;
		sarg:       string;
		iarg0:      int;
		iarg1:      int;
		iarg2:      int;

		frame:      int;
		scroll:     int;
		scrollpos:  int;

		x:          int;
		y:          int;
		w:          int;
		h:          int;

		visible:    int;
		enabled:    int;
		focusable:  int;
		dirty:      int;

		children:   array of int;
	};

	Pos: adt
	{
		x: int;
		y: int;
	};

	Tree: adt
	{
		rootid:         int;
		nodes:          array of ref Node;

		focusid:        int;
		activegroupid:  int;
		activewindowid: int;

		nextid:         int;
	};

	init: fn();

	newroot: fn(): ref Node;
	newnode: fn(id: int, kind: string, parentid: int, x, y, w, h: int): ref Node;
	allocid: fn(t: ref Tree): int;

	newtree: fn(): ref Tree;
	root: fn(t: ref Tree): ref Node;

	id: fn(v: ref Node): int;
	kind: fn(v: ref Node): string;
	parentid: fn(v: ref Node): int;

	settext: fn(v: ref Node, text: string);
	gettext: fn(v: ref Node): string;

	setcontent: fn(v: ref Node, content: string);
	getcontent: fn(v: ref Node): string;

	sethotkey: fn(v: ref Node, hotkey: string);
	gethotkey: fn(v: ref Node): string;

	setaction: fn(v: ref Node, targetid: int, command: string);
	setargs: fn(v: ref Node, sarg: string, iarg0, iarg1, iarg2: int);

	setframe: fn(v: ref Node, frame: int);
	getframe: fn(v: ref Node): int;

	setscroll: fn(v: ref Node, scroll: int);
	getscroll: fn(v: ref Node): int;
	setscrollpos: fn(v: ref Node, scrollpos: int);
	getscrollpos: fn(v: ref Node): int;

	setparent: fn(v: ref Node, parentid: int);
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

	addchild: fn(v: ref Node, childid: int);
	removechild: fn(v: ref Node, childid: int);
	childcount: fn(v: ref Node): int;
	childat: fn(v: ref Node, i: int): int;
	haschild: fn(v: ref Node, childid: int): int;

	find: fn(t: ref Tree, id: int): ref Node;
	addnode: fn(t: ref Tree, n: ref Node): int;
	addchildnode: fn(t: ref Tree, parentid: int, n: ref Node): int;
	reparent: fn(t: ref Tree, id, parentid: int): int;
	removetree: fn(t: ref Tree, id: int): int;

	bringtofront: fn(t: ref Tree, id: int): int;
	sendtoback: fn(t: ref Tree, id: int): int;
	activatewindow: fn(t: ref Tree, id: int): int;

	absx: fn(t: ref Tree, n: ref Node): int;
	absy: fn(t: ref Tree, n: ref Node): int;
	abspos: fn(t: ref Tree, id: int): Pos;

	isvisibletree: fn(t: ref Tree, id: int): int;
	isenabledtree: fn(t: ref Tree, id: int): int;

	showtree: fn(t: ref Tree, id: int);
	hidetree: fn(t: ref Tree, id: int);
	enabletree: fn(t: ref Tree, id: int);
	disabletree: fn(t: ref Tree, id: int);

	movetreeby: fn(t: ref Tree, id: int, dx, dy: int);

	subtreecount: fn(t: ref Tree, id: int): int;

	setfocus: fn(t: ref Tree, id: int): int;
	clearfocus: fn(t: ref Tree);
	focusid: fn(t: ref Tree): int;
	focusnode: fn(t: ref Tree): ref Node;
	nextfocus: fn(t: ref Tree): int;
	prevfocus: fn(t: ref Tree): int;

	findhotkey: fn(t: ref Tree, hotkey: string): ref Node;
};