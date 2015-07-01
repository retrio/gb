package retrio.emu.gb;


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
				((controller.pressed(Button.Right) ? 0 : 0x1) |
				(controller.pressed(Button.Left) ? 0 : 0x2) |
				(controller.pressed(Button.Up) ? 0 : 0x4) |
				(controller.pressed(Button.Down) ? 0 : 0x8))
			: 0x10) |
			(buttonsEnabled ?
				((controller.pressed(Button.A) ? 0 : 0x1) |
				(controller.pressed(Button.B) ? 0 : 0x2) |
				(controller.pressed(Button.Select) ? 0 : 0x4) |
				(controller.pressed(Button.Start) ? 0 : 0x8))
			: 0x20);
	}
}
