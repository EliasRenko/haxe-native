package display;

import math.Vector4;
import math.Matrix;
#if js
import core.View;
#elseif cpp
import core.App.View;
#end
import data.Vertices;
import data.ProgramInfo;
import display.DisplayObject;

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

	public var scaleX(get, set):Float;

	public var scaleY(get, set):Float;

	 /**
	 * The x position of the graphic in space.
	 */
	@:access
	public var x(get, set):Float;

	/**
	 * The y position of the graphic in space.
	 */
	@:access
	public var y(get, set):Float;

	/**
	 * The z position of the graphic in space.
	 */
	public var z(get, set):Float;

	// ** Privates.

	private var __angle:Float = 0;

	private var __height:Float = 0;

	private var __width:Float = 0;

	private var __originX:Float = 0;

	private var __originY:Float = 0;

	private var __scaleX:Float = 1;

	private var __scaleY:Float = 1;

	private var __x:Float = 0;

	private var __y:Float = 0;

	private var __z:Float = 0;

	public function new(view:View, profile:ProgramInfo, textureIds:Array<Int>) {


		var w = 256.0;
		var h = 256.0;
		var vertices = [
			// Bottom-left
			0,    0,    1,  0, 0,
			// Top-left
			0,    h,    1,  0, 1,
			// Top-right
			w,    h,    1,  1, 1,
			// Bottom-right
			w,    0,    1,  1, 0
		];

		var v = new Vertices(vertices);
		//v.insert(profile.dataPerVertex * 4);

		super(profile, v, [0, 1, 2, 0, 2, 3]);

		if (textureIds.length > 0) {
			this.textures = textureIds;
		}

		bufferId = view.generateBuffer();

		__verticesToRender = 4;
		__indicesToRender = 6;
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

		vertices[3] = x;
		
		vertices[8] = x;
		
		vertices[13] = width;
		
		vertices[18] = width;
		
		vertices[4] = y;
		
		vertices[9] = height;
		
		vertices[14] = height;
		
		vertices[19] = y;
	}

	override function render(cameraMatrix:Matrix):Void {

		this.matrix.identity();
		this.matrix.appendScale(__scaleX, __scaleY, 1);
		this.matrix.appendRotation(__angle, Vector4.Z_AXIS);
		this.matrix.appendTranslation(__x, __y, __z);
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

		vertices[1] = 0 - originY;
		
		vertices[6] = (value * __scaleY) - originY;
		
		vertices[11] = (value * __scaleY) - originY;
		
		vertices[16] = 0 - originY;
		
		__height = value;

		__shouldTransform = true;

		return value;
	}
		
	private function set_scaleX(value:Float):Float {
		
		__shouldTransform = true;

		width = __width;

		return __scaleX = value;
	}
		
	private function set_scaleY(value:Float):Float {

		__shouldTransform = true;

		height = __height;

		return __scaleY = value;
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
	
	private function set_width(value:Float):Float {

		vertices[0] = 0 - originX;
		
		vertices[5] = 0 - originX;
		
		vertices[10] = (value * __scaleX) - originX;
		
		vertices[15] = (value * __scaleX) - originX;
		
		__width = value;

		__shouldTransform = true;

		return value;
	}

	private function get_x():Float {

		return __x;
	}

	private function set_x(value:Float):Float {

		__shouldTransform = true;

		return __x = value;
	}

	private function get_y():Float {

		return __y;
	}
		
	private function set_y(value:Float):Float {

		__shouldTransform = true;

		return __y = value;
	}

	private function get_z():Float {

		return __z;
	}

	private function set_z(value:Float):Float {
		
		__z = value;

		__shouldTransform = true;

		return __z;
	}

	private function get_scaleX():Float {
		
		return __scaleX;
	}

	private function get_scaleY():Float {
		
		return __scaleY;
	}

	function get_angle():Float {
		
		return __angle;
	}
}