package retrio.emu.gb;

import haxe.io.Bytes;
import haxe.ds.Vector;
import retrio.emu.gb.sound.*;


@:build(retrio.macro.Optimizer.build())
class Audio
{
	// currently OpenFL on native, like Flash, does not support non-44100 sample rates
	public static inline var SAMPLE_RATE:Int = 44100;//#if flash 44100 #else 48000 #end;
	public static inline var NATIVE_SAMPLE_RATE:Int = (456*154*60);
	public static inline var NATIVE_SAMPLE_RATIO:Int = #if flash 2 #else 2 #end;
	static inline var BUFFER_LENGTH:Int = 0x10000;
	static inline var CPU_SYNC_RATE:Float = NATIVE_SAMPLE_RATE / SAMPLE_RATE / NATIVE_SAMPLE_RATIO;
	static inline var MAX_VOLUME:Int = 8;

	public var cpu:CPU;
	public var memory:Memory;

	public var buffer1:SoundBuffer;
	public var buffer2:SoundBuffer;

	public var bufferStart:Int;
	public var bufferEnd:Int;

	public var speedMultiplier(default, set):Float = 1;
	function set_speedMultiplier(s:Float)
	{
		cycleSkip = Std.int(NATIVE_SAMPLE_RATIO * speedMultiplier);
		return speedMultiplier = s;
	}
	var cycleSkip:Int = NATIVE_SAMPLE_RATIO;

	var vol1:Int = 0;
	var vol2:Int = 0;

	var soundEnabled:Bool = true;

	var ch1:Channel1;
	var ch2:Channel1;	// channel 2 is channel 1 without sweep
	var ch3:Channel3;
	var ch4:Channel4;
	var channels:Vector<ISoundGenerator> = new Vector(4);
	var channelsOn1:Vector<Bool> = new Vector(4);
	var channelsOn2:Vector<Bool> = new Vector(4);

	var cycles:Int = 0;
	var sampleCounter:Int = 0;
	var sampleSync:Int = 0;

	// sample data for interpolation
	var s1:Int = 0;
	var s2:Int = 0;
	var downsample1:Float = 0;
	var downsample2:Float = 0;

	public function new()
	{
		buffer1 = new SoundBuffer(BUFFER_LENGTH);
		buffer2 = new SoundBuffer(BUFFER_LENGTH);

		channels[0] = ch1 = new Channel1();
		channels[1] = ch2 = new Channel1();
		channels[2] = ch3 = new Channel3();
		channels[3] = ch4 = new Channel4();

		for (i in 0 ... channelsOn1.length) channelsOn1[i] = false;
		for (i in 0 ... channelsOn2.length) channelsOn2[i] = false;
	}

	public function init(cpu:CPU, memory:Memory)
	{
		this.cpu = cpu;
		this.memory = memory;
	}

	public inline function read(addr:Int):Int
	{
		switch (addr)
		{
			/*case 0xff10:
				return ch1.sweepNumber |
					(ch1.sweepDirection == 1 ? 0x80 : 0) |
					(ch1.sweepTime << 4);

			case 0xff11:
				return (ch1.length) |
					(ch1.duty << 6);

			case 0xff12:
				return (ch1.envelopeNumber) |
					(ch1.envelopeDirection == -1 ? 0x80 : 0) |
					(ch1.envelopeVolume << 4);

			case 0xff13:
				return ch1.frequency & 0xff;

			case 0xff14:
				return ((ch1.frequency & 0x700) >> 8) |
					(ch1.repeat ? 0 : 0x40);

			case 0xff16:
				return (ch2.length) |
					(ch2.duty << 6);

			case 0xff17:
				return (ch2.envelopeNumber) |
					(ch2.envelopeDirection == -1 ? 0x80 : 0) |
					(ch2.envelopeVolume << 4);

			case 0xff18:
				return ch2.frequency & 0xff;

			case 0xff19:
				return ((ch2.frequency & 0x700) >> 8) |
					(ch2.repeat ? 0 : 0x40);*/

			case 0xff24:
				return (vol1 - 1) | ((vol2 - 1) << 4);

			case 0xff25:
				// TODO
				return 0;

			case 0xff26:
				// TODO
				return 0;

			case 0xff30, 0xff31, 0xff32, 0xff33, 0xff34, 0xff35, 0xff36, 0xff37,
					0xff38, 0xff39, 0xff3a, 0xff3b, 0xff3c, 0xff3d, 0xff3e, 0xff3f:
				var a:Int = (addr - 0xff30) * 2;
				return (ch3.wavData[a] << 4) | (ch3.wavData[a+1]);

			default:
				return 0;
		}
	}

