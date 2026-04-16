implement IcTheme;

include "icurses/theme.m";

init()
{
}

sgr(scheme, attr: int): string
{
	if(attr == IcTheme->AttrFrame)  return "1;37;44";
	if(attr == IcTheme->AttrTitle)  return "1;33;44";
	if(attr == IcTheme->AttrWindow) return "0;37;44";
	if(attr == IcTheme->AttrLabel)  return "1;37;44";
	if(attr == IcTheme->AttrButton) return "1;30;46";
	if(attr == IcTheme->AttrFocus)  return "1;33;41";
	if(attr == IcTheme->AttrShadow) return "0;30;40";
	if(attr == IcTheme->AttrStatus) return "1;30;47";

	return "0";
}