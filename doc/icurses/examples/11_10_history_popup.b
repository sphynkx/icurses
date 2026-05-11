#
# 11_10_history_popup.b
#
# Demonstrates a history popup.
#
# The input field can be edited explicitly:
#
#   - Edit focuses the input field and enables text editing.
#   - Left/Right are handled by the input helper while editing.
#   - Tab, Up or Down leave editing mode and return to button navigation.
#   - Enter submits the current input and leaves editing mode.
#   - Done leaves editing mode without submitting.
#   - Prev/Next browse history.
#   - Apply copies the current history item into the input field.
#   - Submit stores current text into history.
#

implement HistoryPopupDemo;

include "draw.m";
include "icurses/input.m";

HistoryPopupDemo: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

sys: Sys;
ic: Icurses;
ui: IcUi;
input: IcInput;

out: ref Sys->FD;
appscreen: int;

AppTarget: con 1;

LayerId: con 10;
WinId: con 11;
TitleId: con 12;

InputBoxId: con 20;
CommandInputId: con 21;
HintId: con 22;

PopupWinId: con 30;
PopupLine1Id: con 31;
PopupLine2Id: con 32;
PopupLine3Id: con 33;
PopupLine4Id: con 34;
PopupLine5Id: con 35;

InfoBoxId: con 40;
SummaryId: con 41;
CurrentId: con 42;
SubmitCountId: con 43;
ModeId: con 44;

BtnEditId: con 50;
BtnDoneId: con 51;
BtnPrevId: con 52;
BtnNextId: con 53;
BtnApplyId: con 54;
BtnSubmitId: con 55;
BtnExitId: con 56;

hist: array of string;
hsel: int;
submits: int;
editing: int;

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

	input = load IcInput IcInput->PATH;
	if(input == nil)
		raise "fail:load icinput";

	ic->init();
	ui->init();
	input->init();
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

currenthistory(): string
{
	if(hsel < 0 || hsel >= len hist)
		return "";

	return hist[hsel];
}

histline(i: int): string
{
	if(i < 0 || i >= len hist)
		return "";

	if(i == hsel)
		return "> " + hist[i];

	return "  " + hist[i];
}

refresh(u: ref IcUi->Ui, note: string)
{
	ui->settext(u, PopupLine1Id, histline(0));
	ui->settext(u, PopupLine2Id, histline(1));
	ui->settext(u, PopupLine3Id, histline(2));
	ui->settext(u, PopupLine4Id, histline(3));
	ui->settext(u, PopupLine5Id, histline(4));

	ui->settext(u, SummaryId, "History items: " + sys->sprint("%d", len hist));
	ui->settext(u, CurrentId, "Current history item: " + currenthistory());
	ui->settext(u, SubmitCountId, "Submitted commands: " + sys->sprint("%d", submits));

	if(editing)
		ui->settext(u, ModeId, "Mode: editing input");
	else
		ui->settext(u, ModeId, "Mode: button navigation");

	if(note == "")
		note = "history popup ready";

	ui->setstatus(u, note);
	ui->draw(u);
}

addhistory(s: string)
{
	r: array of string;
	i, n: int;

	if(s == "")
		return;

	n = len hist;
	if(n >= 5)
		n = 4;

	r = array[n + 1] of string;
	r[0] = s;

	for(i = 0; i < n; i++)
		r[i + 1] = hist[i];

	hist = r;
	hsel = 0;
}

applyhistory(u: ref IcUi->Ui)
{
	s: string;

	s = currenthistory();
	if(s == "")
		return;

	input->settext(u, CommandInputId, s);
	input->setcursor(u, CommandInputId, len s);
}

submitinput(u: ref IcUi->Ui)
{
	s: string;

	s = input->text(u, CommandInputId);
	addhistory(s);
	submits++;
	editing = 0;
	ui->setfocus(u, BtnSubmitId);
	refresh(u, "submitted: " + s);
}

