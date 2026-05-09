#
# 11_04_input_field.b
#
# Demonstrates Input helper elements.
#
# The input field supports text editing, cursor movement and submit. When the
# input field is active, Left/Right keys are handled by the input helper for
# cursor movement instead of being used for focus navigation.
#

implement InputFieldDemo;

include "draw.m";
include "icurses/input.m";

InputFieldDemo: module
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

FormBoxId: con 20;
NameInputId: con 21;
HintId: con 22;

InspectBoxId: con 30;
RawTextId: con 31;
CursorId: con 32;
LastMsgId: con 33;
SubmitId: con 34;

BtnFocusId: con 40;
BtnClearId: con 41;
BtnSampleId: con 42;
BtnExitId: con 43;

submits: int;
lastmsg: string;
lastsubmit: string;
inputactive: int;

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

refresh(u: ref IcUi->Ui, m: IcMsg->Msg)
{
	text: string;

	text = input->text(u, NameInputId);

	ui->settext(u, RawTextId, "Text: " + text);
	ui->settext(u, CursorId, "Length: " + sys->sprint("%d", len text));
	ui->settext(u, LastMsgId, "Last input msg: " + lastmsg);
	ui->settext(u, SubmitId, "Submits: " + sys->sprint("%d", submits) + "  last=" + lastsubmit);

	if(m.kind != IcMsg->KindNone)
		ui->setstatus(u, "input event: " + m.cmd);
	else
		ui->setstatus(u, "input field ready");

	ui->draw(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;
	m: IcMsg->Msg;

	root = ui->rootid(u);
	x = center(sw, 78);
	y = center(sh, 18);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Type in input field | Left/Right move cursor | Enter submits | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 78, 18, " Input field ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 68, "Input is an editable focusable control with text and cursor state.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, FormBoxId, 3, 4, 35, 7, " Form ") < 0)
		raise "fail:form box";

	if(input->input(u, FormBoxId, NameInputId, 2, 2, 30, "Name:", "n", AppTarget, "app.input.submit", "inferno", 24) < 0)
		raise "fail:input";

	if(ui->label(u, FormBoxId, HintId, 2, 4, 30, "Try typing, Backspace, Left/Right.") < 0)
		raise "fail:hint";

	if(ui->window(u, WinId, InspectBoxId, 41, 4, 34, 7, " Input inspector ") < 0)
		raise "fail:inspect box";

	if(ui->label(u, InspectBoxId, RawTextId, 2, 1, 28, "") < 0)
		raise "fail:raw text";

	if(ui->label(u, InspectBoxId, CursorId, 2, 2, 28, "") < 0)
		raise "fail:cursor";

	if(ui->label(u, InspectBoxId, LastMsgId, 2, 3, 28, "") < 0)
		raise "fail:last msg";

	if(ui->label(u, InspectBoxId, SubmitId, 2, 5, 28, "") < 0)
		raise "fail:submit";

	if(ui->button(u, WinId, BtnFocusId, 3, 14, 10, 1, "Focus", "f", AppTarget, "app.focus") < 0)
		raise "fail:focus";

	if(ui->button(u, WinId, BtnClearId, 15, 14, 10, 1, "Clear", "c", AppTarget, "app.clear") < 0)
		raise "fail:clear";

	if(ui->button(u, WinId, BtnSampleId, 27, 14, 12, 1, "Sample", "s", AppTarget, "app.sample") < 0)
		raise "fail:sample";

	if(ui->button(u, WinId, BtnExitId, 41, 14, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	submits = 0;
	lastmsg = "none";
	lastsubmit = "none";
	inputactive = 1;

	ui->setfocus(u, NameInputId);
	m = input->settext(u, NameInputId, input->text(u, NameInputId));
	refresh(u, m);
}

handlemsg(u: ref IcUi->Ui, m: IcMsg->Msg): int
{
	if(m.cmd == "app.exit")
		return 1;

	if(m.cmd == "app.focus"){
		inputactive = 1;
		ui->setfocus(u, NameInputId);
		lastmsg = "focus input";
		refresh(u, m);
		return 0;
	}

	if(m.cmd == "app.clear"){
		inputactive = 1;
		m = input->settext(u, NameInputId, "");
		input->setcursor(u, NameInputId, 0);
		ui->setfocus(u, NameInputId);
		lastmsg = "clear";
		refresh(u, m);
		return 0;
	}

	if(m.cmd == "app.sample"){
		m = input->settext(u, NameInputId, "worker-01");
		input->setcursor(u, NameInputId, len "worker-01");
		lastmsg = "sample inserted";
		refresh(u, m);
		return 0;
	}

	if(m.cmd == "app.input.submit"){
		submits++;
		lastsubmit = m.sarg;
		lastmsg = "submit";
		inputactive = 1;
		ui->setfocus(u, NameInputId);
		refresh(u, m);
		return 0;
	}

	if(m.kind != IcMsg->KindNone){
		lastmsg = m.cmd;
		refresh(u, m);
		return 0;
	}

	ui->draw(u);
	return 0;
}

run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	m: IcMsg->Msg;
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
			else{
				if(inputactive)
					ui->setfocus(u, NameInputId);

				m = input->handlekey(u, s.key);
				if(m.kind == IcMsg->KindNone)
					m = s.msg;

				if(m.cmd != "input.edit" && m.cmd != "input.cursor")
					inputactive = 0;
				if(m.kind == IcMsg->KindInput)
					inputactive = 1;

				done = handlemsg(u, m);
			}

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