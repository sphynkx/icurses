implement IcTheme;

include "icurses/theme.m";

init()
{
}

sgr(scheme, attr: int): string
{
	if(attr == AttrFrame){
		if(scheme == 0) return "37;44";
		if(scheme == 1) return "30;46";
		if(scheme == 2) return "30;47";
		return "33;44";
	}
	if(attr == AttrTitle){
		if(scheme == 0) return "97;44";
		if(scheme == 1) return "34;46;1";
		if(scheme == 2) return "34;47;1";
		return "97;44";
	}
	if(attr == AttrWindow){
		if(scheme == 0) return "37;40";
		if(scheme == 1) return "30;40";
		if(scheme == 2) return "30;47";
		return "37;40";
	}
	if(attr == AttrLabel){
		if(scheme == 2) return "34;47;1";
		return "92;40";
	}
	if(attr == AttrButton)
		return "30;47";
	if(attr == AttrFocus){
		if(scheme == 2) return "30;103";
		return "30;102";
	}
	if(attr == AttrShadow)
		return "30;1";
	if(attr == AttrStatus)
		return "30;103";
	return "0";
}