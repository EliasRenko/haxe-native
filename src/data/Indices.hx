package data;

import cpp.UInt32;

@:forward(length, pop, push)
abstract Indices(Array<UInt32>) from Array<UInt32> to Array<UInt32> {
	// Publics
	public var data(get, never):Array<UInt32>;

    inline public function new(data:Array<UInt32> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }

	public function insert(count:UInt, ?value:UInt32):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:UInt32):Void {
		this[pos] = value;
	}

	private function get_data():Array<UInt32> {
		return this;
	}
}