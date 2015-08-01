package retrio.emu.gb;

import haxe.ds.Vector;
import haxe.io.BytesInput;


class GB implements IEmulator implements IState
{
	@:stateVersion static var stateVersion = 1;
	@:stateChildren static var stateChildren = ['cpu', 'memory', 'rom', 'video', 'audio'];

	public static inline var WIDTH:Int = 160;
	public static inline var HEIGHT:Int = 144;
	// minimum # of frames to wait between saves
	public static inline var SRAM_SAVE_FRAMES = 60;

	public var width:Int = WIDTH;
	public var height:Int = HEIGHT;

	public var io:IEnvironment;
	public var buffer:ByteString;
	public var extensions:Array<String> = ["*.gb"];

	// hardware components
	public var cpu:CPU;
	public var memory:Memory;
	public var rom:ROM;
	public var video:Video;
	public var audio:Audio;

	public var controllers:Vector<GBController> = new Vector(2);
	public var palette:Palette;

	var _saveCounter:Int = 0;
	@:state var romName:String;
	@:state var useSram:Bool = true;

	public function new() {}

	public function loadGame(gameData:FileWrapper, ?useSram:Bool=true)
	{
		rom = new ROM(gameData);
		memory = new Memory(rom);

		reset();

		romName = gameData.name;
		this.useSram = useSram;
	}

	public function reset():Void
	{
		cpu = new CPU();
		video = new Video();
		audio = new Audio();
		palette = new Palette();

		buffer = video.screenBuffer;

		memory.init(cpu, video, audio, controllers);
		video.init(cpu, memory);
		audio.init(cpu, memory);
		cpu.init(memory, video, audio);
		memory.writeInitialState();

		if (useSram) loadSram();
	}

	public function frame()
	{
		audio.newFrame();
		cpu.runFrame();

		if (memory.sramDirty)
		{
			if (_saveCounter < SRAM_SAVE_FRAMES)
			{
				++_saveCounter;
			}
			else
			{
				saveSram();
			}
		}
		else _saveCounter = 0;
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
		return palette.getColor(c);
	}

	public function savePersistentState(slot:SaveSlot):Void
	{
		if (io != null)
		{
			var state = saveState();
			io.writeBytesToFile(romName + ".st" + slot, state);
		}
	}

	public function loadPersistentState(slot:SaveSlot):Void
	{
		if (io != null)
		{
			var stateFile = io.readFile(romName + ".st" + slot);
			if (stateFile == null) throw "State " + slot + " does not exist";
			var input = new BytesInput(stateFile.readAll());
			loadState(input);
		}
	}

	function saveSram()
	{
		if (useSram && rom.hasSram && memory.sramDirty && io != null)
		{
			io.writeVectorToFile(romName + ".srm", memory.ramBanks);
			memory.sramDirty = false;
			_saveCounter = 0;
		}
	}

	function loadSram()
	{
		if (useSram && io.fileExists(romName + ".srm"))
		{
			var file = io.readFile(romName + ".srm");
			if (file != null)
			{
				for (bank in memory.ramBanks)
				{
					bank.readFrom(file);
				}
				memory.sramDirty = false;
			}
		}
	}
}
