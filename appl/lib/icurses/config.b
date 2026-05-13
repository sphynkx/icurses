implement IcConfig;

include "sys.m";
include "bufio.m";
include "icurses/config.m";

sys: Sys;
bufio: Bufio;

Iobuf: import bufio;

appendentry: fn(a: array of IcConfig->Entry, e: IcConfig->Entry): array of IcConfig->Entry;
findentry: fn(a: array of IcConfig->Entry, section, key, file: string): int;
findmerged: fn(a: array of IcConfig->Entry, section, key: string): int;

trimspace: fn(s: string): string;
startswith: fn(s, prefix: string): int;
endswith: fn(s, suffix: string): int;
splitkv: fn(s: string): (string, string, int);
striplinecomment: fn(s: string): string;
lower: fn(s: string): string;

parseintvalue: fn(s: string, def: int): int;
parseboolvalue: fn(s: string, def: int): int;

parsefile: fn(path: string, origin: int): array of IcConfig->Entry;
buildfileentries: fn(c: ref IcConfig->Config, path: string): array of IcConfig->Entry;
sortentries: fn(a: array of IcConfig->Entry): array of IcConfig->Entry;
entryless: fn(a, b: IcConfig->Entry): int;
swapentries: fn(a: array of IcConfig->Entry, i, j: int);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	bufio = load Bufio Bufio->PATH;
	if(bufio == nil)
		raise "fail:load bufio";
}

