#
# 11_08_menu_demo.b
#
# Demonstrates a Notepad-style menu bar with dropdown menus and nested
# submenus.
#
# This demo is intentionally built from basic IcUi nodes and manual keyboard
# handling, because a real menu needs to use Esc for closing menus instead of
# exiting the whole application.
#
# Keys:
#
#   - Left/Right move between File, Edit and View.
#   - Enter opens the selected dropdown.
#   - Up/Down move inside an open dropdown or submenu.
#   - Enter on View/Scale or View/Charset opens a submenu.
#   - Enter on a command item executes it and closes menus.
#   - Esc closes submenu first, then dropdown.
#   - q exits the application.
#

implement MenuDemo;

include "draw.m";
include "icurses/ui.m";

MenuDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
msg: IcMsg;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

MenuNormal: con "30;47";
MenuFocus: con "30;46";
MenuShadow: con "30;40";
NavbarNormal: con "37;44";
NavbarFocus: con "30;46";
EditorText: con "0";

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

NavbarCanvasId: con 20;
EditorWinId: con 21;
EditorCanvasId: con 22;

FileLayerId: con 30;
FileShadowId: con 31;
FileCanvasId: con 32;

EditLayerId: con 40;
EditShadowId: con 41;
EditCanvasId: con 42;

ViewLayerId: con 50;
ViewShadowId: con 51;
ViewCanvasId: con 52;

SubLayerId: con 60;
SubShadowId: con 61;
SubCanvasId: con 62;

CommandBoxId: con 70;
LastCmdId: con 71;
HintId: con 72;

NavFile: con 0;
NavEdit: con 1;
NavView: con 2;

SubNone: con 0;
SubScale: con 1;
SubCharset: con 2;

navsel: int;
dropsel: int;
subsel: int;
dropopen: int;
subopen: int;
submenu: int;
lastcmd: string;

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

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ic->init();
	ui->init();
	msg->init();
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

sendnode(u: ref IcUi->Ui, id: int, cmd: string)
{
	m: IcMsg->Msg;

	m = msg->newmsg(AppTarget, id, IcMsg->KindCommand, cmd);
	ui->dispatch(u, m);
}

shownode(u: ref IcUi->Ui, id: int, visible: int)
{
	if(visible)
		sendnode(u, id, "node.show");
	else
		sendnode(u, id, "node.hide");
}

showfile(u: ref IcUi->Ui, visible: int)
{
	shownode(u, FileLayerId, visible);
	shownode(u, FileShadowId, visible);
	shownode(u, FileCanvasId, visible);
}

showedit(u: ref IcUi->Ui, visible: int)
{
	shownode(u, EditLayerId, visible);
	shownode(u, EditShadowId, visible);
	shownode(u, EditCanvasId, visible);
}

showview(u: ref IcUi->Ui, visible: int)
{
	shownode(u, ViewLayerId, visible);
	shownode(u, ViewShadowId, visible);
	shownode(u, ViewCanvasId, visible);
}

showsub(u: ref IcUi->Ui, visible: int)
{
	shownode(u, SubLayerId, visible);
	shownode(u, SubShadowId, visible);
	shownode(u, SubCanvasId, visible);
}

hidemenuwindows(u: ref IcUi->Ui)
{
	showfile(u, 0);
	showedit(u, 0);
	showview(u, 0);
	showsub(u, 0);
}

navname(): string
{
	if(navsel == NavFile)
		return "File";
	if(navsel == NavEdit)
		return "Edit";
	return "View";
}

dropitem(i: int): string
{
	if(navsel == NavFile){
		if(i == 0)
			return "Create";
		if(i == 1)
			return "Open";
		if(i == 2)
			return "Save";
		if(i == 3)
			return "Save As";
		return "Close";
	}

	if(navsel == NavEdit){
		if(i == 0)
			return "Select";
		if(i == 1)
			return "Copy";
		if(i == 2)
			return "Paste";
		if(i == 3)
			return "Cut";
		return "Undo";
	}

	if(i == 0)
		return "[x] Auto-LineBreak";
	if(i == 1)
		return "Scale >";
	if(i == 2)
		return "Charset >";
	if(i == 3)
		return "Status Bar";
	return "Preview";
}

