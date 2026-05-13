implement Icurses;

include "icurses/icurses.m";

sys: Sys;

kbd: ref Sys->FD;
consctl: ref Sys->FD;
kbuf: array of byte;
ks: string;
ki: int;
kn: int;

parseintat: fn(s: string, i: int): (int, int, int);
paramint: fn(s, key: string, def: int): int;
paramstr: fn(s, key, def: string): string;
defaultconsinfo: fn(): ConsInfo;
fkeyname: fn(k: int): string;
ctrlkeyname: fn(k: int): string;
altkeyname: fn(k: int): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	kbd = nil;
	consctl = nil;
	kbuf = array[64] of byte;
	ks = "";
	ki = 0;
	kn = 0;
}

openkbd(): int
{
	consctl = sys->open(ConsctlPath, Sys->OWRITE);
	if(consctl != nil)
		sys->fprint(consctl, "rawon");

	kbd = sys->open(KeyboardPath, Sys->OREAD);
	if(kbd == nil){
		if(consctl != nil)
			sys->fprint(consctl, "rawoff");
		consctl = nil;
		return -1;
	}

	ks = "";
	ki = 0;
	kn = 0;
	return 0;
}

closekbd()
{
	if(consctl != nil)
		sys->fprint(consctl, "rawoff");

	kbd = nil;
	consctl = nil;
	ks = "";
	ki = 0;
	kn = 0;
}

readkey(): int
{
	k: int;

	if(kbd == nil)
		return -1;

	for(;;){
		if(ki < len ks){
			k = int ks[ki];
			ki++;
			return k;
		}

		kn = sys->read(kbd, kbuf, len kbuf);
		if(kn <= 0)
			return -1;

		ks = string kbuf[0:kn];
		ki = 0;
	}
}

fkeyname(k: int): string
{
	if(k >= Kf1 && k <= Kf12)
		return "F" + sys->sprint("%d", (k - Kf1) + 1);

	return "";
}

ctrlkeyname(k: int): string
{
	b: array of byte;

	if(k == 0)
		return "Ctrl-Space";

	if(k >= 1 && k <= 26){
		b = array[1] of byte;
		b[0] = byte (k - 1 + int 'A');
		return "Ctrl-" + string b;
	}

	if(k == 127)
		return "Ctrl-Backspace";

	return "";
}

altkeyname(k: int): string
{
	case k {
	57864 =>
		return "Alt-Ctrl-Backspace";

	57865 =>
		return "Alt-Tab";

	57866 =>
		return "Alt-Enter";

	57883 =>
		return "Alt-Escape";

	57889 =>
		return "Alt-!";

	57891 =>
		return "Alt-#";

	57892 =>
		return "Alt-$";

	57893 =>
		return "Alt-%";

	57894 =>
		return "Alt-&";

	57895 =>
		return "Alt-'";

	57896 =>
		return "Alt-(";

	57897 =>
		return "Alt-)";

	57898 =>
		return "Alt-*";

	57899 =>
		return "Alt-+";

	57900 =>
		return "Alt-,";

	57901 =>
		return "Alt--";

	57902 =>
		return "Alt-.";

	57903 =>
		return "Alt-/";

	57904 =>
		return "Alt-0";
	57905 =>
		return "Alt-1";
	57906 =>
		return "Alt-2";
	57907 =>
		return "Alt-3";
	57908 =>
		return "Alt-4";
	57909 =>
		return "Alt-5";
	57910 =>
		return "Alt-6";
	57911 =>
		return "Alt-7";
	57912 =>
		return "Alt-8";
	57913 =>
		return "Alt-9";

	57915 =>
		return "Alt-;";

	57917 =>
		return "Alt-=";

	57920 =>
		return "Alt-@";

	57921 =>
		return "Alt-Shift-A";
	57922 =>
		return "Alt-Shift-B";
	57923 =>
		return "Alt-Shift-C";
	57924 =>
		return "Alt-Shift-D";
	57925 =>
		return "Alt-Shift-E";
	57926 =>
		return "Alt-Shift-F";
	57927 =>
		return "Alt-Shift-G";
	57928 =>
		return "Alt-Shift-H";
	57929 =>
		return "Alt-Shift-I";
	57930 =>
		return "Alt-Shift-J";
	57931 =>
		return "Alt-Shift-K";
	57932 =>
		return "Alt-Shift-L";
	57933 =>
		return "Alt-Shift-M";
	57934 =>
		return "Alt-Shift-N";
	57935 =>
		return "Alt-Shift-O";
	57936 =>
		return "Alt-Shift-P";
	57937 =>
		return "Alt-Shift-Q";
	57938 =>
		return "Alt-Shift-R";
	57939 =>
		return "Alt-Shift-S";
	57940 =>
		return "Alt-Shift-T";
	57941 =>
		return "Alt-Shift-U";
	57942 =>
		return "Alt-Shift-V";
	57943 =>
		return "Alt-Shift-W";
	57944 =>
		return "Alt-Shift-X";
	57945 =>
		return "Alt-Shift-Y";
	57946 =>
		return "Alt-Shift-Z";

	57947 =>
		return "Alt-[";
	57948 =>
		return "Alt-\\";
	57949 =>
		return "Alt-]";
	57950 =>
		return "Alt-^";
	57951 =>
		return "Alt-_";
	57952 =>
		return "Alt-`";

	57953 =>
		return "Alt-A";
	57954 =>
		return "Alt-B";
	57955 =>
		return "Alt-C";
	57956 =>
		return "Alt-D";
	57957 =>
		return "Alt-E";
	57958 =>
		return "Alt-F";
	57959 =>
		return "Alt-G";
	57960 =>
		return "Alt-H";
	57961 =>
		return "Alt-I";
	57962 =>
		return "Alt-J";
	57963 =>
		return "Alt-K";
	57964 =>
		return "Alt-L";
	57965 =>
		return "Alt-M";
	57966 =>
		return "Alt-N";
	57967 =>
		return "Alt-O";
	57968 =>
		return "Alt-P";
	57969 =>
		return "Alt-Q";
	57970 =>
		return "Alt-R";
	57971 =>
		return "Alt-S";
	57972 =>
		return "Alt-T";
	57973 =>
		return "Alt-U";
	57974 =>
		return "Alt-V";
	57975 =>
		return "Alt-W";
	57976 =>
		return "Alt-X";
	57977 =>
		return "Alt-Y";
	57978 =>
		return "Alt-Z";

	57982 =>
		return "Alt-~";

	57983 =>
		return "Alt-Backspace";
	}

	return "";
}

