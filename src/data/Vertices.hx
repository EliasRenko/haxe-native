package data;

#if js
typedef FloatData = Float;
#else
typedef FloatData = cpp.Float32;
#end

@:forward(length, pop, push)
abstract Vertices(Array<FloatData>) from Array<FloatData> to Array<FloatData> {
	// Publics
	public var data(get, never):Array<FloatData>;

    inline public function new(data:Array<FloatData> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }
    
	public function insert(count:UInt, ?value:FloatData):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:FloatData):Void {
		this[pos] = value;
	}

	private function get_data():Array<FloatData> {
		return this;
	}
}