package;

import cpp.Pointer;
import SDL;

class Window {

    // Publics
    public var fullscreen(get, null):Bool;
    public var size(get, set):{x:Int, y:Int};
    public var pixelSize(get, null):{x:Int, y:Int};
    public var ptr(get, null):WindowPtr;

    // Privates
    private var __size:{x:Int, y:Int} = {x: 0, y: 0};
    private var __pixelSize:{x:Int, y:Int} = {x: 0, y: 0};
    private var __windowPtr:WindowPtr;

    public function new(ptr:WindowPtr) {
        __windowPtr = ptr;

        var w = 0;
        var h = 0;
        var pw:Pointer<Int> = Pointer.addressOf(w);
        var ph:Pointer<Int> = Pointer.addressOf(h);

        SDL.getWindowSize(__windowPtr, pw, ph);
        __size = {x: w, y: h};

        SDL.getWindowSizeInPixels(__windowPtr, pw, ph);
        __pixelSize = {x: w, y: h};
    }

    public function getWindowSizeInPixels():{ width:Int, height:Int } {
        return { width: __pixelSize.x, height: __pixelSize.y };
    }

    /** Returns the pixel scale (pixelWidth / logicalWidth) useful for HiDPI handling */
    public function getWindowScale():Float {
        var logical = size;
        var pixels = getWindowSizeInPixels();
        if (logical.x == 0) return 1.0;
        return pixels.width / logical.x;
    }

    public function setPosition(x:Int, y:Int):Void {
        SDL.setWindowPosition(__windowPtr, x, y);
    }

    // Private access
    private function onWindowResized(width:Int, height:Int):Void {
        __size = {x: width, y: height};
    }

    private function onWindowPixelSizeChanged(width:Int, height:Int):Void {
        __pixelSize = {x: width, y: height};
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

    private function get_size():{x:Int, y:Int} {
        return {x: __size.x, y: __size.y};
    }

    private function get_pixelSize():{x:Int, y:Int} {
        return {x: __pixelSize.x, y: __pixelSize.y};
    }

    private function set_size(value:{x:Int, y:Int}):{x:Int, y:Int} {
        //var scale = getWindowScale();
        //var logicalWidth = Std.int(value.x / scale);
        //var logicalHeight = Std.int(value.y / scale);
        SDL.setWindowSize(__windowPtr, Std.int(value.x), Std.int(value.y));
        return value;
    }
}