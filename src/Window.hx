package;

import math.Vec2;
import cpp.Pointer;
import SDL;

class Window {

    // Publics
    public var fullscreen(get, null):Bool;
    public var ptr(get, null):WindowPtr;
    public var size(get, set):Vec2;

    // Privates
    private var __windowPtr:WindowPtr;

    public function new(ptr:WindowPtr) {
        __windowPtr = ptr;
    }

    private function getWindowSize():{ width:Int, height:Int } {
        var w = 0, h = 0;
        var pw:Pointer<Int> = Pointer.addressOf(w);
        var ph:Pointer<Int> = Pointer.addressOf(h);
        SDL.getWindowSize(__windowPtr, pw, ph);
        return { width: w, height: h };
    }

    public function getWindowSizeInPixels():{ width:Int, height:Int } {
        var w = 0, h = 0;
        var pw:Pointer<Int> = Pointer.addressOf(w);
        var ph:Pointer<Int> = Pointer.addressOf(h);
        SDL.getWindowSizeInPixels(__windowPtr, pw, ph);
        return { width: w, height: h };
    }

    /** Returns the pixel scale (pixelWidth / logicalWidth) useful for HiDPI handling */
    public function getWindowScale():Float {
        var logical = getWindowSize();
        var pixels = getWindowSizeInPixels();
        if (logical.width == 0) return 1.0;
        return (pixels.width / logical.width);
    }

    public function setPosition(x:Int, y:Int):Void {
        SDL.setWindowPosition(__windowPtr, x, y);
    }

    // Getters and setters
    private function get_fullscreen():Bool {
        var props:Int = SDL.getWindowProperties(__windowPtr);
        return (props & SDL.WINDOW_FULLSCREEN) != 0;
    }

    private function set_fullscreen(enable:Bool):Bool {
        var res = SDL.setWindowFullscreen(__windowPtr, enable);
        return res == 0;
    }

    private function get_ptr():WindowPtr {
        return __windowPtr;
    }

    private function get_size():Vec2 {
        var size = getWindowSizeInPixels();
        return new Vec2(size.width, size.height);
    }

    private function set_size(value:Vec2):Vec2 {
        var scale = getWindowScale();
        var logicalWidth = Std.int(value.x / scale);
        var logicalHeight = Std.int(value.y / scale);
        SDL.setWindowSize(__windowPtr, logicalWidth, logicalHeight);
        return value;
    }
}


// import cpp.Pointer;

// @:include("SDL3/SDL.h")
// @:native("SDL_Window")
// extern class SDL_Window {}

// typedef Window = Pointer<SDL_Window>;