subitem(i: int): string
{
	if(submenu == SubScale){
		if(i == 0)
			return "10%";
		if(i == 1)
			return "25%";
		if(i == 2)
			return "50%";
		if(i == 3)
			return "100%";
		return "150%";
	}

	if(i == 0)
		return "ASCII";
	if(i == 1)
		return "UTF8";
	if(i == 2)
		return "UTF16";
	if(i == 3)
		return "CP866";
	return "KOI8-R";
}

fillrow(u: ref IcUi->Ui, canvasid, y, w: int, code: string)
{
	ui->canvasfill(u, canvasid, 0, y, w, 1, " ", code);
}

putrow(u: ref IcUi->Ui, canvasid, y, w: int, text: string, selected: int)
{
	code: string;

	if(selected)
		code = MenuFocus;
	else
		code = MenuNormal;

	fillrow(u, canvasid, y, w, code);
	ui->canvasputs(u, canvasid, 1, y, text, code);
}

drawshadow(u: ref IcUi->Ui, canvasid, w, h: int)
{
	ui->canvasfill(u, canvasid, 0, 0, w, h, " ", MenuShadow);
}

drawnavbaritem(u: ref IcUi->Ui, x, w: int, text: string, selected: int)
{
	code: string;

	if(selected)
		code = NavbarFocus;
	else
		code = NavbarNormal;

	ui->canvasfill(u, NavbarCanvasId, x, 0, w, 1, " ", code);
	ui->canvasputs(u, NavbarCanvasId, x + 2, 0, text, code);
}

drawnavbar(u: ref IcUi->Ui)
{
	ui->canvasclear(u, NavbarCanvasId, " ", NavbarNormal);

	drawnavbaritem(u, 0, 10, "File", navsel == NavFile);
	drawnavbaritem(u, 11, 10, "Edit", navsel == NavEdit);
	drawnavbaritem(u, 22, 10, "View", navsel == NavView);
}

draweditor(u: ref IcUi->Ui)
{
	ui->canvasclear(u, EditorCanvasId, " ", EditorText);

	ui->canvasputs(u, EditorCanvasId, 2, 1, "Menu Demo.txt - sample editor workspace", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 3, "This area imitates an editor document. Dropdown menus are", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 4, "drawn above this text, just like in a GUI editor or file", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 5, "manager. Use Left/Right to select File, Edit or View.", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 7, "Press Enter to open the selected menu. Use Up/Down inside", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 8, "the menu. View contains nested Scale and Charset submenus.", EditorText);
	ui->canvasputs(u, EditorCanvasId, 2, 10, "Esc closes submenu or dropdown. Only q exits the demo.", EditorText);
}

drawdropcanvas(u: ref IcUi->Ui, canvasid: int)
{
	ui->canvasclear(u, canvasid, " ", MenuNormal);

	putrow(u, canvasid, 0, 22, dropitem(0), dropsel == 0);
	putrow(u, canvasid, 1, 22, dropitem(1), dropsel == 1);
	putrow(u, canvasid, 2, 22, dropitem(2), dropsel == 2);
	putrow(u, canvasid, 3, 22, dropitem(3), dropsel == 3);
	putrow(u, canvasid, 4, 22, dropitem(4), dropsel == 4);
}

drawsubmenu(u: ref IcUi->Ui)
{
	ui->canvasclear(u, SubCanvasId, " ", MenuNormal);

	putrow(u, SubCanvasId, 0, 16, subitem(0), subsel == 0);
	putrow(u, SubCanvasId, 1, 16, subitem(1), subsel == 1);
	putrow(u, SubCanvasId, 2, 16, subitem(2), subsel == 2);
	putrow(u, SubCanvasId, 3, 16, subitem(3), subsel == 3);
	putrow(u, SubCanvasId, 4, 16, subitem(4), subsel == 4);
}

