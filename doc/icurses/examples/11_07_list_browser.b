#
# 11_07_list_browser.b
#
# Demonstrates a list browser.
#
# The list has two separate concepts:
#
#   - cursor index: the currently highlighted row while browsing;
#   - selected index: the committed choice set by the Choose button.
#
# Next/Prev/Home/End move only the cursor. Choose copies the cursor index into
# the selected index.
#

implement ListBrowserDemo;

include "draw.m";
include "icurses/ui.m";

ListBrowserDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

VisibleRows: con 8;
ListCols: con 30;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

ListFrameId: con 20;
ListCanvasId: con 21;

DetailsBoxId: con 30;
CursorId: con 31;
SelectedId: con 32;
TopId: con 33;
ChosenId: con 34;

BtnPrevId: con 40;
BtnNextId: con 41;
BtnHomeId: con 42;
BtnEndId: con 43;
BtnChooseId: con 44;
BtnExitId: con 45;

items: array of string;
cursor: int;
selected: int;
top: int;
chosen: int;

loadmods()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	ic->init();
	ui->init();
}

enterappscreen()
{
	if(out == nil || appscreen)
		return;

	sys->fprint(out, "%c[?1049h", 27);
	ic->resettty(out);
	ic->hidecursor(out);
	ic->cleartty(out);

	appscreen = 1;
}

leaveappscreen()
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	ic->cleartty(out);

	if(appscreen){
		sys->fprint(out, "%c[?1049l", 27);
		appscreen = 0;
	}

	ic->resettty(out);
	ic->showcursor(out);
}

center(total, size: int): int
{
	x: int;

	x = (total - size) / 2;
	if(x < 0)
		x = 0;

	return x;
}

clamp(v, lo, hi: int): int
{
	if(hi < lo)
		hi = lo;

	if(v < lo)
		return lo;

	if(v > hi)
		return hi;

	return v;
}

itemname(index: int): string
{
	if(index < 0 || index >= len items)
		return "none";

	return items[index];
}

normalizelist()
{
	count: int;

	count = len items;

	if(count <= 0){
		cursor = 0;
		selected = -1;
		top = 0;
		return;
	}

	cursor = clamp(cursor, 0, count - 1);

	if(selected >= count)
		selected = -1;

	if(cursor < top)
		top = cursor;

	if(cursor >= top + VisibleRows)
		top = cursor - VisibleRows + 1;

	if(count > VisibleRows)
		top = clamp(top, 0, count - VisibleRows);
	else
		top = 0;
}

scrollthumb(count, rows: int): int
{
	maxvisibletop, thumb: int;

	if(count <= rows)
		return 0;

	maxvisibletop = count - rows;
	if(maxvisibletop <= 0)
		return 0;

	thumb = (top * (rows - 1)) / maxvisibletop;
	return clamp(thumb, 0, rows - 1);
}

drawlist(u: ref IcUi->Ui)
{
	r, i, count, thumb: int;
	line, prefix, suffix: string;

	normalizelist();

	count = len items;

	ui->canvasclear(u, ListCanvasId, " ", "0");

	for(r = 0; r < VisibleRows; r++){
		i = top + r;
		if(i >= count)
			break;

		if(i == cursor)
			prefix = "> ";
		else
			prefix = "  ";

		if(i == selected)
			suffix = " *";
		else
			suffix = "";

		line = prefix + items[i] + suffix;
		ui->canvasputs(u, ListCanvasId, 0, r, line, "0");
	}

	if(count > VisibleRows){
		ui->canvasfill(u, ListCanvasId, ListCols - 1, 0, 1, VisibleRows, "|", "0");
		thumb = scrollthumb(count, VisibleRows);
		ui->canvasputc(u, ListCanvasId, ListCols - 1, thumb, "#", "0");
	}
}

