package retrio.emu.gb;

import haxe.ds.Vector;


@:enum
abstract Interrupt(Int) from Int to Int
{
	var Vblank = 0;
	var LcdStat = 1;
	var Timer = 2;
	var Serial = 3;
	var Joypad = 4;

	public static var vectors:Vector<Int> = Vector.fromArrayCopy([
		0x40, 0x48, 0x50, 0x58, 0x60
	]);
}
