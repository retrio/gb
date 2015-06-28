package strafe.emu.gb;

import haxe.ds.Vector;
import strafe.emu.gb.mbcs.*;


class Cart
{
	public var name:String;
	public var gbc:Bool;
	public var sgb:Bool;
	public var japan:Bool;
	public var version:Int;
	public var checksum:Int;
	public var globalChecksum:Int;

	public var romSize:Int;
	public var ramSize:Int;

	public var cpu:CPU;
	public var mbc:MBC;
	public var video:Video;

	public var rom1:ByteString;		// fixed ROM bank
	public var rom2:ByteString;		// switchable ROM bank

	public var ram:ByteString;		// external RAM
	public var wram1:ByteString;	// fixed work RAM
	public var wram2:ByteString;	// switchable work RAM
	public var hram:ByteString;		// HRAM

	public var romBanks:Vector<ByteString>;
	public var ramBanks:Vector<ByteString>;
	public var wramBanks:Vector<ByteString>;

	public var rtc:Int = 0;			// RTC register selected or 0 if none

	var rtcTime:Date = Date.now();	// latched RTC time
	var rtcLatch:Bool = false;

	public function new(file:FileWrapper)
	{
		// initial memory allocation
		hram = new ByteString(0x200);
		hram.fillWith(0);

		wramBanks = new Vector(8);
		for (i in 0 ... 8)
		{
			wramBanks[i] = new ByteString(0x1000);
			wramBanks[i].fillWith(0);
		}
		wram1 = wramBanks[0];
		wram2 = wramBanks[1];

		// read fixed ROM bank
		rom1 = new ByteString(0x4000);
		rom1.readFrom(file);

		name = "";
		for (i in 0x134 ... 0x144)
		{
			var c = rom1[i];
			if (c > 0) name += String.fromCharCode(c);
		}

		sgb = rom1.get(0x146) != 0;

		var cartType = rom1[0x147];
		switch (cartType)
		{
			case 0x00, 0x08, 0x09:
				mbc = new NoMBC();
			case 0x01, 0x02, 0x03:
				mbc = new MBC1();
			case 0x05, 0x06:
				mbc = new MBC2();
			case 0xf, 0x10, 0x11, 0x12, 0x13:
				mbc = new MBC3();
			// TODO: MBC5
			default:
				throw "Cart type " + StringTools.hex(cartType) + " not supported";
		}
		mbc.cart = this;

		// read additional ROM banks
		var romSizeByte = rom1[0x148];
		var romBankCount:Int;
		if (romSizeByte < 8)
		{
			romSize = 0x8000 * Std.int(Math.pow(2, romSizeByte));
			romBankCount = Std.int(romSize / 0x4000);
		}
		else
		{
			switch(romSizeByte)
			{
				case 0x52:
					romBankCount = 72;
				case 0x53:
					romBankCount = 80;
				case 0x54:
					romBankCount = 96;
				default:
					throw "Unrecognized rom size byte: " + StringTools.hex(romSizeByte);
			}
			romSize = romBankCount * 0x4000;
		}

		romBanks = new Vector(romBankCount);
		romBanks[0] = rom1;
		for (i in 1 ... romBankCount)
		{
			romBanks[i] = new ByteString(0x4000);
			romBanks[i].readFrom(file);
		}
		rom2 = romBanks[1];

		var ramSizeByte = rom1[0x149];
		ramSize = switch(ramSizeByte)
		{
			case 1: 0x2000;
			case 2: 0x4000;
			case 3: 0x8000;
			case 4: 0x20000;
			case 5: 0x10000;
			default: 0;
		}
		var ramBankCount = Std.int(Math.max(Math.ceil(ramSize/0x2000), 1));
		ramBanks = new Vector(ramBankCount);
		for (i in 0 ... ramBankCount)
		{
			ramBanks[i] = new ByteString(0x2000);
			ramBanks[i].fillWith(0);
		}
		ram = ramBanks[0];

		japan = rom1[0x14a] == 0;
		version = rom1[0x14c];
		checksum = rom1[0x14d];

		globalChecksum = (rom1[0x14e] << 8) | rom1[0x14f];
	}

	public function init(video:Video)
	{
		this.video = video;

		for (key in _regs.keys())
		{
			write(key, _regs[key]);
		}
	}

