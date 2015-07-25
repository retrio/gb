package retrio.emu.gb.sound;


class Channel3 implements ISoundGenerator
{
	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return (lengthCounter > 0 || repeat) && dac && canPlay && outputLevel > 0;
	}
	public var canPlay:Bool = false;
	public var dac:Bool = false;

	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = 0x100-l;
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

	public inline function setOutput(value:Int)
	{
		outputLevel = (value & 0x60) >> 5;
		dac = value & 0xf8 > 0;
	}

	public inline function lengthClock():Void
	{
		if (lengthCounter > 0)
		{
			--lengthCounter;
		}
	}

	public function reset():Void
	{
		if (lengthCounter == 0) lengthCounter = 0x100;
		cyclePos = 0;
	}

	public inline function play():Int
	{
		var val = 0;
		cyclePos += (cycleLengthDenominator * Audio.NATIVE_SAMPLE_RATIO);
		if (cyclePos >= cycleLengthNumerator) cyclePos -= cycleLengthNumerator;

		if (enabled)
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