	public function write(addr:Int, value:Int):Void
	{
		catchUp();

		switch (addr)
		{
			case 0xff10:
				ch1.setSweep(value);

			case 0xff11:
				ch1.setDuty(value);

			case 0xff12:
				ch1.setEnvelope(value);

			case 0xff13:
				ch1.frequency = (ch1.frequency & 0x700) | value;

			case 0xff14:
				ch1.frequency = (ch1.frequency & 0xff) | ((value & 0x7) << 8);
				ch1.repeat = !Util.getbit(value, 6);
				if (ch1.repeat) ch1.enabled = true;
				if (Util.getbit(value, 7))
				{
					ch1.reset();
				}

			case 0xff16:
				ch2.setDuty(value);

			case 0xff17:
				ch2.setEnvelope(value);

			case 0xff18:
				ch2.frequency = (ch2.frequency & 0x700) | value;

			case 0xff19:
				ch2.frequency = (ch2.frequency & 0xff) | ((value & 0x7) << 8);
				ch2.repeat = !Util.getbit(value, 6);
				if (ch2.repeat) ch2.enabled = true;
				if (Util.getbit(value, 7))
				{
					ch2.reset();
				}

			case 0xff1a:
				ch3.enabled = Util.getbit(value, 7);

			case 0xff1b:
				ch3.length = value;

			case 0xff1c:
				ch3.outputLevel = value;

			case 0xff1d:
				ch3.frequency = (ch3.frequency & 0x700) | value;

			case 0xff1e:
				ch3.frequency = (ch3.frequency & 0xff) | ((value & 0x7) << 8);
				ch3.repeat = !Util.getbit(value, 6);
				if (ch3.repeat) ch3.enabled = true;
				if (Util.getbit(value, 7))
				{
					ch3.reset();
				}

			case 0xff20:
				ch4.length = value & 0x3f;

			case 0xff21:
				ch4.setEnvelope(value);

			case 0xff22:
				// TODO

			case 0xff23:
				ch4.repeat = !Util.getbit(value, 6);
				if (ch4.repeat) ch4.enabled = true;
				if (Util.getbit(value, 7))
				{
					ch4.reset();
				}

			case 0xff24:
				vol1 = (value & 0x7) + 1;
				vol2 = ((value >> 4) & 0x7) + 1;

			case 0xff25:
				channelsOn1[0] = Util.getbit(value, 0);
				channelsOn1[1] = Util.getbit(value, 1);
				channelsOn1[2] = Util.getbit(value, 2);
				channelsOn1[3] = Util.getbit(value, 3);

				channelsOn2[0] = Util.getbit(value, 4);
				channelsOn2[1] = Util.getbit(value, 5);
				channelsOn2[2] = Util.getbit(value, 6);
				channelsOn2[3] = Util.getbit(value, 7);

			case 0xff26:
				soundEnabled = Util.getbit(value, 7);

			case 0xff30, 0xff31, 0xff32, 0xff33, 0xff34, 0xff35, 0xff36, 0xff37,
					0xff38, 0xff39, 0xff3a, 0xff3b, 0xff3c, 0xff3d, 0xff3e, 0xff3f:
				var a:Int = (addr - 0xff30) * 2;
				ch3.wavData[a] = (addr & 0xf0) >> 4;
				ch3.wavData[a+1] = (addr & 0xf);

			default: {}
		}
	}

	public function catchUp()
	{
		while (cpu.apuCycles > 0)
		{
			/*--cpu.apuCycles;
			runCycle();
			generateSample();*/
			var runTo = predict();
			cpu.apuCycles -= runTo + 1;
			for (i in 0 ... runTo) generateSample();
			for (i in 0 ... runTo) runCycle();
			generateSample();
			runCycle();
		}
	}

