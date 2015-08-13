package retrio.emu.gb;


interface ISoundGenerator
{
	public var enabled(get, never):Bool;

	public function play(rate:Float):Int;
	public function lengthClock():Void;
	public function reset():Void;
}
