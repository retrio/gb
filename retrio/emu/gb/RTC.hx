package retrio.emu.gb;


class RTC implements IState
{
	@:state public var register:Int = 0;		// RTC register selected or 0 if none

	@:state var rtcTime:Date = Date.now();	// latched RTC time
	@:state var rtcLatch:Bool = false;

	public function new() {}

	public inline function read():Int
	{
		switch (register)
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

	public inline function write(value:Int):Void
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
}
