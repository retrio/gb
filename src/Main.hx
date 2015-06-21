class Main
{
	static function main()
	{
		var file = strafe.FileWrapper.read("assets/roms/ffl.gb");
		var rom = new strafe.emu.gb.Cart(file);
		trace(rom.name);

		var cpu = new strafe.emu.gb.CPU();
		cpu.init(rom);

		for (i in 0 ... 1000)
			cpu.runCycle();
	}
}
