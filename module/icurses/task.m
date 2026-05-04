include "icurses/ui.m";

IcTask: module
{
	PATH: con "/dis/lib/icurses/task.dis";

	Task: adt
	{
		id: int;

		phase: string;
		src: string;
		dst: string;
		item: string;

		itemvalue: int;
		totalvalue: int;
		meter: int;

		ticks: int;
	};

	init: fn();

	new: fn(id: int): ref Task;
	reset: fn(t: ref Task);

	setphase: fn(t: ref Task, phase: string): int;
	setpaths: fn(t: ref Task, src, dst: string): int;
	setitem: fn(t: ref Task, item: string): int;
	setvalues: fn(t: ref Task, itemvalue, totalvalue, meter: int): int;

	render: fn(u: ref IcUi->Ui, t: ref Task): int;

	tick: fn(u: ref IcUi->Ui, t: ref Task): IcMsg->Msg;
	advance: fn(u: ref IcUi->Ui, t: ref Task, itemdelta, totaldelta, meterdelta: int): IcMsg->Msg;
	complete: fn(u: ref IcUi->Ui, t: ref Task): IcMsg->Msg;

	summary: fn(t: ref Task): string;
};