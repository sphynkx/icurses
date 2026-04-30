implement IcTask;

include "icurses/task.m";

sys: Sys;
msg: IcMsg;
ui: IcUi;

clamp: fn(v, lo, hi: int): int;
wrapmeter: fn(v: int): int;
makemsg: fn(t: ref IcTask->Task, cmd: string): IcMsg->Msg;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	msg->init();
	ui->init();
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

wrapmeter(v: int): int
{
	while(v < 0)
		v += 101;

	while(v > 100)
		v -= 101;

	return v;
}

new(id: string): ref IcTask->Task
{
	t: ref IcTask->Task;

	t = ref IcTask->Task;
	t.id = id;

	reset(t);

	return t;
}

reset(t: ref IcTask->Task)
{
	if(t == nil)
		return;

	t.phase = "Preparing";
	t.src = "";
	t.dst = "";
	t.item = "";

	t.itemvalue = 0;
	t.totalvalue = 0;
	t.meter = 0;

	t.ticks = 0;
}

setphase(t: ref IcTask->Task, phase: string): int
{
	if(t == nil)
		return -1;

	t.phase = phase;
	return 0;
}

setpaths(t: ref IcTask->Task, src, dst: string): int
{
	if(t == nil)
		return -1;

	t.src = src;
	t.dst = dst;

	return 0;
}

setitem(t: ref IcTask->Task, item: string): int
{
	if(t == nil)
		return -1;

	t.item = item;
	return 0;
}

setvalues(t: ref IcTask->Task, itemvalue, totalvalue, meter: int): int
{
	if(t == nil)
		return -1;

	t.itemvalue = clamp(itemvalue, 0, 100);
	t.totalvalue = clamp(totalvalue, 0, 100);
	t.meter = clamp(meter, 0, 100);

	return 0;
}

render(u: ref IcUi->Ui, t: ref IcTask->Task): int
{
	if(u == nil || t == nil || t.id == "")
		return -1;

	t.itemvalue = clamp(t.itemvalue, 0, 100);
	t.totalvalue = clamp(t.totalvalue, 0, 100);
	t.meter = clamp(t.meter, 0, 100);

	return ui->settaskdialog(u, t.id,
		t.phase,
		t.src,
		t.dst,
		t.item,
		t.itemvalue,
		t.totalvalue,
		t.meter);
}

makemsg(t: ref IcTask->Task, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;

	if(t == nil)
		return msg->none();

	m = msg->newmsg(t.id, t.id, IcMsg->KindCommand, cmd);
	m.sarg = summary(t);
	m.iarg0 = t.itemvalue;
	m.iarg1 = t.totalvalue;
	m.iarg2 = t.meter;

	return m;
}

tick(u: ref IcUi->Ui, t: ref IcTask->Task): IcMsg->Msg
{
	if(t == nil)
		return msg->none();

	t.ticks++;

	if(u != nil && t.id != "")
		ui->ticktaskdialog(u, t.id);

	return makemsg(t, "task.tick");
}

advance(u: ref IcUi->Ui, t: ref IcTask->Task, itemdelta, totaldelta, meterdelta: int): IcMsg->Msg
{
	if(t == nil)
		return msg->none();

	t.itemvalue = clamp(t.itemvalue + itemdelta, 0, 100);
	t.totalvalue = clamp(t.totalvalue + totaldelta, 0, 100);
	t.meter = wrapmeter(t.meter + meterdelta);
	t.ticks++;

	if(u != nil)
		render(u, t);

	return makemsg(t, "task.advance");
}

complete(u: ref IcUi->Ui, t: ref IcTask->Task): IcMsg->Msg
{
	if(t == nil)
		return msg->none();

	t.itemvalue = 100;
	t.totalvalue = 100;
	t.meter = 100;
	t.ticks++;

	if(u != nil)
		render(u, t);

	return makemsg(t, "task.complete");
}

summary(t: ref IcTask->Task): string
{
	if(t == nil)
		return "task: nil";

	return "task " +
		t.id +
		": phase=" +
		t.phase +
		"; src=" +
		t.src +
		"; dst=" +
		t.dst +
		"; item=" +
		t.item +
		"; itemvalue=" +
		sys->sprint("%d", t.itemvalue) +
		"; totalvalue=" +
		sys->sprint("%d", t.totalvalue) +
		"; meter=" +
		sys->sprint("%d", t.meter) +
		"; ticks=" +
		sys->sprint("%d", t.ticks);
}