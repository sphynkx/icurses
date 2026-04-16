implement IcButton;

include "icurses/button.m";

init()
{
}

new(x, y: int, label: string): ref IcButton->Button
{
	b: ref IcButton->Button;

	b = ref IcButton->Button;
	b.x = x;
	b.y = y;
	b.w = len label + 4;
	b.h = 1;
	b.label = label;
	b.focused = 0;

	return b;
}

contains(b: ref IcButton->Button, x, y: int): int
{
	if(b == nil)
		return 0;

	if(x < b.x)
		return 0;
	if(x >= b.x + b.w)
		return 0;
	if(y < b.y)
		return 0;
	if(y >= b.y + b.h)
		return 0;

	return 1;
}

setfocus(b: ref IcButton->Button, focused: int)
{
	if(b == nil)
		return;
	b.focused = focused;
}