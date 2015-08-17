package retrio.emu.gb.mbcs;


class MBC3 extends MBC implements IState
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
				memory.romBank = val & 0x7f;
				if (memory.romBank == 0) memory.romBank = 1;
			case 0x4000, 0x5000:
				if (val >= 0x8 && val <= 0xc)
				{
					memory.rtc.register = val;
				}
				else
				{
					memory.rtc.register = 0;
					memory.ramBank = val & 0x3;
				}
			case 0x6000, 0x7000:
				memory.rtc.write(val);
		}
	}
}
