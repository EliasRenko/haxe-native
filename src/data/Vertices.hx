package data;

import cpp.Float32;

@:forward(length, pop, push)
abstract Vertices(Array<Float32>) from Array<Float32> to Array<Float32> {
	// Publics
	public var data(get, never):Array<Float32>;

    inline public function new(data:Array<Float32> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }
    
	public function insert(count:UInt, ?value:Float32):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:Float):Void {
		this[pos] = value;
	}

	private function get_data():Array<Float32> {
		return this;
	}
}