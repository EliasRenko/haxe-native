package display;

import Renderer;
import data.Shader;
import data.Indices;
import data.Vertices;
import data.Transform;
import math.Matrix;
import Texture;
import shaders.TexturedShader;

class Image extends DisplayObject {
	
	// Publics
	public var angle(get, set):Float;
	public var height(get, set):Float;
	public var width(get, set):Float;
	public var originX(get, set):Float;
	public var originY(get, set):Float;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var texture(get, set):Texture;

	// Privates
	private var __angle:Float = 0;
	private var __height:Float = 0;
	private var __width:Float = 0;
	private var __originX:Float = 0;
	private var __originY:Float = 0;
	private var __transform:Transform = new Transform();
	private var __finalMatrix:Matrix = new Matrix();
	private var __texture:Texture;

	public function new(renderer:Renderer, texture:Texture) {
		__width = texture.width;
		__height = texture.height;
		
		// Create quad vertices (position + UV coordinates)
		// Format: x, y, z, u, v (5 floats per vertex)
		// Origin at top-left (0,0), extending right (+X) and down (+Y)
		var vertices:Vertices = [
			// Top-left (origin) - UV (0,0) maps to top-left of texture
			0.0,  0.0,  0.0,  0.0, 0.0,
			// Top-right - UV (1,0) maps to top-right of texture
			__width,    0.0,  0.0,  1.0, 0.0,
			// Bottom-right - UV (1,1) maps to bottom-right of texture
			__width,    __height,    0.0,  1.0, 1.0,
			// Bottom-left - UV (0,1) maps to bottom-left of texture
			0.0,  __height,    0.0,  0.0, 1.0
		];

		var indices:Indices = [0, 1, 2, 0, 2, 3]; // Two triangles to make a quad

		super(renderer, vertices, indices);
		
		// Set the texture using the full Texture object
		this.texture = texture;

		// Always pass 0 - 1 values
		setUV(0, 0, 1, 1);

		//__needsBufferUpdate = true;
		updateBuffers(renderer);
	}

	public function centerOrigin():Void {
		originX = __width / 2;
		originY = __height / 2;
	}
	
	public function setUV(x:Float, y:Float, width:Float, height:Float):Void {
		// Update UV coordinates - vertex order: [top-left, top-right, bottom-right, bottom-left]
		vertices.set(3, x);              // Top-left U
		vertices.set(8, x + width);      // Top-right U  
		vertices.set(13, x + width);     // Bottom-right U
		vertices.set(18, x);             // Bottom-left U
		
		vertices.set(4, y);              // Top-left V
		vertices.set(9, y);              // Top-right V
		vertices.set(14, y + height);    // Bottom-right V
		vertices.set(19, y + height);    // Bottom-left V
		
		__needsBufferUpdate = true;
	}

	public function render(renderer:Renderer):Void {

		if (__transform.dirty) {
			__transform.dirty = false;
			__transform.updateTransform();
		}

		Matrix.multiplyInto(__finalMatrix, __transform.matrix, renderer.matrix);
		shader.setUniform("uMatrix", __finalMatrix.data);

		// 1. Get the program info for the current shader program
		var programInfo = renderer.getProgramInfo(shader.programInfoIndex);

		// 2. Use the shader program (binds the program and VAO)
		renderer.useProgram(programInfo);

		// 3. Bind the buffers (VAO) for this object
		renderer.bindBuffers(__bufferId, programInfo.vertexStride);

		// 4. Set the blending factors for transparency
		renderer.setBlendFunction(blending.source, blending.destination);

		// 5. Set the uniform values for the shader program
		renderer.renderUniforms(programInfo, shader);

		// 6. Draw the object using the specified mode and count
		renderer.drawElements(mode, indices.length);
	}

	private function assignShader():Shader {
		return new TexturedShader();
	}

	//** Getters and setters.

	private function get_texture():Texture {
		return __texture;
	}

	private function set_texture(value:Texture):Texture {
		__texture = value;
		if (value != null) {
			shader.setUniform("uTexture", value);
		}
		return value;
	}
	
	private function set_angle(value:Float):Float {
		__angle = (value %= 360) >= 0 ? value : (value + 360);
		__transform.dirty = true;
		return value;
	}

	private function set_height(value:Float):Float {
		// Vertices: [top-left, top-right, bottom-right, bottom-left]
		vertices.set(1, 0 - originY);
		vertices.set(6, 0 - originY);
		vertices.set(11, -(value * __transform.scaleY) - originY);
		vertices.set(16, -(value * __transform.scaleY) - originY);
		
		__height = value;
		__needsBufferUpdate = true;

		return value;
	}
	
	private function set_width(value:Float):Float {
		// Vertices: [top-left, top-right, bottom-right, bottom-left]
		vertices.set(0, 0 - originX);                      
		vertices.set(5, (value * __transform.scaleX) - originX);
		vertices.set(10, (value * __transform.scaleX) - originX);
		vertices.set(15, 0 - originX);
		
		__width = value;
		__needsBufferUpdate = true;

		return value;
	}

	private function get_height():Float {
		return __height;
	}

	public function get_width():Float {
		return __width;
	}

	private function get_originX():Float {
		return __originX;
	}

	private function set_originX(value:Float):Float {
		__originX = value;
		width = __width;
		return __originX;
	}
		
	private function get_originY():Float {
		return __originY;
	}

	private function set_originY(value:Float):Float {
		__originY = value;
		height = __height;
		return __originY;
	}

	private function get_angle():Float {
		return __angle;
	}

	private function set_x(value:Float):Float {
		__transform.x = value;
		return value;
	}

	private function get_x():Float {
		return __transform.x;
	}

	private function set_y(value:Float):Float {
		__transform.y = value;
		return value;
	}

	private function get_y():Float {
		return __transform.y;
	}
}