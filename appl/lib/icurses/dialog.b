implement IcDialog;

include "icurses/dialog.m";

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

	d.focus = IcDialog->BtnOK;
	d.selected = -1;

	return d;
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

select(d: ref IcDialog->Dialog): int
{
	if(d == nil)
		return -1;

	d.selected = d.focus;
	return d.selected;
}

selectedlabel(d: ref IcDialog->Dialog): string
{
	if(d == nil)
		return "";

	if(d.selected == IcDialog->BtnOK)
		return "OK";
	if(d.selected == IcDialog->BtnCancel)
		return "Cancel";
	if(d.selected == IcDialog->BtnHelp)
		return "Help";

	return "";
}