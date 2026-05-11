#
# 14_04_confirm_dialog.b
#
# Demonstrates a confirmation dialog template.
#
# The dialog is a separate layer containing a shadow window. Opening the dialog
# moves focus to the dialog buttons. While the dialog is open, commands outside
# the dialog are ignored so focus remains effectively modal.
#
# The item list demonstrates a common destructive-action pattern:
#
#   - Up/Down moves the cursor between active items.
#   - Delete opens a modal confirm dialog for the current active item.
#   - Yes disables the item and removes it from future navigation.
#   - No cancels the destructive action.
#

implement ConfirmDialogTemplate;

include "draw.m";
include "icurses/ui.m";

ConfirmDialogTemplate: module
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

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

StateBoxId: con 20;
StateLine1Id: con 21;
StateLine2Id: con 22;
StateLine3Id: con 23;

ListBoxId: con 24;
Item1Id: con 25;
Item2Id: con 26;
Item3Id: con 27;
Item4Id: con 28;
Item5Id: con 29;

BtnDeleteId: con 30;
BtnResetId: con 31;
BtnExitId: con 32;

DialogLayerId: con 40;
DialogShadowId: con 41;
DialogWinId: con 42;
DialogText1Id: con 43;
DialogText2Id: con 44;
BtnYesId: con 45;
BtnNoId: con 46;

items: array of string;
deleted: array of int;
cursor: int;
deletes: int;
lastaction: string;
dialogopen: int;
dialogfocus: int;

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

activecount(): int
{
	i, n: int;

	n = 0;
	for(i = 0; i < len items; i++)
		if(!deleted[i])
			n++;

	return n;
}

findnextactive(start, delta: int): int
{
	i, n: int;

	n = len items;
	if(n <= 0)
		return -1;

	i = start;

	for(;;){
		i += delta;

		if(i < 0)
			i = n - 1;
		if(i >= n)
			i = 0;

		if(!deleted[i])
			return i;

		if(i == start)
			break;
	}

	return -1;
}

ensureactivecursor()
{
	n: int;

	if(len items <= 0){
		cursor = 0;
		return;
	}

	if(cursor < 0)
		cursor = 0;
	if(cursor >= len items)
		cursor = len items - 1;

	if(!deleted[cursor])
		return;

	n = findnextactive(cursor, 1);
	if(n >= 0)
		cursor = n;
}

moveactive(delta: int)
{
	n: int;

	if(activecount() <= 0)
		return;

	ensureactivecursor();

	n = findnextactive(cursor, delta);
	if(n >= 0)
		cursor = n;
}

itemline(i: int): string
{
	prefix: string;

	if(deleted[i]){
		if(i == cursor)
			prefix = "x ";
		else
			prefix = "  ";

		return prefix + "[disabled] " + items[i];
	}

	if(i == cursor)
		prefix = "> ";
	else
		prefix = "  ";

	return prefix + "[active]   " + items[i];
}

setdialogfocus(u: ref IcUi->Ui, yes: int)
{
	if(yes){
		dialogfocus = 1;
		ui->setfocus(u, BtnYesId);
	}
	else{
		dialogfocus = 0;
		ui->setfocus(u, BtnNoId);
	}
}

toggledialogfocus(u: ref IcUi->Ui)
{
	if(dialogfocus)
		setdialogfocus(u, 0);
	else
		setdialogfocus(u, 1);
}

refresh(u: ref IcUi->Ui)
{
	ui->settext(u, StateLine1Id, "Active items: " + sys->sprint("%d", activecount()));
	ui->settext(u, StateLine2Id, "Confirmed deletes: " + sys->sprint("%d", deletes));
	ui->settext(u, StateLine3Id, "Last action: " + lastaction);

	ui->settext(u, Item1Id, itemline(0));
	ui->settext(u, Item2Id, itemline(1));
	ui->settext(u, Item3Id, itemline(2));
	ui->settext(u, Item4Id, itemline(3));
	ui->settext(u, Item5Id, itemline(4));

	if(dialogopen)
		ui->setstatus(u, "modal confirm: Left/Right/Tab switches Yes/No, Enter activates");
	else
		ui->setstatus(u, "confirm dialog: Up/Down selects item, Delete asks confirmation");

	ui->draw(u);
}

showdialog(u: ref IcUi->Ui)
{
	if(activecount() <= 0){
		lastaction = "nothing to delete";
		refresh(u);
		return;
	}

	ensureactivecursor();

	if(deleted[cursor]){
		lastaction = "selected item is disabled";
		refresh(u);
		return;
	}

	dialogopen = 1;
	sendnode(u, DialogLayerId, "node.show");
	setdialogfocus(u, 0);
	lastaction = "confirm requested for " + items[cursor];
	refresh(u);
}

hidedialog(u: ref IcUi->Ui)
{
	dialogopen = 0;
	sendnode(u, DialogLayerId, "node.hide");
	ui->setfocus(u, BtnDeleteId);
}

confirmdelete(u: ref IcUi->Ui)
{
	if(activecount() <= 0){
		lastaction = "nothing to delete";
		hidedialog(u);
		refresh(u);
		return;
	}

	if(deleted[cursor]){
		lastaction = "selected item already disabled";
		hidedialog(u);
		refresh(u);
		return;
	}

	deleted[cursor] = 1;
	deletes++;
	lastaction = "deleted " + items[cursor];

	if(activecount() > 0)
		ensureactivecursor();

	hidedialog(u);
	refresh(u);
}