refresh(u: ref IcUi->Ui, note: string)
{
	drawlist(u);

	ui->settext(u, CursorId, "Cursor index: " + sys->sprint("%d", cursor) + "  " + itemname(cursor));

	if(selected >= 0)
		ui->settext(u, SelectedId, "Selected index: " + sys->sprint("%d", selected) + "  " + itemname(selected));
	else
		ui->settext(u, SelectedId, "Selected index: none");

	ui->settext(u, TopId, "Top visible index: " + sys->sprint("%d", top));
	ui->settext(u, ChosenId, "Choose count: " + sys->sprint("%d", chosen));

	if(note == "")
		note = "list ready";

	ui->setstatus(u, note);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 20);

	items = array[] of {
		"auth service",
		"billing worker",
		"cache node",
		"deploy queue",
		"event router",
		"file indexer",
		"gateway",
		"health probe",
		"image builder",
		"job archive",
		"key manager",
		"log shipper"
	};

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Next/Prev move cursor | Choose commits selected index | * marks selected item ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 80, 20, " List browser ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 68, "Browsing cursor and committed selection are separate list states.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, ListFrameId, 3, 4, 36, 10, " Services ") < 0)
		raise "fail:list frame";

	if(ui->canvas(u, ListFrameId, ListCanvasId, 2, 1, ListCols, VisibleRows) < 0)
		raise "fail:list canvas";

	if(ui->window(u, WinId, DetailsBoxId, 42, 4, 36, 10, " Details ") < 0)
		raise "fail:details box";

	if(ui->label(u, DetailsBoxId, CursorId, 2, 2, 32, "") < 0)
		raise "fail:cursor";

	if(ui->label(u, DetailsBoxId, SelectedId, 2, 4, 32, "") < 0)
		raise "fail:selected";

	if(ui->label(u, DetailsBoxId, TopId, 2, 6, 32, "") < 0)
		raise "fail:top";

	if(ui->label(u, DetailsBoxId, ChosenId, 2, 7, 32, "") < 0)
		raise "fail:chosen";

	if(ui->button(u, WinId, BtnPrevId, 3, 17, 9, 1, "Prev", "p", AppTarget, "app.prev") < 0)
		raise "fail:prev";

	if(ui->button(u, WinId, BtnNextId, 14, 17, 9, 1, "Next", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnHomeId, 25, 17, 10, 1, "Home", "h", AppTarget, "app.home") < 0)
		raise "fail:home";

	if(ui->button(u, WinId, BtnEndId, 37, 17, 8, 1, "End", "e", AppTarget, "app.end") < 0)
		raise "fail:end";

	if(ui->button(u, WinId, BtnChooseId, 47, 17, 12, 1, "Choose", "c", AppTarget, "app.choose") < 0)
		raise "fail:choose";

	if(ui->button(u, WinId, BtnExitId, 61, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	cursor = 0;
	selected = -1;
	top = 0;
	chosen = 0;

	ui->setfocus(u, BtnNextId);
	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.prev"){
		cursor--;
		normalizelist();
		refresh(u, "cursor moved up");
		return 0;
	}

	if(cmd == "app.next"){
		cursor++;
		normalizelist();
		refresh(u, "cursor moved down");
		return 0;
	}

	if(cmd == "app.home"){
		cursor = 0;
		normalizelist();
		refresh(u, "cursor moved to first item");
		return 0;
	}

	if(cmd == "app.end"){
		cursor = len items - 1;
		normalizelist();
		refresh(u, "cursor moved to last item");
		return 0;
	}

	if(cmd == "app.choose"){
		selected = cursor;
		chosen++;
		refresh(u, "selected: " + itemname(selected));
		return 0;
	}

	ui->draw(u);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h, done: int;

	out = sys->fildes(1);
	appscreen = 0;

	enterappscreen();

	(w, h) = ic->termsize();
	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	u = ui->new(out, w, h);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	build(u, w, h);

	if(ui->start(u) < 0){
		ui->close(u);
		leaveappscreen();
		sys->print("cannot start ui\n");
		return;
	}

	done = 0;

	for(; !done;){
		s = ui->step(u);

		case s.kind {
		IcUi->StepDone =>
			done = 1;

		IcUi->StepKey =>
			if(ui->isquit(s.key))
				done = 1;
			else
				done = handlecmd(u, s.msg.cmd);

		IcUi->StepTick =>
			;

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	ui->close(u);
	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}