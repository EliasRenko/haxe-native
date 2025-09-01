package math;

// Comprehensive Matrix class for 4x4 transformations
class Matrix {
    public var data:Array<Float>;
    
    public function new() {
        data = [
            1, 0, 0, 0,
            0, 1, 0, 0, 
            0, 0, 1, 0,
            0, 0, 0, 1
        ];
    }
    
    public function identity():Void {
        data = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ];
    }
    
    // Copy constructor
    public static function copy(other:Matrix):Matrix {
        var m = new Matrix();
        for (i in 0...16) {
            m.data[i] = other.data[i];
        }
        return m;
    }
    
    // Matrix transformation methods
    public function setTranslation(x:Float, y:Float, z:Float):Void {
        data[12] = x;  // Translation X
        data[13] = y;  // Translation Y
        data[14] = z;  // Translation Z
    }
    
    public function appendTranslation(x:Float, y:Float, z:Float):Void {
        var m = new Matrix();
        m.identity();
        m.data[12] = x;
        m.data[13] = y; 
        m.data[14] = z;
        this.append(m);
    }
    
    public function appendScale(x:Float, y:Float, z:Float):Void {
        var m = new Matrix();
        m.identity();
        m.data[0] = x;   // Scale X
        m.data[5] = y;   // Scale Y
        m.data[10] = z;  // Scale Z
        this.append(m);
    }
    
	public function appendRotationZ(angle:Float):Void {
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var m = new Matrix();
		m.identity();
		m.data[0] = cos;   // [0,0]
		m.data[1] = sin;   // [0,1]
		m.data[4] = -sin;  // [1,0]
		m.data[5] = cos;   // [1,1]
		this.append(m);
	}
	
	public function appendRotationX(angle:Float):Void {
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var m = new Matrix();
		m.identity();
		m.data[5] = cos;   // [1,1] 
		m.data[6] = sin;   // [1,2]
		m.data[9] = -sin;  // [2,1]
		m.data[10] = cos;  // [2,2]
		this.append(m);
	}
	
	public function appendRotationY(angle:Float):Void {
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var m = new Matrix();
		m.identity();
		m.data[0] = cos;   // [0,0]
		m.data[2] = -sin;  // [0,2]
		m.data[8] = sin;   // [2,0]
		m.data[10] = cos;  // [2,2]
		this.append(m);
	}
	
	public function appendRotation(angle:Float, axis:Dynamic):Void {
		// For now, just support Z-axis rotation for backwards compatibility
		appendRotationZ(angle);
	}    public function append(other:Matrix):Void {
        // Matrix multiplication: this = this * other
        var result = new Array<Float>();
        result.resize(16);
        
        for (i in 0...4) {
            for (j in 0...4) {
                var sum = 0.0;
                for (k in 0...4) {
                    sum += this.data[i * 4 + k] * other.data[k * 4 + j];
                }
                result[i * 4 + j] = sum;
            }
        }
        
        this.data = result;
    }
    
    // Static method to create orthographic projection matrix
    public static function createOrthoMatrix(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float):Matrix {
        var m = new Matrix();
        m.identity();
        
        var width = right - left;
        var height = top - bottom;
        var depth = far - near;
        
        // Orthographic projection matrix
        m.data[0] = 2.0 / width;     // Scale X
        m.data[5] = 2.0 / height;    // Scale Y  
        m.data[10] = -2.0 / depth;   // Scale Z
        m.data[12] = -(right + left) / width;   // Translate X
        m.data[13] = -(top + bottom) / height;  // Translate Y
        m.data[14] = -(far + near) / depth;     // Translate Z
        
        return m;
    }
    
    // Static method to create perspective projection matrix
    public static function createPerspectiveMatrix(fov:Float, aspect:Float, near:Float, far:Float):Matrix {
        var m = new Matrix();
        m.identity();
        
        var f = 1.0 / Math.tan(fov / 2.0);
        var depth = far - near;
        
        // Perspective projection matrix
        m.data[0] = f / aspect;      // Scale X by aspect ratio
        m.data[5] = f;               // Scale Y
        m.data[10] = -(far + near) / depth;     // Z scaling
        m.data[11] = -1.0;           // W = -Z (perspective divide)
        m.data[14] = -(2.0 * far * near) / depth;  // Z translation
        m.data[15] = 0.0;            // Clear W translation
        
        return m;
    }
    
    // Convert to array for shader uniforms
    public function toArray():Array<Float> {
        return data.copy();
    }
    
    // Debug helper
    public function toString():String {
        var str = "Matrix:\n";
        for (i in 0...4) {
            str += "  [";
            for (j in 0...4) {
                str += Std.string(Math.round(data[i * 4 + j] * 1000) / 1000);
                if (j < 3) str += ", ";
            }
            str += "]\n";
        }
        return str;
    }
}
