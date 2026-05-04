implement IcActions;

include "icurses/actions.m";

sys: Sys;
msg: IcMsg;
ui: IcUi;
ic: Icurses;

appendaction: fn(a: array of IcActions->Action, it: IcActions->Action): array of IcActions->Action;
emptyaction: fn(): IcActions->Action;
lower: fn(s: string): string;
samechar: fn(k: int, key: string): int;
handleui: fn(u: ref IcUi->Ui, k: int): IcMsg->Msg;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	msg->init();
	ui->init();
	ic->init();
}

emptyaction(): IcActions->Action
{
	it: IcActions->Action;

	it.key = "";
	it.target = IcMsg->MsgNoNode;
	it.cmd = "";
	it.label = "";
	it.sarg = "";
	it.iarg0 = 0;
	it.iarg1 = 0;
	it.iarg2 = 0;

	return it;
}

appendaction(a: array of IcActions->Action, it: IcActions->Action): array of IcActions->Action
{
	r: array of IcActions->Action;
	i, n: int;

	if(a == nil){
		r = array[1] of IcActions->Action;
		r[0] = it;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcActions->Action;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = it;
	return r;
}

lower(s: string): string
{
	r: string;
	i, c: int;

	r = "";

	for(i = 0; i < len s; i++){
		c = int s[i];

		if(c >= 'A' && c <= 'Z')
			c += 'a' - 'A';

		r += string c;
	}

	return r;
}

samechar(k: int, key: string): int
{
	c, kk: int;

	if(key == "" || len key != 1)
		return 0;

	c = int key[0];
	kk = k;

	if(c >= 'A' && c <= 'Z')
		c += 'a' - 'A';

	if(kk >= 'A' && kk <= 'Z')
		kk += 'a' - 'A';

	return c == kk;
}

new(id: int): ref IcActions->Actions
{
	a: ref IcActions->Actions;

	a = ref IcActions->Actions;
	a.id = id;
	a.items = array[0] of IcActions->Action;
	a.last = msg->none();

	return a;
}

clear(a: ref IcActions->Actions)
{
	if(a == nil)
		return;

	a.items = array[0] of IcActions->Action;
	a.last = msg->none();
}

add(a: ref IcActions->Actions, key: string, target: int, cmd, label: string): int
{
	return addargs(a, key, target, cmd, label, "", 0, 0, 0);
}

addargs(a: ref IcActions->Actions, key: string, target: int, cmd, label, sarg: string,
	iarg0, iarg1, iarg2: int): int
{
	it: IcActions->Action;
	i: int;

	if(a == nil)
		return -1;

	if(key == "" || cmd == "")
		return -1;

	it.key = key;
	it.target = target;
	it.cmd = cmd;
	it.label = label;
	it.sarg = sarg;
	it.iarg0 = iarg0;
	it.iarg1 = iarg1;
	it.iarg2 = iarg2;

	for(i = 0; i < len a.items; i++){
		if(a.items[i].key == key){
			a.items[i] = it;
			return 0;
		}
	}

	a.items = appendaction(a.items, it);
	return 0;
}

count(a: ref IcActions->Actions): int
{
	if(a == nil || a.items == nil)
		return 0;

	return len a.items;
}

bind(u: ref IcUi->Ui, a: ref IcActions->Actions): int
{
	i: int;
	rc: int;

	if(u == nil || a == nil)
		return -1;

	rc = 0;

	for(i = 0; i < len a.items; i++){
		if(ui->bindkeyargs(u,
			a.items[i].key,
			a.items[i].target,
			a.items[i].cmd,
			a.items[i].sarg,
			a.items[i].iarg0,
			a.items[i].iarg1,
			a.items[i].iarg2) < 0)
			rc = -1;
	}

	return rc;
}

matchkey(k: int, key: string): int
{
	kn: string;

	if(key == "")
		return 0;

	#
	# Single-character keys are matched case-insensitively.
	#
	if(len key == 1)
		return samechar(k, key);

	#
	# Symbolic keys are matched through Icurses->keyname().
	# This keeps the action layer future-proof for names such as:
	#   Left, Right, Enter, Esc, Space, F1, Ctrl-X, Alt-A ...
	# once the backend/keyname layer supports them.
	#
	kn = ic->keyname(k);

	if(kn == key)
		return 1;

	if(lower(kn) == lower(key))
		return 1;

	return 0;
}

findkey(a: ref IcActions->Actions, k: int): int
{
	i: int;

	if(a == nil || a.items == nil)
		return -1;

	for(i = len a.items - 1; i >= 0; i--){
		if(matchkey(k, a.items[i].key))
			return i;
	}

	return -1;
}

findcmd(a: ref IcActions->Actions, cmd: string): int
{
	i: int;

	if(a == nil || a.items == nil || cmd == "")
		return -1;

	for(i = 0; i < len a.items; i++){
		if(a.items[i].cmd == cmd)
			return i;
	}

	return -1;
}

message(a: ref IcActions->Actions, index: int): IcMsg->Msg
{
	m: IcMsg->Msg;
	it: IcActions->Action;
	src: int;

	if(a == nil || a.items == nil)
		return msg->none();

	if(index < 0 || index >= len a.items)
		return msg->none();

	it = a.items[index];

	src = a.id;
	if(src == IcMsg->MsgNoNode)
		src = IcMsg->MsgNoNode;

	m = msg->newmsg(src, it.target, IcMsg->KindCommand, it.cmd);
	m.sarg = it.sarg;
	m.iarg0 = it.iarg0;
	m.iarg1 = it.iarg1;
	m.iarg2 = it.iarg2;

	return m;
}

handleui(u: ref IcUi->Ui, k: int): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(u == nil)
		return msg->none();

	#
	# Space is a common focused-control activation key.
	# IcUi currently confirms on Enter/Return, so IcActions maps Space
	# to Enter as a focused-control fallback.
	#
	if(k == ' '){
		m = ui->handlekey(u, '\n');
		if(m.kind != IcMsg->KindNone)
			return m;
	}

	return ui->handlekey(u, k);
}

