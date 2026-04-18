implement IcScreen;

include "icurses/screen.m";

strsig: fn(s: string): int;
idx: fn(scr: ref IcScreen->Screen, x, y: int): int;
inrange: fn(scr: ref IcScreen->Screen, x, y: int): int;
markdirty: fn(scr: ref IcScreen->Screen, x, y: int);
setcell: fn(scr: ref IcScreen->Screen, x, y: int, ch: string, attr: int);
cleardirtyrows: fn(scr: ref IcScreen->Screen);

init()
{
}

strsig(s: string): int
{
	h, i: int;

	h = 0;
	for(i = 0; i < len s; i++)
		h = (h * 33) ^ int s[i];
	return h;
}

idx(scr: ref IcScreen->Screen, x, y: int): int
{
	return y * scr.w + x;
}

inrange(scr: ref IcScreen->Screen, x, y: int): int
{
	if(x < 0 || y < 0 || x >= scr.w || y >= scr.h)
		return 0;
	return 1;
}

cleardirtyrows(scr: ref IcScreen->Screen)
{
	y: int;

	for(y = 0; y < scr.h; y++){
		scr.dirtyrow[y] = 0;
		scr.dirtyx0[y] = scr.w;
		scr.dirtyx1[y] = -1;
	}
}

markdirty(scr: ref IcScreen->Screen, x, y: int)
{
	i: int;

	if(!inrange(scr, x, y))
		return;

	i = idx(scr, x, y);
	scr.dirty[i] = 1;

	scr.dirtyrow[y] = 1;
	if(x < scr.dirtyx0[y])
		scr.dirtyx0[y] = x;
	if(x > scr.dirtyx1[y])
		scr.dirtyx1[y] = x;
}

setcell(scr: ref IcScreen->Screen, x, y: int, ch: string, attr: int)
{
	i, s: int;

	if(!inrange(scr, x, y))
		return;

	i = idx(scr, x, y);
	s = strsig(ch);

	if(scr.back[i].attr == attr && scr.back[i].sig == s && scr.back[i].ch == ch)
		return;

	scr.back[i].ch = ch;
	scr.back[i].attr = attr;
	scr.back[i].sig = s;

	markdirty(scr, x, y);
}

new(w, h: int): ref IcScreen->Screen
{
	scr: ref IcScreen->Screen;
	sp, i, n: int;

	scr = ref IcScreen->Screen;
	scr.w = w;
	scr.h = h;

	n = w * h;
	scr.front = array[n] of IcScreen->Cell;
	scr.back = array[n] of IcScreen->Cell;
	scr.dirty = array[n] of int;

	scr.dirtyrow = array[h] of int;
	scr.dirtyx0 = array[h] of int;
	scr.dirtyx1 = array[h] of int;

	sp = strsig(" ");

	for(i = 0; i < n; i++){
		scr.front[i].ch = " ";
		scr.front[i].attr = 0;
		scr.front[i].sig = sp;

		scr.back[i].ch = " ";
		scr.back[i].attr = 0;
		scr.back[i].sig = sp;

		scr.dirty[i] = 1;
	}

	cleardirtyrows(scr);
	for(i = 0; i < h; i++){
		scr.dirtyrow[i] = 1;
		scr.dirtyx0[i] = 0;
		scr.dirtyx1[i] = w - 1;
	}

	return scr;
}

reset(scr: ref IcScreen->Screen)
{
	i, n, y: int;

	n = scr.w * scr.h;
	for(i = 0; i < n; i++){
		scr.front[i].ch = "?";
		scr.front[i].attr = -1;
		scr.front[i].sig = -1;
		scr.dirty[i] = 1;
	}

	for(y = 0; y < scr.h; y++){
		scr.dirtyrow[y] = 1;
		scr.dirtyx0[y] = 0;
		scr.dirtyx1[y] = scr.w - 1;
	}
}

