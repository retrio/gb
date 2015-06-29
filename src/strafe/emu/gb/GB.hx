package strafe.emu.gb;

import haxe.ds.Vector;
import haxe.io.Output;
import strafe.FileWrapper;
import strafe.IController;


class GB implements IEmulator implements IState
{
	public static inline var WIDTH:Int = 160;
	public static inline var HEIGHT:Int = 144;

	public var width:Int = WIDTH;
	public var height:Int = HEIGHT;

	public var buffer:ByteString;
	public var extensions:Array<String> = ["*.gb"];

	// hardware components
	public var cpu:CPU;
	public var cart:Cart;
	public var video:Video;
	public var controllers:Vector<GBController> = new Vector(2);

	public function new() {}

	public function loadGame(gameData:FileWrapper)
	{
		cart = new Cart(gameData);
		cpu = new CPU();
		video = new Video();

		cpu.init(cart, video);
		video.init(cpu, cart);
		cart.init(video, controllers);

		buffer = video.screenBuffer;
	}

	public function reset():Void
	{
		//cpu.reset(this);
	}

	public function frame()
	{
		cpu.runFrame();
	}

	public function addController(controller:IController, ?port:Int=null):Null<Int>
	{
		if (port == null)
		{
			for (i in 0 ... controllers.length)
			{
				if (controllers[i] == null)
				{
					port = i;
					break;
				}
			}
			if (port == null) return null;
		}
		else
		{
			if (controllers[port] != null) return null;
		}

		controllers[port] = new GBController(controller);
		controller.init(this);

		return port;
	}

	public function getColor(c:Int)
	{
		return Palette.getColor(c);
	}

	public function writeState(out:Output)
	{
	}
}
