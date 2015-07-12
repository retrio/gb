package retrio.emu.gb;


interface ISoundGenerator
{
	public var enabled(get, set):Bool;

	public function play():Int;
	public function lengthClock():Void;
	public function reset():Void;
}