appendentry(a: array of IcConfig->Entry, e: IcConfig->Entry): array of IcConfig->Entry
{
	r: array of IcConfig->Entry;
	i, n: int;

	if(a == nil){
		r = array[1] of IcConfig->Entry;
		r[0] = e;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcConfig->Entry;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = e;
	return r;
}

findentry(a: array of IcConfig->Entry, section, key, file: string): int
{
	i: int;

	if(a == nil)
		return -1;

	for(i = 0; i < len a; i++){
		if(a[i].section == section && a[i].key == key && a[i].file == file)
			return i;
	}

	return -1;
}

findmerged(a: array of IcConfig->Entry, section, key: string): int
{
	i: int;

	if(a == nil)
		return -1;

	for(i = len a - 1; i >= 0; i--){
		if(a[i].section == section && a[i].key == key)
			return i;
	}

	return -1;
}

trimspace(s: string): string
{
	i, j: int;

	if(s == nil)
		return "";

	i = 0;
	j = len s;

	while(i < j && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r' || s[i] == '\n'))
		i++;

	while(j > i && (s[j - 1] == ' ' || s[j - 1] == '\t' || s[j - 1] == '\r' || s[j - 1] == '\n'))
		j--;

	return s[i:j];
}

startswith(s, prefix: string): int
{
	if(len prefix > len s)
		return 0;

	return s[0:len prefix] == prefix;
}

endswith(s, suffix: string): int
{
	if(len suffix > len s)
		return 0;

	return s[len s - len suffix:] == suffix;
}

splitkv(s: string): (string, string, int)
{
	i: int;
	k, v: string;

	for(i = 0; i < len s; i++){
		if(s[i] != '=')
			continue;

		k = trimspace(s[0:i]);
		v = trimspace(s[i + 1:]);

		if(k == "")
			return ("", "", 0);

		return (k, v, 1);
	}

	return ("", "", 0);
}

striplinecomment(s: string): string
{
	i: int;

	for(i = 0; i < len s; i++){
		if(s[i] == '#')
			return trimspace(s[0:i]);

		if(s[i] == ';')
			return trimspace(s[0:i]);
	}

	return trimspace(s);
}

lower(s: string): string
{
	r: string;
	i, c: int;

	r = "";

	for(i = 0; i < len s; i++){
		c = int s[i];

		if(c >= 'A' && c <= 'Z')
			c += 'a' - 'A';

		r += string c;
	}

	return r;
}

parseintvalue(s: string, def: int): int
{
	i, sign, v: int;

	s = trimspace(s);
	if(s == "")
		return def;

	i = 0;
	sign = 1;

	if(i < len s && s[i] == '-'){
		sign = -1;
		i++;
	}

	if(i >= len s)
		return def;

	v = 0;

	for(; i < len s; i++){
		if(s[i] < '0' || s[i] > '9')
			return def;

		v = v * 10 + int s[i] - int '0';
	}

	return sign * v;
}

parseboolvalue(s: string, def: int): int
{
	t: string;

	t = lower(trimspace(s));
	if(t == "")
		return def;

	if(t == "1" || t == "true" || t == "yes" || t == "on")
		return 1;

	if(t == "0" || t == "false" || t == "no" || t == "off")
		return 0;

	return def;
}

parsefile(path: string, origin: int): array of IcConfig->Entry
{
	iob: ref Iobuf;
	line, raw, section, key, value: string;
	ok, block: int;
	e: IcConfig->Entry;
	entries: array of IcConfig->Entry;

	entries = array[0] of IcConfig->Entry;
	section = "";
	block = 0;

	iob = bufio->open(path, Sys->OREAD);
	if(iob == nil)
		return entries;

	while((line = iob.gets('\n')) != nil){
		raw = trimspace(line);

		if(block){
			if(raw != "" && endswith(raw, "*/"))
				block = 0;
			continue;
		}

		if(raw == "")
			continue;

		if(startswith(raw, "/*")){
			if(!endswith(raw, "*/"))
				block = 1;
			continue;
		}

		raw = striplinecomment(raw);
		if(raw == "")
			continue;

		if(len raw >= 2 && raw[0] == '[' && raw[len raw - 1] == ']'){
			section = trimspace(raw[1:len raw - 1]);
			continue;
		}

		(key, value, ok) = splitkv(raw);
		if(!ok)
			continue;

		e.section = section;
		e.key = key;
		e.value = value;
		e.file = path;
		e.origin = origin;

		entries = appendentry(entries, e);
	}

	return entries;
}

buildfileentries(c: ref IcConfig->Config, path: string): array of IcConfig->Entry
{
	r: array of IcConfig->Entry;
	e: IcConfig->Entry;
	i, j, found: int;

	r = array[0] of IcConfig->Entry;

	if(c == nil || c.entries == nil)
		return r;

	for(i = 0; i < len c.entries; i++){
		e = c.entries[i];

		if(e.file != path)
			continue;

		found = 0;
		for(j = 0; j < len r; j++){
			if(r[j].section == e.section && r[j].key == e.key){
				r[j] = e;
				found = 1;
				break;
			}
		}

		if(!found)
			r = appendentry(r, e);
	}

	return sortentries(r);
}

entryless(a, b: IcConfig->Entry): int
{
	fa, fb: string;

	fa = fullkey(a.section, a.key);
	fb = fullkey(b.section, b.key);

	if(fa < fb)
		return 1;

	return 0;
}

swapentries(a: array of IcConfig->Entry, i, j: int)
{
	t: IcConfig->Entry;

	t = a[i];
	a[i] = a[j];
	a[j] = t;
}

sortentries(a: array of IcConfig->Entry): array of IcConfig->Entry
{
	i, j: int;

	if(a == nil)
		return array[0] of IcConfig->Entry;

	for(i = 0; i < len a; i++){
		for(j = i + 1; j < len a; j++){
			if(entryless(a[j], a[i]))
				swapentries(a, i, j);
		}
	}

	return a;
}

new(): ref IcConfig->Config
{
	c: ref IcConfig->Config;

	c = ref IcConfig->Config;
	c.entries = array[0] of IcConfig->Entry;

	return c;
}

clear(c: ref IcConfig->Config)
{
	if(c == nil)
		return;

	c.entries = array[0] of IcConfig->Entry;
}

loadcfg(c: ref IcConfig->Config, path: string, origin: int): int
{
	if(c == nil || path == "")
		return -1;

	clear(c);
	return overlay(c, path, origin);
}

overlay(c: ref IcConfig->Config, path: string, origin: int): int
{
	a: array of IcConfig->Entry;
	i: int;

	if(c == nil || path == "")
		return -1;

	a = parsefile(path, origin);

	for(i = 0; i < len a; i++)
		c.entries = appendentry(c.entries, a[i]);

	return 0;
}

get(c: ref IcConfig->Config, section, key: string): string
{
	i: int;

	if(c == nil)
		return "";

	i = findmerged(c.entries, section, key);
	if(i < 0)
		return "";

	return c.entries[i].value;
}

getfull(c: ref IcConfig->Config, fullkeyname: string): string
{
	section, key: string;

	(section, key) = splitfull(fullkeyname);
	return get(c, section, key);
}

getint(c: ref IcConfig->Config, section, key: string, def: int): int
{
	return parseintvalue(get(c, section, key), def);
}

getbool(c: ref IcConfig->Config, section, key: string, def: int): int
{
	return parseboolvalue(get(c, section, key), def);
}

set(c: ref IcConfig->Config, file, section, key, value: string): int
{
	i: int;
	e: IcConfig->Entry;

	if(c == nil || file == "" || key == "")
		return -1;

	i = findentry(c.entries, section, key, file);
	if(i >= 0){
		c.entries[i].value = value;
		return 0;
	}

	e.section = section;
	e.key = key;
	e.value = value;
	e.file = file;
	e.origin = IcConfig->OriginUser;

	c.entries = appendentry(c.entries, e);
	return 0;
}

setfull(c: ref IcConfig->Config, file, fullkeyname, value: string): int
{
	section, key: string;

	(section, key) = splitfull(fullkeyname);
	return set(c, file, section, key, value);
}

setint(c: ref IcConfig->Config, file, section, key: string, value: int): int
{
	return set(c, file, section, key, sys->sprint("%d", value));
}

setbool(c: ref IcConfig->Config, file, section, key: string, value: int): int
{
	if(value)
		return set(c, file, section, key, "1");

	return set(c, file, section, key, "0");
}

flush(c: ref IcConfig->Config, path: string): int
{
	fd: ref Sys->FD;
	a: array of IcConfig->Entry;
	i: int;
	cursec: string;

	if(c == nil || path == "")
		return -1;

	a = buildfileentries(c, path);

	fd = sys->create(path, Sys->OWRITE, 8r666);
	if(fd == nil)
		return -1;

	cursec = "";

	for(i = 0; i < len a; i++){
		if(a[i].section != cursec){
			if(i > 0)
				sys->fprint(fd, "\n");

			cursec = a[i].section;

			if(cursec != "")
				sys->fprint(fd, "[%s]\n", cursec);
		}

		sys->fprint(fd, "%s=%s\n", a[i].key, a[i].value);
	}

	return 0;
}

splitfull(fullkeyname: string): (string, string)
{
	i: int;
	section, key: string;

	for(i = len fullkeyname - 1; i >= 0; i--){
		if(fullkeyname[i] != '.')
			continue;

		section = trimspace(fullkeyname[0:i]);
		key = trimspace(fullkeyname[i + 1:]);

		if(key == "")
			return ("", trimspace(fullkeyname));

		return (section, key);
	}

	return ("", trimspace(fullkeyname));
}

fullkey(section, key: string): string
{
	if(section == "")
		return key;

	if(key == "")
		return section;

	return section + "." + key;
}