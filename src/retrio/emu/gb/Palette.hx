package retrio.emu.gb;

import haxe.ds.Vector;


typedef PaletteInfo =
{
	name:String,
	colors:Array<Int>,
}

class Palette
{
	public static var paletteMap:Map<String, Vector<Int>>;
	public static var paletteInfo:Array<PaletteInfo> = [
		{colors: [0xffffff, 0xc0c0c0, 0x606060, 0x000000], name: "default"},
		{colors: [0x9cba29, 0x8cab26, 0x326132, 0x113711], name: "classic green"},
		{colors: [0xe3e6c9, 0xc3c4a5, 0x8e8b61, 0x6c6c4e], name: "pocket"},
		{colors: [0xfff77b, 0xb5ae4a, 0x6b6931, 0x212010], name: "yellow"},
		{colors: [0xf3f3f3, 0xa5a5a5, 0x525252, 0x262626], name: "soft"},
		{colors: [0xe7d79c, 0xb5a66b, 0x7b7163, 0x393829], name: "tan"},
		{colors: [0xf3f3f3, 0xffad63, 0x833100, 0x262626], name: "orange"},
		{colors: [0xf3f3f3, 0x7bff30, 0x008300, 0x262626], name: "lime"},
		{colors: [0xf3f3f3, 0xff8584, 0x833100, 0x262626], name: "cherry"},
		{colors: [0xf3f3f3, 0xfe9494, 0x9394fe, 0x262626], name: "sunset"},
		{colors: [0xf3f3f3, 0x65a49b, 0x0000fe, 0x262626], name: "seaside"},
		{colors: [0xf3f3f3, 0x51ff00, 0xff4200, 0x262626], name: "watermelon"},
		{colors: [0xf3f3f3, 0xff8584, 0x943a3a, 0x262626], name: "salmon"},
		{colors: [0x262626, 0x008486, 0xffde00, 0xf3f3f3], name: "negative"},
		{colors: [0x000000, 0x480000, 0x900000, 0xf00000], name: "virtual reality"},
	];

	static var palettes:Vector<Vector<Int>> = getColors();

	static function getColors():Vector<Vector<Int>>
	{
		var palettes = new Vector(paletteInfo.length);
		paletteMap = new Map();

		for (i in 0 ... paletteInfo.length)
		{
			var info = paletteInfo[i];
			var pal = Vector.fromArrayCopy([for (color in info.colors) convert(color)]);
			palettes[i] = paletteMap[info.name] = pal;
		}

		return palettes;
	}

	static function convert(c:Int):Int
	{
#if (flash || legacy)
		var r = (c & 0xff0000) >> 16;
		var g = (c & 0xff00) >> 8;
		var b = (c & 0xff);

		// store colors as little-endian for flash.Memory
		return (0xff) | ((Std.int(r) & 0xff) << 8) | ((Std.int(g) & 0xff) << 16) | ((Std.int(b) & 0xff) << 24);
#else
		// store colors as big-endian for flash.Memory
		return (0xff000000) | c;
#end
	}

	public var palette:Vector<Int>;

	public function new()
	{
		palette = paletteMap['pocket'];
	}

	public function swapPalettes(name:String)
	{
		palette = paletteMap.exists(name) ? paletteMap[name] : palettes[0];
	}

	public inline function getColor(i:Int) return palette[i];
}
