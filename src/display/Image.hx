package display;

import DisplayObject;
import math.Matrix;

// Simple Vector4 for axis constants
class Vector4 {
	public static var Z_AXIS = {x: 0.0, y: 0.0, z: 1.0};
}

class Image extends DisplayObject {
	
	// ** Publics.

	/**
	 * The angle of the graphic.
	 */
	public var angle(get, set):Float;

	/**
	 * The width of the graphic.
	 */
	 public var width(get, set):Float;

	 /**
	  * The height of the graphic.
	  */
	 public var height(get, set):Float;

	/**
	 * The x origin of the graphic.
	 */
	public var originX(get, set):Float;

	/**
	 * The y origin of the graphic.
	 */
	public var originY(get, set):Float;

	// ** Privates.

	private var __angle:Float = 0;

	private var __height:Float = 0;

	private var __width:Float = 0;

	private var __originX:Float = 0;

	private var __originY:Float = 0;

	public function new(programInfo:ProgramInfo, ?textureIds:Array<Int>) {
		var w = 256.0;
		var h = 256.0;
		var vertices = [
			// Position (x,y,z) + UV (u,v) - interleaved
			// Bottom-left
			0,    0,    0,  0, 0,
			// Top-left
			0,    h,    0,  0, 1,
			// Top-right
			w,    h,    0,  1, 1,
			// Bottom-right
			w,    0,    0,  1, 0
		];

		var v = new Vertices(vertices);
		var indices = [0, 1, 2, 0, 2, 3]; // Two triangles to make a quad

		super(programInfo, v, new Indices(indices));

		if (textureIds != null && textureIds.length > 0) {
			this.textures = textureIds;
		}

		__verticesToRender = 4;
		__indicesToRender = 6;
		
		// Set default size
		__width = w;
		__height = h;
	}

	public function centerOrigin():Void {

		originX = __width / 2;
		
		originY = __height / 2;
	}

	public function setTextures(textures:Array<Int>, width:Int, height:Int) {
		
		if (textures.length == 0) {

			trace("No textures to set!");

			return;
		}
		else {

			if (textures.length == programInfo.textureCount) {

				this.textures = textures;
			}
			else {

				throw "Invalid number of textures!";
			}

			// ** Set the width of the texture.

			this.width = width;
			
			// ** Set the height of the texture.

			this.height = height;
		}

		setUV(0, 0, 1, 1); // Always pass 0 - 1 values
	}
	
	public function setUV(x:Float, y:Float, width:Float, height:Float):Void {
		vertices.set(3, x);      // Bottom-left U
		vertices.set(8, x);      // Top-left U
		vertices.set(13, width); // Top-right U
		vertices.set(18, width); // Bottom-right U
		
		vertices.set(4, y);      // Bottom-left V
		vertices.set(9, height); // Top-left V
		vertices.set(14, height);// Top-right V
		vertices.set(19, y);     // Bottom-right V
		
		// Update buffers if initialized
		if (initialized) {
			updateBuffers();
		}
	}

	override function render(cameraMatrix:Matrix):Void {

		this.matrix.identity();
		this.matrix.appendScale(scaleX, scaleY, 1);
		this.matrix.appendRotation(__angle, Vector4.Z_AXIS);
		this.matrix.appendTranslation(x, y, z);
		this.matrix.append(cameraMatrix);

		uniforms.set("matrix", this.matrix);
        uniforms.set("color", [1.0, 1.0, 1.0, 1.0]);

		__shouldTransform = false;
	}

	//** Getters and setters.
	
	private function set_angle(value:Float):Float {

		__angle = (value %= 360) >= 0 ? value : (value + 360);
		
		__shouldTransform = true;

		return value;
	}

	private function set_height(value:Float):Float {
		vertices.set(1, 0 - originY);                  // Bottom-left Y
		vertices.set(6, (value * scaleY) - originY);   // Top-left Y
		vertices.set(11, (value * scaleY) - originY);  // Top-right Y
		vertices.set(16, 0 - originY);                 // Bottom-right Y
		
		__height = value;
		__shouldTransform = true;
		
		// Update buffers if initialized
		if (initialized) {
			updateBuffers();
		}

		return value;
	}
	
	private function set_width(value:Float):Float {
		vertices.set(0, 0 - originX);                  // Bottom-left X
		vertices.set(5, 0 - originX);                  // Top-left X
		vertices.set(10, (value * scaleX) - originX); // Top-right X
		vertices.set(15, (value * scaleX) - originX); // Bottom-right X
		
		__width = value;
		__shouldTransform = true;
		
		// Update buffers if initialized
		if (initialized) {
			updateBuffers();
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