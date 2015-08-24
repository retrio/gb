package retrio.emu.gb;

import haxe.io.BytesInput;
import retrio.io.FileWrapper;
import retrio.io.IEnvironment;
import retrio.io.IScreenBuffer;


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
	public var extensions:Array<String> = ["*.gb"];
	public var screenBuffer(default, set):IScreenBuffer;
	function set_screenBuffer(screenBuffer:IScreenBuffer)
	{
		return this.screenBuffer = screenBuffer;
	}

	// hardware components
	public var cpu:CPU;
	public var memory:Memory;
	public var rom:ROM;
	public var video:Video;
	public var audio:Audio;
	public var palette:Palette = new Palette();

	public var maxControllers:Int = 1;
	public var controller:GBController;

	var _saveCounter:Int = 0;
	@:state var romName:String;
	@:state var useSram:Bool = true;

	public function new()
	{
		controller = new GBController();
	}

	public function loadGame(gameData:FileWrapper, ?useSram:Bool=true)
	{
		rom = new ROM(gameData);
		memory = new Memory(rom);

		romName = gameData.name;
		this.useSram = useSram;

		reset();
	}

	public function reset():Void
	{
		cpu = new CPU();
		video = new Video();
		audio = new Audio();

		memory.init(cpu, video, audio, controller);
		video.init(this, cpu, memory);
		audio.init(cpu, memory);
		cpu.init(memory, video, audio);
		memory.writeInitialState();

		if (useSram) loadSram();
	}

	public function frame(rate:Float)
	{
		audio.newFrame(rate);
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

	public function addController(controller:IController, port:Int)
	{
		this.controller.controller = controller;
	}

	public function removeController(port:Int)
	{
		controller.controller = null;
	}

	public inline function getColor(c:Int)
	{
		return palette.getColor(c);
	}

	public function savePersistentState(slot:SaveSlot):Void
	{
		if (io != null)
		{
			var state = saveState();
			var file = io.writeFile();
			file.writeBytes(state);
			file.save(romName + ".st" + slot);
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
			var file = io.writeFile();
			file.writeVector(memory.ramBanks);
			file.save(romName + ".srm");
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
