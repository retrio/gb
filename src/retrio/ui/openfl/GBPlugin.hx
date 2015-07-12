package retrio.ui.openfl;

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
import retrio.emu.gb.GB;
import retrio.emu.gb.Palette;


@:access(retrio.emu.gb.GB)
class GBPlugin extends EmulatorPlugin
{
	static var _registered = Shell.registerPlugin("gb", new GBPlugin());

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
#if encode
	var encoder = new retrio.WavEncoder();
#end

	public function new()
	{
		super();
		this.emu = this.gb = new GB();
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
			gb.frame();

			if (!gb.video.finished) return;

			if (frameSkip > 0)
			{
				var skip = frameCount > 0;
				frameCount = (frameCount + 1) % (frameSkip + 1);
				if (skip) return;
			}

			var bm = gb.buffer;
			for (i in 0 ... GB.WIDTH * GB.HEIGHT)
			{
				Memory.setI32(i*4, Palette.getColor(bm.get(i)));
			}

			pixels.position = 0;
			bmpData.setPixels(r, pixels);
			canvas.draw(bmpData, m);
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
		gb.saveSram();
	}

	function initScreen(width:Int, height:Int)
	{
		canvas = new BitmapData(width, height, false, 0);
		bmp = new Bitmap(canvas);
		addChild(bmp);

		var sx = canvas.width / GB.WIDTH, sy = canvas.height / (GB.HEIGHT);
		m.setTo(sx, 0, 0, sy, 0, 0);

		initialized = true;
	}

	override public function capture()
	{
#if encode
		var outFile = sys.io.File.write("out.wav", true);
		encoder.encode(outFile);
#end
		var capture = new BitmapData(bmpData.width, bmpData.height);
		capture.copyPixels(bmpData, capture.rect, new flash.geom.Point());
		return capture;
	}

	var _buffering:Bool = true;
	override public function getSamples(e:Dynamic)
	{
		gb.audio.catchUp();

#if encode
		while (gb.audio.buffer1.length > 0)
		{
			encoder.writeSample(Util.clamp(gb.audio.buffer2.pop(), -0xf, 0xf) / 0xf);
			encoder.writeSample(Util.clamp(gb.audio.buffer1.pop(), -0xf, 0xf) / 0xf);
		}

		for (i in 0 ... 0x800)
		{
			e.data.writeFloat(0);
			e.data.writeFloat(0);
		}
#else
		var l:Int;
		if (_buffering)
		{
			l = Std.int(Math.max(0, 0x1000 - gb.audio.buffer1.length));
			if (l <= 0) _buffering = false;
		}
		else
		{
			// not enough samples; buffer until more arrive
			l = Std.int(Math.max(0, 0x800 - gb.audio.buffer1.length));
			if (l > 0)
			{
				_buffering = true;
			}
		}

		for (i in 0 ... l)
		{
			e.data.writeDouble(0);
		}

		for (i in l ... 0x800)
		{
			e.data.writeFloat(Util.clamp(gb.audio.buffer2.pop(), -0xf, 0xf) / 0xf);
			e.data.writeFloat(Util.clamp(gb.audio.buffer1.pop(), -0xf, 0xf) / 0xf);
		}
#end
	}

	override public function setSpeed(speed:EmulationSpeed)
	{
		gb.audio.speedMultiplier = speed;
	}
}
