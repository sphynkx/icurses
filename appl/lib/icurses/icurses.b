implement Icurses;

include "icurses/icurses.m";

sys: Sys;

kbd: ref Sys->FD;
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
	kbuf = array[64] of byte;
	ks = "";
	ki = 0;
	kn = 0;
}

openkbd(): int
{
	kbd = sys->open(KeyboardPath, Sys->OREAD);
	if(kbd == nil)
		return -1;

	ks = "";
	ki = 0;
	kn = 0;
	return 0;
}

closekbd()
{
	kbd = nil;
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