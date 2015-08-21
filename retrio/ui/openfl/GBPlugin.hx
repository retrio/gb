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
import flash.utils.Endian;
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

	var bmp:Bitmap;
	var canvas:BitmapData;
	var bmpData:BitmapData;
	var m:Matrix = new Matrix();
	var pixels:ByteArray = new ByteArray();
	var frameCount = 0;
	var r = new Rectangle(0, 0, GB.WIDTH, GB.HEIGHT);
	var screenDirty:Bool = false;

	public function new()
	{
		super();

		controllers = new Vector(1);

		this.emu = this.gb = new GB();
		this.settings = GlobalSettings.settings.concat(
			retrio.emu.gb.Settings.settings
		).concat(
			GBControls.settings(this)
		);
		extensions = gb.extensions;

		bmpData = new BitmapData(GB.WIDTH, GB.HEIGHT, false, 0);

		pixels.endian = Endian.BIG_ENDIAN;
		pixels.clear();
		for (i in 0 ... GB.WIDTH*GB.HEIGHT*4)
			pixels.writeByte(0);
	}

	override public function resize(width:Int, height:Int)
	{
		if (width == 0 || height == 0)
			return;

		if (bmp != null)
		{
			removeChild(bmp);
			canvas.dispose();
			bmp = null;
			canvas = null;
		}

		initScreen(width, height);
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
			var bm = gb.buffer;
			for (i in 0 ... GB.WIDTH * GB.HEIGHT)
			{
				Memory.setI32(i*4, gb.palette.getColor(bm.get(i)));
			}

			pixels.position = 0;

			bmpData.lock();
			canvas.lock();
			bmpData.setPixels(r, pixels);
			canvas.draw(bmpData, m, null, null, null, smooth);
			canvas.unlock();
			bmpData.unlock();

			screenDirty = false;
		}
	}

	override public function activate()
	{
		super.activate();
		Memory.select(pixels);
	}

	override public function deactivate()
	{
		super.deactivate();
		gb.audio.buffer1.clear();
		gb.audio.buffer2.clear();
		gb.saveSram();
	}

	function initScreen(width:Int, height:Int)
	{
		canvas = new BitmapData(width, height, false, 0);
		bmp = new Bitmap(canvas);
		addChildAt(bmp, 0);

		var sx = canvas.width / GB.WIDTH, sy = canvas.height / (GB.HEIGHT);
		m.setTo(sx, 0, 0, sy, 0, 0);

		initialized = true;
	}

	override public function capture()
	{
		var capture = new BitmapData(bmpData.width, bmpData.height);
		capture.copyPixels(bmpData, capture.rect, new flash.geom.Point());
		return capture;
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
