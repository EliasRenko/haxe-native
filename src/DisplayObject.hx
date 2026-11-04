package;

import Renderer;
import types.BlendFactors;
import types.DrawingMode;
import data.Blending;
import data.Indices;
import data.Vertices;
import data.Shader;

abstract class DisplayObject {

	// Publics
	public var blending:Blending = { source: BlendFactors.SRC_ALPHA, destination: BlendFactors.ONE_MINUS_SRC_ALPHA };
	public var indices(get, null):Indices;
	public var mode:Int = DrawingMode.TRIANGLES;
	public var shader(get, set):Shader;
	public var vertices(get, null):Vertices;
	public var visible:Bool = true;

	// Privates
	private var __bufferId:Int;
	private var __indices:Indices = new Indices([]);
	private var __needsBufferUpdate:Bool = true;
	private var __vertices:Vertices = new Vertices([]);
	private var __shader:Shader;
	
	public function new(renderer:Renderer, vertices:Vertices, ?indices:Indices) {
		__vertices = vertices;
		__indices = indices != null ? indices : new Indices([]);

		__shader = assignShader();
		if (__shader == null) {
			throw "Shader is null! Please assign a shader before rendering.";
		}

		__bufferId = renderer.createBuffers(__shader.programInfoIndex);
	}

	public function release(renderer:Renderer):Void {
		renderer.deleteBuffers(__bufferId);
		__bufferId = -1;
	}
	
	public function updateBuffers(renderer:Renderer):Void {
		if (!__needsBufferUpdate) return;

		renderer.uploadData(__bufferId, vertices, indices);
		__needsBufferUpdate = false;
	}

	public abstract function render(renderer:Renderer):Void;

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
}