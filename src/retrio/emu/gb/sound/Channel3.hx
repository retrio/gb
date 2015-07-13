package retrio.emu.gb.sound;


class Channel3 implements ISoundGenerator
{
	var _enabled:Bool = false;
	public var enabled(get, set):Bool;
	inline function get_enabled()
	{
		return _enabled && dac;
	}
	inline function set_enabled(b:Bool)
	{
		return _enabled = b;
	}
	public var dac:Bool = false;

	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = 0x100-l;
		enabled = true;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var wavData:ByteString;

	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Std.int(Audio.NATIVE_SAMPLE_RATE/64) * (0x800 - f);
		cycleLengthDenominator = Std.int(0x10000/64);
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
		enabled = repeat = true;
		if (lengthCounter == 0) lengthCounter = 0x100;
		cyclePos = 0;
	}

	public inline function play():Int
	{
		var val = 0;
		cyclePos += (cycleLengthDenominator * Audio.NATIVE_SAMPLE_RATIO);
		if (cyclePos >= cycleLengthNumerator) cyclePos -= cycleLengthNumerator;

		if (outputLevel > 0)
		{
			var val1 = wavData[Math.floor(cyclePos / sampleLength) & 0x1f];
			var val2 = wavData[Math.ceil(cyclePos / sampleLength) & 0x1f];
			var t = (cyclePos / sampleLength) % 1;
			val = Std.int(Math.round(Util.lerp(val1, val2, t)));
			if (outputLevel > 1) val >>= (outputLevel - 1);
		}

		return val;
	}
}