resetitems()
{
	i: int;

	for(i = 0; i < len deleted; i++)
		deleted[i] = 0;

	cursor = 0;
	deletes = 0;
	lastaction = "reset";
	dialogopen = 0;
	dialogfocus = 0;
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 76);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Up/Down selects active item | Delete opens modal confirm | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 76, 20, " Confirmation dialog template ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 68, "Destructive actions should be isolated behind a modal confirm layer.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, StateBoxId, 3, 4, 32, 8, " Application state ") < 0)
		raise "fail:state box";

	if(ui->label(u, StateBoxId, StateLine1Id, 2, 2, 26, "") < 0)
		raise "fail:state 1";

	if(ui->label(u, StateBoxId, StateLine2Id, 2, 3, 26, "") < 0)
		raise "fail:state 2";

	if(ui->label(u, StateBoxId, StateLine3Id, 2, 5, 26, "") < 0)
		raise "fail:state 3";

	if(ui->window(u, WinId, ListBoxId, 39, 4, 34, 8, " Items ") < 0)
		raise "fail:list box";

	if(ui->label(u, ListBoxId, Item1Id, 2, 1, 28, "") < 0)
		raise "fail:item 1";

	if(ui->label(u, ListBoxId, Item2Id, 2, 2, 28, "") < 0)
		raise "fail:item 2";

	if(ui->label(u, ListBoxId, Item3Id, 2, 3, 28, "") < 0)
		raise "fail:item 3";

	if(ui->label(u, ListBoxId, Item4Id, 2, 4, 28, "") < 0)
		raise "fail:item 4";

	if(ui->label(u, ListBoxId, Item5Id, 2, 5, 28, "") < 0)
		raise "fail:item 5";

	if(ui->button(u, WinId, BtnDeleteId, 3, 17, 12, 1, "Delete", "d", AppTarget, "app.delete") < 0)
		raise "fail:delete";

	if(ui->button(u, WinId, BtnResetId, 17, 17, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 29, 17, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	if(ui->group(u, WinId, DialogLayerId, 0, 0, 76, 20) < 0)
		raise "fail:dialog layer";

	if(ui->shadowwindow(u, DialogLayerId, DialogShadowId, DialogWinId, 18, 6, 40, 9, " Confirm ", 1, 1) < 0)
		raise "fail:dialog window";

	if(ui->label(u, DialogWinId, DialogText1Id, 4, 2, 30, "Delete the selected item?") < 0)
		raise "fail:dialog text 1";

	if(ui->label(u, DialogWinId, DialogText2Id, 4, 3, 32, "Only Yes or No is accepted here.") < 0)
		raise "fail:dialog text 2";

	if(ui->button(u, DialogWinId, BtnYesId, 9, 6, 8, 1, "Yes", "y", AppTarget, "app.confirm.yes") < 0)
		raise "fail:yes";

	if(ui->button(u, DialogWinId, BtnNoId, 23, 6, 8, 1, "No", "n", AppTarget, "app.confirm.no") < 0)
		raise "fail:no";

	items = array[] of {
		"draft.txt",
		"cache.tmp",
		"old.log",
		"backup.zip",
		"notes.md"
	};

	deleted = array[len items] of int;
	resetitems();

	sendnode(u, DialogLayerId, "node.hide");

	ui->setfocus(u, BtnDeleteId);
	refresh(u);
}

handledialogkey(u: ref IcUi->Ui, k: int, cmd: string): int
{
	#
	# Keep modal focus inside the dialog. Even if the framework navigation
	# already moved focus outside, this handler immediately restores it.
	#
	if(k == Icurses->Kleft || k == Icurses->Kright || k == 9 || k == Icurses->Kbacktab){
		toggledialogfocus(u);
		refresh(u);
		return 0;
	}

	if(k == 'y' || k == 'Y' || cmd == "app.confirm.yes"){
		setdialogfocus(u, 1);
		confirmdelete(u);
		return 0;
	}

	if(k == 'n' || k == 'N' || cmd == "app.confirm.no"){
		setdialogfocus(u, 0);
		lastaction = "delete canceled";
		hidedialog(u);
		refresh(u);
		return 0;
	}

	if(ic->isconfirm(k)){
		if(dialogfocus)
			confirmdelete(u);
		else{
			lastaction = "delete canceled";
			hidedialog(u);
			refresh(u);
		}
		return 0;
	}

	if(dialogfocus)
		ui->setfocus(u, BtnYesId);
	else
		ui->setfocus(u, BtnNoId);

	refresh(u);
	return 0;
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.delete"){
		showdialog(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetitems();
		sendnode(u, DialogLayerId, "node.hide");
		ui->setfocus(u, BtnDeleteId);
		refresh(u);
		return 0;
	}

	ui->draw(u);
	return 0;
}

handlekey(u: ref IcUi->Ui, k: int, cmd: string): int
{
	if(dialogopen)
		return handledialogkey(u, k, cmd);

	if(k == Icurses->Kup){
		moveactive(-1);
		lastaction = "cursor moved up";
		refresh(u);
		return 0;
	}

	if(k == Icurses->Kdown){
		moveactive(1);
		lastaction = "cursor moved down";
		refresh(u);
		return 0;
	}

	return handlecmd(u, cmd);
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
			if(ui->isquit(s.key) && !dialogopen)
				done = 1;
			else
				done = handlekey(u, s.key, s.msg.cmd);

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