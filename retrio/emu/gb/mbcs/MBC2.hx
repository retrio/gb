package retrio.emu.gb.mbcs;


class MBC2 extends MBC implements IState
{
	@:state var ramEnable:Bool = false;
	@:state var romSelect:Bool = true;

	override public function write(addr:Int, val:Int):Void
	{
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000:
				if (addr & 0x100 == 0)
					ramEnable = (val & 0xf) == 0xa;
			case 0x2000, 0x3000:
				if (addr & 0x100 == 0x100)
					memory.romBank = val & 0xf;
		}
	}
}
