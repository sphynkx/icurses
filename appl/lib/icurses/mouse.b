implement IcMouse;

include "sys.m";
include "icurses/mouse.m";

sys: Sys;

mousefd: ref Sys->FD;
buf: array of byte;

last: IcMouse->Event;
lastok: int;

parseintat: fn(s: string, i: int): (int, int, int);
classify: fn(e: IcMouse->Event): IcMouse->Event;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	mousefd = nil;
	buf = array[128] of byte;

	last = none();
	lastok = 0;
}

open(): int
{
	if(mousefd != nil)
		return 0;

	mousefd = sys->open(IcMouse->MousePath, Sys->OREAD);
	if(mousefd == nil)
		return -1;

	last = none();
	lastok = 0;

	return 0;
}

close()
{
	mousefd = nil;
	last = none();
	lastok = 0;
}

isopen(): int
{
	return mousefd != nil;
}

none(): IcMouse->Event
{
	e: IcMouse->Event;

	e.x = 0;
	e.y = 0;
	e.buttons = 0;
	e.lastbuttons = 0;
	e.mods = 0;

	e.dx = 0;
	e.dy = 0;

	e.kind = IcMouse->KindNone;

	return e;
}

parseintat(s: string, i: int): (int, int, int)
{
	sign, v, c, ok: int;

	while(i < len s && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
		i++;

	sign = 1;

	if(i < len s && s[i] == '-'){
		sign = -1;
		i++;
	}

	v = 0;
	ok = 0;

	while(i < len s){
		c = int s[i];

		if(c < '0' || c > '9')
			break;

		v = v * 10 + c - '0';
		ok = 1;
		i++;
	}

	if(!ok)
		return (0, i, 0);

	return (sign * v, i, 1);
}

classify(e: IcMouse->Event): IcMouse->Event
{
	oldbuttons: int;

	if(!lastok){
		e.lastbuttons = 0;
		e.dx = 0;
		e.dy = 0;

		if(e.buttons != 0)
			e.kind = IcMouse->KindDown;
		else
			e.kind = IcMouse->KindMove;

		last = e;
		lastok = 1;
		return e;
	}

	oldbuttons = last.buttons;

	e.lastbuttons = oldbuttons;
	e.dx = e.x - last.x;
	e.dy = e.y - last.y;

	if(e.buttons != oldbuttons){
		if(oldbuttons == 0 && e.buttons != 0)
			e.kind = IcMouse->KindDown;
		else if(oldbuttons != 0 && e.buttons == 0)
			e.kind = IcMouse->KindUp;
		else
			e.kind = IcMouse->KindButton;
	}
	else if(e.buttons != 0 && (e.dx != 0 || e.dy != 0))
		e.kind = IcMouse->KindDrag;
	else if(e.dx != 0 || e.dy != 0)
		e.kind = IcMouse->KindMove;
	else
		e.kind = IcMouse->KindMove;

	last = e;
	lastok = 1;

	return e;
}

parse(s: string): IcMouse->Event
{
	e: IcMouse->Event;
	i, ok: int;

	e = none();

	if(s == "" || len s < 2)
		return e;

	if(s[0] != 'm')
		return e;

	i = 1;

	(e.x, i, ok) = parseintat(s, i);
	if(!ok)
		return none();

	(e.y, i, ok) = parseintat(s, i);
	if(!ok)
		return none();

	(e.buttons, i, ok) = parseintat(s, i);
	if(!ok)
		return none();

	(e.mods, i, ok) = parseintat(s, i);
	if(!ok)
		e.mods = 0;

	e = classify(e);

	return e;
}

read(): IcMouse->Event
{
	n: int;
	s: string;

	if(mousefd == nil)
		return none();

	n = sys->read(mousefd, buf, len buf);
	if(n <= 0)
		return none();

	s = string buf[0:n];

	return parse(s);
}

kindname(kind: int): string
{
	if(kind == IcMouse->KindMove)
		return "move";

	if(kind == IcMouse->KindDown)
		return "down";

	if(kind == IcMouse->KindUp)
		return "up";

	if(kind == IcMouse->KindDrag)
		return "drag";

	if(kind == IcMouse->KindButton)
		return "button";

	return "none";
}

buttondown(e: IcMouse->Event, button: int): int
{
	return (e.buttons & button) != 0 && (e.lastbuttons & button) == 0;
}

buttonup(e: IcMouse->Event, button: int): int
{
	return (e.buttons & button) == 0 && (e.lastbuttons & button) != 0;
}

pressed(e: IcMouse->Event, button: int): int
{
	return (e.buttons & button) != 0;
}

shift(e: IcMouse->Event): int
{
	return (e.mods & IcMouse->ModShift) != 0;
}

ctrl(e: IcMouse->Event): int
{
	return (e.mods & IcMouse->ModCtrl) != 0;
}

altmod(e: IcMouse->Event): int
{
	return (e.mods & IcMouse->ModAlt) != 0;
}

summary(e: IcMouse->Event): string
{
	if(e.kind == IcMouse->KindNone)
		return "mouse none";

	return "mouse " +
		kindname(e.kind) +
		" x=" +
		sys->sprint("%d", e.x) +
		" y=" +
		sys->sprint("%d", e.y) +
		" buttons=" +
		sys->sprint("%d", e.buttons) +
		" last=" +
		sys->sprint("%d", e.lastbuttons) +
		" mods=" +
		sys->sprint("%d", e.mods) +
		" dx=" +
		sys->sprint("%d", e.dx) +
		" dy=" +
		sys->sprint("%d", e.dy);
}