	inline function predict()
	{
		var nextEvent:Int = Std.int(cpu.apuCycles - 1);
		var next:Int;

		if (ch1.enabled)
		{
			// length
			if (!ch1.repeat)
			{
				next = (8 - cycles) + (8 * ch1.lengthCounter);
				if (next < nextEvent) nextEvent = next;
			}
			// sweep
			next = (cycles > 2 ? (10 - cycles) : (2 - cycles)) + (8 * ch1.sweepCounter);
			if (next < nextEvent) nextEvent = next;
			// envelope
			next = (cycles > 4 ? (12 - cycles) : (4 - cycles)) + (8 * ch1.envelopeCounter);
			if (next < nextEvent) nextEvent = next;
		}
		if (ch2.enabled)
		{
			// length
			if (!ch2.repeat)
			{
				next = (8 - cycles) + (8 * ch2.lengthCounter);
				if (next < nextEvent) nextEvent = next;
			}
			// envelope
			next = (cycles > 4 ? (12 - cycles) : (4 - cycles)) + (8 * ch2.envelopeCounter);
			if (next < nextEvent) nextEvent = next;
		}
		if (ch3.enabled)
		{
			// length
			if (!ch3.repeat)
			{
				next = (8 - cycles) + (8 * ch3.lengthCounter);
				if (next < nextEvent) nextEvent = next;
			}
		}
		if (ch4.enabled)
		{
			// length
			if (!ch4.repeat)
			{
				next = (8 - cycles) + (8 * ch4.lengthCounter);
				if (next < nextEvent) nextEvent = next;
			}
			// envelope
			next = (cycles > 4 ? (12 - cycles) : (4 - cycles)) + (8 * ch4.envelopeCounter);
			if (next < nextEvent) nextEvent = next;
		}

		return nextEvent < 0 ? 0 : nextEvent;
	}

	inline function runCycle()
	{
		switch (cycles++)
		{
			case 0:
				lengthClock();
			case 2:
				lengthClock();
				sweepClock();
			case 4:
				lengthClock();
			case 6:
				lengthClock();
				sweepClock();
			case 7:
				envelopeClock();
				cycles = 0;
		}
	}

	inline function lengthClock()
	{
		ch1.lengthClock();
		ch2.lengthClock();
		ch3.lengthClock();
		ch4.lengthClock();
	}

	inline function sweepClock()
	{
		ch1.sweepClock();
	}

	inline function envelopeClock()
	{
		ch1.envelopeClock();
		ch2.envelopeClock();
		ch4.envelopeClock();
	}

	var _samples:Vector<Int> = new Vector(4);
	inline function generateSample()
	{
		if (++sampleCounter >= cycleSkip)
		{
			sampleCounter -= cycleSkip;
			sampleSync += SAMPLE_RATE * NATIVE_SAMPLE_RATIO;

			if (soundEnabled)
			{
				getSoundOut1();
				getSoundOut2();
			}
			else
			{
				s1 = s2 = 0;
			}

			if (sampleSync >= NATIVE_SAMPLE_RATE)
			{
				var t = (sampleSync - NATIVE_SAMPLE_RATE) / SAMPLE_RATE;
				downsample1 += s1 * t;
				downsample2 += s2 * t;

				buffer1.push(downsample1 / CPU_SYNC_RATE / MAX_VOLUME);
				buffer2.push(downsample2 / CPU_SYNC_RATE / MAX_VOLUME);

				downsample1 = s1 * (1 - t);
				downsample2 = s2 * (1 - t);

				sampleSync -= NATIVE_SAMPLE_RATE;
			}
			else
			{
				downsample1 += s1;
				downsample2 += s2;
			}
		}
	}

	inline function getSoundOut1()
	{
		s1 = 0;

		if (channelsOn1[0])
		{
			s1 += _samples[0] = ch1.play();
		}
		if (channelsOn1[1])
		{
			s1 += _samples[1] = ch2.play();
		}
		if (channelsOn1[2])
		{
			s1 += _samples[2] = ch3.play();
		}
		if (channelsOn1[3])
		{
			s1 += _samples[3] = ch4.play();
		}

		s1 *= vol1;
	}

	inline function getSoundOut2()
	{
		s2 = 0;

		if (channelsOn2[0])
		{
			s2 += channelsOn1[0] ? _samples[0] : ch1.play();
		}
		if (channelsOn2[1])
		{
			s2 += channelsOn1[1] ? _samples[1] : ch2.play();
		}
		if (channelsOn2[2])
		{
			s2 += channelsOn1[2] ? _samples[2] : ch3.play();
		}
		if (channelsOn2[3])
		{
			s2 += channelsOn1[3] ? _samples[3] : ch4.play();
		}

		s2 *= vol2;
	}
}
