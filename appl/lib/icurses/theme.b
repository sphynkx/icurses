implement IcTheme;

include "icurses/theme.m";

_colorcount: int;
_truecolor: int;

init(ci: Icurses->ConsInfo)
{
	_colorcount = 16;
	_truecolor = 0;

	if(ci.colors > 0)
		_colorcount = ci.colors;

	if(ci.truecolor != 0)
		_truecolor = 1;
}

colors(): int
{
	return _colorcount;
}

truecolor(): int
{
	return _truecolor;
}

sgr(attr: int): string
{
	if(_truecolor){
		if(attr == AttrNormal)
			return "0";
		if(attr == AttrWindow)
			return "38;2;220;230;255;48;2;20;45;90";
		if(attr == AttrFrame)
			return "38;2;230;240;255;48;2;20;45;90";
		if(attr == AttrTitle)
			return "38;2;255;230;120;48;2;20;45;90";
		if(attr == AttrButton)
			return "38;2;10;25;35;48;2;70;210;230";
		if(attr == AttrFocus)
			return "38;2;255;240;120;48;2;170;35;45";
		if(attr == AttrStatus)
			return "38;2;20;25;30;48;2;225;225;225";
		if(attr == AttrScroll)
			return "38;2;255;220;80;48;2;20;45;90";

		#
		# Shadow is a compositing effect in paint.b:
		# Cell.ch is preserved, only Cell.code is replaced.
		#
		# Use a dark background and muted foreground so text/frames
		# remain visible but look dimmed.
		#
		if(attr == AttrShadow)
			return "38;2;120;130;150;48;2;6;14;30";

		if(attr == AttrEffectHead)
			return "38;2;220;255;220;40";
		if(attr == AttrEffectBright)
			return "38;2;100;255;140;40";
		if(attr == AttrEffectMid)
			return "38;2;0;230;80;40";
		if(attr == AttrEffectDim)
			return "38;2;0;155;50;40";
		if(attr == AttrEffectDark)
			return "38;2;0;55;18;40";

		return "0";
	}

	if(attr == AttrNormal)
		return "0";
	if(attr == AttrWindow)
		return "0;37;44";
	if(attr == AttrFrame)
		return "1;37;44";
	if(attr == AttrTitle)
		return "1;33;44";
	if(attr == AttrButton)
		return "1;30;46";
	if(attr == AttrFocus)
		return "1;33;41";
	if(attr == AttrStatus)
		return "1;30;47";
	if(attr == AttrScroll)
		return "1;33;44";

	#
	# 16-color fallback shadow.
	#
	# Important: this is still compositing shadow, not character shadow.
	# It preserves glyphs and only changes their style.
	#
	if(attr == AttrShadow)
		return "0;37;40";

	if(attr == AttrEffectHead)
		return "1;37;40";
	if(attr == AttrEffectBright)
		return "1;32;40";
	if(attr == AttrEffectMid)
		return "1;32;40";
	if(attr == AttrEffectDim)
		return "0;32;40";
	if(attr == AttrEffectDark)
		return "0;30;40";

	return "0";
}