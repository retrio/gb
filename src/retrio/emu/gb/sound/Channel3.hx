package retrio.emu.gb.sound;


class Channel3 implements ISoundGenerator
{
	public var enabled:Bool = false;

	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = 256-l;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var wavData:ByteString;

	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Audio.NATIVE_SAMPLE_RATE * (0x800 - f);
		cycleLengthDenominator = 0x10000;
		sampleLength = Std.int(cycleLengthNumerator / 32);
		return frequency = f;
	}

	public var outputLevel:Int;

	var cycleLengthNumerator:Int = 1;
	var cycleLengthDenominator:Int = 1;
	var cyclePos:Int = 0;
	var sampleLength:Int = 1;

	public function new()
	{
		// memory region FF30-FF3F; contains 16 bytes, but each is made up of
		// two 4-bit samples
		wavData = new ByteString(32);
	}

	public inline function lengthClock():Void
	{
		if (lengthCounter > 0)
		{
			if (--lengthCounter == 0)
			{
				enabled = repeat;
			}
		}
	}

	public function reset():Void
	{
		set_length(length);
		enabled = true;
		repeat = true;
		if (lengthCounter == 0) lengthCounter = 0x40;
		cyclePos = 0;
	}

	public inline function play():Int
	{
		var val = 0;
		if (enabled && outputLevel > 0)
		{
			cyclePos += (cycleLengthDenominator * Audio.NATIVE_SAMPLE_RATIO);
			if (cyclePos >= cycleLengthNumerator) cyclePos -= cycleLengthNumerator;
			if (sampleLength != 0)
			{
				val = wavData[Std.int(cyclePos / sampleLength) & 0x1f];
			}
			if (outputLevel > 1) val >>= (outputLevel - 1);
		}

		return val;
	}
}
