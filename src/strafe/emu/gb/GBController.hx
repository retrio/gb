package strafe.emu.gb;


class GBController
{
	public var directionsEnabled:Bool = false;
	public var buttonsEnabled:Bool = false;

	var controller:IController;

	public function new(controller:IController)
	{
		this.controller = controller;
	}

	public inline function buttons()
	{
		return
			(directionsEnabled ?
				((controller.pressed(Button.Right) ? 0x1 : 0) |
				(controller.pressed(Button.Left) ? 0x2 : 0) |
				(controller.pressed(Button.Up) ? 0x4 : 0) |
				(controller.pressed(Button.Down) ? 0x8 : 0))
			: 0x10) |
			(buttonsEnabled ?
				((controller.pressed(Button.A) ? 0x1 : 0) |
				(controller.pressed(Button.B) ? 0x2 : 0) |
				(controller.pressed(Button.Select) ? 0x4 : 0) |
				(controller.pressed(Button.Start) ? 0x8 : 0))
			: 0x20);
	}
}
