package;

import GL;
import ProgramInfo;
import ProgramInfo.UniformFormat;
import Renderer;
import Texture;
import data.BlendFactors;
import data.Vertices;
import data.Indices;
import math.Matrix;

#if js
typedef GlUInt = UInt;
#elseif cpp
import cpp.UInt32;
typedef GlUInt = UInt32;
#end

typedef Blending = {
	source:Int,
	destination:Int
}

@:autoBuild(ShaderMacro.build())
abstract class DisplayObject {
	// Publics
	public var active:Bool = false;
	public var mode:Int = GL.TRIANGLES;
	public var blending:Blending;
	public var indices:Indices = new Indices([]);
	public var vertices:Vertices = new Vertices([]);
	public var programInfo:ProgramInfo;
	public var textures:Array<Texture> = new Array<Texture>();
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var visible:Bool = true;
	
	// Rendering properties
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var cullFace:Bool = false;

	// Privates
	public var __verticesToRender:Int = 0;
	public var __indicesToRender:UInt = 0;
	private var matrix:Matrix = new Matrix();
	
	// Flag to indicate buffers need updating
	public var needsBufferUpdate:Bool = false;
	
	@:allow(native.Renderer) 
	private var vbo:GlUInt = 0; // Vertex Buffer Object
	@:allow(native.Renderer)
	private var ebo:GlUInt = 0; // Element Buffer Object
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		this.vertices = vertices;
		this.indices = indices != null ? indices : new Indices([]);

		blending = {
			source: BlendFactors.SRC_ALPHA,
			destination: BlendFactors.ONE_MINUS_SRC_ALPHA
		};

		// Auto-resolve programInfo by looking up the pre-compiled shader in the
		// renderer's map. The state must register the ProgramInfo before creating
		// any instance of this class (virtual dispatch is safe in HxCPP).
		var shaderName = getShaderName();
		if (shaderName != null) {
			this.programInfo = renderer.getProgramInfo(shaderName);
			if (this.programInfo == null) {
				throw 'DisplayObject: ProgramInfo "$shaderName" not found. Pre-register it in the state before creating this object.';
			}
		}

		var buffers = renderer.createBuffers();
		vbo = buffers.vbo;
		ebo = buffers.ebo;
		active = true;
	}

	/** Override in subclasses (or use @:shader metadata) to declare the shader name. */
	public function getShaderName():String { return null; }
	
	public function updateBuffers(renderer:Renderer):Void {
		if (!active || !needsBufferUpdate) return;
	
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

	public function render(cameraMatrix:Matrix, cameraDirty:Bool):Void {
		if (cameraDirty) {
			var finalMatrix = Matrix.copy(matrix);
			finalMatrix.append(cameraMatrix);
			uniforms.set("uMatrix", finalMatrix.data);
		}
	}

	public function postRender():Void {
		// Override in subclasses if needed
	}
}