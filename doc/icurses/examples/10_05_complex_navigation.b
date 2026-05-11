#
# 10_05_complex_navigation.b
#
# Demonstrates navigation inside a complex element.
#
# The service list is treated as one logical complex control. It has its own
# internal state:
#
#   - selected item index;
#   - top visible row;
#   - custom scrollbar position.
#
# Up/Down changes the internal list selection. Select copies the current item
# into the selected-items panel. The command buttons keep ordinary button focus,
# while the list viewport shows its own independent navigation state.
#

implement ComplexNavigationDemo;

include "draw.m";
include "icurses/ui.m";

ComplexNavigationDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

VisibleRows: con 6;
ListCols: con 32;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

OwnerBoxId: con 20;
LogicalFocusId: con 21;
ButtonFocusId: con 22;
InnerStateId: con 23;

ListFrameId: con 30;
ListCanvasId: con 31;

SelectedBoxId: con 40;
SelectedTitleId: con 41;
SelectedLine1Id: con 42;
SelectedLine2Id: con 43;
SelectedLine3Id: con 44;

DetailsBoxId: con 50;
DetailsTitleId: con 51;
DetailsLine1Id: con 52;
DetailsLine2Id: con 53;

BtnUpId: con 60;
BtnDownId: con 61;
BtnSelectId: con 62;
BtnExitId: con 63;

items: array of string;
sel: int;
top: int;
chosen: int;
lastbutton: string;
selected1: string;
selected2: string;
selected3: string;

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

