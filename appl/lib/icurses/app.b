implement IcApp;

include "icurses/app.m";

sys: Sys;
_appname: string;

init(name: string)
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	_appname = name;
	if(_appname == "")
		_appname = "icapp";
}

name(): string
{
	return _appname;
}

note(s: string)
{
	if(sys != nil)
		sys->print("NOTE[%s]: %s\n", _appname, s);
}

warn(s: string)
{
	if(sys != nil)
		sys->print("WARN[%s]: %s\n", _appname, s);
}

fail(s: string)
{
	if(sys != nil)
		sys->print("FAIL[%s]: %s\n", _appname, s);

	if(_appname == "")
		raise "fail:icapp";

	raise "fail:" + _appname;
}

check(ok: int, s: string): int
{
	if(!ok)
		fail(s);

	return ok;
}

stdout(): ref Sys->FD
{
	fd: ref Sys->FD;

	if(sys == nil)
		raise "fail:icapp:sys";

	fd = sys->fildes(1);
	if(fd == nil)
		fail("stdout");

	return fd;
}

stderr(): ref Sys->FD
{
	fd: ref Sys->FD;

	if(sys == nil)
		raise "fail:icapp:sys";

	fd = sys->fildes(2);
	if(fd == nil)
		fail("stderr");

	return fd;
}

requirefd(fd: ref Sys->FD, s: string): ref Sys->FD
{
	if(fd == nil)
		fail(s);

	return fd;
}

requireui(u: ref IcUi->Ui, s: string): ref IcUi->Ui
{
	if(u == nil)
		fail(s);

	return u;
}

requireactions(a: ref IcActions->Actions, s: string): ref IcActions->Actions
{
	if(a == nil)
		fail(s);

	return a;
}

status(u: ref IcUi->Ui, s: string)
{
	if(u == nil)
		return;

	u.status = s;
}

help(u: ref IcUi->Ui, s: string)
{
	if(u == nil)
		return;

	u.help = s;
}

pause(ms: int)
{
	if(sys == nil)
		return;

	if(ms > 0)
		sys->sleep(ms);
}