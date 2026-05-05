#
# 00_sceleton.b
#
# Minimal icurses application skeleton.
#
# This example is intended as a starting point for new applications.
# It demonstrates the smallest complete program structure that:
#   - loads the required modules,
#   - creates a UI,
#   - builds a minimal widget tree,
#   - runs a step-based event loop,
#   - exits cleanly and restores the terminal.
#
# The example is intentionally simple. It is useful as a template that can be
# copied and extended into a real application.
#

implement IcursesSkeleton;

include "draw.m";
include "icurses/ui.m";

IcursesSkeleton: module
{
	#
	# Standard Inferno application entry point.
	#
	init: fn(nil: ref Draw->Context, nil: list of string);
};

#
# Runtime module handles loaded with load().
#
sys: Sys;
ic: Icurses;
ui: IcUi;

#
# Output file descriptor used by the renderer and terminal helpers.
#
out: ref Sys->FD;

#
# Tracks whether the application has entered the alternate/app screen.
#
appscreen: int;

#
# Application target used by button commands routed back to the app loop.
#
AppTarget: con 1;

#
# Static node ids used by this minimal example.
# These ids are intentionally simple and explicit so the example is easy to read.
#
MainLayerId: con 10;
MainWinId:   con 11;
MainTextId:  con 12;
BtnExitId:   con 13;

#
# Load required runtime modules.
#
# The example uses:
#   Sys     - system calls and file descriptors,
#   Icurses - terminal helpers and terminal size,
#   IcUi    - high-level UI layer.
#
# Each loaded module is checked and then initialized.
#
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

#
# Enter alternate/app screen.
#
# This gives the example its own temporary screen buffer so the shell contents
# are restored after exit.
#
enterappscreen()
{
	if(out == nil)
		return;

	if(appscreen)
		return;

	sys->fprint(out, "%c[?1049h", 27);
	ic->resettty(out);
	ic->hidecursor(out);
	ic->cleartty(out);

	appscreen = 1;
}

#
# Leave alternate/app screen and restore normal terminal state.
#
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

#
# Build the minimal UI tree.
#
# Parameters:
#   u  - active UI instance returned by ui->new().
#   sw - terminal width in columns.
#   sh - terminal height in rows.
#
# This function creates:
#   root
#   └── MainLayerId
#       └── MainWinId
#           ├── MainTextId
#           └── BtnExitId
#
# The window is centered approximately on screen and contains:
#   - one static label,
#   - one Exit button.
#
build(u: ref IcUi->Ui, sw, sh: int)
{
	root: int;
	winx, winy: int;
	winw, winh: int;

	#
	# root is the id of the automatically created root container.
	#
	root = ui->rootid(u);

	#
	# Window size for this minimal example.
	#
	winw = 40;
	winh = 7;

	#
	# Approximate center placement.
	#
	winx = (sw - winw) / 2;
	winy = (sh - winh) / 2;

	if(winx < 0)
		winx = 0;
	if(winy < 0)
		winy = 0;

	#
	# Reserve bottom rows for help and status text.
	#
	ui->setstatusrows(u, sh - 2, sh - 1);
	ui->sethelp(u, " Tab changes focus | Enter activates button | q/Esc exits ");

	#
	# Create the top-level application layer under the root.
	#
	if(ui->group(u, root, MainLayerId, 0, 0, sw, sh) < 0)
		raise "fail:main layer";

	#
	# Create the main window.
	#
	if(ui->window(u, MainLayerId, MainWinId, winx, winy, winw, winh, " Skeleton ") < 0)
		raise "fail:main window";

	#
	# Create a static label inside the window.
	#
	if(ui->label(u, MainWinId, MainTextId, 3, 2, 30, "Minimal icurses skeleton") < 0)
		raise "fail:main text";

	#
	# Create an Exit button.
	#
	# Parameters:
	#   u         - UI instance,
	#   MainWinId - parent container,
	#   BtnExitId - node id,
	#   14, 4     - x, y inside the window,
	#   10, 1     - width and height,
	#   "Exit"    - visible label,
	#   ""        - no hotkey string,
	#   AppTarget - command target handled by the app loop,
	#   "app.exit"- command string delivered on activation.
	#
	if(ui->button(u, MainWinId, BtnExitId, 14, 4, 10, 1, "Exit", "", AppTarget, "app.exit") < 0)
		raise "fail:exit button";

	#
	# Set initial focus and status text.
	#
	ui->setfocus(u, BtnExitId);
	ui->setstatus(u, "Ready");
}

#
# Run the application.
#
# This function:
#   - prepares terminal output,
#   - enters app screen,
#   - determines terminal size,
#   - creates and builds the UI,
#   - starts the UI event loop,
#   - handles the Exit command,
#   - closes the UI and restores the terminal.
#
run()
{
	u: ref IcUi->Ui;
	s: IcUi->Step;
	w, h: int;
	done: int;

	#
	# stdout becomes the renderer output stream.
	#
	out = sys->fildes(1);
	appscreen = 0;

	enterappscreen();

	#
	# Read terminal size and use safe defaults if it is unavailable.
	#
	(w, h) = ic->termsize();
	if(w <= 0)
		w = Icurses->DefaultCols;
	if(h <= 0)
		h = Icurses->DefaultRows;

	#
	# Create the UI object.
	#
	u = ui->new(out, w, h);
	if(u == nil){
		leaveappscreen();
		sys->print("cannot create ui\n");
		return;
	}

	#
	# Build widget tree and perform first draw.
	#
	build(u, w, h);
	ui->draw(u);

	#
	# Start input processing and internal UI state.
	#
	if(ui->start(u) < 0){
		ui->close(u);
		leaveappscreen();
		sys->print("cannot start ui\n");
		return;
	}

	done = 0;

	#
	# Main step loop.
	#
	# The loop exits on:
	#   - StepDone from the framework,
	#   - command "app.exit" from the Exit button.
	#
	for(; !done;){
		s = ui->step(u);

		case s.kind {
		IcUi->StepDone =>
			done = 1;

		IcUi->StepKey =>
			if(s.msg.cmd == "app.exit")
				done = 1;
			else
				ui->draw(u);

		IcUi->StepTick =>
			;

		IcUi->StepMouse =>
			;

		* =>
			;
		}
	}

	#
	# Close UI and restore terminal.
	#
	ui->close(u);
	leaveappscreen();

	sys->print("result: ok\n");
}

#
# Application entry point.
#
# The example performs only two high-level actions:
#   1. load and initialize modules,
#   2. run the application.
#
init(nil: ref Draw->Context, nil: list of string)
{
	loadmods();
	run();
}