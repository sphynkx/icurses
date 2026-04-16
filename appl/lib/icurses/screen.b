implement IcScreen;

include "sys.m";
	sys: Sys;
include "icurses/theme.m";
include "icurses/term.m";
include "icurses/screen.m";

theme: IcTheme;
term: IcTerm;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	theme = load IcTheme IcTheme->PATH;
	if(theme == nil)
		raise "fail:load theme";
	theme->init();

	term = load IcTerm IcTerm->PATH;
	if(term == nil)
		raise "fail:load term";
	term->init();
}

strsig(s: string): int
{
	h := 0;
	for(i := 0; i < len s; i++)
		h = (h * 33) ^ int s[i];
	return h;
}

new(w, h: int): ref IcScreen->Screen
{
	scr := ref IcScreen->Screen;
	scr.w = w;
	scr.h = h;
	scr.front = array[w*h] of IcScreen->Cell;
	scr.back = array[w*h] of IcScreen->Cell;
	scr.dirty = array[w*h] of int;

	sp := strsig(" ");

	for(i := 0; i < w*h; i++){
		scr.front[i].ch = " ";
		scr.front[i].attr = IcTheme->AttrNone;
		scr.front[i].sig = sp;

		scr.back[i].ch = " ";
		scr.back[i].attr = IcTheme->AttrNone;
		scr.back[i].sig = sp;

		scr.dirty[i] = 1;
	}
	return scr;
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

markdirty(scr: ref IcScreen->Screen, x, y: int)
{
	if(!inrange(scr, x, y))
		return;
	scr.dirty[idx(scr, x, y)] = 1;
}

reset(scr: ref IcScreen->Screen)
{
	n := scr.w * scr.h;
	for(i := 0; i < n; i++){
		scr.front[i].ch = "?";
		scr.front[i].attr = -1;
		scr.front[i].sig = -1;
		scr.dirty[i] = 1;
	}
}

invalidate(scr: ref IcScreen->Screen)
{
	n := scr.w * scr.h;
	for(i := 0; i < n; i++)
		scr.dirty[i] = 1;
}

clear(scr: ref IcScreen->Screen, ch: string, attr: int)
{
	n := scr.w * scr.h;
	s := strsig(ch);
	for(i := 0; i < n; i++){
		scr.back[i].ch = ch;
		scr.back[i].attr = attr;
		scr.back[i].sig = s;
		scr.dirty[i] = 1;
	}
}

clearrect(scr: ref IcScreen->Screen, r: IcRect->Rect, ch: string, attr: int)
{
	fill(scr, r.x, r.y, r.w, r.h, ch, attr);
}

putc(scr: ref IcScreen->Screen, x, y: int, ch: string, attr: int)
{
	if(!inrange(scr, x, y))
		return;

	i := idx(scr, x, y);
	scr.back[i].ch = ch;
	scr.back[i].attr = attr;
	scr.back[i].sig = strsig(ch);
	scr.dirty[i] = 1;
}

put(scr: ref IcScreen->Screen, x, y: int, s: string, attr: int)
{
	col := x;
	for(i := 0; i < len s; ){
		c := int s[i];
		m := 1;

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
		i += m;
	}
}

text(scr: ref IcScreen->Screen, x, y: int, s: string, attr: int)
{
	col := x;
	for(i := 0; i < len s; ){
		c := int s[i];
		m := 1;

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
		i += m;
	}
}

fill(scr: ref IcScreen->Screen, x, y, w, h: int, ch: string, attr: int)
{
	for(r := 0; r < h; r++)
		for(c := 0; c < w; c++)
			putc(scr, x + c, y + r, ch, attr);
}

hline(scr: ref IcScreen->Screen, x, y, w: int, ch: string, attr: int)
{
	for(i := 0; i < w; i++)
		putc(scr, x + i, y, ch, attr);
}

vline(scr: ref IcScreen->Screen, x, y, h: int, ch: string, attr: int)
{
	for(i := 0; i < h; i++)
		putc(scr, x, y + i, ch, attr);
}

boxdouble(scr: ref IcScreen->Screen, x, y, w, h: int, attr: int)
{
	if(w < 2 || h < 2)
		return;

	putc(scr, x, y, "╔", attr);
	putc(scr, x + w - 1, y, "╗", attr);
	putc(scr, x, y + h - 1, "╚", attr);
	putc(scr, x + w - 1, y + h - 1, "╝", attr);

	hline(scr, x + 1, y, w - 2, "═", attr);
	hline(scr, x + 1, y + h - 1, w - 2, "═", attr);
	vline(scr, x, y + 1, h - 2, "║", attr);
	vline(scr, x + w - 1, y + 1, h - 2, "║", attr);
}

shadow(scr: ref IcScreen->Screen, x, y, w, h: int, attr: int)
{
	for(r := 1; r < h; r++){
		putc(scr, x + w, y + r, "▒", attr);
		putc(scr, x + w + 1, y + r, "▒", attr);
	}
	for(c := 2; c < w; c++)
		putc(scr, x + c, y + h, "▒", attr);
	for(c = 3; c < w; c++)
		putc(scr, x + c, y + h + 1, "▒", attr);
}

flush(scr: ref IcScreen->Screen, fd: ref Sys->FD, scheme: int)
{
	for(y := 0; y < scr.h; y++){
		for(x := 0; x < scr.w; x++){
			i := idx(scr, x, y);
			if(scr.dirty[i] == 0)
				continue;

			attr := scr.back[i].attr;
			x0 := x;
			x1 := x;

			for(j := x + 1; j < scr.w; j++){
				k := idx(scr, j, y);
				if(scr.dirty[k] == 0)
					break;
				if(scr.back[k].attr != attr)
					break;
				x1 = j;
			}

			buf := "";
			for(j = x0; j <= x1; j++)
				buf += scr.back[idx(scr, j, y)].ch;

			term->cup(fd, y + 1, x0 + 1);
			term->sgr(fd, theme->sgr(scheme, attr));
			sys->fprint(fd, "%s", buf);

			for(j = x0; j <= x1; j++){
				k := idx(scr, j, y);
				scr.front[k].ch = scr.back[k].ch;
				scr.front[k].attr = scr.back[k].attr;
				scr.front[k].sig = scr.back[k].sig;
				scr.dirty[k] = 0;
			}

			x = x1;
		}
	}
	term->resettty(fd);
}