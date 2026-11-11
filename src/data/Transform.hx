package data;

import data.Indices;
import data.Vertices;
import math.Matrix;

class Transform {

	// Publics
	public var matrix(get, null):Matrix;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;
	public var rotationX(get, set):Float;
	public var rotationY(get, set):Float;
	public var rotationZ(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var scaleZ(get, set):Float;
	public var dirty(get, set):Bool;

	// Privates
	private var __matrix:Matrix = new Matrix();
	private var __x:Float = 0;
	private var __y:Float = 0;
	private var __z:Float = 0;
	private var __rotationX:Float = 0;
	private var __rotationY:Float = 0;
	private var __rotationZ:Float = 0;
	private var __scaleX:Float = 1;
	private var __scaleY:Float = 1;
	private var __scaleZ:Float = 1;
	private var __dirty:Bool = true;

	public function new() {}

    public function updateTransform():Void {
		__matrix.identity();
		__matrix.appendScale(__scaleX, __scaleY, __scaleZ);
		__matrix.appendRotationX(__rotationX);
		__matrix.appendRotationY(__rotationY);
		__matrix.appendRotationZ(-__rotationZ * Math.PI / 180.0);
		__matrix.appendTranslation(__x, __y, __z);
	}

	// Getters and setters
	private function get_x():Float {
		return __x;
	}

	private function get_y():Float {
		return __y;
	}

	private function get_z():Float {
		return __z;
	}

	private function get_rotationX():Float {
		return __rotationX;
	}

	private function get_rotationY():Float {
		return __rotationY;
	}

	private function get_rotationZ():Float {
		return __rotationZ;
	}

	private function get_scaleX():Float {
		return __scaleX;
	}

	private function get_scaleY():Float {
		return __scaleY;
	}

	private function set_x(v:Float):Float {
		__x = v;
		__dirty = true;
		return v;
	}

	private function set_y(v:Float):Float {
		__y = v;
		__dirty = true;
		return v;
	}

	private function set_z(v:Float):Float {
		__z = v;
		__dirty = true;
		return v;
	}

	private function set_rotationX(v:Float):Float {
		__rotationX = v;
		__dirty = true;
		return v;
	}

	private function set_rotationY(v:Float):Float {
		__rotationY = v;
		__dirty = true;
		return v;
	}

	private function set_rotationZ(v:Float):Float {
		__rotationZ = v;
		__dirty = true;
		return v;
	}

	private function set_scaleX(v:Float):Float {
		__scaleX = v;
		__dirty = true;
		return v;
	}

	private function set_scaleY(v:Float):Float {
		__scaleY = v;
		__dirty = true;
		return v;
	}

	private function set_scaleZ(v:Float):Float {
		__scaleZ = v;
		__dirty = true;
		return v;
	}

	private function get_matrix():Matrix {
		return __matrix;
	}

	private function get_dirty():Bool {
		return __dirty;
	}
}
