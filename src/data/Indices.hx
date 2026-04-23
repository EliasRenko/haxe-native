package data;

#if js
typedef UIntData = UInt;
#else
typedef UIntData = cpp.UInt32;
#end

@:forward(length, pop, push)
abstract Indices(Array<UIntData>) from Array<UIntData> to Array<UIntData> {
	// Publics
	public var data(get, never):Array<UIntData>;

    inline public function new(data:Array<UIntData> = null) {
		this = data;
    }

	public function dispose():Void {
		for (index in 0...this.length) {
			this.pop();
		}
    }

	public function insert(count:UInt, ?value:UIntData):Void {
		for (value in 0...count) {
			this.push(1);
		}
	}

	public function set(pos:Int, value:UIntData):Void {
		this[pos] = value;
	}

	private function get_data():Array<UIntData> {
		return this;
	}
}