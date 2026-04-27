implement IcGlyph;

include "icurses/glyph.m";

_profile: int;

init(ci: Icurses->ConsInfo)
{
	#
	# Default to Unicode when /dev/consinfo is available.
	# This preserves the current good-looking terminal rendering.
	#
	_profile = ProfileUnicode;

	#
	# If consinfo is missing entirely, use the safest fallback.
	#
	if(ci.ok == 0)
		_profile = ProfileAscii;

	#
	# Explicit source names can force ASCII fallback.
	# These names are intentionally simple and backend-independent.
	#
	if(ci.source == "ascii" || ci.source == "dumb")
		_profile = ProfileAscii;
}

profile(): int
{
	return _profile;
}

frame(style: int): Frame
{
	f: Frame;

	if(_profile == ProfileUnicode){
		if(style == StyleDouble){
			f.h = "═";
			f.v = "║";
			f.nw = "╔";
			f.ne = "╗";
			f.sw = "╚";
			f.se = "╝";
			return f;
		}

		if(style == StyleSingle){
			f.h = "─";
			f.v = "│";
			f.nw = "┌";
			f.ne = "┐";
			f.sw = "└";
			f.se = "┘";
			return f;
		}
	}

	#
	# ASCII fallback. Also used for StyleAscii explicitly.
	#
	f.h = "-";
	f.v = "|";
	f.nw = "+";
	f.ne = "+";
	f.sw = "+";
	f.se = "+";

	return f;
}