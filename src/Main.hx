import strafe.ui.openfl.KeyboardController;
import strafe.FileWrapper;
import strafe.ui.openfl.GBPlugin;
import strafe.ui.openfl.Shell;
import strafe.emu.gb.Button;


class Main extends strafe.ui.openfl.Shell
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
		var controller = new strafe.ui.openfl.KeyboardController();

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