handlekey(u: ref IcUi->Ui, a: ref IcActions->Actions, k: int): IcMsg->Msg
{
	i: int;
	m: IcMsg->Msg;

	if(a == nil)
		return handleui(u, k);

	#
	# Explicit app actions win over generic Ui handling.
	# Do not bind the same actions into u.keymap if using this function
	# as the primary input path, otherwise focused controls may be hidden
	# by global keymap bindings.
	#
	i = findkey(a, k);
	if(i >= 0){
		m = message(a, i);

		if(u != nil)
			m = ui->dispatch(u, m);

		a.last = m;
		return m;
	}

	m = handleui(u, k);
	a.last = m;

	return m;
}

iscmd(m: IcMsg->Msg, cmd: string): int
{
	if(m.kind == IcMsg->KindNone)
		return 0;

	if(m.cmd == cmd)
		return 1;

	return 0;
}

isnone(m: IcMsg->Msg): int
{
	return m.kind == IcMsg->KindNone;
}

keyhelp(a: ref IcActions->Actions): string
{
	i: int;
	s, part: string;

	if(a == nil || a.items == nil)
		return "";

	s = "";

	for(i = 0; i < len a.items; i++){
		part = a.items[i].key;

		if(a.items[i].label != "")
			part += " " + a.items[i].label;
		else
			part += " " + a.items[i].cmd;

		if(s != "")
			s += " | ";

		s += part;
	}

	return s;
}

summary(m: IcMsg->Msg): string
{
	s: string;

	if(m.kind == IcMsg->KindNone)
		return "none";

	s = "cmd=" +
		m.cmd +
		" src=" +
		sys->sprint("%d", m.src) +
		" dst=" +
		sys->sprint("%d", m.dst) +
		" handled=" +
		sys->sprint("%d", m.handled);

	if(m.sarg != "")
		s += " sarg=" + m.sarg;

	s += " i0=" +
		sys->sprint("%d", m.iarg0) +
		" i1=" +
		sys->sprint("%d", m.iarg1) +
		" i2=" +
		sys->sprint("%d", m.iarg2);

	return s;
}