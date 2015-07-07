package retrio.emu.gb.sound;

import haxe.ds.Vector;


class Channel1 implements ISoundGenerator
{
	static var dutyLookup:Vector<Vector<Bool>> = Vector.fromArrayCopy([
		Vector.fromArrayCopy([	false,	false,	false,	false,	false,	false,	false,	true,	]),
		Vector.fromArrayCopy([	true,	false,	false,	false,	false,	false,	false,	true,	]),
		Vector.fromArrayCopy([	true,	false,	false,	false,	false,	true,	true,	true,	]),
		Vector.fromArrayCopy([	false,	true,	true,	true,	true,	true,	true,	false,	]),
	]);

	public var enabled:Bool = false;

	public var sweepDecrease:Bool = false;
	public var sweepDiv:Int = 0;
	public var sweepTime:Int = 0;
	public var sweepCounter:Int = 0;

	public var length:Int = 0;
	inline function set_length(l:Int)
	{
		lengthCounter = 0x40 - l;
		enabled = true;
		return length = l;
	}
	public var lengthCounter:Int = 0;

	public var duty(default, set):Int = 0;
	function set_duty(i:Int)
	{
		cachedDuty = dutyLookup[i];
		return duty = i;
	}
	var cachedDuty:Vector<Bool> = dutyLookup[0];

	public var envelopeType:Bool = false;
	public var envelopeDiv:Int = 0;
	public var envelopeVolume:Int = 0;
	public var envelopeCounter:Int = 0;

	public var repeat:Bool = true;
	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Audio.NATIVE_SAMPLE_RATE * (0x800 - f);
		cycleLengthDenominator = 0x20000;
		dutyLength = Std.int(cycleLengthNumerator / 8);
		return frequency = f;
	}

	var cycleLengthNumerator:Int = 1;
	var cycleLengthDenominator:Int = 1;
	var cyclePos:Int = 0;
	var dutyLength:Int = 1;
	var amplitude:Int = 0;

	public function new() {}

	public function setSweep(value:Int):Void
	{
		sweepDiv = value & 0x7;
		sweepDecrease = Util.getbit(value, 3);
		sweepTime = (value & 0x70) >> 4;
		sweepCounter = sweepTime;
	}

	public function setDuty(value:Int):Void
	{
		length = value & 0x3f;
		duty = (value & 0xc0) >> 6;
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
		sweepCounter = sweepTime;
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

	public inline function sweepClock():Void
	{
		if (--sweepCounter == 0)
		{
			if (sweepDiv > 0)
			{
				if (sweepDecrease)
				{
					frequency = (frequency - (frequency >> sweepDiv)) & 0x7ff;
				}
				else
				{
					frequency = (frequency + (frequency >> sweepDiv)) & 0x7ff;
				}
			}
			sweepCounter = sweepTime;
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
			val = (cachedDuty[Std.int(cyclePos / dutyLength) & 0x7]) ? amplitude : -amplitude;
		}

		return val;
	}
}
