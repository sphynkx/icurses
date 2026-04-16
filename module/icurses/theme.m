IcTheme: module
{
	PATH: con "/dis/lib/icurses/theme.dis";

	AttrNone,
	AttrFrame,
	AttrTitle,
	AttrWindow,
	AttrLabel,
	AttrButton,
	AttrFocus,
	AttrShadow,
	AttrStatus: con iota;

	init: fn();
	sgr: fn(scheme, attr: int): string;
};