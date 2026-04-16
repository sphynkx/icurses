implement IcTerm;

include "sys.m";
	sys: Sys;
include "icurses/term.m";

ESC: con byte 16r1B;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

cup(fd: ref Sys->FD, row, col: int)
{
	sys->fprint(fd, "%c[%d;%dH", int ESC, row, col);
}

cleartty(fd: ref Sys->FD)
{
	sys->fprint(fd, "%c[2J%c[H", int ESC, int ESC);
}

resettty(fd: ref Sys->FD)
{
	sys->fprint(fd, "%c[0m", int ESC);
}

hidecursor(fd: ref Sys->FD)
{
	sys->fprint(fd, "%c[?25l", int ESC);
}

showcursor(fd: ref Sys->FD)
{
	sys->fprint(fd, "%c[?25h", int ESC);
}

sgr(fd: ref Sys->FD, s: string)
{
	sys->fprint(fd, "%c[%sm", int ESC, s);
}

write(fd: ref Sys->FD, s: string)
{
	sys->write(fd, array of byte s, len s);
}