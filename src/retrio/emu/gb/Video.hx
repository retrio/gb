package retrio.emu.gb;

import haxe.ds.Vector;


@:enum
abstract VideoMode(Int) from Int to Int
{
	var Hblank = 0;
	var Vblank = 1;
	var Oam = 2;
	var Vram = 3;
}


typedef SpriteInfo = {
	var x:Int;
	var y:Int;
	var tile:Int;
	var palette:Bool;	// true = second palette
	var xflip:Bool;		// true = flipped
	var yflip:Bool;		// true = flipped
	var behindBg:Bool;	// false = above BG
}


@:build(retrio.macro.Optimizer.build())
class Video
{
	public var cpu:CPU;
	public var memory:Memory;

	public var screenBuffer:ByteString = new ByteString(160 * 144);

	public var oam:ByteString;		// object attribute memory
	public var vram:ByteString;		// video RAM

	public var frameCount:Int = 0;
	public var scanline:Int = 153;
	public var cycles:Int = 396;
	public var stolenCycles:Int = 0;
	public var finished:Bool = false;

	public var lcdDisplay:Bool = true;

	var bgDisplay:Bool = false;
	var objDisplay:Bool = false;
	var tallSprites:Bool = false;
	var bgTileAddr:Int = 0x9800;
	var tileDataAddr:Int = 0x8800;
	var windowDisplay:Bool = false;
	var windowTileAddr:Int = 0x9800;

	public var hblankInterrupt:Bool = false;
	public var vblankInterrupt:Bool = false;
	public var oamInterrupt:Bool = false;
	public var coincidenceInterrupt:Bool = false;
	public var coincidenceScanline:Int = 0;

	var mode:VideoMode = Oam;

	var bgPalette:Vector<Int> = Vector.fromArrayCopy([0, 1, 2, 3]);
	var sp1Palette:Vector<Int> = Vector.fromArrayCopy([0, 1, 2, 3]);
	var sp2Palette:Vector<Int> = Vector.fromArrayCopy([0, 1, 2, 3]);

	var tileBuffer:ByteString;
	var spriteInfo:Vector<SpriteInfo> = new Vector(40);

	var scrollX:Int = 0;
	var scrollY:Int = 0;
	var windowX:Int = 0;
	var windowY:Int = 0;

	var dmaAddress:Int = 0;

	public function new()
	{
		oam = new ByteString(0xa0);
		oam.fillWith(0);

		vram = new ByteString(0x2000);
		vram.fillWith(0);

		tileBuffer = new ByteString(0x8000);
		tileBuffer.fillWith(0);

		screenBuffer.fillWith(0);

		for (i in 0 ... 40) spriteInfo[i] = {x:0, y:0, tile:0, palette:false, xflip:false, yflip:false, behindBg:false};
	}

	public function init(cpu:CPU, memory:Memory)
	{
		this.cpu = cpu;
		this.memory = memory;
	}

	public inline function ioRead(addr:Int):Int
	{
		catchUp();

		switch(addr)
		{
			case 0xff40:
				// LCD control
				return (bgDisplay ? 0x1 : 0) |
					(objDisplay ? 0x2 : 0) |
					(tallSprites ? 0x4 : 0) |
					(bgTileAddr == 0x9c00 ? 0x8 : 0) |
					(tileDataAddr == 0x8000 ? 0x10 : 0) |
					(windowDisplay ? 0x20 : 0) |
					(windowTileAddr == 0x9c00 ? 0x40 : 0) |
					(lcdDisplay ? 0x80 : 0);

			case 0xff41:
				// LCDC status
				return Std.int(mode) |
					(scanline == coincidenceScanline ? 0x4 : 0) |
					(hblankInterrupt ? 0x8 : 0) |
					(vblankInterrupt ? 0x10 : 0) |
					(oamInterrupt ? 0x20 : 0) |
					(coincidenceInterrupt ? 0x40 : 0);

			// scroll
			case 0xff42: return scrollY;
			case 0xff43: return scrollX;

			// scanline
			case 0xff44: return scanline % 153;
			case 0xff45: return coincidenceScanline;

			// DMA
			case 0xff46: return dmaAddress;

			// palettes
			case 0xff47: return getPalette(bgPalette);
			case 0xff48: return getPalette(sp1Palette);
			case 0xff49: return getPalette(sp2Palette);

			// window
			case 0xff4a: return windowY;
			case 0xff4b: return windowX + 7;

			default:
				return memory.hram.get(addr - 0xfe00);
		}
	}

