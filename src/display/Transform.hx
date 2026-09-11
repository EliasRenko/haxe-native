package display;

import data.Indices;
import data.Vertices;
import Renderer;

class Transform extends DisplayObject {

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;
	public var rotationX(get, set):Float;
	public var rotationY(get, set):Float;
	public var rotationZ(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;

	private var __x:Float = 0;
	private var __y:Float = 0;
	private var __z:Float = 0;
	private var __rotationX:Float = 0;
	private var __rotationY:Float = 0;
	private var __rotationZ:Float = 0;
	private var __scaleX:Float = 1;
	private var __scaleY:Float = 1;

	private var __transformDirty:Bool = true;

	public function new(renderer:Renderer, vertices:Vertices, indices:Indices) {
        super(renderer, vertices, indices);
    }

    public function updateTransform():Void {
		matrix.identity();
		matrix.appendScale(__scaleX, __scaleY, 1);
		matrix.appendRotationX(__rotationX);
		matrix.appendRotationY(__rotationY);
		matrix.appendRotationZ(-__rotationZ * Math.PI / 180.0);
		matrix.appendTranslation(__x, __y, __z);
	}

	private function get_x():Float      { return __x; }
	private function get_y():Float      { return __y; }
	private function get_z():Float      { return __z; }
	private function get_rotationX():Float { return __rotationX; }
	private function get_rotationY():Float { return __rotationY; }
	private function get_rotationZ():Float { return __rotationZ; }
	private function get_scaleX():Float { return __scaleX; }
	private function get_scaleY():Float { return __scaleY; }

	private function set_x(v:Float):Float      { __x = v;         __transformDirty = true; return v; }
	private function set_y(v:Float):Float      { __y = v;         __transformDirty = true; return v; }
	private function set_z(v:Float):Float      { __z = v;         __transformDirty = true; return v; }
	private function set_rotationX(v:Float):Float { __rotationX = v; __transformDirty = true; return v; }
	private function set_rotationY(v:Float):Float { __rotationY = v; __transformDirty = true; return v; }
	private function set_rotationZ(v:Float):Float { __rotationZ = v; __transformDirty = true; return v; }
	private function set_scaleX(v:Float):Float { __scaleX = v;    __transformDirty = true; return v; }
	private function set_scaleY(v:Float):Float { __scaleY = v;    __transformDirty = true; return v; }
}
