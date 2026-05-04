implement IcKeymap;

include "icurses/keymap.m";

msg: IcMsg;

appendbinding: fn(a: array of IcKeymap->Binding, b: IcKeymap->Binding): array of IcKeymap->Binding;
matchkey: fn(k: int, key: string): int;

init()
{
	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	msg->init();
}

new(): ref IcKeymap->Keymap
{
	km: ref IcKeymap->Keymap;

	km = ref IcKeymap->Keymap;
	km.bindings = array[0] of IcKeymap->Binding;

	return km;
}

appendbinding(a: array of IcKeymap->Binding, b: IcKeymap->Binding): array of IcKeymap->Binding
{
	n, i: int;
	r: array of IcKeymap->Binding;

	if(a == nil){
		r = array[1] of IcKeymap->Binding;
		r[0] = b;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcKeymap->Binding;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = b;
	return r;
}

matchkey(k: int, key: string): int
{
	c, kk: int;

	if(key == "")
		return 0;

	c = int key[0];
	kk = k;

	if(c >= 'A' && c <= 'Z')
		c += 'a' - 'A';

	if(kk >= 'A' && kk <= 'Z')
		kk += 'a' - 'A';

	return c == kk;
}

bind(km: ref IcKeymap->Keymap, key: string, target: int, cmd: string): int
{
	return bindargs(km, key, target, cmd, "", 0, 0, 0);
}

bindargs(km: ref IcKeymap->Keymap, key: string, target: int, cmd, sarg: string, iarg0, iarg1, iarg2: int): int
{
	b: IcKeymap->Binding;
	i: int;

	if(km == nil)
		return -1;

	if(key == "" || target < 0 || cmd == "")
		return -1;

	b.key = key;
	b.target = target;
	b.cmd = cmd;
	b.sarg = sarg;
	b.iarg0 = iarg0;
	b.iarg1 = iarg1;
	b.iarg2 = iarg2;

	for(i = 0; i < len km.bindings; i++){
		if(km.bindings[i].key == key){
			km.bindings[i] = b;
			return 0;
		}
	}

	km.bindings = appendbinding(km.bindings, b);
	return 0;
}

find(km: ref IcKeymap->Keymap, k: int): IcMsg->Msg
{
	i: int;
	b: IcKeymap->Binding;
	m: IcMsg->Msg;

	if(km == nil || km.bindings == nil)
		return msg->none();

	for(i = len km.bindings - 1; i >= 0; i--){
		b = km.bindings[i];

		if(!matchkey(k, b.key))
			continue;

		m = msg->newmsg(IcMsg->MsgNoNode, b.target, IcMsg->KindCommand, b.cmd);
		m.sarg = b.sarg;
		m.iarg0 = b.iarg0;
		m.iarg1 = b.iarg1;
		m.iarg2 = b.iarg2;

		return m;
	}

	return msg->none();
}