package;

import GL;
import ProgramInfo;
import ProgramInfo.UniformFormat;
import Texture;
import data.Vertices;
import data.Indices;
import math.Matrix;

typedef BlendFactors = {
	source:Int,
	destination:Int
}

// Blend factor constants
class BlendFactor {
	public static var SRC_ALPHA:Int = 770;  // GL.SRC_ALPHA
	public static var ONE_MINUS_SRC_ALPHA:Int = 771;  // GL.ONE_MINUS_SRC_ALPHA
}

class DisplayObject {
	//** Publics
	public var active:Bool = false;
	public var mode:Int = GL.TRIANGLES; // Use proper GL constant
	public var blendFactors:BlendFactors;
	public var indices:Indices = new Indices([]);
	public var vertices:Vertices = new Vertices([]);
	public var programInfo:ProgramInfo;
	public var textures:Array<Texture> = new Array<Texture>();
	public var matrix:Matrix = new Matrix();
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var visible:Bool = true;

	// public var x:Float = 0.0;
	// public var y:Float = 0.0;
	// public var z:Float = 0.0;
	
	// // 3D Rotation support (in radians)
	// public var rotationX:Float = 0.0; // Pitch
	// public var rotationY:Float = 0.0; // Yaw  
	// public var rotationZ:Float = 0.0; // Roll
	
	// public var scaleX:Float = 1.0;
	// public var scaleY:Float = 1.0;
	// public var scaleZ:Float = 1.0;
	
	// Rendering properties
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var cullFace:Bool = false; // Set to true for 3D objects

	// ** Privates.
	public var __verticesToRender:Int = 0;
	public var __indicesToRender:UInt = 0;
	
	// Flag to indicate buffers need updating
	public var needsBufferUpdate:Bool = false;
	
	// VAO and VBO for this display object
	//public var vao:GlUInt = 0;
	public var vbo:GlUInt = 0;
	public var ebo:GlUInt = 0; // Element buffer for indices
	
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
		if (active) return;
		var buffers = renderer.createBuffers();
		// TODO: Fix createBuffers to return both VBO and EBO
		vbo = buffers.vbo;
		ebo = buffers.ebo;
		
		active = true;
		//updateBuffers(renderer);
	}
	
	public function updateBuffers(renderer:Renderer):Void {
		if (!active) return;
	
		renderer.uploadData(this);
		needsBufferUpdate = false;
	}

	public function release(renderer:Renderer):Void {
		if (active) {
			renderer.deleteBuffers(vbo, ebo);
			vbo = 0;
			ebo = 0;
			active = false;
		}
	}
	
	/**
	 * Convenience method to set the primary texture
	 * @param texture Texture object (null to remove texture)
	 */
	public function setTexture(texture:Texture):Void {
		if (texture == null) {
			textures = [];
		} else {
			textures = [texture];
		}
	}
	
	/**
	 * Add an additional texture to the texture array
	 * @param texture Texture object
	 * @return The texture slot index
	 */
	public function addTexture(texture:Texture):Int {
		textures.push(texture);
		return textures.length - 1;
	}
	
	/**
	 * Check if this object has any textures assigned
	 */
	public function hasTextures():Bool {
		return textures.length > 0 && textures[0] != null;
	}
	
	/**
	 * Get the primary texture ID for OpenGL operations
	 */
	public function getTextureId():Int {
		return (textures.length > 0 && textures[0] != null) ? textures[0].id : 0;
	}

	public function updateTransform():Void {
		needsBufferUpdate = true;
	}

	// Fallback/default rendering implementation
	// This method can be overridden by specific display objects for custom rendering behavior
	public function render(cameraMatrix:Matrix):Void {
		if (!visible) return;
		
		// Update transformation matrix based on current properties
		updateTransform();
		
		// Create final matrix by combining object matrix with camera matrix
		// Order: finalMatrix = objectMatrix * cameraMatrix  
		var finalMatrix = Matrix.copy(matrix);
		finalMatrix.append(cameraMatrix);
		
		// Set the transform matrix in uniforms map
		uniforms.set("uMatrix", finalMatrix.data);
	}

	public function postRender():Void {
		// Override in subclasses if needed
	}
}