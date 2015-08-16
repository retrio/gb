package retrio.ui.openfl;

import retrio.emu.gb.GBControllerButton;
import retrio.ui.haxeui.ControllerSettingsPage;
import retrio.ui.openfl.controllers.*;


class GBControls
{
	public static var controllerImg:String = "graphics/controllers/gb.png";

	// String because Class<IController> can't be used as a map key
	public static var defaultBindings:Map<String, Map<Int, Int>> = [
#if (flash || desktop)
		KeyboardController.name => [
			GBControllerButton.Up => 87,
			GBControllerButton.Down => 83,
			GBControllerButton.Left => 65,
			GBControllerButton.Right => 68,
			GBControllerButton.A => 76,
			GBControllerButton.B => 75,
			GBControllerButton.Select => 9,
			GBControllerButton.Start => 13,
		],
#end
	];

	public static function settings(plugin:GBPlugin):Array<SettingCategory>
	{
		return [
			{name: "Controls", custom: {
				render:ControllerSettingsPage.render.bind(
					plugin,
					controllerImg,
					GBControllerButton.buttons,
					GBControllerButton.buttonNames,
					ControllerInfo.controllerTypes
				),
				save:ControllerSettingsPage.save.bind(plugin)
			}},
		];
	}
}
