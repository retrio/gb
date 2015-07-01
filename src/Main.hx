import retrio.ui.openfl.KeyboardController;
import retrio.FileWrapper;
import retrio.ui.openfl.GBPlugin;
import retrio.ui.openfl.Shell;
import retrio.emu.gb.Button;


class Main extends retrio.ui.openfl.Shell
{
	function new()
	{
		super();

#if (cpp && profile)
		cpp.vm.Profiler.start();
	}

	var _profiling:Bool = true;
	var _f = 0;
	override public function update(e:Dynamic)
	{
		super.update(e);

		if (_profiling)
		{
			_f++;
			trace(_f);
			if (_f >= 60*15)
			{
				trace("DONE");
				cpp.vm.Profiler.stop();
				_profiling = false;
			}
		}
#end
	}

	static function main()
	{
		var m = new Main();
	}

	override function onStage(e:Dynamic)
	{
		super.onStage(e);

		var plugin = new GBPlugin();
		var controller = new retrio.ui.openfl.KeyboardController();

		var keyDefaults:Map<Button, Int> = [
			Button.A => 76,
			Button.B => 75,
			Button.Select => 9,
			Button.Start => 13,
			Button.Up => 87,
			Button.Down => 83,
			Button.Left => 65,
			Button.Right => 68
		];
		for (btn in keyDefaults.keys())
			controller.defineKey(keyDefaults[btn], btn);

		plugin.addController(controller);

		loadPlugin(plugin);
	}
}
