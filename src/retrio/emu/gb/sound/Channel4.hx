package retrio.emu.gb.sound;

import haxe.ds.Vector;


class Channel4 implements ISoundGenerator
{
	static var randomValues:Vector<Bool>;

	public var enabled:Bool = false;
	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = 64-l;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Audio.NATIVE_SAMPLE_RATE * (0x800 - f);
		cycleLengthDenominator = 0x20000;
		return frequency = f;
	}

	public var envelopeType:Bool = false;
	public var envelopeDiv:Int = 0;
	public var envelopeVolume:Int = 0;
	public var envelopeCounter:Int = 0;

	var amplitude:Int = 0;
	var cycleLengthNumerator:Int = 1;
	var cycleLengthDenominator:Int = 1;
	var cyclePos:Int = 0;

	public function new()
	{
		randomValues = new Vector(0x10000);
		for (i in 0 ... randomValues.length)
		{
			randomValues[i] = Math.random() > 0.5;
		}
	}

	public function setEnvelope(value:Int):Void
	{
		envelopeDiv = value & 0x7;
		envelopeType = Util.getbit(value, 3);
		envelopeVolume = (value & 0xf0) >> 4;

		amplitude = envelopeVolume;
	}

	public function reset():Void
	{
		amplitude = envelopeVolume;
		set_length(length);
		enabled = true;
		repeat = true;
		if (lengthCounter == 0) lengthCounter = 0x40;
		cyclePos = 0;
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

	public inline function envelopeClock():Void
	{
		if (envelopeDiv > 0)
		{
			if (envelopeCounter-- == 0)
			{
				if (envelopeType)
				{
					if (amplitude < 0xf) ++amplitude;
				}
				else
				{
					if (amplitude > 0) --amplitude;
				}
				envelopeCounter = envelopeDiv;
			}
		}
	}

	public inline function play():Int
	{
		var val = 0;
		if (enabled)
		{
			cyclePos += (cycleLengthDenominator * Audio.NATIVE_SAMPLE_RATIO);
			if (cyclePos >= cycleLengthNumerator) cyclePos -= cycleLengthNumerator;
			val = (randomValues[cyclePos & (randomValues.length - 1)]) ? amplitude : -amplitude;
		}

		return val;
	}
}
