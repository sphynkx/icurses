include "icurses/ui.m";

IcActions: module
{
	PATH: con "/dis/lib/icurses/actions.dis";

	Action: adt
	{
		key:    string;
		target: int;
		cmd:    string;
		label:  string;

		sarg:   string;
		iarg0:  int;
		iarg1:  int;
		iarg2:  int;
	};

	Actions: adt
	{
		id:    int;
		items: array of Action;
		last:  IcMsg->Msg;
	};

	init: fn();

	new: fn(id: int): ref Actions;
	clear: fn(a: ref Actions);

	add: fn(a: ref Actions, key: string, target: int, cmd, label: string): int;
	addargs: fn(a: ref Actions, key: string, target: int, cmd, label, sarg: string,
		iarg0, iarg1, iarg2: int): int;

	count: fn(a: ref Actions): int;

	bind: fn(u: ref IcUi->Ui, a: ref Actions): int;

	matchkey: fn(k: int, key: string): int;
	findkey: fn(a: ref Actions, k: int): int;
	findcmd: fn(a: ref Actions, cmd: string): int;

	message: fn(a: ref Actions, index: int): IcMsg->Msg;
	handlekey: fn(u: ref IcUi->Ui, a: ref Actions, k: int): IcMsg->Msg;

	iscmd: fn(m: IcMsg->Msg, cmd: string): int;
	isnone: fn(m: IcMsg->Msg): int;

	keyhelp: fn(a: ref Actions): string;
	summary: fn(m: IcMsg->Msg): string;
};