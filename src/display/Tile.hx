package display;

class Tile {
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var width(get, set):Float;
    public var height(get, set):Float;
    public var regionId(get, set):Int;
    public var parent:Dynamic; // Reference to the owning tile manager/batch
    public var visible(get, set):Bool;
    public var offsetX(get, set):Float;
    public var offsetY(get, set):Float;
    public var rotation(get, set):Float;

    private var __x:Float = 0.0;
    private var __y:Float = 0.0;
    private var __width:Float = 1.0;
    private var __height:Float = 1.0;
    private var __regionId:Int = 0;
    private var __visible:Bool = true;
    private var __offsetX:Float = 0.0;
    private var __offsetY:Float = 0.0;
    private var __rotation:Float = 0.0;

    public var onChanged:Null<Void->Void>;

    public function new(parent:Dynamic, regionId:Int = 0) {
        this.parent = parent;
        __regionId = regionId;
    }

    private inline function notifyChanged():Void {
        if (onChanged != null) onChanged();
    }

    private function get_x():Float return __x;
    private function set_x(value:Float):Float {
        if (__x == value) return __x;
        __x = value;
        notifyChanged();
        return __x;
    }

    private function get_y():Float return __y;
    private function set_y(value:Float):Float {
        if (__y == value) return __y;
        __y = value;
        notifyChanged();
        return __y;
    }

    private function get_width():Float return __width;
    private function set_width(value:Float):Float {
        if (__width == value) return __width;
        __width = value;
        notifyChanged();
        return __width;
    }

    private function get_height():Float return __height;
    private function set_height(value:Float):Float {
        if (__height == value) return __height;
        __height = value;
        notifyChanged();
        return __height;
    }

    private function get_regionId():Int return __regionId;
    private function set_regionId(value:Int):Int {
        if (__regionId == value) return __regionId;
        __regionId = value;
        notifyChanged();
        return __regionId;
    }

    private function get_visible():Bool return __visible;
    private function set_visible(value:Bool):Bool {
        if (__visible == value) return __visible;
        __visible = value;
        notifyChanged();
        return __visible;
    }

    private function get_offsetX():Float return __offsetX;
    private function set_offsetX(value:Float):Float {
        if (__offsetX == value) return __offsetX;
        __offsetX = value;
        notifyChanged();
        return __offsetX;
    }

    private function get_offsetY():Float return __offsetY;
    private function set_offsetY(value:Float):Float {
        if (__offsetY == value) return __offsetY;
        __offsetY = value;
        notifyChanged();
        return __offsetY;
    }

    private function get_rotation():Float return __rotation;
    private function set_rotation(value:Float):Float {
        if (__rotation == value) return __rotation;
        __rotation = value;
        notifyChanged();
        return __rotation;
    }
}