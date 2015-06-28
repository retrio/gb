package strafe.ui.openfl;

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
import strafe.emu.gb.GB;
import strafe.emu.gb.Palette;


class GBPlugin extends EmulatorPlugin
{
	var loopStart:Int = 0;
	var loopEnd:Int = 0;
	var clipTop(default, set):Int = 0;
	var clipBottom(default, set):Int = 0;
	function set_clipTop(y:Int)
	{
		clipTop = y;
		setClip();
		return y;
	}
	function set_clipBottom(y:Int)
	{
		clipBottom = y;
		setClip();
		return y;
	}
	function setClip()
	{
		loopStart = clipTop*GB.WIDTH;
		loopEnd = (GB.HEIGHT-(clipBottom))*GB.WIDTH;
		r.height = GB.HEIGHT-clipBottom-clipTop;
		bmpData.fillRect(bmpData.rect, 0xff000000);
	}

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

	public function new()
	{
		super();
		this.emu = this.gb = new GB();
		extensions = gb.extensions;

		_stage.quality = flash.display.StageQuality.LOW;
		bmpData = new BitmapData(GB.WIDTH, GB.HEIGHT, false, 0);

		pixels.endian = Endian.BIG_ENDIAN;
		pixels.clear();
		for (i in 0 ... GB.WIDTH*GB.HEIGHT*4)
			pixels.writeByte(0);

		Memory.select(pixels);

		clipTop = clipBottom = 0;
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
			for (i in loopStart ... loopEnd) // GB.WIDTH x GB.HEIGHT
			{
				Memory.setI32((i-loopStart)*4, Palette.getColor(bm.get(i)));
			}

			pixels.position = 0;
			bmpData.setPixels(r, pixels);
			canvas.draw(bmpData, m);
		}
	}

	function initScreen(width:Int, height:Int)
	{
		canvas = new BitmapData(width, height, false, 0);
		bmp = new Bitmap(canvas);
		addChild(bmp);

		var sx = canvas.width / GB.WIDTH, sy = canvas.height / (GB.HEIGHT-clipTop-clipBottom);
		m.setTo(sx, 0, 0, sy, 0, 0);

		initialized = true;
	}

	override public function capture()
	{
		var capture = new BitmapData(bmpData.width, bmpData.height - clipTop - clipBottom);
		capture.copyPixels(bmpData, capture.rect, new flash.geom.Point());
		return capture;
	}
}
