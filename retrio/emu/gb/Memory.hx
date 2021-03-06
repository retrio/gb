package retrio.emu.gb;

import haxe.ds.Vector;
import retrio.emu.gb.mbcs.*;


class Memory implements IState
{
	@:stateChildren static var stateChildren = ['mbc', 'rtc'];

	public var rom:ROM;
	public var mbc:MBC;
	public var cpu:CPU;
	public var video:Video;
	public var audio:Audio;
	public var rtc:RTC;
	public var controller:GBController;

	public var ram:ByteString;				// pointer to external RAM
	public var wram1:ByteString;			// pointer to fixed work RAM
	public var wram2:ByteString;			// pointer to switchable work RAM
	@:state public var hram:ByteString;		// HRAM

	public var romBanks:Vector<ByteString>;
	@:state public var ramBanks:Vector<ByteString>;
	@:state public var wramBanks:Vector<ByteString>;

	@:state public var romBank(default, set):Byte;
	inline function set_romBank(b:Byte)
	{
		rom2 = romBanks[b % romBanks.length];
		return romBank = b;
	}

	@:state public var ramBank(default, set):Byte;
	inline function set_ramBank(b:Byte)
	{
		ram = ramBanks[b % ramBanks.length];
		return ramBank = b;
	}

	@:state public var wram1Bank(default, set):Byte;
	inline function set_wram1Bank(b:Byte)
	{
		wram1 = wramBanks[b % wramBanks.length];
		return wram1Bank = b;
	}
	@:state public var wram2Bank(default, set):Byte;
	inline function set_wram2Bank(b:Byte)
	{
		wram2 = wramBanks[b % wramBanks.length];
		return wram2Bank = b;
	}

	public var rom1:ByteString;		// pointer to fixed ROM bank
	public var rom2:ByteString;		// pointer to switchable ROM bank

	public var sramDirty:Bool = false;

	@:state var joypadButtons:Bool = false;

	public function new(rom:ROM)
	{
		rom1 = rom.fixedRom;

		// initial memory allocation
		hram = new ByteString(0x200);

		wramBanks = new Vector(8);
		for (i in 0 ... 8)
		{
			wramBanks[i] = new ByteString(0x1000);
		}

		// MBC
		mbc = switch (rom.cartType)
		{
			case 0x00, 0x08, 0x09:
				// no MBC; base class doesn't actually do anything
				new MBC();
			case 0x01, 0x02, 0x03:
				new MBC1();
			case 0x05, 0x06:
				new MBC2();
			case 0xf, 0x10, 0x11, 0x12, 0x13:
				new MBC3();
			// TODO: MBC5
			default:
				throw "Cart type " + StringTools.hex(rom.cartType) + " not supported";
		}
		mbc.memory = this;

		// additional ROM banks
		romBanks = new Vector(rom.romBankCount);
		romBanks[0] = rom1;
		for (i in 1 ... rom.romBankCount)
		{
			romBanks[i] = new ByteString(0x4000);
			romBanks[i].readFrom(rom.data);
		}

		// set up RAM
		ramBanks = new Vector(rom.ramBankCount);
		for (i in 0 ... rom.ramBankCount)
		{
			ramBanks[i] = new ByteString(0x2000);
		}

		// real time clock
		rtc = new RTC();
	}

	public function init(cpu:CPU, video:Video, audio:Audio, controller:GBController)
	{
		this.cpu = cpu;
		this.video = video;
		this.audio = audio;
		this.controller = controller;

		hram.fillWith(0);

		for (i in 0 ... wramBanks.length) wramBanks[i].fillWith(0);
		for (i in 0 ... ramBanks.length) ramBanks[i].fillWith(0);

		romBank = 1;
		wram1Bank = 0;
		wram2Bank = 1;
		ramBank = 0;
	}

	public function writeInitialState()
	{
		for (key in _regs.keys())
			write(key, _regs[key]);
	}

	public function read(addr:Int):Int
	{
		switch (addr & 0xf000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000:
				return rom1[addr];
			case 0x4000, 0x5000, 0x6000, 0x7000:
				return rom2[addr-0x4000];
			case 0x8000, 0x9000:
				return video.vramRead(addr);
			case 0xa000, 0xb000:
				return (rtc.register > 0) ? rtc.read() : ram[addr-0xa000];
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
					return video.oamRead(addr);
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
		switch (addr & 0xf000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000,
					0x4000, 0x5000, 0x6000, 0x7000:
				mbc.write(addr, value);

			case 0x8000, 0x9000:
				video.vramWrite(addr, value);
			case 0xa000, 0xb000:
				if (rtc.register > 0) rtc.write(value);
				else
				{
					var a = addr-0xa000;
					sramDirty = sramDirty || ram[a] != value;
					ram.set(a, value);
				}
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
					video.oamWrite(addr, value);
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
			case 0xff00:
				return controller == null ? 0 : controller.buttons();
			case 0xff04:
				var result = (cpu.divTicks >> 8) & 0xff;
				//cpu.divTicks &= 0xff;
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
			default: return audio.read(addr);
		}
	}

	inline function ioWrite(addr:Int, value:Int):Void
	{
		switch(addr)
		{
			case 0xff00:
				if (controller != null)
				{
					controller.directionsEnabled = !Util.getbit(value, 4);
					controller.buttonsEnabled = !Util.getbit(value, 5);
				}
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

			default: return audio.write(addr, value);
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
