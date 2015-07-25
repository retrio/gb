package retrio.emu.gb.sound;

import haxe.ds.Vector;


class Channel4 implements ISoundGenerator
{
	static var randomValues:Vector<Bool>;

	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return (lengthCounter > 0 || repeat) && dac && amplitude > 0;
	}
	public var dac:Bool = false;

	public var repeat:Bool = true;
	public var length(default, set):Int = 0;
	function set_length(l:Int)
	{
		lengthCounter = 0x40-l;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Std.int(Audio.NATIVE_SAMPLE_RATE/64 * (f == 0 ? 0.5 : f)) << (shiftClockFrequency + 1);
		cycleLengthDenominator = Std.int(0x80000/64);
		return frequency = f;
	}

	public var envelopeType:Bool = false;
	public var envelopeTime:Int = 0;
	public var envelopeVolume:Int = 0;
	public var envelopeCounter:Int = 0;
	var envelopeOn:Bool = false;

	public var shiftClockFrequency:Int = 0;
	public var counterStep:Bool = false;

	var amplitude:Int = 0;
	var cycleLengthNumerator:Int = 1;
	var cycleLengthDenominator:Int = 1;
	var cyclePos:Int = 0;
	var noisePos:Int = 0;
	var counterFlip:Bool = false;

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
		envelopeTime = (value & 0x7);
		envelopeCounter = envelopeTime;
		envelopeType = Util.getbit(value, 3);
		envelopeVolume = (value & 0xf0) >> 4;
		envelopeOn = envelopeTime > 0;
		dac = value & 0xf8 > 0;
	}

	public function setPolynomial(value:Int):Void
	{
		shiftClockFrequency = (value & 0xf0) >> 4;
		counterStep = Util.getbit(value, 3);
		frequency = (value & 0x7);
	}

	public function reset():Void
	{
		amplitude = envelopeVolume;
		envelopeCounter = envelopeTime;
		if (lengthCounter == 0) lengthCounter = 0x40;
		cyclePos = 0;
	}

	public inline function lengthClock():Void
	{
		if (lengthCounter > 0)
		{
			--lengthCounter;
		}
	}

	public inline function envelopeClock():Void
	{
		if (envelopeOn && envelopeTime > 0)
		{
			if (--envelopeCounter == 0)
			{
				if (envelopeType)
				{
					if (++amplitude >= 0xf)
					{
						amplitude = 0xf;
						envelopeOn = false;
					}
					else envelopeCounter = envelopeTime;
				}
				else
				{
					if (--amplitude <= 0)
					{
						amplitude = 0;
						envelopeOn = false;
					}
					else envelopeCounter = envelopeTime;
				}
			}
		}
	}

	public inline function play():Int
	{
		var val = 0;

		if (enabled)
		{
			cyclePos += (cycleLengthDenominator * Audio.NATIVE_SAMPLE_RATIO);
			if (cyclePos >= cycleLengthNumerator)
			{
				cyclePos -= cycleLengthNumerator;
				noisePos++;
				if (counterStep && (noisePos & 7 == 0))
				{
					if (counterFlip)
						noisePos -= 8;
					counterFlip = !counterFlip;
				}
				noisePos %= randomValues.length;
			}
			val = (randomValues[noisePos]) ? amplitude : -amplitude;
		}

		return val;
	}
}
