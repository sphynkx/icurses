implement IcForm;

include "icurses/form.m";

IcControl: module
{
	PATH: con "/dis/lib/icurses/control.dis";

	init: fn();

	checked: fn(u: ref IcUi->Ui, id: string): int;
	selected: fn(u: ref IcUi->Ui, groupid: string): string;
};

IcSlider: module
{
	PATH: con "/dis/lib/icurses/slider.dis";

	init: fn();

	value: fn(u: ref IcUi->Ui, id: string): int;
};

sys: Sys;
msg: IcMsg;
input: IcInput;
control: IcControl;
slider: IcSlider;

appendfield: fn(a: array of IcForm->Field, f: IcForm->Field): array of IcForm->Field;
findkey: fn(f: ref IcForm->Form, key: string): int;
fieldvalue: fn(u: ref IcUi->Ui, f: IcForm->Field): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	input = load IcInput IcInput->PATH;
	if(input == nil)
		raise "fail:load icinput";

	control = load IcControl IcControl->PATH;
	if(control == nil)
		raise "fail:load iccontrol";

	slider = load IcSlider IcSlider->PATH;
	if(slider == nil)
		raise "fail:load icslider";

	msg->init();
	input->init();
	control->init();
	slider->init();
}

appendfield(a: array of IcForm->Field, f: IcForm->Field): array of IcForm->Field
{
	r: array of IcForm->Field;
	i: int;

	if(a == nil)
		a = array[0] of IcForm->Field;

	r = array[len a + 1] of IcForm->Field;

	for(i = 0; i < len a; i++)
		r[i] = a[i];

	r[len a] = f;
	return r;
}

findkey(f: ref IcForm->Form, key: string): int
{
	i: int;

	if(f == nil || f.fields == nil)
		return -1;

	for(i = 0; i < len f.fields; i++){
		if(f.fields[i].key == key)
			return i;
	}

	return -1;
}

new(id: string): ref IcForm->Form
{
	f: ref IcForm->Form;

	f = ref IcForm->Form;
	f.id = id;
	f.fields = array[0] of IcForm->Field;

	return f;
}

clear(f: ref IcForm->Form)
{
	if(f == nil)
		return;

	f.fields = array[0] of IcForm->Field;
}

addinput(f: ref IcForm->Form, id, key: string): int
{
	field: IcForm->Field;

	if(f == nil || id == "" || key == "")
		return -1;

	field.kind = IcForm->KindInput;
	field.id = id;
	field.key = key;
	field.value = "";

	f.fields = appendfield(f.fields, field);
	return 0;
}

addcheckbox(f: ref IcForm->Form, id, key: string): int
{
	field: IcForm->Field;

	if(f == nil || id == "" || key == "")
		return -1;

	field.kind = IcForm->KindCheckbox;
	field.id = id;
	field.key = key;
	field.value = "";

	f.fields = appendfield(f.fields, field);
	return 0;
}

addradiogroup(f: ref IcForm->Form, id, key: string): int
{
	field: IcForm->Field;

	if(f == nil || id == "" || key == "")
		return -1;

	field.kind = IcForm->KindRadioGroup;
	field.id = id;
	field.key = key;
	field.value = "";

	f.fields = appendfield(f.fields, field);
	return 0;
}

addslider(f: ref IcForm->Form, id, key: string): int
{
	field: IcForm->Field;

	if(f == nil || id == "" || key == "")
		return -1;

	field.kind = IcForm->KindSlider;
	field.id = id;
	field.key = key;
	field.value = "";

	f.fields = appendfield(f.fields, field);
	return 0;
}

fieldvalue(u: ref IcUi->Ui, f: IcForm->Field): string
{
	if(u == nil)
		return "";

	if(f.kind == IcForm->KindInput)
		return input->text(u, f.id);

	if(f.kind == IcForm->KindCheckbox){
		if(control->checked(u, f.id))
			return "1";
		return "0";
	}

	if(f.kind == IcForm->KindRadioGroup)
		return control->selected(u, f.id);

	if(f.kind == IcForm->KindSlider)
		return sys->sprint("%d", slider->value(u, f.id));

	return "";
}

collect(u: ref IcUi->Ui, f: ref IcForm->Form): int
{
	i: int;
	field: IcForm->Field;

	if(u == nil || f == nil || f.fields == nil)
		return -1;

	for(i = 0; i < len f.fields; i++){
		field = f.fields[i];
		field.value = fieldvalue(u, field);
		f.fields[i] = field;
	}

	return 0;
}

value(f: ref IcForm->Form, key: string): string
{
	i: int;

	i = findkey(f, key);
	if(i < 0)
		return "";

	return f.fields[i].value;
}

setvalue(f: ref IcForm->Form, key, value: string): int
{
	i: int;
	field: IcForm->Field;

	i = findkey(f, key);
	if(i < 0)
		return -1;

	field = f.fields[i];
	field.value = value;
	f.fields[i] = field;

	return 0;
}

summary(f: ref IcForm->Form): string
{
	s: string;
	i: int;

	if(f == nil)
		return "form: nil";

	s = "form " + f.id + ":";

	if(f.fields == nil || len f.fields == 0)
		return s + " empty";

	for(i = 0; i < len f.fields; i++){
		if(i > 0)
			s += "; ";

		s += f.fields[i].key + "=" + f.fields[i].value;
	}

	return s;
}

submit(u: ref IcUi->Ui, f: ref IcForm->Form, dst, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;
	src: string;

	if(f == nil)
		return msg->none();

	collect(u, f);

	src = f.id;
	if(src == "")
		src = "form";

	if(dst == "")
		dst = src;

	if(cmd == "")
		cmd = "form.submit";

	m = msg->newmsg(src, dst, IcMsg->KindCommand, cmd);
	m.sarg = summary(f);
	m.iarg0 = 0;
	m.iarg1 = 0;
	m.iarg2 = 0;

	return m;
}