IcInput: module
{
	PATH: con "/dis/lib/icurses/input.dis";

	Khome:     con 57360;
	Kend:      con 57361;
	Kup:       con 57362;
	Kdown:     con 57363;
	Kleft:     con 57364;
	Kright:    con 57365;
	Kpgup:     con 57366;
	Kpgdown:   con 57367;
	Kbacktab:  con 57368;
	Kins:      con 57443;
	Kdel:      con 57444;

	Input: adt
	{
		fd: ref Sys->FD;
		buf: array of byte;
		s: string;
		i: int;
		n: int;
	};

	init: fn();
	open: fn(): ref Input;
	readkey: fn(in: ref Input): int;
};