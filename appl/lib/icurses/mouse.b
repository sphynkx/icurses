implement IcMouse;

include "icurses/mouse.m";

sys: Sys;

mousefd: ref Sys->FD;
buf: array of byte;
pending: string;
lastbuttons: int;

skipspace: fn(s: string, i: int): int;
parseintat: fn(s: string, i: int): (int, int, int);
appendname: fn(s, name: string): string;
readline: fn(): string;
empty: fn(): Event;
marktransition: fn(e: Event): Event;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	mousefd = nil;
	buf = array[128] of byte;
	pending = "";
	lastbuttons = 0;
}

open(): int
{
	if(mousefd != nil)
		return 0;

	mousefd = sys->open(MousePath, Sys->OREAD);
	if(mousefd == nil)
		return -1;

	pending = "";
	lastbuttons = 0;
	return 0;
}

close()
{
	mousefd = nil;
	pending = "";
	lastbuttons = 0;
}

empty(): Event
{
	e: Event;

	e.x = 0;
	e.y = 0;
	e.buttons = 0;
	e.mods = 0;

	e.kind = KindNone;
	e.changed = 0;
	e.pressed = 0;
	e.released = 0;

	e.ok = 0;
	e.raw = "";

	return e;
}

skipspace(s: string, i: int): int
{
	while(i < len s){
		if(s[i] != ' ' && s[i] != '\t' && s[i] != '\n' && s[i] != '\r')
			break;
		i++;
	}

	return i;
}

parseintat(s: string, i: int): (int, int, int)
{
	sign, v, ok: int;

	i = skipspace(s, i);

	sign = 1;
	if(i < len s && s[i] == '-'){
		sign = -1;
		i++;
	}

	v = 0;
	ok = 0;

	while(i < len s){
		if(s[i] < '0' || s[i] > '9')
			break;

		v = v * 10 + s[i] - '0';
		ok = 1;
		i++;
	}

	return (v * sign, i, ok);
}

parse(s: string): Event
{
	e: Event;
	i, ok: int;

	e = empty();
	e.raw = s;

	i = skipspace(s, 0);

	if(i >= len s)
		return e;

	if(s[i] != 'm')
		return e;

	i++;

	(e.x, i, ok) = parseintat(s, i);
	if(!ok)
		return e;

	(e.y, i, ok) = parseintat(s, i);
	if(!ok)
		return e;

	(e.buttons, i, ok) = parseintat(s, i);
	if(!ok)
		return e;

	(e.mods, i, ok) = parseintat(s, i);
	if(!ok)
		return e;

	e.ok = 1;
	e.kind = KindMove;
	return e;
}

marktransition(e: Event): Event
{
	buttons, changed: int;

	if(!e.ok)
		return e;

	if(e.buttons & WheelMask){
		e.kind = KindWheel;
		e.changed = e.buttons & WheelMask;
		e.pressed = e.buttons & WheelMask;
		e.released = 0;
		return e;
	}

	buttons = e.buttons & ButtonMask;
	changed = buttons ^ lastbuttons;

	e.changed = changed;
	e.pressed = buttons & changed;
	e.released = lastbuttons & changed;

	if(changed == 0){
		if(buttons != 0)
			e.kind = KindDrag;
		else
			e.kind = KindMove;
	}else if(e.pressed != 0 && e.released == 0)
		e.kind = KindPress;
	else if(e.released != 0 && e.pressed == 0)
		e.kind = KindRelease;
	else
		e.kind = KindChange;

	lastbuttons = buttons;
	return e;
}

readline(): string
{
	n, i: int;
	s, line: string;

	for(;;){
		for(i = 0; i < len pending; i++){
			if(pending[i] == '\n'){
				line = pending[0:i];
				pending = pending[i + 1:];
				return line;
			}
		}

		if(mousefd == nil)
			return "";

		n = sys->read(mousefd, buf, len buf);
		if(n <= 0)
			return "";

		s = string buf[0:n];
		pending += s;
	}
}

read(): Event
{
	line: string;
	e: Event;

	for(;;){
		line = readline();
		if(line == "")
			return empty();

		e = parse(line);
		if(e.ok)
			return marktransition(e);
	}
}

appendname(s, name: string): string
{
	if(s == "")
		return name;

	return s + "+" + name;
}

buttons(e: Event): string
{
	s: string;

	s = "";

	if(e.buttons & ButtonLeft)
		s = appendname(s, "left");

	if(e.buttons & ButtonMiddle)
		s = appendname(s, "middle");

	if(e.buttons & ButtonRight)
		s = appendname(s, "right");

	if(e.buttons & ButtonWheelUp)
		s = appendname(s, "wheel-up");

	if(e.buttons & ButtonWheelDown)
		s = appendname(s, "wheel-down");

	if(s == "")
		s = "none";

	return s;
}

mods(e: Event): string
{
	s: string;

	s = "";

	if(e.mods & ModShift)
		s = appendname(s, "shift");

	if(e.mods & ModCtrl)
		s = appendname(s, "ctrl");

	if(e.mods & ModAlt)
		s = appendname(s, "alt");

	if(s == "")
		s = "none";

	return s;
}

kind(e: Event): string
{
	if(e.kind == KindMove)
		return "move";

	if(e.kind == KindPress)
		return "press";

	if(e.kind == KindRelease)
		return "release";

	if(e.kind == KindDrag)
		return "drag";

	if(e.kind == KindWheel)
		return "wheel";

	if(e.kind == KindChange)
		return "change";

	return "none";
}

hasbutton(e: Event, b: int): int
{
	return (e.buttons & b) != 0;
}

hasmod(e: Event, m: int): int
{
	return (e.mods & m) != 0;
}

inside(e: Event, x, y, w, h: int): int
{
	if(w <= 0 || h <= 0)
		return 0;

	if(e.x < x)
		return 0;

	if(e.y < y)
		return 0;

	if(e.x >= x + w)
		return 0;

	if(e.y >= y + h)
		return 0;

	return 1;
}