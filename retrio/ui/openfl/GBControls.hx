package retrio.ui.openfl;

import retrio.config.SettingCategory;
import retrio.config.CustomSetting;
import retrio.emu.gb.GBControllerButton;
import retrio.ui.haxeui.ControllerSettingsPage;
import retrio.ui.openfl.controllers.*;


class GBControls
{
	public static var controllerImg:String = "graphics/gb_controls.png";

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
			{id: "controls", name: "Controls", custom: new CustomSetting({
				render:ControllerSettingsPage.render.bind(
					plugin,
					controllerImg,
					GBControllerButton.buttons,
					GBControllerButton.buttonNames,
					ControllerInfo.controllerTypes
				),
				save:ControllerSettingsPage.save.bind(plugin),
				serialize:ControllerSettingsPage.serialize.bind(plugin),
				unserialize:ControllerSettingsPage.unserialize.bind(plugin, ControllerInfo.controllerTypes),
			})},
		];
	}
}