drawmenus(u: ref IcUi->Ui)
{
	drawshadow(u, FileShadowId, 22, 5);
	drawshadow(u, EditShadowId, 22, 5);
	drawshadow(u, ViewShadowId, 22, 5);
	drawshadow(u, SubShadowId, 16, 5);

	drawdropcanvas(u, FileCanvasId);
	drawdropcanvas(u, EditCanvasId);
	drawdropcanvas(u, ViewCanvasId);
	drawsubmenu(u);
}

showactivewindow(u: ref IcUi->Ui)
{
	hidemenuwindows(u);

	if(dropopen){
		if(navsel == NavFile)
			showfile(u, 1);
		else if(navsel == NavEdit)
			showedit(u, 1);
		else
			showview(u, 1);
	}

	if(subopen)
		showsub(u, 1);
}

refreshlastcmd(u: ref IcUi->Ui)
{
	ui->settext(u, LastCmdId, "Last command: " + lastcmd);
}

refresh(u: ref IcUi->Ui)
{
	drawnavbar(u);
	draweditor(u);
	drawmenus(u);
	showactivewindow(u);
	refreshlastcmd(u);

	ui->setstatus(u, "Left/Right menu bar | Enter open/execute | Up/Down select | Esc close | q exit");
	ui->draw(u);
}

execute(u: ref IcUi->Ui)
{
	if(subopen)
		lastcmd = "View / " + dropitem(dropsel) + " / " + subitem(subsel);
	else if(dropopen)
		lastcmd = navname() + " / " + dropitem(dropsel);
	else
		lastcmd = navname();

	dropopen = 0;
	subopen = 0;
	submenu = SubNone;

	refresh(u);
}

openmenu(u: ref IcUi->Ui)
{
	dropopen = 1;
	subopen = 0;
	submenu = SubNone;
	dropsel = 0;
	subsel = 0;

	refresh(u);
}

opensubmenu(u: ref IcUi->Ui)
{
	if(navsel != NavView)
		return;

	if(dropsel == 1)
		submenu = SubScale;
	else if(dropsel == 2)
		submenu = SubCharset;
	else
		return;

	subopen = 1;
	subsel = 0;

	refresh(u);
}

closeone(u: ref IcUi->Ui)
{
	if(subopen){
		subopen = 0;
		submenu = SubNone;
		refresh(u);
		return;
	}

	if(dropopen){
		dropopen = 0;
		refresh(u);
		return;
	}

	refresh(u);
}

