implement IcCanvas;

include "icurses/canvas.m";

registry: array of ref IcCanvas->Canvas;

idx: fn(c: ref IcCanvas->Canvas, x, y: int): int;
inrange: fn(c: ref IcCanvas->Canvas, x, y: int): int;
mkcell: fn(ch, code: string): IcCanvas->Cell;
appendcanvas: fn(a: array of ref IcCanvas->Canvas, c: ref IcCanvas->Canvas): array of ref IcCanvas->Canvas;
removecanvasid: fn(a: array of ref IcCanvas->Canvas, id: string): array of ref IcCanvas->Canvas;

DefaultCode: con "0";

init()
{
	registry = array[0] of ref IcCanvas->Canvas;
}

mkcell(ch, code: string): IcCanvas->Cell
{
	cell: IcCanvas->Cell;

	if(ch == "")
		ch = " ";
	if(code == "")
		code = DefaultCode;

	cell.ch = ch;
	cell.code = code;

	return cell;
}

appendcanvas(a: array of ref IcCanvas->Canvas, c: ref IcCanvas->Canvas): array of ref IcCanvas->Canvas
{
	b: array of ref IcCanvas->Canvas;
	i, n: int;

	if(a == nil){
		b = array[1] of ref IcCanvas->Canvas;
		b[0] = c;
		return b;
	}

	n = len a;
	b = array[n + 1] of ref IcCanvas->Canvas;

	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = c;
	return b;
}

removecanvasid(a: array of ref IcCanvas->Canvas, id: string): array of ref IcCanvas->Canvas
{
	b: array of ref IcCanvas->Canvas;
	i, n, k: int;

	if(a == nil || id == "")
		return a;

	n = 0;
	for(i = 0; i < len a; i++){
		if(a[i] != nil && a[i].id == id)
			continue;
		n++;
	}

	b = array[n] of ref IcCanvas->Canvas;
	k = 0;

	for(i = 0; i < len a; i++){
		if(a[i] != nil && a[i].id == id)
			continue;
		b[k++] = a[i];
	}

	return b;
}

idx(c: ref IcCanvas->Canvas, x, y: int): int
{
	return y * c.w + x;
}

inrange(c: ref IcCanvas->Canvas, x, y: int): int
{
	if(c == nil)
		return 0;
	if(x < 0 || y < 0)
		return 0;
	if(x >= c.w || y >= c.h)
		return 0;
	return 1;
}

newcanvas(id: string, w, h: int): ref IcCanvas->Canvas
{
	c: ref IcCanvas->Canvas;
	i, n: int;

	if(id == "")
		return nil;

	if(w <= 0)
		w = 1;
	if(h <= 0)
		h = 1;

	remove(id);

	c = ref IcCanvas->Canvas;
	c.id = id;
	c.w = w;
	c.h = h;

	n = w * h;
	c.cells = array[n] of IcCanvas->Cell;

	for(i = 0; i < n; i++)
		c.cells[i] = mkcell(" ", DefaultCode);

	registry = appendcanvas(registry, c);

	return c;
}

find(id: string): ref IcCanvas->Canvas
{
	i: int;

	if(id == "" || registry == nil)
		return nil;

	for(i = 0; i < len registry; i++){
		if(registry[i] != nil && registry[i].id == id)
			return registry[i];
	}

	return nil;
}

remove(id: string)
{
	if(id == "")
		return;

	registry = removecanvasid(registry, id);
}

clear(c: ref IcCanvas->Canvas, ch, code: string)
{
	i, n: int;
	cell: IcCanvas->Cell;

	if(c == nil || c.cells == nil)
		return;

	cell = mkcell(ch, code);
	n = len c.cells;

	for(i = 0; i < n; i++)
		c.cells[i] = cell;
}

fillrect(c: ref IcCanvas->Canvas, x, y, w, h: int, ch, code: string)
{
	xx, yy: int;

	if(c == nil)
		return;

	for(yy = 0; yy < h; yy++){
		for(xx = 0; xx < w; xx++)
			putc(c, x + xx, y + yy, ch, code);
	}
}

putc(c: ref IcCanvas->Canvas, x, y: int, ch, code: string)
{
	if(!inrange(c, x, y))
		return;

	c.cells[idx(c, x, y)] = mkcell(ch, code);
}

puts(c: ref IcCanvas->Canvas, x, y: int, text, code: string)
{
	i: int;

	if(c == nil || text == "")
		return;

	for(i = 0; i < len text; i++)
		putc(c, x + i, y, text[i:i+1], code);
}

w(c: ref IcCanvas->Canvas): int
{
	if(c == nil)
		return 0;
	return c.w;
}

h(c: ref IcCanvas->Canvas): int
{
	if(c == nil)
		return 0;
	return c.h;
}

cell(c: ref IcCanvas->Canvas, x, y: int): IcCanvas->Cell
{
	empty: IcCanvas->Cell;

	empty = mkcell(" ", DefaultCode);

	if(!inrange(c, x, y))
		return empty;

	return c.cells[idx(c, x, y)];
}