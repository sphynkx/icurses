#
# 09_04_command_dispatch.b
#
# Demonstrates command dispatch.
#
# Framework commands are sent to UI tree nodes, for example node.toggle.
# Application commands are handled by the application, for example app.export
# and app.build. The difference is visible:
#
#   - Toggle hides/shows a UI node through ui->dispatch().
#   - Export updates an export package panel.
#   - Build advances a build pipeline panel.
#

implement CommandDispatchDemo;

include "draw.m";
include "icurses/ui.m";

CommandDispatchDemo: module
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

DispatchBoxId: con 20;
DispatchTitleId: con 21;
RouteFrameworkId: con 22;
RouteExportId: con 23;
RouteBuildId: con 24;
LastCmdId: con 25;

FrameworkPanelId: con 30;
FrameworkTextId: con 31;
FrameworkStateId: con 32;

ExportPanelId: con 40;
ExportTitleId: con 41;
ExportFileId: con 42;
ExportRowsId: con 43;
ExportProgressId: con 44;

BuildPanelId: con 50;
BuildTitleId: con 51;
BuildStep1Id: con 52;
BuildStep2Id: con 53;
BuildStep3Id: con 54;
BuildProgressId: con 55;

BtnToggleId: con 60;
BtnExportId: con 61;
BtnBuildId: con 62;
BtnResetId: con 63;
BtnExitId: con 64;

frameworkvisible: int;
exports: int;
buildstep: int;
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

buildmark(n: int, text: string): string
{
	if(buildstep >= n)
		return "[x] " + text;

	return "[ ] " + text;
}

exportprogress(): int
{
	v: int;

	v = exports * 25;
	if(v > 100)
		v = 100;

	return v;
}

buildprogress(): int
{
	v: int;

	v = buildstep * 33;
	if(buildstep >= 3)
		v = 100;

	return v;
}

refresh(u: ref IcUi->Ui)
{
	if(frameworkvisible)
		ui->settext(u, FrameworkStateId, "Framework target node: visible");
	else
		ui->settext(u, FrameworkStateId, "Framework target node: hidden");

	if(exports == 0){
		ui->settext(u, ExportFileId, "No export package yet.");
		ui->settext(u, ExportRowsId, "Rows exported: 0");
	}
	else{
		ui->settext(u, ExportFileId, "Package: export-" + sys->sprint("%d", exports) + ".tgz");
		ui->settext(u, ExportRowsId, "Rows exported: " + sys->sprint("%d", exports * 25));
	}
	ui->setprogress(u, ExportProgressId, exportprogress(), 100);

	ui->settext(u, BuildStep1Id, buildmark(1, "configure"));
	ui->settext(u, BuildStep2Id, buildmark(2, "compile"));
	ui->settext(u, BuildStep3Id, buildmark(3, "package"));
	ui->setprogress(u, BuildProgressId, buildprogress(), 100);

	ui->settext(u, LastCmdId, "Last command: " + lastcmd);

	if(frameworkvisible)
		ui->settext(u, BtnToggleId, "[ Hide UI ]");
	else
		ui->settext(u, BtnToggleId, "[ Show UI ]");

	ui->setstatus(u, "dispatch: " + lastcmd);
	ui->draw(u);
}

resetstate(u: ref IcUi->Ui)
{
	exports = 0;
	buildstep = 0;
	lastcmd = "app.reset";

	if(!frameworkvisible){
		sendnode(u, FrameworkPanelId, "node.show");
		frameworkvisible = 1;
	}

	refresh(u);
}

