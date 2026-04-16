implement IcRect;

include "icurses/rect.m";

mk(x, y, w, h: int): Rect
{
	r: Rect;
	r.x = x;
	r.y = y;
	r.w = w;
	r.h = h;
	return r;
}

empty(r: Rect): int
{
	if(r.w <= 0 || r.h <= 0)
		return 1;
	return 0;
}

contains(r: Rect, x, y: int): int
{
	if(x < r.x)
		return 0;
	if(y < r.y)
		return 0;
	if(x >= r.x + r.w)
		return 0;
	if(y >= r.y + r.h)
		return 0;
	return 1;
}

intersect(a, b: Rect): Rect
{
	x0 := a.x;
	if(b.x > x0)
		x0 = b.x;

	y0 := a.y;
	if(b.y > y0)
		y0 = b.y;

	x1 := a.x + a.w;
	if(b.x + b.w < x1)
		x1 = b.x + b.w;

	y1 := a.y + a.h;
	if(b.y + b.h < y1)
		y1 = b.y + b.h;

	r: Rect;

	if(x1 <= x0 || y1 <= y0){
		r.x = 0;
		r.y = 0;
		r.w = 0;
		r.h = 0;
		return r;
	}

	r.x = x0;
	r.y = y0;
	r.w = x1 - x0;
	r.h = y1 - y0;
	return r;
}

inset(r: Rect, dx, dy: int): Rect
{
	nx := r.x + dx;
	ny := r.y + dy;
	nw := r.w - 2*dx;
	nh := r.h - 2*dy;

	if(nw < 0)
		nw = 0;
	if(nh < 0)
		nh = 0;

	out: Rect;
	out.x = nx;
	out.y = ny;
	out.w = nw;
	out.h = nh;
	return out;
}

move(r: Rect, dx, dy: int): Rect
{
	out: Rect;
	out.x = r.x + dx;
	out.y = r.y + dy;
	out.w = r.w;
	out.h = r.h;
	return out;
}