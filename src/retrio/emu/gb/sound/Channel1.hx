package retrio.emu.gb.sound;

import haxe.ds.Vector;


class Channel1 implements ISoundGenerator
{
	static var dutyLookup:Vector<Vector<Bool>> = Vector.fromArrayCopy([
		Vector.fromArrayCopy([	true,	false,	false,	false,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	false,	false,	false,	false,	true,	true,	false,	false,	]),
		Vector.fromArrayCopy([	true,	true,	true,	true,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	true,	true,	true,	true,	true,	true,	false,	false,	]),
	]);

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

	public var sweepDecrease:Bool = false;
	public var sweepDiv:Int = 0;
	public var sweepTime:Int = 0;
	public var sweepCounter:Int = 0;

	public var envelopeType:Bool = false;
	public var envelopeTime:Int = 0;
	public var envelopeVolume:Int = 0;
	public var envelopeCounter:Int = 0;

	public var repeat:Bool = true;
	public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		cycleLengthNumerator = Std.int(Audio.NATIVE_SAMPLE_RATE/64) * (0x800 - f);
		cycleLengthDenominator = Std.int(0x20000/64);
		dutyLength = Std.int(cycleLengthNumerator / 8);
		return frequency = f;
	}
	public var baseFrequency(default, set):Int = 0;
	inline function set_baseFrequency(f:Int)
	{
		return baseFrequency = frequency = f;
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

	public var sweepRegister(get, never):Int;
	inline function get_sweepRegister()
	{
		return (sweepDiv) | (sweepDecrease ? 0x8 : 0) | (sweepTime << 4);
	}

	public function setDuty(value:Int):Void
	{
		length = value & 0x3f;
		duty = (value & 0xc0) >> 6;
	}

	public var dutyRegister(get, never):Int;
	inline function get_dutyRegister()
	{
		return (length) | (duty << 6);
	}

	public function setEnvelope(value:Int):Void
	{
		envelopeTime = value & 0x7;
		envelopeCounter = envelopeTime;
		envelopeType = Util.getbit(value, 3);
		amplitude = envelopeVolume = (value & 0xf0) >> 4;
		// TODO: seems like this should work, but it doesn't?
		dac = true;//value & 0xf8 > 0;
	}

	public var envelopeRegister(get, never):Int;
	inline function get_envelopeRegister()
	{
		return (envelopeTime) | (envelopeType ? 0x8 : 0) | (envelopeVolume << 4);
	}

	public function reset():Void
	{
		amplitude = envelopeVolume;
		envelopeCounter = envelopeTime;
		sweepCounter = sweepTime;
		enabled = repeat = true;
		if (lengthCounter == 0) lengthCounter = 0x40;
		cyclePos = 0;
		frequency = baseFrequency;
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
		if (envelopeTime > 0)
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
