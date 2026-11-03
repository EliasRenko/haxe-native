package;

import GL;
import Renderer;
import Texture;
import data.BlendFactors;
import data.DrawingMode;
import data.Vertices;
import data.Indices;
import math.Matrix;
import data.Shader;

typedef Blending = {
	source:Int,
	destination:Int
}

abstract class DisplayObject {

	// Publics
	public var blending:Blending;
	public var culling:Bool = false;
	public var depthTest:Bool = true;
	public var depthWrite:Bool = true;
	public var indices(get, null):Indices;
	public var mode:Int = DrawingMode.TRIANGLES;
	public var shader(get, set):Shader;
	public var vertices(get, null):Vertices;
	public var visible:Bool = true;

	// Privates
	private var __bufferId:Int;
	private var __indices:Indices = new Indices([]);
	private var __needsBufferUpdate:Bool = false;
	private var __vertices:Vertices = new Vertices([]);
	private var __shader:Shader;
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		__vertices = vertices;
		__indices = indices != null ? indices : new Indices([]);
		__needsBufferUpdate = true;
		__shader = assignShader();
		if (__shader == null) {
			throw "Shader is null! Please assign a shader before rendering.";
		}

		__bufferId = renderer.createBuffers(shader.programInfoIndex);

		blending = {
			source: BlendFactors.SRC_ALPHA,
			destination: BlendFactors.ONE_MINUS_SRC_ALPHA
		};
	}

	public function release(renderer:Renderer):Void {
		renderer.deleteBuffers(__bufferId);
		__bufferId = -1;
	}

	@:noCompletion
	public function replaceVertices(vertices:Vertices):Void {
		__vertices = vertices;
		__needsBufferUpdate = true;
	}
	
	public abstract function render(renderer:Renderer):Void;

	private function updateBuffers(renderer:Renderer):Void {
		if (!__needsBufferUpdate) return;

		renderer.uploadData(__bufferId, vertices, indices);
		__needsBufferUpdate = false;
	}

	private abstract function assignShader():Shader;

	// Getters and setters
	private function get_indices():Indices {
		return __indices;
	}

	private function get_vertices():Vertices {
		return __vertices;
	}

	private function get_shader():Shader {
		return __shader;
	}

	private function set_shader(value:Shader):Shader {
		__shader = value;
		return value;
	}

	// Macros
	private function getProgramInfoName():String { return null; }
}