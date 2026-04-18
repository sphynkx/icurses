implement IcDialog;

include "icurses/dialog.m";

centerx(x, w: int, s: string): int
{
	col: int;

	col = x + (w - len s) / 2;
	if(col < x)
		col = x;
	return col;
}

init()
{
}

new(x, y, w, h: int, title, msg1, msg2, msg3, msg4: string): ref IcDialog->Dialog
{
	d: ref IcDialog->Dialog;

	d = ref IcDialog->Dialog;
	d.x = x;
	d.y = y;
	d.w = w;
	d.h = h;

	d.title = title;
	d.msg1 = msg1;
	d.msg2 = msg2;
	d.msg3 = msg3;
	d.msg4 = msg4;

	reset(d);
	return d;
}

reset(d: ref IcDialog->Dialog)
{
	if(d == nil)
		return;

	d.focus = IcDialog->BtnOK;
	d.selected = -1;
}

x(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.x;
}

y(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.y;
}

w(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.w;
}

h(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.h;
}

contentx(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.x + 3;
}

buttony(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;
	return d.y + d.h - 3;
}

nextfocus(d: ref IcDialog->Dialog)
{
	if(d == nil)
		return;

	d.focus = d.focus + 1;
	if(d.focus > IcDialog->BtnHelp)
		d.focus = IcDialog->BtnOK;
}

prevfocus(d: ref IcDialog->Dialog)
{
	if(d == nil)
		return;

	d.focus = d.focus - 1;
	if(d.focus < IcDialog->BtnOK)
		d.focus = IcDialog->BtnHelp;
}

focusfirst(d: ref IcDialog->Dialog)
{
	if(d == nil)
		return;

	d.focus = IcDialog->BtnOK;
}

focuslast(d: ref IcDialog->Dialog)
{
	if(d == nil)
		return;

	d.focus = IcDialog->BtnHelp;
}

focused(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return -1;

	return d.focus;
}

isfocused(d: ref IcDialog->Dialog, btn: int): int
{
	if(d == nil)
		return 0;

	return d.focus == btn;
}

titletext(d: ref IcDialog->Dialog): string
{
	if(d == nil)
		return "";

	return d.title;
}

titlex(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;

	return centerx(d.x, d.w, d.title);
}

titley(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return 0;

	return d.y;
}

linecount(): int
{
	return 4;
}

lineat(d: ref IcDialog->Dialog, i: int): string
{
	if(d == nil)
		return "";

	if(i == 0)
		return d.msg1;
	if(i == 1)
		return d.msg2;
	if(i == 2)
		return d.msg3;
	if(i == 3)
		return d.msg4;

	return "";
}

liney(d: ref IcDialog->Dialog, i: int): int
{
	if(d == nil)
		return 0;

	return d.y + 2 + i;
}

buttoncount(): int
{
	return 3;
}

buttonat(i: int): int
{
	if(i == 0)
		return BtnOK;
	if(i == 1)
		return BtnCancel;
	if(i == 2)
		return BtnHelp;
	return -1;
}

buttonlabel(btn: int): string
{
	if(btn == BtnOK)
		return "OK";
	if(btn == BtnCancel)
		return "Cancel";
	if(btn == BtnHelp)
		return "Help";
	return "";
}

buttonx(d: ref IcDialog->Dialog, btn: int): int
{
	if(d == nil)
		return 0;

	if(btn == BtnOK)
		return d.x + 5;
	if(btn == BtnCancel)
		return d.x + 17;
	if(btn == BtnHelp)
		return d.x + 32;

	return d.x;
}

navigate(d: ref IcDialog->Dialog, nav: int): int
{
	if(d == nil)
		return 0;

	if(nav == NavPrev){
		prevfocus(d);
		return 1;
	}

	if(nav == NavNext){
		nextfocus(d);
		return 1;
	}

	if(nav == NavFirst){
		focusfirst(d);
		return 1;
	}

	if(nav == NavLast){
		focuslast(d);
		return 1;
	}

	return 0;
}

select(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return -1;

	d.selected = d.focus;
	return d.selected;
}

cancel(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return -1;

	d.selected = BtnCancel;
	return d.selected;
}

selected(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return -1;

	return d.selected;
}

isselected(d: ref IcDialog->Dialog, btn: int): int
{
	if(d == nil)
		return 0;

	return d.selected == btn;
}

selectedlabel(d: ref IcDialog->Dialog): string
{
	if(d == nil)
		return "";

	return buttonlabel(d.selected);
}

activate(d: ref IcDialog->Dialog): string
{
	if(d == nil)
		return "";

	select(d);
	return selectedlabel(d);
}

finish(d: ref IcDialog->Dialog, cancelit: int): string
{
	if(d == nil)
		return "";

	if(cancelit)
		cancel(d);
	else
		select(d);

	return selectedlabel(d);
}

step(d: ref IcDialog->Dialog, act: int): Step
{
	s: Step;

	s.done = 0;
	s.code = -1;
	s.label = "";
	s.status = "";

	if(d == nil){
		s.status = "Dialog unavailable";
		return s;
	}

	if(act == ActNavPrev){
		prevfocus(d);
		s.status = "Focus moved backward";
		return s;
	}

	if(act == ActNavNext){
		nextfocus(d);
		s.status = "Focus moved forward";
		return s;
	}

	if(act == ActNavFirst){
		focusfirst(d);
		s.status = "Focus moved to first";
		return s;
	}

	if(act == ActNavLast){
		focuslast(d);
		s.status = "Focus moved to last";
		return s;
	}

	if(act == ActConfirm){
		s.code = select(d);
		s.label = selectedlabel(d);
		s.status = "Selection complete";
		s.done = 1;
		return s;
	}

	if(act == ActCancel){
		s.code = cancel(d);
		s.label = selectedlabel(d);
		s.status = "Canceled";
		s.done = 1;
		return s;
	}

	s.status = "No action";
	return s;
}