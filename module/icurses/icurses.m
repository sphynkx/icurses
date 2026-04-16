include "sys.m";

Icurses: module
{
	PATH: con "/dis/lib/icurses/icurses.dis";

	KeyboardPath: con "/dev/ekeyboard";

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

	init: fn();

	openkbd: fn(): int;
	closekbd: fn();
	readkey: fn(): int;
};