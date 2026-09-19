package;

import GL;
import Renderer;
import Texture;
import data.BlendFactors;
import data.DrawingMode;
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
	public var blending:Blending;
	public var culling:Bool = false;
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var indices(get, null):Indices;
	public var mode:Int = DrawingMode.TRIANGLES;
	public var uniforms:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var vertices(get, null):Vertices;
	public var visible:Bool = true;

	// Privates
	private var __bufferId:Int;
	private var __indices:Indices = new Indices([]);
	private var __needsBufferUpdate:Bool = false;
	private var __vertices:Vertices = new Vertices([]);
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		__vertices = vertices;
		__indices = indices != null ? indices : new Indices([]);

		__bufferId = renderer.createBuffers(getProgramInfoName());

		blending = {
			source: BlendFactors.SRC_ALPHA,
			destination: BlendFactors.ONE_MINUS_SRC_ALPHA
		};
	}

	public function release(renderer:Renderer):Void {
		renderer.deleteBuffers(__bufferId);
		__bufferId = -1;
	}
	
	public function render(renderer:Renderer):Void {
		
		if (!visible) return;

		// 0. Update buffers (if needed) and set uniforms before rendering
		//updateBuffers(renderer);
		// 1. Get the program info for the current shader program
		//var programInfo = renderer.getProgramInfo(getProgramInfoName());
		// 2. Use the shader program (binds the program and VAO)
		//renderer.useProgram(programInfo);
		// 3. Bind the buffers (VAO) for this object
		//renderer.bindBuffers(__bufferId, programInfo.vertexStride);
		// 4. Set the blending factors for transparency
		//renderer.setBlendFunction(blending.source, blending.destination);
		// 5. Set the uniform values for the shader program
		//renderer.renderUniforms(programInfo, this);
		// 6. Set the textures for the shader program
		//renderer.bindTexture(texture.id, 0);
		// 7. Draw the object using the specified mode and count
		//renderer.drawElements(mode, indices.length);
	}

	private function updateBuffers(renderer:Renderer):Void {
		if (!__needsBufferUpdate) return;

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
	private function getProgramInfoName():String { return null; }
}