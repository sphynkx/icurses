include "sys.m";

Icurses: module
{
	PATH: con "/dis/lib/icurses/icurses.dis";

	KeyboardPath: con "/dev/ekeyboard";
	ConsctlPath:  con "/dev/consctl";

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

	NavNone:     con 0;
	NavPrev:     con 1;
	NavNext:     con 2;
	NavLeft:     con 3;
	NavRight:    con 4;
	NavUp:       con 5;
	NavDown:     con 6;
	NavHome:     con 7;
	NavEnd:      con 8;
	NavPageUp:   con 9;
	NavPageDown: con 10;

	Run: adt
	{
		row:	int;
		col:	int;
		code:	string;
		text:	string;
	};

	StepCtl: adt
	{
		rc:   int;
		done: int;
	};

	init: fn();

	openkbd: fn(): int;
	closekbd: fn();
	readkey: fn(): int;
	keyname: fn(k: int): string;

	stepok: fn(done: int): StepCtl;
	steperr: fn(): StepCtl;

	isconfirm: fn(k: int): int;
	iscancel: fn(k: int): int;
	navkind: fn(k: int): int;
};