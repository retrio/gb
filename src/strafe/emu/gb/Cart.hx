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

	public var mbc:MBC;

	public var rom1:ByteString;	// fixed ROM bank
	public var rom2:ByteString;	// switchable ROM bank

	public var vram:ByteString;	// video RAM
	public var ram:ByteString;		// external RAM
	public var wram1:ByteString;	// fixed work RAM
	public var wram2:ByteString;	// switchable work RAM
	public var oam:ByteString;		// object attribute memory

	public var romBanks:Vector<ByteString>;
	public var ramBanks:Vector<ByteString>;
	public var wramBanks:Vector<ByteString>;

	public function new(file:FileWrapper)
	{
		// initial memory allocation
		vram = new ByteString(0x2000);
		oam = new ByteString(0xa0);
		wramBanks = new Vector(8);
		for (i in 0 ... 8) wramBanks[i] = new ByteString(0x1000);
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
			//case
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
		ramBanks = new Vector(Math.ceil(ramSize/0x2000));
		for (i in 0 ... ramBanks.length) ramBanks[i] = new ByteString(0x2000);
		ram = ramBanks[0];

		trace(StringTools.hex(romSize), StringTools.hex(ramSize));

		japan = rom1[0x14a] == 0;
		version = rom1[0x14c];
		checksum = rom1[0x14d];

		globalChecksum = (rom1[0x14e] << 8) | rom1[0x14f];
	}

	public inline function read(addr:Int):Int
	{
		trace("READ", StringTools.hex(addr));
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000:
				return rom1[addr];
			case 0x4000, 0x5000, 0x6000, 0x7000:
				return rom2[addr-0x4000];
			case 0x8000, 0x9000:
				return vram[addr-0x8000];
			case 0xa000, 0xb000:
				return ram[addr-0xa000];
			case 0xc000:
				return wram1[addr-0xc000];
			case 0xd000:
				return wram2[addr-0xc000];
			case 0xe000:
				return wram1[addr-0xe000];
			case 0xf000:
				if (addr < 0xfe00)
					return wram2[addr-0xf000];
				else if (addr < 0xfea0)
				{
					return oam[addr - 0xfe00];
				}
				else if (addr < 0xff00)
				{
					throw "Bad read: " + StringTools.hex(addr, 4);
				}
				else if (addr < 0xff80)
				{
					// TODO: io registers
					throw "not implemented yet";
				}
				else if (addr < 0xffff)
				{
					// TODO: HRAM
					throw "not implemented yet";
				}
				else
				{
					// TODO: interrupts enable
					throw "not implemented yet";
				}
			default:
				throw "Bad read: " + StringTools.hex(addr, 4);
		}
	}

	public inline function write(addr:Int, value:Int):Void
	{
		trace("WRITE", StringTools.hex(addr));
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000, 0x2000, 0x3000,
					0x4000, 0x5000, 0x6000, 0x7000:
				mbc.write(addr, value);

			case 0x8000, 0x9000:
				vram.set(addr-0x8000, value);
			case 0xa000, 0xb000:
				ram.set(addr-0xa000, value);
			case 0xc000:
				wram1.set(addr-0xc000, value);
			case 0xd000:
				wram2.set(addr-0xc000, value);
			case 0xe000:
				wram1.set(addr-0xe000, value);
			case 0xf000:
				if (addr < 0xfe00)
					wram2.set(addr-0xf000, value);
				else if (addr < 0xfea0)
				{
					oam.set(addr - 0xfe00, value);
				}
				else if (addr < 0xff00)
				{
					throw "Bad write: " + StringTools.hex(addr, 4);
				}
				else if (addr < 0xff80)
				{
					// TODO: io registers
					throw "not implemented yet";
				}
				else if (addr < 0xffff)
				{
					// TODO: HRAM
					throw "not implemented yet";
				}
				else
				{
					// TODO: interrupts enable
					throw "not implemented yet";
				}

			default:
				throw "Bad write: " + StringTools.hex(addr, 4);
		}
	}
}
