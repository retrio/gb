package retrio.emu.gb;


interface ISoundGenerator
{
	public var enabled:Bool;

	public function play():Int;
	public function lengthClock():Void;
	public function reset():Void;
}
