include "icurses/actions.m";

IcApp: module
{
	PATH: con "/dis/lib/icurses/app.dis";

	init: fn(name: string);

	name: fn(): string;

	note: fn(s: string);
	warn: fn(s: string);
	fail: fn(s: string);

	check: fn(ok: int, s: string): int;

	stdout: fn(): ref Sys->FD;
	stderr: fn(): ref Sys->FD;

	requirefd: fn(fd: ref Sys->FD, s: string): ref Sys->FD;
	requireui: fn(u: ref IcUi->Ui, s: string): ref IcUi->Ui;
	requireactions: fn(a: ref IcActions->Actions, s: string): ref IcActions->Actions;

	status: fn(u: ref IcUi->Ui, s: string);
	help: fn(u: ref IcUi->Ui, s: string);

	pause: fn(ms: int);
};