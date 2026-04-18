# WARNING
# On this target/runtime, internal helper functions in this module may crash
# if they create local heap-managed values (for example string, array, list, ref).
# Keep such allocations in exported/top-level call functions and pass the values
# into helpers as arguments instead.

implement IcText;

include "icurses/text.m";

findwrapcut: fn(s: string, start, stop, width: int): int;
nextwrapstart: fn(s: string, start, stop, cut: int): int;
countwrappedpartsrange: fn(s: string, start, stop, width: int): int;
findlineend: fn(s: string, start: int): int;

init()
{
}

padright(s: string, w: int): string
{
	t: string;

	t = s;
	while(len t < w)
		t += " ";
	if(len t > w)
		t = t[0:w];
	return t;
}

slicestr(s: string, start, width: int): string
{
	stop: int;

	if(width <= 0)
		return "";
	if(start < 0)
		start = 0;
	if(start >= len s)
		return "";

	stop = start + width;
	if(stop > len s)
		stop = len s;

	return s[start:stop];
}

linecount(s: string): int
{
	i, n: int;

	if(len s == 0)
		return 1;

	n = 1;
	for(i = 0; i < len s; i++){
		if(s[i] == '\n')
			n++;
	}
	return n;
}

splitlines(s: string): array of string
{
	lines: array of string;
	i, start, n, k: int;

	n = linecount(s);
	lines = array[n] of string;

	start = 0;
	k = 0;

	for(i = 0; i < len s; i++){
		if(s[i] == '\n'){
			lines[k] = s[start:i];
			k++;
			start = i + 1;
		}
	}

	if(k < n)
		lines[k] = s[start:len s];

	return lines;
}

findlineend(s: string, start: int): int
{
	i: int;

	for(i = start; i < len s; i++){
		if(s[i] == '\n')
			return i;
	}
	return len s;
}

findwrapcut(s: string, start, stop, width: int): int
{
	limit, i: int;

	if(width <= 0)
		return start;

	limit = start + width;
	if(limit > stop)
		limit = stop;

	if(limit >= stop)
		return stop;

	for(i = limit - 1; i > start; i--){
		if(s[i] == ' ')
			return i;
	}

	return limit;
}

nextwrapstart(s: string, start, stop, cut: int): int
{
	i: int;

	if(cut <= start)
		return start + 1;

	if(cut >= stop)
		return stop;

	i = cut;
	if(i < stop && s[i] == ' ')
		i++;

	while(i < stop){
		if(s[i] != ' ')
			break;
		i++;
	}

	return i;
}

countwrappedpartsrange(s: string, start, stop, width: int): int
{
	off, cut, n: int;

	if(width <= 0 || start >= stop)
		return 1;

	off = start;
	n = 0;

	while(off < stop){
		cut = findwrapcut(s, off, stop, width);
		n++;
		if(cut >= stop)
			break;
		off = nextwrapstart(s, off, stop, cut);
	}

	if(n == 0)
		n = 1;

	return n;
}

wrapline(s: string, width: int): array of string
{
	lines: array of string;
	off, cut, n, i: int;

	n = countwrappedpartsrange(s, 0, len s, width);
	lines = array[n] of string;

	if(width <= 0 || len s == 0){
		lines[0] = "";
		return lines;
	}

	off = 0;
	i = 0;

	while(off < len s && i < len lines){
		cut = findwrapcut(s, off, len s, width);

		if(cut >= len s){
			lines[i] = s[off:len s];
			i++;
			break;
		}

		lines[i] = s[off:cut];
		i++;
		off = nextwrapstart(s, off, len s, cut);
	}

	for(; i < len lines; i++)
		lines[i] = "";

	return lines;
}

wrapbuflines(buf: string, width: int): array of string
{
	out: array of string;
	lineend, start, total, off, cut, k: int;

	total = 0;
	start = 0;

	while(start <= len buf){
		lineend = findlineend(buf, start);
		total += countwrappedpartsrange(buf, start, lineend, width);

		if(lineend >= len buf)
			break;
		start = lineend + 1;
	}

	out = array[total] of string;

	k = 0;
	start = 0;

	while(start <= len buf){
		lineend = findlineend(buf, start);

		if(width <= 0 || start >= lineend){
			out[k] = "";
			k++;
		}else{
			off = start;
			while(off < lineend){
				cut = findwrapcut(buf, off, lineend, width);

				if(cut >= lineend){
					out[k] = buf[off:lineend];
					k++;
					break;
				}

				out[k] = buf[off:cut];
				k++;
				off = nextwrapstart(buf, off, lineend, cut);
			}
		}

		if(lineend >= len buf)
			break;
		start = lineend + 1;
	}

	return out;
}