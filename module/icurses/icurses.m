include "sys.m";

Icurses: module
{
	PATH: con "/dis/lib/icurses/icurses.dis";

	KeyboardPath: con "/dev/ekeyboard";
	ConsctlPath:  con "/dev/consctl";
	ConsinfoPath: con "/dev/consinfo";

	DefaultCols: con 80;
	DefaultRows: con 24;

	Kcapslock:   con 57348;
	Knumlock:    con 57349;

	Khome:       con 57360;
	Kend:        con 57361;
	Kup:         con 57362;
	Kdown:       con 57363;
	Kleft:       con 57364;
	Kright:      con 57365;
	Kpgup:       con 57366;
	Kpgdown:     con 57367;
	Kbacktab:    con 57368;

	Kf1:         con 57409;
	Kf2:         con 57410;
	Kf3:         con 57411;
	Kf4:         con 57412;
	Kf5:         con 57413;
	Kf6:         con 57414;
	Kf7:         con 57415;
	Kf8:         con 57416;
	Kf9:         con 57417;
	Kf10:        con 57418;
	Kf11:        con 57419;
	Kf12:        con 57420;

	Kscrolllock:  con 57442;
	Kins:         con 57443;
	Kdel:         con 57444;
	Kctrlnumlock: con 57446;

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

	#
	# Parsed /dev/consinfo data.
	#
	# The first line of /dev/consinfo is expected to be:
	#   "<cols> <rows>"
	#
	# Additional key=value lines are optional. Missing fields keep
	# conservative fallback values.
	#
	ConsInfo: adt
	{
		cols:       int;
		rows:       int;

		buffercols: int;
		bufferrows: int;

		left:       int;
		top:        int;
		right:      int;
		bottom:     int;

		cursorx:    int;
		cursory:    int;

		colors:     int;
		truecolor:  int;
		utf8:       int;
		vt:         int;

		ok:         int;
		source:     string;
		raw:        string;
	};

	init: fn();

	openkbd: fn(): int;
	closekbd: fn();
	readkey: fn(): int;
	keyname: fn(k: int): string;

	#
	# Read and parse /dev/consinfo.
	# Returns fallback DefaultCols x DefaultRows when unavailable.
	#
	consinfo: fn(): ConsInfo;

	#
	# Convenience wrapper around consinfo().
	# Returns: (cols, rows).
	#
	termsize: fn(): (int, int);

	stepok: fn(done: int): StepCtl;
	steperr: fn(): StepCtl;

	isconfirm: fn(k: int): int;
	navkind: fn(k: int): int;

	cleartty: fn(out: ref Sys->FD);
	resettty: fn(out: ref Sys->FD);
	hidecursor: fn(out: ref Sys->FD);
	showcursor: fn(out: ref Sys->FD);
	cup: fn(out: ref Sys->FD, row, col: int);
	sgr: fn(out: ref Sys->FD, code: string);
	emitrun: fn(out: ref Sys->FD, row, col: int, code, text: string);
};