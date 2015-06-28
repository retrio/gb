package strafe.emu.gb.mbcs;


class MBC2 extends MBC
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
				if (addr & 0x100 == 0)
					ramEnable = (val & 0xf) == 0xa;
			case 0x2000, 0x3000:
				if (addr & 0x100 == 0x100)
					romBank = val & 0xf;
		}
	}
}
