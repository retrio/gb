package retrio.emu.gb.sound;

import haxe.ds.Vector;


class Channel1 implements ISoundGenerator implements IState
{
	static var dutyLookup:Vector<Vector<Bool>> = Vector.fromArrayCopy([
		Vector.fromArrayCopy([	true,	false,	false,	false,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	false,	false,	false,	false,	true,	true,	false,	false,	]),
		Vector.fromArrayCopy([	true,	true,	true,	true,	false,	false,	false,	false,	]),
		Vector.fromArrayCopy([	true,	true,	true,	true,	true,	true,	false,	false,	]),
	]);

	@:state public var ch2:Bool = false;

	public var enabled(get, never):Bool;
	inline function get_enabled()
	{
		return (repeat || lengthCounter > 0) && !sweepFault && dac && (amplitude > 0 || (envelopeType && envelopeTime > 0));
	}
	@:state public var dac:Bool = false;

	@:state public var length:Int = 0;
	inline function set_length(l:Int)
	{
		lengthCounter = 0x40 - l;
		return length = l;
	}
	@:state public var lengthCounter:Int = 0;

	@:state public var duty(default, set):Int = 0;
	function set_duty(i:Int)
	{
		cachedDuty = dutyLookup[i];
		return duty = i;
	}
	var cachedDuty:Vector<Bool> = dutyLookup[0];

	@:state public var sweepDecrease:Bool = false;
	@:state public var sweepDiv:Int = 0;
	@:state public var sweepTime:Int = 0;
	@:state public var sweepCounter:Int = 0;
	@:state var swept:Bool = false;
	@:state var sweepFault:Bool = false;
	@:state var shadowFrequency:Int = 0;

	@:state public var envelopeType:Bool = false;
	@:state public var envelopeTime:Int = 0;
	@:state public var envelopeVolume:Int = 0;
	@:state public var envelopeCounter:Int = 0;
	@:state var envelopeOn:Bool = false;

	@:state public var repeat:Bool = true;
	@:state public var frequency(default, set):Int = 0;
	inline function set_frequency(f:Int)
	{
		sweepFault = false;
		cycleLengthNumerator = Std.int(Audio.NATIVE_SAMPLE_RATE/64) * (0x800 - f);
		cycleLengthDenominator = Std.int(0x20000/64);
		dutyLength = Std.int(cycleLengthNumerator / 8);
		return frequency = f;
	}
	@:state public var baseFrequency(default, set):Int = 0;
	inline function set_baseFrequency(f:Int)
	{
		return baseFrequency = frequency = f;
	}

	@:state var cycleLengthNumerator:Int = 1;
	@:state var cycleLengthDenominator:Int = 1;
	@:state var cyclePos:Int = 0;
	@:state var dutyLength:Int = 1;
	@:state public var amplitude:Int = 0;

	public function new() {}

	public function setSweep(value:Int):Void
	{
		sweepDiv = value & 0x7;
		if (sweepDecrease && !Util.getbit(value, 3)) sweepFault = true;
		else sweepFault = false;
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
		envelopeTime = (value & 0x7);
		envelopeCounter = envelopeTime;
		envelopeType = Util.getbit(value, 3);
		envelopeVolume = (value & 0xf0) >> 4;
		envelopeOn = envelopeTime > 0;
		dac = value & 0xf8 > 0;
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
		envelopeOn = envelopeTime > 0;
		sweepCounter = sweepTime;
		swept = sweepFault = false;
		if (lengthCounter == 0) lengthCounter = 0x40;
		cyclePos = 0;
		frequency = baseFrequency;
		shadowFrequency = frequency;
		sweepDummy();
	}

	public inline function lengthClock():Void
	{
		if (lengthCounter > 0)
		{
			--lengthCounter;
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
					shadowFrequency -= shadowFrequency >> sweepDiv;
					frequency = (shadowFrequency) & 0x7ff;
				}
				else
				{
					shadowFrequency += shadowFrequency >> sweepDiv;
					if (shadowFrequency + (shadowFrequency >> sweepDiv) > 0x7ff)
					{
						// overflow
						sweepFault = true;
					}
					else
					{
						frequency = shadowFrequency;
					}
				}
				swept = true;
			}
			sweepCounter = sweepTime;
		}
	}

	inline function sweepDummy():Void
	{
		if (sweepDiv > 0)
		{
			if (!sweepDecrease)
			{
				shadowFrequency += shadowFrequency >> sweepDiv;
				if (shadowFrequency + (shadowFrequency >> sweepDiv) > 0x7ff)
				{
					// overflow
					sweepFault = true;
				}
			}
			swept = true;
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
			if (cyclePos >= cycleLengthNumerator) cyclePos -= cycleLengthNumerator;
			val = (cachedDuty[Std.int(cyclePos / dutyLength) & 0x7]) ? amplitude : -amplitude;
		}

		return val;
	}
}