currentitem(): string
{
	if(sel < 0 || sel >= len items)
		return "none";

	return items[sel];
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

normalizelist()
{
	count: int;

	count = len items;

	if(count <= 0){
		sel = 0;
		top = 0;
		return;
	}

	sel = clamp(sel, 0, count - 1);

	if(sel < top)
		top = sel;

	if(sel >= top + VisibleRows)
		top = sel - VisibleRows + 1;

	if(count > VisibleRows)
		top = clamp(top, 0, count - VisibleRows);
	else
		top = 0;
}

drawlist(u: ref IcUi->Ui)
{
	r, i, count, thumb: int;
	line, prefix: string;

	normalizelist();

	count = len items;

	ui->canvasclear(u, ListCanvasId, " ", "0");

	for(r = 0; r < VisibleRows; r++){
		i = top + r;

		if(i >= count)
			break;

		if(i == sel)
			prefix = "> ";
		else
			prefix = "  ";

		line = prefix + items[i];
		ui->canvasputs(u, ListCanvasId, 0, r, line, "0");
	}

	if(count > VisibleRows){
		ui->canvasfill(u, ListCanvasId, ListCols - 1, 0, 1, VisibleRows, "|", "0");
		thumb = scrollthumb(count, VisibleRows);
		ui->canvasputc(u, ListCanvasId, ListCols - 1, thumb, "#", "0");
	}
}

refresh(u: ref IcUi->Ui)
{
	drawlist(u);

	ui->settext(u, LogicalFocusId, "Logical owner: ListViewportId");
	ui->settext(u, ButtonFocusId, "Command button focus: " + lastbutton);
	ui->settext(u, InnerStateId, "selected=" + sys->sprint("%d", sel) +
		" top=" + sys->sprint("%d", top) +
		" item=" + currentitem());

	ui->settext(u, DetailsTitleId, "Current item: " + currentitem());
	ui->settext(u, DetailsLine1Id, "Up/Down changes list internal state.");
	ui->settext(u, DetailsLine2Id, "Scrollbar reaches bottom on the last item.");

	ui->settext(u, SelectedLine1Id, selected1);
	ui->settext(u, SelectedLine2Id, selected2);
	ui->settext(u, SelectedLine3Id, selected3);

	ui->setstatus(u, "list selected: " + currentitem());
	ui->draw(u);
}

setbuttonfocus(u: ref IcUi->Ui, id: int, name: string)
{
	lastbutton = name;
	ui->setfocus(u, id);
}

moveitem(u: ref IcUi->Ui, delta: int, buttonid: int, name: string)
{
	setbuttonfocus(u, buttonid, name);

	sel += delta;
	normalizelist();

	refresh(u);
}

selectitem(u: ref IcUi->Ui)
{
	setbuttonfocus(u, BtnSelectId, "Select");

	chosen++;

	selected3 = selected2;
	selected2 = selected1;
	selected1 = sys->sprint("%d", chosen) + ". " + currentitem();

	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 92);
	y = center(sh, 22);

	items = array[] of {
		"Alpha service",
		"Build queue",
		"Cache worker",
		"Deploy stage",
		"Event router",
		"File scanner",
		"Graph renderer",
		"Health probe",
		"Input bridge",
		"Job archive",
		"Kernel monitor",
		"Log shipper"
	};

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Up/Down scroll internal list state | Select copies item | j/k also move | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 96, 22, " Complex navigation ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 78, "A complex control has one logical focus owner and its own internal selection.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, OwnerBoxId, 3, 4, 42, 6, " Focus and internal state ") < 0)
		raise "fail:owner box";

	if(ui->label(u, OwnerBoxId, LogicalFocusId, 2, 1, 32, "") < 0)
		raise "fail:logical focus";

	if(ui->label(u, OwnerBoxId, ButtonFocusId, 2, 2, 32, "") < 0)
		raise "fail:button focus";

	if(ui->label(u, OwnerBoxId, InnerStateId, 2, 4, 38, "") < 0)
		raise "fail:inner state";

	if(ui->window(u, WinId, ListFrameId, 3, 11, 38, 8, " Service list viewport ") < 0)
		raise "fail:list frame";

	if(ui->canvas(u, ListFrameId, ListCanvasId, 2, 1, ListCols, VisibleRows) < 0)
		raise "fail:list canvas";

	if(ui->window(u, WinId, DetailsBoxId, 47, 4, 47, 6, " Current item ") < 0)
		raise "fail:details";

	if(ui->label(u, DetailsBoxId, DetailsTitleId, 2, 1, 44, "") < 0)
		raise "fail:details title";

	if(ui->label(u, DetailsBoxId, DetailsLine1Id, 2, 3, 44, "") < 0)
		raise "fail:details line 1";

	if(ui->label(u, DetailsBoxId, DetailsLine2Id, 2, 4, 44, "") < 0)
		raise "fail:details line 2";

	if(ui->window(u, WinId, SelectedBoxId, 45, 11, 34, 8, " Selected items ") < 0)
		raise "fail:selected box";

	if(ui->label(u, SelectedBoxId, SelectedTitleId, 2, 1, 28, "Select copies list item here:") < 0)
		raise "fail:selected title";

	if(ui->label(u, SelectedBoxId, SelectedLine1Id, 2, 3, 28, "") < 0)
		raise "fail:selected line 1";

	if(ui->label(u, SelectedBoxId, SelectedLine2Id, 2, 4, 28, "") < 0)
		raise "fail:selected line 2";

	if(ui->label(u, SelectedBoxId, SelectedLine3Id, 2, 5, 28, "") < 0)
		raise "fail:selected line 3";

	if(ui->button(u, WinId, BtnUpId, 3, 20, 8, 1, "Up", "u", AppTarget, "app.up") < 0)
		raise "fail:up";

	if(ui->button(u, WinId, BtnDownId, 13, 20, 10, 1, "Down", "d", AppTarget, "app.down") < 0)
		raise "fail:down";

	if(ui->button(u, WinId, BtnSelectId, 25, 20, 12, 1, "Select", "s", AppTarget, "app.select") < 0)
		raise "fail:select";

	if(ui->button(u, WinId, BtnExitId, 39, 20, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	if(ui->bindkey(u, "j", AppTarget, "app.down") < 0)
		raise "fail:bind j";

	if(ui->bindkey(u, "k", AppTarget, "app.up") < 0)
		raise "fail:bind k";

	sel = 0;
	top = 0;
	chosen = 0;
	lastbutton = "Down";
	selected1 = "(none)";
	selected2 = "(none)";
	selected3 = "(none)";

	ui->setfocus(u, BtnDownId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.up"){
		moveitem(u, -1, BtnUpId, "Up");
		return 0;
	}

	if(cmd == "app.down"){
		moveitem(u, 1, BtnDownId, "Down");
		return 0;
	}

	if(cmd == "app.select"){
		selectitem(u);
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