package;

import GL;
import ProgramInfo;
import ProgramInfo.UniformFormat;
import math.Matrix;
import Texture;
import data.Vertices;
import data.Indices;

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
	public var bufferId:UInt = 0;
	public var mode:Int = GL.TRIANGLES; // Use proper GL constant
	public var blendFactors:BlendFactors;
	public var indices:Indices = new Indices([]);
	public var vertices:Vertices = new Vertices([]);
	public var programInfo:ProgramInfo;
	public var textures:Array<Texture> = new Array<Texture>();
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
	//public var vao:GlUInt = 0;
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
		
		// Create VBO and EBO only (VAO is shared from ProgramInfo)
		var buffers = renderer.createBuffers(vertices.data.length, indices.data.length);
		//vao = programInfo.vao; // Use shared VAO from ProgramInfo
		vbo = buffers.vbo;
		ebo = buffers.ebo;
		
		// Set initialized to true BEFORE calling updateBuffers
		initialized = true;
		
		// Upload data
		updateBuffers(renderer);
		
		// If using classic VAO approach (not ARB_vertex_attrib_binding),
		// we need to set up vertex attributes for this specific VBO
		// if (!programInfo.useModernBinding) {
		// 	GL.bindVertexArray(vao);
		// 	GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
		// 	if (ebo != 0) {
		// 		GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
		// 	}
		// 	programInfo.setupVertexAttributes(renderer);
		// 	GL.bindVertexArray(0);
		// }
	}
	
	public function updateBuffers(renderer:Renderer):Void {
		if (!initialized) return;
		
		// Use Renderer's upload methods
		renderer.uploadData(this);
		// TODO: Remove the vertex setup. It contains the unbind for the buffer which must be moved to the upload data.
		//renderer.setupVertexAttributes(programInfo);
		
		// Clear the update flag
		needsBufferUpdate = false;
	}

	public function release(renderer:Renderer):Void {
		if (initialized) {
			// Delete VBO and EBO only (VAO belongs to ProgramInfo, not this DisplayObject)
			renderer.deleteBuffers(0, vbo, ebo); // Pass 0 for VAO to skip deletion
			vbo = 0;
			ebo = 0;
			initialized = false;
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
		matrix.identity();
		matrix.appendScale(scaleX, scaleY, scaleZ);
		matrix.appendRotationX(rotationX);
		matrix.appendRotationY(rotationY);
		matrix.appendRotationZ(-rotationZ * Math.PI / 180.0);
		matrix.appendTranslation(x, y, z);
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
}