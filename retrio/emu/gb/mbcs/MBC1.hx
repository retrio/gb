package retrio.emu.gb.mbcs;


class MBC1 extends MBC implements IState
{
	@:state var ramEnable:Bool = false;
	@:state var romSelect:Bool = true;

	override public function write(addr:Int, val:Int):Void
	{
		switch (addr & 0xF000)
		{
			case 0x0000, 0x1000:
				ramEnable = (val & 0xf) == 0xa;
			case 0x2000, 0x3000:
				var lower = val & 0x1f;
				if (lower == 0) lower = 1;
				memory.romBank = (memory.romBank & 0xe0) | lower;
			case 0x4000, 0x5000:
				if (romSelect)
				{
					memory.romBank = (memory.romBank & 0x1f) | ((val & 0x3) << 5);
				}
				else
				{
					memory.ramBank = val & 0x3;
				}
			case 0x6000, 0x7000:
				romSelect = (val & 1) == 0;
				if (romSelect)
				{
					memory.ramBank = 0;
				}
				else
				{
					memory.romBank &= 0x1f;
				}
		}
	}
}
