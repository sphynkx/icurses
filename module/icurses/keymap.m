include "icurses/msg.m";

IcKeymap: module
{
	PATH: con "/dis/lib/icurses/keymap.dis";

	Binding: adt
	{
		key:    string;
		target: string;
		cmd:    string;

		sarg:   string;
		iarg0:  int;
		iarg1:  int;
		iarg2:  int;
	};

	Keymap: adt
	{
		bindings: array of Binding;
	};

	init: fn();

	new: fn(): ref Keymap;

	bind: fn(km: ref Keymap, key, target, cmd: string): int;
	bindargs: fn(km: ref Keymap, key, target, cmd, sarg: string, iarg0, iarg1, iarg2: int): int;

	find: fn(km: ref Keymap, k: int): IcMsg->Msg;
};