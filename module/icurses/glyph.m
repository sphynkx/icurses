include "icurses/theme.m";

IcGlyph: module
{
	PATH: con "/dis/lib/icurses/glyph.dis";

	#
	# Glyph profile selected from console capabilities.
	#
	ProfileAscii:   con 0;
	ProfileUnicode: con 1;

	#
	# Frame style ids intentionally match IcPaint frame constants:
	#   IcPaint->FrameAscii  == 0
	#   IcPaint->FrameSingle == 1
	#   IcPaint->FrameDouble == 2
	#
	StyleAscii:  con 0;
	StyleSingle: con 1;
	StyleDouble: con 2;

	#
	# Box frame glyphs.
	# nw/ne/sw/se are compass names for corners:
	#   nw ---- ne
	#   |       |
	#   sw ---- se
	#
	Frame: adt
	{
		h:  string;
		v:  string;
		nw: string;
		ne: string;
		sw: string;
		se: string;
	};

	init: fn(ci: Icurses->ConsInfo);

	profile: fn(): int;

	frame: fn(style: int): Frame;
};