package;

import GL;
import Renderer;
import Texture;
import data.BlendFactors;
import data.Vertices;
import data.Indices;
import math.Matrix;

typedef Blending = {
	source:Int,
	destination:Int
}

@:autoBuild(ShaderMacro.build())
abstract class DisplayObject {

	// Publics
	public var mode:Int = GL.TRIANGLES;
	public var blending:Blending;
	public var indices(get, null):Indices = new Indices([]);
	public var vertices(get, null):Vertices = new Vertices([]);
	public var matrix(get, null):Matrix;
	public var programInfoName:String;

	public var textures:Array<Texture> = new Array<Texture>();
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var visible:Bool = true;
	
	// Rendering properties
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var cullFace:Bool = false;

	// Privates
	private var __active:Bool = false;
	private var __matrix:Matrix = new Matrix();
	private var __indices:Indices = new Indices([]);
	private var __vertices:Vertices = new Vertices([]);
	public var __bufferId:Int;
	
	public var __verticesToRender:Int = 0;
	public var __indicesToRender:UInt = 0;

	// Flag to indicate buffers need updating
	public var needsBufferUpdate:Bool = false;
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		__vertices = vertices;
		__indices = indices != null ? indices : new Indices([]);

		blending = {
			source: BlendFactors.SRC_ALPHA,
			destination: BlendFactors.ONE_MINUS_SRC_ALPHA
		};

		programInfoName = getShaderName();

		__bufferId = renderer.createBuffers();
		__active = true;
	}

	public function release(renderer:Renderer):Void {
		if (__active) {
			renderer.deleteBuffers(__bufferId);
			__bufferId = null;
			__active = false;
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

	public function render(renderer:Renderer, cameraMatrix:Matrix, cameraDirty:Bool):Void {
		// if (!__active) return;
		
		// // renderer.uploadData(this); can be added here
		updateBuffers(renderer);

		// if (cameraDirty) {
		// 	var finalMatrix = Matrix.copy(matrix);
		// 	finalMatrix.append(cameraMatrix);
		// 	uniforms.set("uMatrix", finalMatrix.data);
		// }

		renderer.renderDisplayObject(this);
	}

	public function updateBuffers(renderer:Renderer):Void {
		if (!__active || !needsBufferUpdate) return;

		renderer.uploadData(__bufferId, programInfoName, vertices, indices);
		needsBufferUpdate = false;
	}

	public function postRender():Void {}

	// Getters and setters
	private function get_matrix():Matrix {
		return __matrix;
	}

	private function get_indices():Indices {
		return __indices;
	}

	private function get_vertices():Vertices {
		return __vertices;
	}

	// Macros

	// Override in subclasses (or use @:shader metadata) to declare the shader name.
	public function getShaderName():String { return null; }
}