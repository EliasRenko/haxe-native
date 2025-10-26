package data;

@:forward(length, pop, push)
abstract Indices(Array<UInt>) from Array<UInt> to Array<UInt> {
	// Publics
	public var data(get, never):Array<UInt>;

    inline public function new(data:Array<UInt> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }
    
	public function insert(count:UInt, ?value:UInt):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:UInt):Void {
		this[pos] = value;
	}

	private function get_data():Array<UInt> {
		return this;
	}
}