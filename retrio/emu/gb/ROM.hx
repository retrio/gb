package retrio.emu.gb;

import haxe.ds.Vector;


class ROM implements IState
{
	@:state public var name:String;
	@:state public var gbc:Bool;
	@:state public var sgb:Bool;
	@:state public var cartType:Int;
	@:state public var japan:Bool;
	@:state public var version:Int;
	@:state public var checksum:Int;
	@:state public var globalChecksum:Int;
	@:state public var hasSram:Bool;

	@:state public var romSize:Int;
	@:state public var ramSize:Int;
	@:state public var romBankCount:Int;
	@:state public var ramBankCount:Int;

	public var data:FileWrapper;
	public var fixedRom:ByteString;

	public function new(file:FileWrapper)
	{
		// read fixed ROM bank
		data = file;

		fixedRom = new ByteString(0x4000);
		fixedRom.readFrom(data);

		name = "";
		for (i in 0x134 ... 0x144)
		{
			var c = fixedRom[i];
			if (c > 0) name += String.fromCharCode(c);
		}

		sgb = fixedRom.get(0x146) != 0;

		cartType = fixedRom[0x147];
		hasSram = switch(cartType)
		{
			case 0x02, 0x03, 0x08, 0x09, 0x0c, 0x0d, 0x10, 0x12,
				0x13, 0x16, 0x17, 0x1a, 0x1b, 0x1d, 0x1e, 0xff:
				true;
			default:
				false;
		}

		// read additional ROM banks
		var romSizeByte = fixedRom[0x148];
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

		var ramSizeByte = fixedRom[0x149];
		ramSize = switch(ramSizeByte)
		{
			case 1: 0x2000;
			case 2: 0x4000;
			case 3: 0x8000;
			case 4: 0x20000;
			case 5: 0x10000;
			default: 0;
		}
		ramBankCount = Std.int(Math.max(Math.ceil(ramSize/0x2000), 1));

		japan = fixedRom[0x14a] == 0;
		version = fixedRom[0x14c];
		checksum = fixedRom[0x14d];

		globalChecksum = (fixedRom[0x14e] << 8) | fixedRom[0x14f];
	}
}
