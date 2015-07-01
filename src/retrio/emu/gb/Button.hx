package retrio.emu.gb;


@:enum
abstract Button(Int) from Int to Int
{
	var A = 0;
	var B = 1;
	var Select = 2;
	var Start = 3;
	var Right = 4;
	var Left = 5;
	var Up = 6;
	var Down = 7;
}