	public function read(addr:Int):Int
	{
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000:
				return rom1[addr];
			case 0x4000, 0x5000, 0x6000, 0x7000:
				return rom2[addr-0x4000];
			case 0x8000, 0x9000:
				return video.vramRead(addr);
			case 0xa000, 0xb000:
				if (rtc > 0) return rtcRead();
				else return ram[addr-0xa000];
			case 0xc000:
				return wram1[addr-0xc000];
			case 0xd000:
				return wram2[addr-0xd000];
			case 0xe000:
				return wram1[addr-0xe000];
			case 0xf000:
				if (addr < 0xfe00)
				{
					return wram2[addr-0xf000];
				}
				else if (addr < 0xfea0)
				{
					return video.oam[addr - 0xfe00];
				}
				else if (addr < 0xff00)
				{
					// unused memory region
					return 0xff;
				}
				else if (addr < 0xff40)
				{
					return ioRead(addr);
				}
				else if (addr < 0xff80)
				{
					return video.ioRead(addr);
				}
				else if (addr < 0xffff)
				{
					return hram[addr - 0xff80];
				}
				else
				{
					return cpu.interruptsEnabledFlag;
				}

			default:
				return 0xff;
		}
	}

	public function write(addr:Int, value:Int):Void
	{
		//trace(StringTools.hex(addr), StringTools.hex(value));
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000,
					0x4000, 0x5000, 0x6000, 0x7000:
				mbc.write(addr, value);

			case 0x8000, 0x9000:
				video.vramWrite(addr, value);
			case 0xa000, 0xb000:
				if (rtc > 0) rtcWrite(value);
				else ram.set(addr-0xa000, value);
			case 0xc000:
				wram1.set(addr-0xc000, value);
			case 0xd000:
				wram2.set(addr-0xd000, value);
			case 0xe000:
				wram1.set(addr-0xe000, value);
			case 0xf000:
				if (addr < 0xfe00)
				{
					wram2.set(addr-0xf000, value);
				}
				else if (addr < 0xfea0)
				{
					video.oam.set(addr - 0xfe00, value);
				}
				else if (addr < 0xff00)
				{
					// writing here does nothing
				}
				else if (addr < 0xff40)
				{
					ioWrite(addr, value);
				}
				else if (addr < 0xff80)
				{
					video.ioWrite(addr, value);
				}
				else if (addr < 0xffff)
				{
					hram.set(addr - 0xff80, value);
				}
				else
				{
					cpu.interruptsEnabledFlag = value;
				}

			default: {}
		}
	}

	inline function ioRead(addr:Int):Int
	{
		switch (addr)
		{
			case 0xff04:
				var result = (cpu.divTicks >> 8) & 0xff;
				cpu.divTicks &= 0xff;
				return result;
			case 0xff05: return cpu.timerValue;
			case 0xff06: return cpu.timerMod;
			case 0xff07:
				return (switch (cpu.tacClocks)
				{
					case 0x10: 1;
					case 0x40: 2;
					case 0x100: 3;
					default: 0;
				}) | (cpu.timerEnabled ? 0x4 : 0);
			case 0xff0f: return 0xe0 | cpu.interruptsRequestedFlag;
			default: return 0;
		}
	}

	inline function ioWrite(addr:Int, value:Int):Void
	{
		//trace(StringTools.hex(addr), value);
		switch(addr)
		{
			case 0xff04: cpu.divTicks = 0;
			case 0xff05: cpu.timerValue = value;
			case 0xff06: cpu.timerMod = value;
			case 0xff07:
				cpu.tacClocks = switch (value & 0x3)
				{
					case 1: 0x10;
					case 2: 0x40;
					case 3: 0x100;
					default: 0x400;
				}
				cpu.timerEnabled = Util.getbit(value, 2);
			case 0xff0f: cpu.interruptsRequestedFlag = value;
			default: {}
		}
	}

	inline function rtcRead():Int
	{
		switch (rtc)
		{
			case 0x8: return rtcTime.getSeconds();
			case 0x9: return rtcTime.getMinutes();
			case 0xa: return rtcTime.getHours();
			case 0xb:
				return Std.int((Date.now().getTime() - rtcTime.getTime()) / 86400) & 0xff;
			case 0xc:
				var dayCounter = Std.int((Date.now().getTime() - rtcTime.getTime()) / 86400);
				return ((dayCounter >> 8) & 1) | (dayCounter > 511 ? 0x80 : 0);
			default: return 0xff;
		}
	}

	inline function rtcWrite(value:Int):Void
	{
		if (rtcLatch)
		{
			if (value == 1)
			{
				rtcTime = Date.now();
			}
			else rtcLatch = false;
		}
		else
		{
			rtcLatch = value == 0;
		}
	}

	static var _regs:Map<Int, Int> = [
		0xff05 => 0x00,
		0xff06 => 0x00,
		0xff07 => 0x00,
		0xff10 => 0x80,
		0xff11 => 0xbf,
		0xff12 => 0xf3,
		0xff14 => 0xbf,
		0xff16 => 0x3f,
		0xff17 => 0x00,
		0xff19 => 0xbf,
		0xff1a => 0x7f,
		0xff1b => 0xff,
		0xff1c => 0x9f,
		0xff1e => 0xbf,
		0xff20 => 0xff,
		0xff21 => 0x00,
		0xff22 => 0x00,
		0xff23 => 0xbf,
		0xff24 => 0x77,
		0xff25 => 0xf3,
		0xff26 => 0xf0,
		0xff40 => 0x91,
		0xff42 => 0x00,
		0xff43 => 0x00,
		0xff45 => 0x00,
		0xff47 => 0xfc,
		0xff48 => 0xff,
		0xff49 => 0xff,
		0xff4a => 0x00,
		0xff4b => 0x00,
		0xffff => 0x00,
	];
}
