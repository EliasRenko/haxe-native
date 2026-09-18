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
	public var programInfoName:String;
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var cullFace:Bool = false;
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var visible:Bool = true;

	// Privates
	private var __active:Bool = false;
	private var __indices:Indices = new Indices([]);
	private var __vertices:Vertices = new Vertices([]);
	private var __bufferId:Int;
	private var __verticesToRender:Int = 0;
	private var __indicesToRender:UInt = 0;
	private var __needsBufferUpdate:Bool = false;
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		__vertices = vertices;
		__indices = indices != null ? indices : new Indices([]);

		blending = {
			source: BlendFactors.SRC_ALPHA,
			destination: BlendFactors.ONE_MINUS_SRC_ALPHA
		};

		programInfoName = getShaderName();

		__bufferId = renderer.createBuffers(programInfoName);
		__active = true;
	}

	public function release(renderer:Renderer):Void {
		if (__active) {
			renderer.deleteBuffers(__bufferId);
			__bufferId = -1;
			__active = false;
		}
	}
	
	public function render(renderer:Renderer):Void {
		
		updateBuffers(renderer);

		// 1. Get the program info for the current shader program
		var programInfo = renderer.getProgramInfo(programInfoName);

		// 2. Use the shader program (binds the program and VAO)
		renderer.useProgram(programInfo);

		// 3. Bind the buffers (VAO) for this object
		renderer.bindBuffers(__bufferId, programInfo.vertexStride);

		// 4. Set the blending factors for transparency
		renderer.setBlendFunction(blending.source, blending.destination);

		// 5. Set the uniform values for the shader program
		renderer.renderUniforms(programInfo, this);

		// 6. Set the textures for the shader program
		// renderer.renderTextures(programInfo, this);

		// 7. Draw the object using the specified mode and count
		renderer.drawElements(mode, __indicesToRender);
	}

	private function updateBuffers(renderer:Renderer):Void {
		if (!__active || !__needsBufferUpdate) return;

		renderer.uploadData(__bufferId, vertices, indices);
		__needsBufferUpdate = false;
	}

	// Getters and setters
	private function get_indices():Indices {
		return __indices;
	}

	private function get_vertices():Vertices {
		return __vertices;
	}

	// Macros

	// Override in subclasses (or use @:shader metadata) to declare the shader name.
	private function getShaderName():String { return null; }
}