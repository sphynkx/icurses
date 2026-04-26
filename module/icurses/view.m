IcView: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	ScrollClip: con 0;
	ScrollNoBar: con 1;
	ScrollBar: con 2;

	FrameDefault: con -1;

	Node: adt
	{
		id:         string;
		kind:       string;
		parentid:   string;

		text:       string;
		content:    string;

		hotkey:     string;
		targetid:   string;
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

	settext: fn(v: ref Node, text: string);
	gettext: fn(v: ref Node): string;

	setcontent: fn(v: ref Node, content: string);
	getcontent: fn(v: ref Node): string;

	sethotkey: fn(v: ref Node, hotkey: string);
	gethotkey: fn(v: ref Node): string;

	setaction: fn(v: ref Node, targetid, command: string);
	setargs: fn(v: ref Node, sarg: string, iarg0, iarg1, iarg2: int);

	setframe: fn(v: ref Node, frame: int);
	getframe: fn(v: ref Node): int;

	setscroll: fn(v: ref Node, scroll: int);
	getscroll: fn(v: ref Node): int;
	setscrollpos: fn(v: ref Node, scrollpos: int);
	getscrollpos: fn(v: ref Node): int;

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

	bringtofront: fn(t: ref Tree, id: string): int;
	sendtoback: fn(t: ref Tree, id: string): int;
	activatewindow: fn(t: ref Tree, id: string): int;

	absx: fn(t: ref Tree, n: ref Node): int;
	absy: fn(t: ref Tree, n: ref Node): int;
	abspos: fn(t: ref Tree, id: string): Pos;

	isvisibletree: fn(t: ref Tree, id: string): int;
	isenabledtree: fn(t: ref Tree, id: string): int;

	showtree: fn(t: ref Tree, id: string);
	hidetree: fn(t: ref Tree, id: string);
	enabletree: fn(t: ref Tree, id: string);
	disabletree: fn(t: ref Tree, id: string);

	movetreeby: fn(t: ref Tree, id: string, dx, dy: int);

	subtreecount: fn(t: ref Tree, id: string): int;

	setfocus: fn(t: ref Tree, id: string): int;
	clearfocus: fn(t: ref Tree);
	focusid: fn(t: ref Tree): string;
	focusnode: fn(t: ref Tree): ref Node;
	nextfocus: fn(t: ref Tree): string;
	prevfocus: fn(t: ref Tree): string;

	findhotkey: fn(t: ref Tree, hotkey: string): ref Node;
};