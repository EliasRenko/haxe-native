package data;

@:forward(length, pop, push)
abstract Vertices(Array<Float>) from Array<Float> to Array<Float> {
	// Publics
	public var data(get, never):Array<Float>;

    inline public function new(data:Array<Float> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }
    
	public function insert(count:UInt, ?value:Float):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:Float):Void {
		this[pos] = value;
	}

	private function get_data():Array<Float> {
		return this;
	}
}