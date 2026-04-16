implement IcInput;

include "sys.m";
	sys: Sys;
include "icurses/input.m";

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

open(): ref IcInput->Input
{
	in := ref IcInput->Input;

	in.fd = sys->open("/dev/ekeyboard", Sys->OREAD);
	if(in.fd == nil)
		raise "fail: cannot open /dev/ekeyboard";

	in.buf = array[64] of byte;
	in.s = "";
	in.i = 0;
	in.n = 0;

	return in;
}

readkey(in: ref IcInput->Input): int
{
	if(in == nil)
		return -1;

	for(;;){
		if(in.i < len in.s){
			k := int in.s[in.i];
			in.i++;
			return k;
		}

		in.n = sys->read(in.fd, in.buf, len in.buf);
		if(in.n <= 0)
			return -1;

		in.s = string in.buf[0:in.n];
		in.i = 0;
	}
}