build(u: ref IcUi->Ui, sw, sh: int)
{
	root, x, y: int;

	root = ui->rootid(u);
	x = center(sw, 82);
	y = center(sh, 22);

	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Toggle is framework dispatch | Export and Build are app handlers | q/Esc exits ");

	if(ui->group(u, root, LayerId, 0, 0, sw, sh) < 0)
		raise "fail:layer";

	if(ui->window(u, LayerId, WinId, x, y, 82, 22, " Command dispatch ") < 0)
		raise "fail:window";

	if(ui->label(u, WinId, TitleId, 3, 2, 72, "The same command field can drive framework actions or application logic.") < 0)
		raise "fail:title";

	if(ui->window(u, WinId, DispatchBoxId, 3, 4, 76, 6, " Dispatch map ") < 0)
		raise "fail:dispatch box";

	if(ui->label(u, DispatchBoxId, DispatchTitleId, 2, 1, 68, "Command string decides which handler processes the message:") < 0)
		raise "fail:dispatch title";

	if(ui->label(u, DispatchBoxId, RouteFrameworkId, 4, 2, 68, "app.framework.toggle -> ui->dispatch(node.toggle) -> tree node") < 0)
		raise "fail:route framework";

	if(ui->label(u, DispatchBoxId, RouteExportId, 4, 3, 68, "app.export           -> application handler -> export package panel") < 0)
		raise "fail:route export";

	if(ui->label(u, DispatchBoxId, RouteBuildId, 4, 4, 68, "app.build            -> application handler -> build pipeline panel") < 0)
		raise "fail:route build";

	if(ui->window(u, WinId, FrameworkPanelId, 3, 11, 24, 6, " UI node ") < 0)
		raise "fail:framework panel";

	if(ui->label(u, FrameworkPanelId, FrameworkTextId, 2, 1, 18, "node.toggle target") < 0)
		raise "fail:framework text";

	if(ui->label(u, FrameworkPanelId, FrameworkStateId, 2, 3, 20, "") < 0)
		raise "fail:framework state";

	if(ui->window(u, WinId, ExportPanelId, 29, 11, 24, 6, " Export job ") < 0)
		raise "fail:export panel";

	if(ui->label(u, ExportPanelId, ExportTitleId, 2, 1, 18, "Application data") < 0)
		raise "fail:export title";

	if(ui->label(u, ExportPanelId, ExportFileId, 2, 2, 20, "") < 0)
		raise "fail:export file";

	if(ui->label(u, ExportPanelId, ExportRowsId, 2, 3, 20, "") < 0)
		raise "fail:export rows";

	if(ui->progress(u, ExportPanelId, ExportProgressId, 2, 4, 18, 0, 100) < 0)
		raise "fail:export progress";

	if(ui->window(u, WinId, BuildPanelId, 55, 11, 24, 6, " Build job ") < 0)
		raise "fail:build panel";

	if(ui->label(u, BuildPanelId, BuildTitleId, 2, 1, 18, "Pipeline") < 0)
		raise "fail:build title";

	if(ui->label(u, BuildPanelId, BuildStep1Id, 2, 2, 18, "") < 0)
		raise "fail:build step 1";

	if(ui->label(u, BuildPanelId, BuildStep2Id, 2, 3, 18, "") < 0)
		raise "fail:build step 2";

	if(ui->label(u, BuildPanelId, BuildStep3Id, 2, 4, 18, "") < 0)
		raise "fail:build step 3";

	if(ui->progress(u, BuildPanelId, BuildProgressId, 2, 5, 18, 0, 100) < 0)
		raise "fail:build progress";

	if(ui->label(u, WinId, LastCmdId, 3, 18, 72, "") < 0)
		raise "fail:last command";

	if(ui->button(u, WinId, BtnToggleId, 3, 20, 12, 1, "Hide UI", "t", AppTarget, "app.framework.toggle") < 0)
		raise "fail:toggle";

	if(ui->button(u, WinId, BtnExportId, 17, 20, 12, 1, "Export", "e", AppTarget, "app.export") < 0)
		raise "fail:export";

	if(ui->button(u, WinId, BtnBuildId, 31, 20, 10, 1, "Build", "b", AppTarget, "app.build") < 0)
		raise "fail:build";

	if(ui->button(u, WinId, BtnResetId, 43, 20, 10, 1, "Reset", "r", AppTarget, "app.reset") < 0)
		raise "fail:reset";

	if(ui->button(u, WinId, BtnExitId, 55, 20, 10, 1, "Exit", "q", AppTarget, "app.exit") < 0)
		raise "fail:exit";

	frameworkvisible = 1;
	exports = 0;
	buildstep = 0;
	lastcmd = "none";

	ui->setfocus(u, BtnToggleId);
	refresh(u);
}

handlecmd(u: ref IcUi->Ui, cmd: string): int
{
	if(cmd == "app.exit")
		return 1;

	if(cmd == "app.framework.toggle"){
		sendnode(u, FrameworkPanelId, "node.toggle");
		frameworkvisible = !frameworkvisible;
		lastcmd = "app.framework.toggle -> node.toggle";
		refresh(u);
		return 0;
	}

	if(cmd == "app.export"){
		exports++;
		lastcmd = "app.export";
		refresh(u);
		return 0;
	}

	if(cmd == "app.build"){
		buildstep++;
		if(buildstep > 3)
			buildstep = 1;
		lastcmd = "app.build";
		refresh(u);
		return 0;
	}

	if(cmd == "app.reset"){
		resetstate(u);
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