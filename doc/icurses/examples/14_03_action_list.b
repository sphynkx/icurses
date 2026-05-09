#
# 14_03_action_list.b
#
# Demonstrates a list-with-actions application template.
#
# The list has a cursor for browsing and a selected item for actions. The Run,
# Disable and Delete buttons operate on the current cursor item.
#

implement ActionListTemplate;

include "draw.m";
include "icurses/ui.m";

ActionListTemplate: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

Rows: con 8;
Cols: con 34;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

ListBoxId: con 20;
ListCanvasId: con 21;

ActionBoxId: con 30;
CurrentId: con 31;
SelectedId: con 32;
RunsId: con 33;
LastActionId: con 34;

BtnPrevId: con 40;
BtnNextId: con 41;
BtnRunId: con 42;
BtnDisableId: con 43;
BtnDeleteId: con 44;
BtnExitId: con 45;

items: array of string;
disabled: array of int;
cursor: int;
selected: int;
top: int;
runs: int;
lastaction: string;

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

normalizelist()
{
	n: int;

	n = len items;
	if(n <= 0){
		cursor = 0;
		selected = -1;
		top = 0;
		return;
	}

	cursor = clamp(cursor, 0, n - 1);

	if(cursor < top)
		top = cursor;
	if(cursor >= top + Rows)
		top = cursor - Rows + 1;

	if(n > Rows)
		top = clamp(top, 0, n - Rows);
	else
		top = 0;
}

itemname(i: int): string
{
	if(i < 0 || i >= len items)
		return "none";

	return items[i];
}

drawlist(u: ref IcUi->Ui)
{
	r, i: int;
	line, prefix, mark: string;

	normalizelist();
	ui->canvasclear(u, ListCanvasId, " ", "0");

	for(r = 0; r < Rows; r++){
		i = top + r;
		if(i >= len items)
			break;

		if(i == cursor)
			prefix = "> ";
		else
			prefix = "  ";

		if(i == selected)
			mark = " *";
		else if(disabled[i])
			mark = " disabled";
		else
			mark = "";

		line = prefix + items[i] + mark;
		ui->canvasputs(u, ListCanvasId, 0, r, line, "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	drawlist(u);

	ui->settext(u, CurrentId, "Cursor: " + sys->sprint("%d", cursor) + " " + itemname(cursor));

	if(selected >= 0)
		ui->settext(u, SelectedId, "Selected: " + sys->sprint("%d", selected) + " " + itemname(selected));
	else
		ui->settext(u, SelectedId, "Selected: none");

	ui->settext(u, RunsId, "Run count: " + sys->sprint("%d", runs));
	ui->settext(u, LastActionId, "Last action: " + lastaction);

	ui->setstatus(u, "action list: " + lastaction);
	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y, i: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 20);

	items = array[] of {
		"backup job",
		"deploy staging",
		"scan files",
		"generate report",
		"sync mirror",
		"clean cache",
		"package release",
		"notify users",
		"archive logs",
		"rotate keys"
	};

	disabled = array[len items] of int;
	for(i = 0; i < len disabled; i++)
		disabled[i] = 0;

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Browse list, then run/disable/delete current item | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 20, " List with actions template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "A common pattern: browse a list and execute actions on the current row.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, ListBoxId, 3, 4, 40, 10, " Jobs ") < 0)
		raise "fail:list box";

	if(ui->canvas(u, ListBoxId, ListCanvasId, 2, 1, Cols, Rows) < 0)
		raise "fail:list canvas";

	if(ui->window(u, WinId, ActionBoxId, 47, 4, 32, 10, " Action state ") < 0)
		raise "fail:action box";

	if(ui->label(u, ActionBoxId, CurrentId, 2, 2, 26, "") < 0)
		raise "fail:current";

	if(ui->label(u, ActionBoxId, SelectedId, 2, 4, 26, "") < 0)
		raise "fail:selected";

	if(ui->label(u, ActionBoxId, RunsId, 2, 6, 26, "") < 0)
		raise "fail:runs";

	if(ui->label(u, ActionBoxId, LastActionId, 2, 7, 26, "") < 0)
		raise "fail:last action";

	if(ui->button(u, WinId, BtnPrevId, 3, 17, 8, 1, "Prev", "p", AppTarget, "app.prev") < 0)
		raise "fail:prev";

	if(ui->button(u, WinId, BtnNextId, 13, 17, 8, 1, "Next", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnRunId, 23, 17, 8, 1, "Run", "r", AppTarget, "app.run") < 0)
		raise "fail:run";

	if(ui->button(u, WinId, BtnDisableId, 33, 17, 12, 1, "Disable", "d", AppTarget, "app.disable") < 0)
		raise "fail:disable";

	if(ui->button(u, WinId, BtnDeleteId, 47, 17, 10, 1, "Delete", "x", AppTarget, "app.delete") < 0)
		raise "fail:delete";

	if(ui->button(u, WinId, BtnExitId, 59, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	cursor = 0;
	selected = -1;
	top = 0;
	runs = 0;
	lastaction = "none";

	ui->setfocus(u, BtnNextId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.prev"){
		cursor--;
		normalizelist();
		lastaction = "cursor moved up";
		refresh(u);
		return 0;
	}

	if(cmd == "app.next"){
		cursor++;
		normalizelist();
		lastaction = "cursor moved down";
		refresh(u);
		return 0;
	}

	if(cmd == "app.run"){
		selected = cursor;
		if(disabled[cursor])
			lastaction = "blocked disabled item";
		else{
			runs++;
			lastaction = "run " + itemname(cursor);
		}
		refresh(u);
		return 0;
	}

	if(cmd == "app.disable"){
		disabled[cursor] = !disabled[cursor];
		selected = cursor;
		lastaction = "toggle disabled " + itemname(cursor);
		refresh(u);
		return 0;
	}

	if(cmd == "app.delete"){
		items[cursor] = "(removed)";
		disabled[cursor] = 1;
		selected = cursor;
		lastaction = "delete current row";
		refresh(u);
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