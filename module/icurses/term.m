IcTerm: module
{
	PATH: con "/dis/lib/icurses/term.dis";

	init: fn();
	cup: fn(fd: ref Sys->FD, row, col: int);
	cleartty: fn(fd: ref Sys->FD);
	resettty: fn(fd: ref Sys->FD);
	hidecursor: fn(fd: ref Sys->FD);
	showcursor: fn(fd: ref Sys->FD);
	sgr: fn(fd: ref Sys->FD, s: string);
	write: fn(fd: ref Sys->FD, s: string);
};