	public inline function ioWrite(addr:Int, value:Int):Void
	{
		catchUp();

		switch(addr)
		{
			case 0xff40:
				bgDisplay = Util.getbit(value, 0);
				objDisplay = Util.getbit(value, 1);
				tallSprites = Util.getbit(value, 2);
				bgTileAddr = Util.getbit(value, 3) ? 0x9c00 : 0x9800;
				tileDataAddr = Util.getbit(value, 4) ? 0x8000 : 0x8800;
				windowDisplay = Util.getbit(value, 5);
				windowTileAddr = Util.getbit(value, 6) ? 0x9c00 : 0x9800;
				lcdDisplay = Util.getbit(value, 7);
				if (!lcdDisplay)
				{
					scanline = cycles = 0;
				}

			case 0xff41:
				// ignore first three bits
				hblankInterrupt = Util.getbit(value, 3);
				vblankInterrupt = Util.getbit(value, 4);
				oamInterrupt = Util.getbit(value, 5);
				coincidenceInterrupt = Util.getbit(value, 6);

			// scroll
			case 0xff42: scrollY = value;
			case 0xff43: scrollX = value;

			// scanline
			case 0xff44: scanline = 0;
			case 0xff45: coincidenceScanline = value;

			// DMA
			case 0xff46:
				if (value > 0x7f && value < 0xe0)
				{
					dmaAddress = value;
					dma();
				}

			// palettes
			case 0xff47: setPalette(bgPalette, value);
			case 0xff48: setPalette(sp1Palette, value);
			case 0xff49: setPalette(sp2Palette, value);

			// window
			case 0xff4a: windowY = value;
			case 0xff4b: windowX = value - 7;

			// destination VRAM
			case 0xff4f: // TODO

			// GBC
			case 0xff68: // TODO
			case 0xff69: // TODO
			case 0xff6a: // TODO

			default: {}
		}
	}

	public inline function oamRead(addr:Int)
	{
		return oam.get(addr - 0xfe00);
	}

	public inline function oamWrite(addr:Int, value:Int)
	{
		oam.set(addr - 0xfe00, value);

		// update sprite info cache
		var obj = (addr - 0xfe00) >> 2;
		if (obj < 40)
		{
			var sprite = spriteInfo[obj];

			switch (addr & 3)
			{
				case 0:
					sprite.y = value - 16;
				case 1:
					sprite.x = value - 8;
				case 2:
					sprite.tile = value;
				default:
					sprite.palette = Util.getbit(value, 4);
					sprite.xflip = Util.getbit(value, 5);
					sprite.yflip = Util.getbit(value, 6);
					sprite.behindBg = Util.getbit(value, 7);
			}
		}
	}

	inline function getPalette(pal:Vector<Int>)
	{
		return pal[0] | (pal[1] << 2) | (pal[2] << 4) | (pal[3] << 6);
	}

	inline function setPalette(pal:Vector<Int>, value:Int)
	{
		pal[0] = value & 0x3;
		pal[1] = (value >> 2) & 0x3;
		pal[2] = (value >> 4) & 0x3;
		pal[3] = (value >> 6) & 0x3;
	}

	inline function dma()
	{
		var startAddr = dmaAddress << 8;
		@unroll for (i in 0 ... 160)
		{
			oamWrite(0xfe00 + i, memory.read(startAddr + i));
		}
	}

	public function catchUp()
	{
		if (lcdDisplay)
		{
			while (cpu.cycles > 0)
			{
				--cpu.cycles;
				stolenCycles += cpu.cycles;
				advance();
				runCycle();
			}
		}
		else
		{
			stolenCycles = cpu.cycles;
			cpu.cycles = 0;
		}
	}

	inline function advance()
	{
		if (++cycles > 455)
		{
			cycles = 0;
			if (++scanline > 153)
			{
				scanline = 0;
				++frameCount;
				finished = true;
			}
			if (lcdDisplay && coincidenceInterrupt && scanline == coincidenceScanline)
			{
				cpu.irq(Interrupt.LcdStat);
			}
		}
	}

	inline function runCycle()
	{
		if (scanline < 144)
		{
			switch (cycles)
			{
				case 0:
					mode = Oam;
					if (oamInterrupt) cpu.irq(Interrupt.LcdStat);

				case 80:
					mode = Vram;

				case 252:
					renderScanline();
					if (hblankInterrupt) cpu.irq(Interrupt.LcdStat);
					mode = Hblank;

				default: {}
			}
		}
		else if (scanline == 144 && cycles == 0)
		{
			cpu.irq(Interrupt.Vblank);
			if (vblankInterrupt) cpu.irq(Interrupt.LcdStat);
			mode = Vblank;
		}
	}

