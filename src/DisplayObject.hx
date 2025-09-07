package;

import GL;
import ProgramInfo;
import ProgramInfo.UniformFormat;
import math.Matrix;

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
	
	// 3D Rotation support (in radians)
	public var rotationX:Float = 0.0; // Pitch
	public var rotationY:Float = 0.0; // Yaw  
	public var rotationZ:Float = 0.0; // Roll
	
	public var scaleX:Float = 1.0;
	public var scaleY:Float = 1.0;
	public var scaleZ:Float = 1.0;

	// Scene graph support
	public var parent:DisplayObject = null;
	public var children:Array<DisplayObject> = [];
	
	// Rendering properties
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var cullFace:Bool = false; // Set to true for 3D objects

	// ** Privates.
	private var __shouldTransform:Bool = false;
	public var __verticesToRender:Int = 0;
	public var __indicesToRender:UInt = 0;
	
	// Debug frame counter
	private var framesSinceLastMatrixDebug:Int = 0;
	
	// Flag to indicate buffers need updating
	public var needsBufferUpdate:Bool = false;
	
	// VAO and VBO for this display object
	public var vao:GlUInt = 0;
	public var vbo:GlUInt = 0;
	public var ebo:GlUInt = 0; // Element buffer for indices
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

	public function init(renderer:Renderer):Void {
		if (initialized) return;
		
		// Use Renderer's buffer creation method
		var buffers = renderer.createBuffers(vertices.data.length, indices.data.length);
		vao = buffers.vao;
		vbo = buffers.vbo;
		ebo = buffers.ebo;
		
		// Set initialized to true BEFORE calling updateBuffers
		initialized = true;
		updateBuffers(renderer);
	}
	
	public function updateBuffers(renderer:Renderer):Void {
		if (!initialized) return;
		
		// Use Renderer's upload methods
		renderer.uploadVertexData(vao, vbo, vertices.data);
		renderer.uploadIndexData(ebo, indices.data);
		renderer.setupVertexAttributes(programInfo);
		
		// Clear the update flag
		needsBufferUpdate = false;
	}

	public function remove(renderer:Renderer):Void {
		if (initialized) {
			// Use Renderer's buffer cleanup method
			renderer.deleteBuffers(vao, vbo, ebo);
			vao = 0;
			vbo = 0;
			ebo = 0;
			initialized = false;
		}
	}
	
	/**
	 * Convenience method to set the primary texture
	 * @param textureId OpenGL texture ID (0 to remove texture)
	 */
	public function setTexture(textureId:GlUInt):Void {
		if (textureId == 0) {
			textures = [];
		} else {
			textures = [textureId];
		}
	}
	
	/**
	 * Add an additional texture to the texture array
	 * @param textureId OpenGL texture ID
	 * @return The texture slot index
	 */
	public function addTexture(textureId:GlUInt):Int {
		textures.push(textureId);
		return textures.length - 1;
	}
	
	/**
	 * Check if this object has any textures assigned
	 */
	public function hasTextures():Bool {
		return textures.length > 0 && textures[0] != 0;
	}

	public function updateTransform():Void {
		// Reset matrix to identity
		matrix.identity();
		
		// Debug: Log transformation values occasionally (reduced frequency)
		if ((x != 0.0 || y != 0.0 || z != 0.0 || rotationX != 0.0 || rotationY != 0.0 || rotationZ != 0.0) && framesSinceLastMatrixDebug % 900 == 0) {
			trace("Transform - Pos: (" + x + ", " + y + ", " + z + ") Rot: (" + rotationX + ", " + rotationY + ", " + rotationZ + ")");
		}
		
		// Apply transformations in order: Scale -> Rotate -> Translate
		if (scaleX != 1.0 || scaleY != 1.0 || scaleZ != 1.0) {
			matrix.appendScale(scaleX, scaleY, scaleZ);
		}
		
		// Apply rotations in order: X -> Y -> Z (standard Euler order)
		if (rotationX != 0.0) {
			matrix.appendRotationX(rotationX);
		}
		if (rotationY != 0.0) {
			matrix.appendRotationY(rotationY);
		}
		if (rotationZ != 0.0) {
			// Negate angle to make positive values rotate clockwise (standard 2D behavior)
			matrix.appendRotationZ(-rotationZ * Math.PI / 180.0);
		}
		
		if (x != 0.0 || y != 0.0 || z != 0.0) {
			matrix.appendTranslation(x, y, z);
			if (framesSinceLastMatrixDebug % 900 == 0) {
				trace("Applied translation: (" + x + ", " + y + ", " + z + ")");
			}
		}
	}

	// Fallback/default rendering implementation
	// This method can be overridden by specific display objects for custom rendering behavior
	public function render(cameraMatrix:Matrix, renderer:Renderer):Void {
		if (!visible || !initialized) return;
		
		// Update transformation matrix based on current properties
		updateTransform();
		
		// Create final matrix by combining object matrix with camera matrix
		// Order: finalMatrix = objectMatrix * cameraMatrix  
		var finalMatrix = Matrix.copy(matrix);
		finalMatrix.append(cameraMatrix);
		
		// Set the transform matrix in uniforms map
		uniforms.set("uMatrix", finalMatrix.data);
		
		// Let the Renderer handle all GL operations
		renderer.renderObject(this);
	}
}