package retrio.emu.gb;


@:enum
abstract Settings(String) from String to String
{
	var GBPalette = "gbpalette";

	var Ch1Volume = "ch1";
	var Ch2Volume = "ch2";
	var Ch3Volume = "ch3";
	var Ch4Volume = "ch4";

	public static var settings:Array<SettingCategory> = [
		{
			id: "gb", name: 'GB', settings: [
				new Setting(GBPalette, "Palette (GB)", SettingType.Options([for (p in Palette.paletteInfo) p.name]), "default"),
			]
		},
		{
			id: "gbaudio", name: 'GB Audio', settings: [
				new Setting(Ch1Volume, "Square 1", IntValue(0,100), 100),
				new Setting(Ch2Volume, "Square 2", IntValue(0,100), 100),
				new Setting(Ch3Volume, "Noise", IntValue(0,100), 100),
				new Setting(Ch4Volume, "Sample", IntValue(0,100), 100),
			]
		},
	];
}
