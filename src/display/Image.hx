package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import math.Matrix;
import Texture;

class Image extends DisplayObject {
	
	// Publics
	public var angle(get, set):Float;
	public var width(get, set):Float;
	public var height(get, set):Float;
	public var originX(get, set):Float;
	public var originY(get, set):Float;

	// Privates
	private var __angle:Float = 0;
	private var __height:Float = 0;
	private var __width:Float = 0;
	private var __originX:Float = 0;
	private var __originY:Float = 0;

	public function new(programInfo:ProgramInfo, texture:Texture) {
		// Use texture dimensions directly
		var w = texture.width;
		var h = texture.height;
		
		// Create quad vertices (position + UV coordinates)
		// Format: x, y, z, u, v (5 floats per vertex)
		// Origin at top-left (0,0), extending right (+X) and down (+Y)
		var vertices = [
			// Top-left (origin) - UV (0,0) maps to top of texture
			0.0,  0.0,  0.0,  0.0, 0.0,
			// Top-right - UV (1,0) maps to top-right of texture
			w,    0.0,  0.0,  1.0, 0.0,
			// Bottom-right - UV (1,1) maps to bottom-right of texture
			w,    h,    0.0,  1.0, 1.0,
			// Bottom-left - UV (0,1) maps to bottom-left of texture
			0.0,  h,    0.0,  0.0, 1.0
		];

		var indices = [0, 1, 2, 0, 2, 3]; // Two triangles to make a quad

		super(programInfo, new Vertices(vertices), new Indices(indices));

		// Set OpenGL properties
		mode = GL.TRIANGLES;
		__verticesToRender = 4;
		__indicesToRender = 6;
		
		// Set the texture using the full Texture object
		setTexture(texture);
		
		// Initialize dimensions from texture
		__width = texture.width;
		__height = texture.height;
	}

	public function centerOrigin():Void {

		originX = __width / 2;
		
		originY = __height / 2;
	}

	public function setTextures(textureObjects:Array<Texture>, width:Int, height:Int) {
		
		if (textureObjects.length == 0) {
			trace("No textures to set!");
			return;
		}

		// Set the first texture (Image only supports single texture for now)
		setTexture(textureObjects[0]);
		
		// Set the width and height
		this.width = width;
		this.height = height;

		setUV(0, 0, 1, 1); // Always pass 0 - 1 values
	}
	
	public function setUV(x:Float, y:Float, width:Float, height:Float):Void {
		// Update UV coordinates - vertex order: [top-left, top-right, bottom-right, bottom-left]
		// Flip V coordinates to compensate for OpenGL texture coordinate system
		// where (0,0) is bottom-left but we want (0,0) to be top-left visually
		vertices.set(3, x);              // Top-left U
		vertices.set(8, x + width);      // Top-right U  
		vertices.set(13, x + width);     // Bottom-right U
		vertices.set(18, x);             // Bottom-left U
		
		vertices.set(4, 1.0 - y);        // Top-left V (flipped)
		vertices.set(9, 1.0 - y);        // Top-right V (flipped)
		vertices.set(14, 1.0 - (y + height)); // Bottom-right V (flipped)
		vertices.set(19, 1.0 - (y + height)); // Bottom-left V (flipped)
		
		// Mark for buffer update on next render
		if (initialized) {
			needsBufferUpdate = true;
		}
	}

	override function render(cameraMatrix:Matrix):Void {
		if (!visible || !initialized) return;
		
		// Update transformation matrix based on current properties
		updateTransform();
		
		// Create final matrix by combining object matrix with camera matrix
		var finalMatrix = Matrix.copy(matrix);
		finalMatrix.append(cameraMatrix);
		
		// Set the transform matrix uniform (using correct uniform name for textured shader)
		uniforms.set("uMatrix", finalMatrix.data);
	}

	//** Getters and setters.
	
	private function set_angle(value:Float):Float {
		__angle = (value %= 360) >= 0 ? value : (value + 360);
		__shouldTransform = true;
		return value;
	}

	private function set_height(value:Float):Float {
		// Vertices: [top-left, top-right, bottom-right, bottom-left]
		vertices.set(1, 0 - originY);
		vertices.set(6, 0 - originY);
		vertices.set(11, -(value * scaleY) - originY);
		vertices.set(16, -(value * scaleY) - originY);
		
		__height = value;
		__shouldTransform = true;
		
		// Mark for buffer update on next render
		if (initialized) {
			needsBufferUpdate = true;
		}

		return value;
	}
	
	private function set_width(value:Float):Float {
		// Vertices: [top-left, top-right, bottom-right, bottom-left]
		vertices.set(0, 0 - originX);                      
		vertices.set(5, (value * scaleX) - originX);
		vertices.set(10, (value * scaleX) - originX);
		vertices.set(15, 0 - originX);
		
		__width = value;
		__shouldTransform = true;
		
		// Mark for buffer update on next render
		if (initialized) {
			needsBufferUpdate = true;
		}

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
		__shouldTransform = true;
		width = __width;
		return __originX;
	}
		
	private function get_originY():Float {
		return __originY;
	}

	private function set_originY(value:Float):Float {
		__originY = value;
		__shouldTransform = true;
		height = __height;
		return __originY;
	}

	function get_angle():Float {
		return __angle;
	}
}