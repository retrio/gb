package retrio.emu.gb.sound;


class Channel3 implements ISoundGenerator
{
	public var enabled:Bool = false;

	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = l;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var wavData:ByteString;

	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		var freq = Std.int(0x10000/(0x800-f));
		cycleLength = Math.ceil(48*Audio.SAMPLE_RATE / freq);
		sampleLength = Math.ceil(cycleLength / 32);
		return frequency = f;
	}

	var cycleLength:Int = 0;
	var sampleLength:Int = 0;
	var pos:Int = 0;

	public function new()
	{
		// memory region FF30-FF3F; contains 16 bytes, but each is made up of
		// two 4-bit samples
		wavData = new ByteString(32);
	}

	public inline function lengthClock():Void
	{
		if (!repeat && lengthCounter > 0)
		{
			if (--lengthCounter == 0)
			{
				if (!repeat) enabled = false;
			}
		}
	}

	public function reset():Void
	{
		set_length(length);
		enabled = true;
		repeat = true;
		if (lengthCounter == 0) lengthCounter = 0x40;
		pos = 0;
	}

	public inline function play():Int
	{
		pos = (pos + Audio.NATIVE_SAMPLE_RATIO) % cycleLength;

		var val = 0;
		if (enabled)
		{
			if (sampleLength != 0)
			{
				val = wavData[Std.int(pos / sampleLength) & 0x1f];
			}
		}

		return val;
	}
}
