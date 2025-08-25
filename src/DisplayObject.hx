package;

import GL;
import ProgramInfo;
import ProgramInfo.UniformFormat;

typedef BlendFactors = {
	source:Int,
	destination:Int
}

// Simple vertex data container
class Vertices {
	public var data:Array<Float>;
	
	public function new(data:Array<Float>) {
		this.data = data;
	}
	
	// Allow array access
	public function get(index:Int):Float {
		return data[index];
	}
	
	public function set(index:Int, value:Float):Float {
		return data[index] = value;
	}
}

// Simple index data container  
class Indices {
	public var data:Array<Int>;
	
	public function new(data:Array<Int>) {
		this.data = data;
	}
}

// Simple matrix class for transformations
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
	
	public function appendRotation(angle:Float, axis:Dynamic):Void {
		// For now, just support Z-axis rotation
		appendRotationZ(angle);
	}
	
	public function append(other:Matrix):Void {
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
}

// Blend factor constants
class BlendFactor {
	public static var SRC_ALPHA:Int = 770;  // GL.SRC_ALPHA
	public static var ONE_MINUS_SRC_ALPHA:Int = 771;  // GL.ONE_MINUS_SRC_ALPHA
}

class DisplayObject {
	//** Publics.
	public var bufferId:UInt = 0;
	public var mode:Int = GL.TRIANGLES; // Use proper GL constant
	public var blendFactors:BlendFactors;
	public var indices:Indices = new Indices([]);
	public var vertices:Vertices = new Vertices([]);
	public var programInfo:ProgramInfo;
	public var textures:Array<Int> = new Array<Int>();
	public var matrix:Matrix = new Matrix();
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var visible:Bool = true;
	public var signature:String = "";

	// Transformation properties
	public var x:Float = 0.0;
	public var y:Float = 0.0;
	public var z:Float = 0.0;
	public var rotationZ:Float = 0.0; // Rotation in radians
	public var scaleX:Float = 1.0;
	public var scaleY:Float = 1.0;
	public var scaleZ:Float = 1.0;

	// ** Privates.
	private var __shouldTransform:Bool = false;
	public var __verticesToRender:Int = 0;
	public var __indicesToRender:UInt = 0;
	
	// VAO and VBO for this display object
	private var vao:GlUInt = 0;
	private var vbo:GlUInt = 0;
	private var ebo:GlUInt = 0; // Element buffer for indices
	public var initialized:Bool = false;
	
	public function new(programInfo:ProgramInfo, vertices:Vertices, ?indices:Indices) {
		if (programInfo == null) throw 'programInfo cannot be null';
		this.programInfo = programInfo;

		this.vertices = vertices;
		this.indices = indices != null ? indices : new Indices([]);

		blendFactors = { 
			source: BlendFactor.SRC_ALPHA,
			destination: BlendFactor.ONE_MINUS_SRC_ALPHA
		};
	}

	public function init():Void {
		if (initialized) return;
		
		// Generate VAO and VBO
		var vaoArray = new Array<GlUInt>();
		vaoArray.resize(1);
		GL.genVertexArrays(1, untyped __cpp__("(unsigned int*)&{0}[0]", vaoArray));
		vao = vaoArray[0];
		
		var vboArray = new Array<GlUInt>();
		vboArray.resize(1);
		GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", vboArray));
		vbo = vboArray[0];
		
		// Generate EBO if we have indices
		if (indices.data.length > 0) {
			var eboArray = new Array<GlUInt>();
			eboArray.resize(1);
			GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", eboArray));
			ebo = eboArray[0];
		}
		
		// Set initialized to true BEFORE calling updateBuffers
		initialized = true;
		updateBuffers();
	}
	
	public function updateBuffers():Void {
		if (!initialized) return;
		
		// Bind VAO
		GL.bindVertexArray(vao);
		
		// Upload vertex data
		GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
		var vertexBytes = haxe.io.Bytes.alloc(vertices.data.length * 4);
		for (i in 0...vertices.data.length) {
			vertexBytes.setFloat(i * 4, vertices.data[i]);
		}
		GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.DYNAMIC_DRAW);
		
		// Upload index data if we have indices
		if (indices.data.length > 0 && ebo != 0) {
			GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
			var indexBytes = haxe.io.Bytes.alloc(indices.data.length * 4);
			for (i in 0...indices.data.length) {
				indexBytes.setInt32(i * 4, indices.data[i]);
			}
			GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBytes.length, indexBytes.getData(), GL.DYNAMIC_DRAW);
		}
		
		// Setup vertex attributes
		programInfo.setupVertexAttributes();
		
		// Unbind
		GL.bindBuffer(GL.ARRAY_BUFFER, 0);
		GL.bindVertexArray(0);
	}

	public function remove():Void {
		if (initialized) {
			if (vao != 0) {
				var vaoArray = [vao];
				GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaoArray));
			}
			if (vbo != 0) {
				var vboArray = [vbo];
				GL.deleteBuffers(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vboArray));
			}
			if (ebo != 0) {
				var eboArray = [ebo];
				GL.deleteBuffers(1, untyped __cpp__("(const unsigned int*)&{0}[0]", eboArray));
			}
			initialized = false;
		}
	}

	public function updateTransform():Void {
		// Reset matrix to identity
		matrix.identity();
		
		// Apply transformations in order: Scale -> Rotate -> Translate
		if (scaleX != 1.0 || scaleY != 1.0 || scaleZ != 1.0) {
			matrix.appendScale(scaleX, scaleY, scaleZ);
		}
		
		if (rotationZ != 0.0) {
			matrix.appendRotationZ(rotationZ);
		}
		
		if (x != 0.0 || y != 0.0 || z != 0.0) {
			matrix.appendTranslation(x, y, z);
		}
	}

	public function render(cameraMatrix:Matrix):Void {
		if (!visible || !initialized) return;
		
		// Update transformation matrix based on current properties
		updateTransform();
		
		// Use the program
		GL.useProgram(programInfo.program);
		
		// Set uniforms (subclasses should override this method to set their specific uniforms)
		setUniforms();
		
		// Bind VAO and draw
		GL.bindVertexArray(vao);
		
		if (indices.data.length > 0) {
			// Draw with indices
			GL.drawElements(mode, __indicesToRender, GL.UNSIGNED_INT, 0);
		} else {
			// Draw arrays
			GL.drawArrays(mode, 0, __verticesToRender);
		}
		
		GL.bindVertexArray(0);
	}
	
	// Override this in subclasses to set specific uniforms
	private function setUniforms():Void {
		// Automatically set the uMatrix uniform if it exists in the shader
		for (uniform in programInfo.uniforms) {
			if (uniform.name == "uMatrix" && uniform.format == UniformFormat.Mat4) {
				programInfo.setUniformMatrix4("uMatrix", matrix.data);
				break;
			}
		}
		
		// Set any uniforms stored in the uniforms map
		for (name => value in uniforms) {
			// Check if it's a Float using Type.typeof instead of Std.isOfType
			switch(Type.typeof(value)) {
				case TFloat:
					programInfo.setUniformFloat(name, cast value);
				case TInt:
					// Convert Int to Float for uniform
					programInfo.setUniformFloat(name, cast(value, Float));
				default:
					// TODO: Add support for other uniform types (Vec2, Vec3, Vec4, Mat4, etc.)
			}
		}
	}
}