leaveedit(u: ref IcUi->Ui, id: int, note: string)
{
	editing = 0;
	ui->setfocus(u, id);
	refresh(u, note);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);
	x = center(sw, 80);
	y = center(sh, 20);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Edit enables input | Left/Right edit cursor | Tab/Up/Down leave edit mode ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 86, 20, " History popup ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 70, "History popup stores submitted input values and applies them later.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, InputBoxId, 3, 4, 36, 6, " Command input ") < 0)
		raise "fail:input box";

	if(input->input(u, InputBoxId, CommandInputId, 2, 2, 30, "cmd:", "", AppTarget, "app.input.submit", "build all", 32) < 0)
		raise "fail:input";

	if(ui->label(u, InputBoxId, HintId, 2, 4, 30, "Use Edit before typing text.") < 0)
		raise "fail:hint";

	if(ui->window(u, WinId, PopupWinId, 5, 10, 32, 7, " History ") < 0)
		raise "fail:popup window";

	if(ui->label(u, PopupWinId, PopupLine1Id, 2, 1, 26, "") < 0)
		raise "fail:popup line 1";

	if(ui->label(u, PopupWinId, PopupLine2Id, 2, 2, 26, "") < 0)
		raise "fail:popup line 2";

	if(ui->label(u, PopupWinId, PopupLine3Id, 2, 3, 26, "") < 0)
		raise "fail:popup line 3";

	if(ui->label(u, PopupWinId, PopupLine4Id, 2, 4, 26, "") < 0)
		raise "fail:popup line 4";

	if(ui->label(u, PopupWinId, PopupLine5Id, 2, 5, 26, "") < 0)
		raise "fail:popup line 5";

	if(ui->window(u, WinId, InfoBoxId, 43, 4, 40, 11, " History inspector ") < 0)
		raise "fail:info box";

	if(ui->label(u, InfoBoxId, SummaryId, 2, 1, 28, "") < 0)
		raise "fail:summary";

	if(ui->label(u, InfoBoxId, CurrentId, 2, 3, 36, "") < 0)
		raise "fail:current";

	if(ui->label(u, InfoBoxId, SubmitCountId, 2, 5, 28, "") < 0)
		raise "fail:submit count";

	if(ui->label(u, InfoBoxId, ModeId, 2, 7, 28, "") < 0)
		raise "fail:mode";

	if(ui->button(u, WinId, BtnEditId, 3, 18, 9, 1, "Edit", "e", AppTarget, "app.edit") < 0)
		raise "fail:edit";

	if(ui->button(u, WinId, BtnDoneId, 14, 18, 9, 1, "Done", "d", AppTarget, "app.done") < 0)
		raise "fail:done";

	if(ui->button(u, WinId, BtnPrevId, 25, 18, 9, 1, "Prev", "p", AppTarget, "app.prev") < 0)
		raise "fail:prev";

	if(ui->button(u, WinId, BtnNextId, 36, 18, 9, 1, "Next", "n", AppTarget, "app.next") < 0)
		raise "fail:next";

	if(ui->button(u, WinId, BtnApplyId, 47, 18, 10, 1, "Apply", "a", AppTarget, "app.apply") < 0)
		raise "fail:apply";

	if(ui->button(u, WinId, BtnSubmitId, 59, 18, 10, 1, "Submit", "s", AppTarget, "app.submit") < 0)
		raise "fail:submit";

	if(ui->button(u, WinId, BtnExitId, 71, 18, 8, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	hist = array[] of {
		"build all",
		"test ui",
		"deploy staging",
		"open README",
		"save draft"
	};

	hsel = 0;
	submits = 0;
	editing = 0;

	ui->setfocus(u, BtnEditId);
	m = input->settext(u, CommandInputId, input->text(u, CommandInputId));
	m = m;

	refresh(u, "");
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.edit"){
		editing = 1;
		ui->setfocus(u, CommandInputId);
		refresh(u, "input editing enabled");
		return 0;
	}

	if(cmd == "app.done"){
		leaveedit(u, BtnDoneId, "button navigation enabled");
		return 0;
	}

	if(cmd == "app.prev"){
		editing = 0;
		hsel--;
		if(hsel < 0)
			hsel = len hist - 1;
		ui->setfocus(u, BtnPrevId);
		refresh(u, "history previous");
		return 0;
	}

	if(cmd == "app.next"){
		editing = 0;
		hsel++;
		if(hsel >= len hist)
			hsel = 0;
		ui->setfocus(u, BtnNextId);
		refresh(u, "history next");
		return 0;
	}

	if(cmd == "app.apply"){
		editing = 0;
		applyhistory(u);
		ui->setfocus(u, BtnApplyId);
		refresh(u, "history applied");
		return 0;
	}

	if(cmd == "app.submit" || cmd == "app.input.submit"){
		submitinput(u);
		return 0;
	}

	ui->draw(u);
	return 0;
}

handleeditkey(u: ref IcUi->Ui, k: int): int
{
	m: IcMsg->Msg;

	if(k == 9 || k == Icurses->Kbacktab){
		leaveedit(u, BtnDoneId, "left edit mode with Tab");
		return 0;
	}

	if(k == Icurses->Kup){
		leaveedit(u, BtnPrevId, "left edit mode with Up");
		return 0;
	}

	if(k == Icurses->Kdown){
		leaveedit(u, BtnNextId, "left edit mode with Down");
		return 0;
	}

	ui->setfocus(u, CommandInputId);
	m = input->handlekey(u, k);

	if(m.kind != IcMsg->KindNone)
		return handlecmd(u, m.cmd);

	refresh(u, "editing input");
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
			else if(editing)
				done = handleeditkey(u, s.key);
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