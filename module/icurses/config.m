IcConfig: module
{
	PATH: con "/dis/lib/icurses/config.dis";

	OriginDefault: con 1;
	OriginUser: con 2;

	Entry: adt
	{
		section: string;
		key: string;
		value: string;
		file: string;
		origin: int;
	};

	Config: adt
	{
		entries: array of Entry;
	};

	init: fn();

	new: fn(): ref Config;
	clear: fn(c: ref Config);

	loadcfg: fn(c: ref Config, path: string, origin: int): int;
	overlay: fn(c: ref Config, path: string, origin: int): int;

	get: fn(c: ref Config, section, key: string): string;
	getfull: fn(c: ref Config, fullkey: string): string;
	getint: fn(c: ref Config, section, key: string, def: int): int;
	getbool: fn(c: ref Config, section, key: string, def: int): int;

	set: fn(c: ref Config, file, section, key, value: string): int;
	setfull: fn(c: ref Config, file, fullkey, value: string): int;
	setint: fn(c: ref Config, file, section, key: string, value: int): int;
	setbool: fn(c: ref Config, file, section, key: string, value: int): int;

	flush: fn(c: ref Config, path: string): int;

	splitfull: fn(fullkey: string): (string, string);
	fullkey: fn(section, key: string): string;
};