menukey(u: ref IcUi->Ui, k: int): int
{
	if(k == 'q' || k == 'Q')
		return 1;

	if(ic->iscancel(k)){
		closeone(u);
		return 0;
	}

	if(k == Icurses->Kleft){
		if(!subopen){
			navsel--;
			if(navsel < NavFile)
				navsel = NavView;

			if(dropopen){
				dropsel = 0;
				subopen = 0;
				submenu = SubNone;
			}
		}

		refresh(u);
		return 0;
	}

	if(k == Icurses->Kright){
		if(!subopen){
			navsel++;
			if(navsel > NavView)
				navsel = NavFile;

			if(dropopen){
				dropsel = 0;
				subopen = 0;
				submenu = SubNone;
			}
		}

		refresh(u);
		return 0;
	}

	if(k == Icurses->Kdown){
		if(!dropopen){
			openmenu(u);
			return 0;
		}

		if(subopen){
			subsel++;
			if(subsel > 4)
				subsel = 0;
		}
		else{
			dropsel++;
			if(dropsel > 4)
				dropsel = 0;
		}

		refresh(u);
		return 0;
	}

	if(k == Icurses->Kup){
		if(subopen){
			subsel--;
			if(subsel < 0)
				subsel = 4;
		}
		else if(dropopen){
			dropsel--;
			if(dropsel < 0)
				dropsel = 4;
		}

		refresh(u);
		return 0;
	}

	if(ic->isconfirm(k)){
		if(!dropopen)
			openmenu(u);
		else if(subopen)
			execute(u);
		else if(navsel == NavView && (dropsel == 1 || dropsel == 2))
			opensubmenu(u);
		else
			execute(u);

		return 0;
	}

	return 0;
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 84);
	y = center(sh, 23);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Left/Right menu bar | Enter open/execute | Up/Down select | Esc close | q exit ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 84, 23, " Notepad-style menu demo ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 74, "A menu bar can open dropdown menus and nested submenus above editor text.") < 0)
		raise "fail:title";

	if(ui->canvas(u, WinId, NavbarCanvasId, 3, 4, 36, 1) < 0)
		raise "fail:navbar canvas";

	if(ui->window(u, WinId, EditorWinId, 3, 6, 78, 11, " Editor text ") < 0)
		raise "fail:editor window";

	if(ui->canvas(u, EditorWinId, EditorCanvasId, 1, 1, 76, 9) < 0)
		raise "fail:editor canvas";

	if(ui->group(u, WinId, FileLayerId, 3, 5, 24, 7) < 0)
		raise "fail:file layer";

	if(ui->canvas(u, FileLayerId, FileShadowId, 1, 1, 22, 5) < 0)
		raise "fail:file shadow";

	if(ui->canvas(u, FileLayerId, FileCanvasId, 0, 0, 22, 5) < 0)
		raise "fail:file canvas";

	if(ui->group(u, WinId, EditLayerId, 14, 5, 24, 7) < 0)
		raise "fail:edit layer";

	if(ui->canvas(u, EditLayerId, EditShadowId, 1, 1, 22, 5) < 0)
		raise "fail:edit shadow";

	if(ui->canvas(u, EditLayerId, EditCanvasId, 0, 0, 22, 5) < 0)
		raise "fail:edit canvas";

	if(ui->group(u, WinId, ViewLayerId, 25, 5, 24, 7) < 0)
		raise "fail:view layer";

	if(ui->canvas(u, ViewLayerId, ViewShadowId, 1, 1, 22, 5) < 0)
		raise "fail:view shadow";

	if(ui->canvas(u, ViewLayerId, ViewCanvasId, 0, 0, 22, 5) < 0)
		raise "fail:view canvas";

	if(ui->group(u, WinId, SubLayerId, 47, 7, 18, 7) < 0)
		raise "fail:sub layer";

	if(ui->canvas(u, SubLayerId, SubShadowId, 1, 1, 16, 5) < 0)
		raise "fail:sub shadow";

	if(ui->canvas(u, SubLayerId, SubCanvasId, 0, 0, 16, 5) < 0)
		raise "fail:sub canvas";

	if(ui->window(u, WinId, CommandBoxId, 3, 18, 78, 3, " Command log ") < 0)
		raise "fail:command box";

	if(ui->label(u, CommandBoxId, LastCmdId, 2, 1, 72, "") < 0)
		raise "fail:last command";

	if(ui->label(u, CommandBoxId, HintId, 2, 2, 72, "Esc closes menu/submenu. Only q exits.") < 0)
		raise "fail:hint";

	navsel = NavFile;
	dropsel = 0;
	subsel = 0;
	dropopen = 0;
	subopen = 0;
	submenu = SubNone;
	lastcmd = "none";

	hidemenuwindows(u);
	refresh(u);
}

run()
{
	u: ref IcUi->Ui;
	w, h, done, k: int;

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

	if(ui->openinput() < 0){
		ui->close(u);
		leaveappscreen();
		sys->print("cannot open input\n");
		return;
	}

	done = 0;

	for(; !done;){
		k = ui->readkey();
		done = menukey(u, k);
	}

	ui->closeinput();
	ui->close(u);
	leaveappscreen();

	sys->print("result: ok\n");
}

init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}