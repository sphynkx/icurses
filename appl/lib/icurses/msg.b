implement IcMsg;

include "icurses/msg.m";

seqno: int;

init()
{
	seqno = 0;
}

none(): IcMsg->Msg
{
	m: IcMsg->Msg;

	m.src = IcMsg->MsgNoNode;
	m.dst = IcMsg->MsgNoNode;
	m.kind = IcMsg->KindNone;
	m.cmd = "";
	m.route = IcMsg->RouteDirect;
	m.flags = 0;
	m.seq = 0;
	m.sarg = "";
	m.iarg0 = 0;
	m.iarg1 = 0;
	m.iarg2 = 0;
	m.handled = 0;

	return m;
}

newmsg(src, dst: int, kind: int, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;

	seqno++;

	m.src = src;
	m.dst = dst;
	m.kind = kind;
	m.cmd = cmd;
	m.route = IcMsg->RouteDirect;
	m.flags = 0;
	m.seq = seqno;
	m.sarg = "";
	m.iarg0 = 0;
	m.iarg1 = 0;
	m.iarg2 = 0;
	m.handled = 0;

	return m;
}

isnone(m: IcMsg->Msg): int
{
	return m.kind == IcMsg->KindNone;
}