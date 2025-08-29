package;

import math.Matrix;

class Camera {

    public var ortho:Bool = false;
    public var pitch(get, set):Int;
    public var roll(get, set):Int;
    public var x:Int = 0;
    public var yaw(get, set):Int;
    public var y:Int = 0;
    public var z:Int = 0;

    // ** Privates 

    private var __matrix:Matrix = new Matrix();
    private var __pitch:Int = 0;
    private var __roll:Int = 0;
    private var __yaw:Int = 0;

    public function new() {}

    public function renderMatrix(width:Float, height:Float):Void {

        __matrix.identity();
        __matrix.appendTranslation(x, y, z);

        if (ortho) {
            // Center-based orthographic projection: (-width/2, width/2, -height/2, height/2)
            __matrix.append(Matrix.createOrthoMatrix(-width/2, width/2, -height/2, height/2, 1000, -1000));
        }
        else {
            __matrix.append(Matrix.createPerspectiveMatrix(45 * Math.PI / 180, 4 / 3, width, height, 10, 1000));
        }

        //trace("Came matrix: " + __matrix.toArray());
    }

    public function getMatrix() {
        
        return __matrix;
    }

    // ** Getters and setters.

    private function get_pitch():Int {

        return __pitch;
    }

    private function set_pitch(value:Int):Int {

        return __pitch = (value %= 360) >= 0 ? value : (value + 360);
    }

    private function get_roll():Int {

        return __roll;
    }

    private function set_roll(value:Int):Int {

        return __roll = (value %= 360) >= 0 ? value : (value + 360);
    }

    private function get_yaw():Int {

        return __yaw;
    }

    private function set_yaw(value:Int):Int {

        return __yaw = (value %= 360) >= 0 ? value : (value + 360);
    }
}