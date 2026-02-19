package data;

import haxe.io.UInt8Array;

class TextureData {

    // ** Publics.

    public var allocated:Bool = false;
    public var bytes(get, null):UInt8Array;
    public var bytesPerPixel(get, null):Int;
    public var dirty(get, null):Bool;
    public var height(get, null):Int;
    public var powerOfTwo(get, null):Bool;
    public var transparent(get, null):Bool;
    public var width(get, null):Int;
    public var src(get, null):String; 

    // ** Privates.

    private var __id:UInt;
    private var __data:UInt8Array;
    private var __bytesPerPixel:Int;
    private var __dirty:Bool = false;
    private var __height:Int;
    private var __transparent:Bool;
    private var __width:Int;
    private var __src:String;
    
    public function new(data:UInt8Array, bytesPerPixel:Int, width:Int, height:Int, transparent:Bool = false, src:String = "") {
     
        __data = data;
        __bytesPerPixel = bytesPerPixel;
        __width = width;
        __height = height;
        __src = src;
        __transparent = transparent;
        allocated = true;
    }

    /** Getters and setters. **/

    private function get_bytes():UInt8Array {

        return __data;
    }

    private function get_bytesPerPixel():Int {

        return __bytesPerPixel;
    }

    private function get_dirty():Bool {
        
        return __dirty;
    }

    public function get_height():Int {
        
        return __height;
    }

    private function get_powerOfTwo():Bool {

        return ((__width != 0) && ((__width & (~__width + 1)) == __width)) && ((__height != 0) && ((__height & (~__height + 1)) == __height));
    }

    private function get_transparent():Bool {

        return __transparent;
    }
    
    public function get_width():Int {
        
        return __width;
    }

    private function get_src():String {
        return __src;
    }

    // ** Methods

    public function dispose():Void {
        if (allocated) {
            __data = null;
            allocated = false;
            __dirty = false;
        }
    }

    public function getPixel(x:Int, y:Int):UInt {
        if (x < 0 || x >= __width || y < 0 || y >= __height) return 0;
        
        var index = (y * __width + x) * __bytesPerPixel;
        var pixel:UInt = 0;
        
        for (i in 0...__bytesPerPixel) {
            pixel |= __data[index + i] << (i * 8);
        }
        
        return pixel;
    }

    public function setPixel(x:Int, y:Int, color:UInt):Void {
        if (x < 0 || x >= __width || y < 0 || y >= __height) return;
        
        var index = (y * __width + x) * __bytesPerPixel;
        
        for (i in 0...__bytesPerPixel) {
            __data[index + i] = (color >> (i * 8)) & 0xFF;
        }
        
        __dirty = true;
    }

    // ** Statics

    public static function generateRGBA(width:Int, height:Int, bpp:Int, value:Int = 0):TextureData {

        var dimensions = width * height;
        var _bytes = new UInt8Array(dimensions * bpp);

        for (i in 0...dimensions) {
            var pos = bpp * i;

            for(j in 0...bpp) {
                _bytes[pos + j] = value;
            }

            // Set alpha to 255 for RGBA textures
            if (bpp == 4) {
                _bytes[pos + 3] = 255;
            }
        }

        return new TextureData(_bytes, bpp, width, height, bpp == 4);
    }
    
    // Convert grayscale texture to RGB for better OpenGL compatibility
    public function toRGB():TextureData {
        if (__bytesPerPixel != 1) {
            return this; // Already RGB/RGBA, return unchanged
        }
        
        var rgbData = new UInt8Array(__width * __height * 3);
        
        for (i in 0...(__width * __height)) {
            var grayValue = __data[i];
            rgbData[i * 3 + 0] = grayValue; // R
            rgbData[i * 3 + 1] = grayValue; // G
            rgbData[i * 3 + 2] = grayValue; // B
        }
        
        return new TextureData(rgbData, 3, __width, __height, false);
    }
}
