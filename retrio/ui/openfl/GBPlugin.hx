package retrio.ui.openfl;

import haxe.ds.Vector;
import flash.Lib;
import flash.Memory;
import flash.display.Sprite;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.geom.Rectangle;
import flash.geom.Matrix;
import flash.utils.ByteArray;
import retrio.config.GlobalSettings;
import retrio.emu.gb.GB;
import retrio.emu.gb.Settings;
import retrio.emu.gb.Palette;


@:access(retrio.emu.gb.GB)
class GBPlugin extends EmulatorPlugin
{
	public static var _name:String = "gb";

	static inline var AUDIO_BUFFER_SIZE:Int = 0x800;
	static var _registered = Shell.registerPlugin(_name, new GBPlugin());

	var _stage(get, never):flash.display.Stage;
	inline function get__stage() return Lib.current.stage;

	var gb:GB;

	var frameCount = 0;
	var screenDirty:Bool = false;

	public function new()
	{
		super();

		controllers = new Vector(1);

		this.emu = this.gb = new GB();
		screenBuffer = new BitmapScreenBuffer(GB.WIDTH, GB.HEIGHT);

		this.settings = GlobalSettings.settings.concat(
			retrio.emu.gb.Settings.settings
		).concat(
			GBControls.settings(this)
		);
		extensions = gb.extensions;

		if (Std.is(screenBuffer, Bitmap)) addChildAt(cast(screenBuffer, Bitmap), 0);
	}

	override public function resize(width:Int, height:Int)
	{
		if (width == 0 || height == 0)
			return;

		screenBuffer.resize(width, height);
		initialized = true;
	}

	override public function frame()
	{
		if (!initialized) return;

		if (running)
		{
			super.frame();
			gb.frame(frameRate);

			if (!gb.video.finished) return;

			if (frameSkip > 0)
			{
				frameCount = (frameCount + 1) % (frameSkip + 1);
				if (frameCount > 0) return;
			}
		}

		if (running || screenDirty)
		{
			screenBuffer.render();
			screenDirty = false;
		}
	}

	override public function activate()
	{
		super.activate();
	}

	override public function deactivate()
	{
		super.deactivate();
		gb.audio.buffer1.clear();
		gb.audio.buffer2.clear();
		gb.saveSram();
	}

	var _buffering:Bool = true;
	override public function getSamples(e:Dynamic)
	{
		gb.audio.catchUp();

		var l:Int;
		if (_buffering)
		{
			l = Std.int(Math.max(0, AUDIO_BUFFER_SIZE * 2 - gb.audio.buffer1.length));
			if (l <= 0) _buffering = false;
			else l = AUDIO_BUFFER_SIZE;
		}
		else
		{
			// not enough samples; buffer until more arrive
			l = Std.int(Math.max(0, AUDIO_BUFFER_SIZE - gb.audio.buffer1.length));
			if (l > 0)
			{
				_buffering = true;
			}
		}

		for (i in 0 ... l)
		{
			e.data.writeDouble(0);
		}

		for (i in l ... AUDIO_BUFFER_SIZE)
		{
			e.data.writeFloat(volume * Util.clamp(gb.audio.buffer2.pop(), -0xf, 0xf) / 0xf);
			e.data.writeFloat(volume * Util.clamp(gb.audio.buffer1.pop(), -0xf, 0xf) / 0xf);
		}
	}

	override public function setSetting(id:String, value:Dynamic):Void
	{
		switch (id)
		{
			case Settings.GBPalette:
				gb.palette.swapPalettes(Std.string(value));
				screenDirty = true;

			case Settings.Ch1Volume:
				if (gb != null && gb.audio != null) gb.audio.ch1vol = cast(value, Int) / 100;
			case Settings.Ch2Volume:
				if (gb != null && gb.audio != null) gb.audio.ch2vol = cast(value, Int) / 100;
			case Settings.Ch3Volume:
				if (gb != null && gb.audio != null) gb.audio.ch3vol = cast(value, Int) / 100;
			case Settings.Ch4Volume:
				if (gb != null && gb.audio != null) gb.audio.ch4vol = cast(value, Int) / 100;

			default:
				super.setSetting(id, value);
		}
	}
}