keyname(k: int): string
{
	n: string;

	case k {
	Kcapslock =>
		return "CapsLock";

	Knumlock =>
		return "NumLock";

	Khome =>
		return "Home";

	Kend =>
		return "End";

	Kup =>
		return "Up";

	Kdown =>
		return "Down";

	Kleft =>
		return "Left";

	Kright =>
		return "Right";

	Kpgup =>
		return "PageUp";

	Kpgdown =>
		return "PageDown";

	Kbacktab =>
		return "Shift-Tab";

	Kscrolllock =>
		return "ScrollLock";

	Kins =>
		return "Insert";

	Kdel =>
		return "Delete";

	Kctrlnumlock =>
		return "Ctrl-NumLock";

	'\n' =>
		return "Enter";

	'\r' =>
		return "Return";

	'\t' =>
		return "Tab";

	8 =>
		return "Backspace";

	27 =>
		return "Escape";

	' ' =>
		return "Space";
	}

	n = fkeyname(k);
	if(n != "")
		return n;

	n = ctrlkeyname(k);
	if(n != "")
		return n;

	n = altkeyname(k);
	if(n != "")
		return n;

	if(k >= 32 && k < 127)
		return "'" + string k + "'";

	return "key=" + string k;
}

#
# Parse a non-negative integer from s starting at index i.
# Skips whitespace before the number.
# Returns: parsed value, next index, and ok flag.
#
parseintat(s: string, i: int): (int, int, int)
{
	v, ok: int;

	v = 0;
	ok = 0;

	while(i < len s && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
		i++;

	while(i < len s && s[i] >= '0' && s[i] <= '9'){
		v = v * 10 + int s[i] - int '0';
		i++;
		ok = 1;
	}

	return (v, i, ok);
}

#
# Read integer key=value parameter from a multi-line text block.
# Returns def when key is missing or value is not numeric.
#
paramint(s, key: string, def: int): int
{
	i, j, v, ok: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		(v, j, ok) = parseintat(s, j);
		if(ok)
			return v;

		return def;
	}

	return def;
}

#
# Read string key=value parameter from a multi-line text block.
# Returns def when key is missing or value is empty.
#
paramstr(s, key, def: string): string
{
	i, j: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		while(j < len s && s[j] != '\n' && s[j] != '\r')
			j++;

		if(j > i + len prefix)
			return s[i + len prefix:j];

		return def;
	}

	return def;
}

