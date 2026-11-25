package data;

import haxe.io.Bytes;

class SoundData {
    public var bytes(get, null):Bytes;
    public var length(get, null):Int;
    public var src(get, null):String;
    public var allocated(get, null):Bool;

    private var __bytes:Bytes;
    private var __src:String;
    private var __allocated:Bool;

    public function new(bytes:Bytes, src:String = "") {
        if (bytes == null) throw "SoundData bytes must not be null";
        if (bytes.length == 0) throw "SoundData bytes must not be empty";

        __bytes = bytes;
        __src = src;
        __allocated = true;
    }

    public function dispose():Void {
        if (!__allocated) return;
        __bytes = null;
        __allocated = false;
    }

    private function get_bytes():Bytes {
        return __bytes;
    }

    private function get_length():Int {
        return __allocated ? __bytes.length : 0;
    }

    private function get_src():String {
        return __src;
    }

    private function get_allocated():Bool {
        return __allocated;
    }
}
