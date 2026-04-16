IcTheme: module
{
	PATH: con "/dis/lib/icurses/theme.dis";

	AttrNone:   con 0;
	AttrFrame:  con 1;
	AttrTitle:  con 2;
	AttrWindow: con 3;
	AttrLabel:  con 4;
	AttrButton: con 5;
	AttrFocus:  con 6;
	AttrShadow: con 7;
	AttrStatus: con 8;

	init: fn();
	sgr: fn(scheme, attr: int): string;
};