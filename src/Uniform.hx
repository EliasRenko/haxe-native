package;

class Uniform<T> {
    public final index:Int;
    public var value:T;

    public function new(index:Int) {
        this.index = index;
    }
}