	var _bg:Vector<Bool> = new Vector(160);
	var _spritePriority:Vector<Int> = new Vector(160);
	inline function renderScanline()
	{
		if (!windowDisplay || (scanline < windowY || windowX > 0))
		{
			// background tiles
			var mapOffset = bgTileAddr + (((scanline + scrollY) & 0xf8) << 2);
			var lineOffset = scrollX >> 3;
			var y = (scanline + scrollY) & 0x7;
			var x = scrollX & 0x7;
			var bufferOffset = 160 * scanline;

			var tile = vram[(mapOffset + lineOffset) & 0x1fff] & 0x1ff;
			if (tileDataAddr == 0x8800 && tile < 0x80) tile += 0x100;

			var value:Int, color:Int;
			var pixelEnd:Int = (windowDisplay && scanline >= windowY) ? Std.int(Math.min(160, Math.max(windowX, 0))) : 160;
			for (i in 0 ... pixelEnd)
			{
				value = bgDisplay ? tileBuffer[(tile << 6) + (y << 3) + (x)] : 0;
				_bg[i] = value == 0;
				color = bgPalette[value];
				screenBuffer[bufferOffset++] = color;
				if (++x == 8)
				{
					x = 0;
					lineOffset = (lineOffset + 1) & 0x1f;
					tile = vram[(mapOffset + lineOffset) & 0x1fff] & 0x1ff;
					if (tileDataAddr == 0x8800 && tile < 0x80) tile += 0x100;
				}
			}
		}
		if (windowDisplay && scanline >= windowY)
		{
			// window
			var mapOffset = windowTileAddr + (((scanline - windowY) & 0xf8) << 2);
			var lineOffset = 0;
			var y = scanline & 0x7;
			var x = 0;
			var pixelStart = Std.int(Math.min(160, Math.max(windowX, 0)));
			var bufferOffset = 160 * scanline + pixelStart;

			var tile = (vram[(mapOffset + lineOffset) & 0x1fff] & 0x1ff);
			if (tile < 0x80) tile += 0x100;

			var value:Int, color:Int;
			for (i in pixelStart ... 160)
			{
				value = tileBuffer[(tile << 6) + (y << 3) + (x)];
				_bg[i] = value == 0;
				color = bgPalette[value];
				screenBuffer[bufferOffset++] = color;
				if (++x == 8)
				{
					x = 0;
					lineOffset = (lineOffset + 1);
					tile = (vram[(mapOffset + lineOffset) & 0x1fff] & 0x1ff);
					if (tile < 0x80) tile += 0x100;
				}
			}
		}
		if (!(bgDisplay || windowDisplay))
		{
			var bufferOffset = 160 * scanline;
			// nothing is visible
			for (i in 0 ... 160)
			{
				screenBuffer[bufferOffset + i] = bgPalette[0];
				_bg[i] = false;
			}
		}

		// sprites
		if (objDisplay)
		{
			var height = tallSprites ? 16 : 8;
			// when sprites overlap, the one further to the left takes priority
			// TODO: in color mode, this isn't the case
			for (i in 0 ... 160)
			{
				_spritePriority[i] = 0xff;
			}
			var spriteCount:Int = 0;
			for (sprite in spriteInfo)
			{
				var x = sprite.x, y = sprite.y;
				if (y <= scanline && y+height > scanline)
				{
					var pal = sprite.palette ? sp2Palette : sp1Palette;
					var bufferOffset = 160 * scanline + x;
					var tileRow = (sprite.tile << 6) + ((sprite.yflip ? (height - 1 - (scanline - y)) : (scanline - y)) << 3);

					var displayed:Bool = false;
					var value:Int, color:Int;
					@unroll for (xi in 0 ... 8)
					{
						if (x + xi >= 0 && x + xi < 160 && (!sprite.behindBg || _bg[x+xi]) && x < _spritePriority[x + xi])
						{
							value = tileBuffer[tileRow + (sprite.xflip ? (7-xi) : (xi))];
							if (value > 0)
							{
								displayed = true;
								color = pal[value];
								screenBuffer[bufferOffset+xi] = color;
								_spritePriority[x + xi] = x;
							}
						}
					}
					if (displayed) if (++spriteCount >= 10) break;
				}
			}
		}
	}

	public inline function vramRead(addr:Int):Int
	{
		catchUp();
		return vram[addr & 0x1fff];
	}

	public inline function vramWrite(addr:Int, value:Int):Void
	{
		catchUp();

		vram.set(addr & 0x1fff, value);
		updateTile(addr, value);
	}

	inline function updateTile(addr:Int, value:Int)
	{
		addr &= 0x1ffe;
		var tile = (addr >> 4) & 0x1ff;
		var y = (addr >> 1) & 7;

		@unroll for (x in 0 ... 8)
		{
			tileBuffer.set(
				(tile << 6) + (y << 3) + x,
				(Util.getbit(vram[addr], 7-x) ? 1 : 0) +
				(Util.getbit(vram[addr+1], 7-x) ? 2 : 0)
			);
		}
	}
}
