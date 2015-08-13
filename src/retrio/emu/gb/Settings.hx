package retrio.emu.gb;


@:enum
abstract Settings(String) from String to String
{
	var GBPalette = "Palette (GB)";

	public static var settings:Array<SettingCategory> = [{
		name: 'GB', settings: [
			new Setting(GBPalette, SettingType.Options([for (p in Palette.paletteInfo) p.name]), "default"),
		]
	}];
}
