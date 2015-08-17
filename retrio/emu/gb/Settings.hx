package retrio.emu.gb;


@:enum
abstract Settings(String) from String to String
{
	var GBPalette = "Palette (GB)";

	var Ch1Volume = "Square 1";
	var Ch2Volume = "Square 2";
	var Ch3Volume = "Sample";
	var Ch4Volume = "Noise";

	public static var settings:Array<SettingCategory> = [
		{
			name: 'GB', settings: [
				new Setting(GBPalette, SettingType.Options([for (p in Palette.paletteInfo) p.name]), "default"),
			]
		},
		{
			name: 'GB Audio', settings: [
				new Setting(Ch1Volume, IntValue(0,100), 100),
				new Setting(Ch2Volume, IntValue(0,100), 100),
				new Setting(Ch3Volume, IntValue(0,100), 100),
				new Setting(Ch4Volume, IntValue(0,100), 100),
			]
		},
	];
}
