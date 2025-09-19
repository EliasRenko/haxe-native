package;

import cpp.Pointer;
import SDL;

class Window {

    // Publics
    public var ptr(get, null):WindowPtr;

    // Privates
    private var __windowPtr:WindowPtr;

    public function new(ptr:WindowPtr) {
        __windowPtr = ptr;
    }

    public function getWindowSize():{ width:Int, height:Int } {
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

    public function getWindowWidth():Int {
        return getWindowSizeInPixels().width;
    }

    public function getWindowHeight():Int {
        return getWindowSizeInPixels().height;
    }

    /** Returns the pixel scale (pixelWidth / logicalWidth) useful for HiDPI handling */
    public function getWindowScale():Float {
        var logical = getWindowSize();
        var pixels = getWindowSizeInPixels();
        if (logical.width == 0) return 1.0;
        return (pixels.width / logical.width);
    }

    public function isFullscreen():Bool {
        var props:Int = SDL.getWindowProperties(__windowPtr);
        return (props & SDL.WINDOW_FULLSCREEN) != 0 || (props & SDL.WINDOW_FULLSCREEN_DESKTOP) != 0;
    }

    public function setFullscreen(enable:Bool):Bool {
        var res = SDL.setWindowFullscreen(__windowPtr, enable);
        return res == 0;
    }

    public function toggleFullscreen():Bool {
        var currently = isFullscreen();
        return setFullscreen(!currently);
    }

    // Getters and setters
    private function get_ptr():WindowPtr {
        return __windowPtr;
    }
}


// import cpp.Pointer;

// @:include("SDL3/SDL.h")
// @:native("SDL_Window")
// extern class SDL_Window {}

// typedef Window = Pointer<SDL_Window>;