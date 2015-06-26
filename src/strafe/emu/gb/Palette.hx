package strafe.emu.gb;

import haxe.ds.Vector;


class Palette
{

	public static var palette:Vector<Int> = getColors();

	static function getColors():Vector<Int>
	{
		var baseColors = [
			0xffffff, 0xc0c0c0, 0x606060, 0x000000
		];

		return Vector.fromArrayCopy([for (color in baseColors) convert(color)]);
	}

	static function convert(c:Int):Int
	{
		var r = (c & 0xff0000) >> 16;
		var g = (c & 0xff00) >> 8;
		var b = (c & 0xff);
#if flash
		// store colors as little-endian for flash.Memory
		return (0xff) | ((Std.int(r) & 0xff) << 8) | ((Std.int(g) & 0xff) << 16) | ((Std.int(b) & 0xff) << 24);
#else
		// store colors as big-endian for flash.Memory
		return (0xff000000) | ((Std.int(r) & 0xff) << 16) | ((Std.int(g) & 0xff) << 8) | ((Std.int(b) & 0xff) << 0);
#end
	}

	public static inline function getColor(i:Int) return palette[i];
}
