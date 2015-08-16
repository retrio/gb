package retrio.emu.gb;


class GBController
{
	public var controller(default, set):IController;
	function set_controller(c:IController)
	{
		if (c != null) c.inputHandler = this.handleInput;
		return controller = c;
	}

	public var directionsEnabled:Bool = false;
	public var buttonsEnabled:Bool = false;
	public var changed:Bool = false;

	public function new() {}

	inline function pressed(btn:Int)
	{
		return controller == null ? false : controller.pressed(btn);
	}

	public inline function buttons()
	{
		return
			(directionsEnabled ?
				((pressed(GBControllerButton.Right) ? 0 : 0x1) |
				(pressed(GBControllerButton.Left) ? 0 : 0x2) |
				(pressed(GBControllerButton.Up) ? 0 : 0x4) |
				(pressed(GBControllerButton.Down) ? 0 : 0x8))
			: 0x1f) &
			(buttonsEnabled ?
				((pressed(GBControllerButton.A) ? 0 : 0x1) |
				(pressed(GBControllerButton.B) ? 0 : 0x2) |
				(pressed(GBControllerButton.Select) ? 0 : 0x4) |
				(pressed(GBControllerButton.Start) ? 0 : 0x8))
			: 0x2f);
	}

	function handleInput(e:Dynamic)
	{
		changed = true;
	}
}
