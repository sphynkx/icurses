IcRect: module
{
	PATH: con "/dis/lib/icurses/rect.dis";

	Rect: adt
	{
		x: int;
		y: int;
		w: int;
		h: int;
	};

	mk: fn(x, y, w, h: int): Rect;
	empty: fn(r: Rect): int;
	contains: fn(r: Rect, x, y: int): int;
	intersect: fn(a, b: Rect): Rect;
	inset: fn(r: Rect, dx, dy: int): Rect;
	move: fn(r: Rect, dx, dy: int): Rect;
};