invalidate(scr: ref IcScreen->Screen)
{
	i, n, y: int;

	n = scr.w * scr.h;
	for(i = 0; i < n; i++)
		scr.dirty[i] = 1;

	for(y = 0; y < scr.h; y++){
		scr.dirtyrow[y] = 1;
		scr.dirtyx0[y] = 0;
		scr.dirtyx1[y] = scr.w - 1;
	}
}

clear(scr: ref IcScreen->Screen, ch: string, attr: int)
{
	i, x, y, n, s: int;

	n = scr.w * scr.h;
	s = strsig(ch);

	for(i = 0; i < n; i++){
		if(scr.back[i].attr == attr && scr.back[i].sig == s && scr.back[i].ch == ch)
			continue;
		scr.back[i].ch = ch;
		scr.back[i].attr = attr;
		scr.back[i].sig = s;
		scr.dirty[i] = 1;
	}

	for(y = 0; y < scr.h; y++){
		scr.dirtyrow[y] = 1;
		scr.dirtyx0[y] = 0;
		scr.dirtyx1[y] = scr.w - 1;
	}

	# keep compiler happy in older limbo if needed
	x = 0;
	x++;
}

clearrect(scr: ref IcScreen->Screen, x, y, w, h: int, ch: string, attr: int)
{
	fill(scr, x, y, w, h, ch, attr);
}

putc(scr: ref IcScreen->Screen, x, y: int, ch: string, attr: int)
{
	setcell(scr, x, y, ch, attr);
}

put(scr: ref IcScreen->Screen, x, y: int, s: string, attr: int)
{
	col, i, c, m: int;

	col = x;
	i = 0;
	while(i < len s){
		c = int s[i];
		m = 1;

		if((c & 16r80) == 0)
			m = 1;
		else if((c & 16rE0) == 16rC0)
			m = 2;
		else if((c & 16rF0) == 16rE0)
			m = 3;
		else if((c & 16rF8) == 16rF0)
			m = 4;

		if(i + m > len s)
			m = 1;

		putc(scr, col, y, s[i:i+m], attr);
		col++;
		i = i + m;
	}
}

text(scr: ref IcScreen->Screen, x, y: int, s: string, attr: int)
{
	put(scr, x, y, s, attr);
}

fill(scr: ref IcScreen->Screen, x, y, w, h: int, ch: string, attr: int)
{
	r, c: int;

	for(r = 0; r < h; r++)
		for(c = 0; c < w; c++)
			setcell(scr, x + c, y + r, ch, attr);
}

hline(scr: ref IcScreen->Screen, x, y, w: int, ch: string, attr: int)
{
	i: int;

	for(i = 0; i < w; i++)
		setcell(scr, x + i, y, ch, attr);
}

vline(scr: ref IcScreen->Screen, x, y, h: int, ch: string, attr: int)
{
	i: int;

	for(i = 0; i < h; i++)
		setcell(scr, x, y + i, ch, attr);
}

boxdouble(scr: ref IcScreen->Screen, x, y, w, h: int, attr: int)
{
	if(w < 2 || h < 2)
		return;

	setcell(scr, x, y, "╔", attr);
	setcell(scr, x + w - 1, y, "╗", attr);
	setcell(scr, x, y + h - 1, "╚", attr);
	setcell(scr, x + w - 1, y + h - 1, "╝", attr);

	hline(scr, x + 1, y, w - 2, "═", attr);
	hline(scr, x + 1, y + h - 1, w - 2, "═", attr);
	vline(scr, x, y + 1, h - 2, "║", attr);
	vline(scr, x + w - 1, y + 1, h - 2, "║", attr);
}

shadow(scr: ref IcScreen->Screen, x, y, w, h: int, attr: int)
{
	r, c: int;

	for(r = 1; r < h; r++){
		setcell(scr, x + w, y + r, "▒", attr);
		setcell(scr, x + w + 1, y + r, "▒", attr);
	}
	for(c = 2; c < w; c++)
		setcell(scr, x + c, y + h, "▒", attr);
	for(c = 3; c < w; c++)
		setcell(scr, x + c, y + h + 1, "▒", attr);
}