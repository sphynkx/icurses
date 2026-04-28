include "icurses/input.m";

IcForm: module
{
	PATH: con "/dis/lib/icurses/form.dis";

	KindInput:      con 0;
	KindCheckbox:   con 1;
	KindRadioGroup: con 2;
	KindSlider:     con 3;

	Field: adt
	{
		kind:  int;
		id:    string;
		key:   string;
		value: string;
	};

	Form: adt
	{
		id:     string;
		fields: array of Field;
	};

	init: fn();

	new: fn(id: string): ref Form;
	clear: fn(f: ref Form);

	addinput: fn(f: ref Form, id, key: string): int;
	addcheckbox: fn(f: ref Form, id, key: string): int;
	addradiogroup: fn(f: ref Form, id, key: string): int;
	addslider: fn(f: ref Form, id, key: string): int;

	collect: fn(u: ref IcUi->Ui, f: ref Form): int;

	value: fn(f: ref Form, key: string): string;
	setvalue: fn(f: ref Form, key, value: string): int;

	summary: fn(f: ref Form): string;
	submit: fn(u: ref IcUi->Ui, f: ref Form, dst, cmd: string): IcMsg->Msg;
};