#
# Conservative fallback terminal information.
#
defaultconsinfo(): ConsInfo
{
	ci: ConsInfo;

	ci.cols = DefaultCols;
	ci.rows = DefaultRows;

	ci.buffercols = DefaultCols;
	ci.bufferrows = DefaultRows;

	ci.left = 0;
	ci.top = 0;
	ci.right = DefaultCols - 1;
	ci.bottom = DefaultRows - 1;

	ci.cursorx = 0;
	ci.cursory = 0;

	ci.colors = 16;
	ci.truecolor = 0;
	ci.utf8 = 0;
	ci.vt = 0;

	ci.ok = 0;
	ci.source = "default";
	ci.raw = "";

	return ci;
}

#
# Read and parse /dev/consinfo.
#
# Expected minimum format:
#   120 40
#
# Optional key=value fields:
#   cols=120
#   rows=40
#   colors=16777216
#   truecolor=1
#   utf8=1
#   vt=1
#   source=mingw-console
#
# Missing fields keep safe fallback values.
#
consinfo(): ConsInfo
{
	fd: ref Sys->FD;
	buf: array of byte;
	n, i, ok, v: int;
	s: string;
	ci: ConsInfo;

	ci = defaultconsinfo();

	fd = sys->open(ConsinfoPath, Sys->OREAD);
	if(fd == nil)
		return ci;

	buf = array[1024] of byte;
	n = sys->read(fd, buf, len buf);
	if(n <= 0)
		return ci;

	s = string buf[0:n];
	ci.raw = s;

	i = 0;
	(v, i, ok) = parseintat(s, i);
	if(ok)
		ci.cols = v;
	else
		ci.cols = paramint(s, "cols", DefaultCols);

	(v, i, ok) = parseintat(s, i);
	if(ok)
		ci.rows = v;
	else
		ci.rows = paramint(s, "rows", DefaultRows);

	if(ci.cols < 1)
		ci.cols = DefaultCols;
	if(ci.rows < 1)
		ci.rows = DefaultRows;

	ci.buffercols = paramint(s, "buffercols", ci.cols);
	ci.bufferrows = paramint(s, "bufferrows", ci.rows);

	ci.left = paramint(s, "left", 0);
	ci.top = paramint(s, "top", 0);
	ci.right = paramint(s, "right", ci.cols - 1);
	ci.bottom = paramint(s, "bottom", ci.rows - 1);

	ci.cursorx = paramint(s, "cursorx", 0);
	ci.cursory = paramint(s, "cursory", 0);

	ci.colors = paramint(s, "colors", 16);
	ci.truecolor = paramint(s, "truecolor", 0);
	ci.utf8 = paramint(s, "utf8", 0);
	ci.vt = paramint(s, "vt", 0);

	ci.source = paramstr(s, "source", "unknown");
	ci.ok = 1;

	return ci;
}

termsize(): (int, int)
{
	ci: ConsInfo;

	ci = consinfo();
	return (ci.cols, ci.rows);
}

stepok(done: int): StepCtl
{
	s: StepCtl;

	s.rc = 0;
	s.done = done;
	return s;
}

steperr(): StepCtl
{
	s: StepCtl;

	s.rc = -1;
	s.done = 1;
	return s;
}

isconfirm(k: int): int
{
	if(k == '\n')
		return 1;
	if(k == '\r')
		return 1;
	return 0;
}

navkind(k: int): int
{
	if(k == Kleft) return NavLeft;
	if(k == Kright) return NavRight;
	if(k == Kup) return NavUp;
	if(k == Kdown) return NavDown;
	if(k == 9) return NavNext;
	if(k == Kbacktab) return NavPrev;
	if(k == Khome) return NavHome;
	if(k == Kend) return NavEnd;
	if(k == Kpgup) return NavPageUp;
	if(k == Kpgdown) return NavPageDown;
	return NavNone;
}

cleartty(out: ref Sys->FD)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[2J", 27);
	sys->fprint(out, "%c[H", 27);
}

resettty(out: ref Sys->FD)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[0m", 27);
}

hidecursor(out: ref Sys->FD)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[?25l", 27);
}

showcursor(out: ref Sys->FD)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[?25h", 27);
}

cup(out: ref Sys->FD, row, col: int)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[%d;%dH", 27, row, col);
}

sgr(out: ref Sys->FD, code: string)
{
	if(out == nil)
		return;
	sys->fprint(out, "%c[%sm", 27, code);
}

emitrun(out: ref Sys->FD, row, col: int, code, text: string)
{
	cup(out, row, col);
	sgr(out, code);
	sys->fprint(out, "%s", text);
}