implement Icurses;

include "icurses/icurses.m";

sys: Sys;

kbd: ref Sys->FD;
consctl: ref Sys->FD;
kbuf: array of byte;
ks: string;
ki: int;
kn: int;

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

keyname(k: int): string
{
	if(k == Khome) return "Home";
	if(k == Kend) return "End";
	if(k == Kup) return "Up";
	if(k == Kdown) return "Down";
	if(k == Kleft) return "Left";
	if(k == Kright) return "Right";
	if(k == Kpgup) return "PgUp";
	if(k == Kpgdown) return "PgDown";
	if(k == Kbacktab) return "Shift-Tab";
	if(k == Kins) return "Ins";
	if(k == Kdel) return "Del";
	if(k == 9) return "Tab";
	if(k == 10) return "Enter";
	if(k == 13) return "CR";
	if(k == 27) return "Esc";
	if(k == 'q') return "q";
	if(k == 'Q') return "Q";
	return sys->sprint("%d", k);
}

stepok(done: int): StepCtl
{
	ctl: StepCtl;

	ctl.rc = 0;
	ctl.done = done;
	return ctl;
}

steperr(): StepCtl
{
	ctl: StepCtl;

	ctl.rc = -1;
	ctl.done = 0;
	return ctl;
}

isconfirm(k: int): int
{
	return k == 10 || k == 13;
}

iscancel(k: int): int
{
	return k == 27 || k == 'q' || k == 'Q';
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