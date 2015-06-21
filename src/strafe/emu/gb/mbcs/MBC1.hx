package strafe.emu.gb.mbcs;


class MBC1 extends MBC
{
	var ramEnable:Bool = false;
	var romSelect:Bool = true;
	var romBank(default, set):Int = 1;
	inline function set_romBank(b:Int)
	{
		cart.rom2 = cart.romBanks[b];
		return romBank = b;
	}

	override public function write(addr:Int, val:Int):Void
	{
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000:
				ramEnable = (val & 0xf) == 0xa;
			case 0x2000, 0x3000:
				var lower = val & 0x1f;
				if (lower == 0) lower = 1;
				romBank = (romBank & 0xe0) | lower;
			case 0x4000, 0x5000:
				if (romSelect)
				{
					var upper = val & 0xe0;
					romBank = (romBank & 0x1f) | upper;
				}
				else
				{
					cart.ram = cart.ramBanks[val & 0x3];
				}
			case 0x6000, 0x7000:
				romSelect = val != 0;
		}
	}
}
