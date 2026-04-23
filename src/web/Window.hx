package web;

#if js
import js.Browser;
import js.html.CanvasElement;
import math.Vec2;

/**
 * Web window abstraction wrapping an HTML5 <canvas> element.
 * Mirrors the public API of the native Window class.
 */
class Window {

    // Publics
    public var fullscreen(get, set):Bool;
    public var size(get, set):Vec2;

    // Privates
    private var __canvas:CanvasElement;

    public function new(canvas:CanvasElement) {
        __canvas = canvas;
    }

    public function getWindowSizeInPixels():{ width:Int, height:Int } {
        var dpr = Browser.window.devicePixelRatio;
        return {
            width:  Std.int(__canvas.width),
            height: Std.int(__canvas.height)
        };
    }

    /** Returns the pixel scale (devicePixelRatio) useful for HiDPI handling. */
    public function getWindowScale():Float {
        return Browser.window.devicePixelRatio;
    }

    /** No-op on web — canvas position is controlled by CSS. */
    public function setPosition(x:Int, y:Int):Void {}

    // Getters and setters

    private function get_fullscreen():Bool {
        return Browser.document.fullscreenElement != null;
    }

    private function set_fullscreen(enable:Bool):Bool {
        if (enable) {
            __canvas.requestFullscreen();
        } else {
            if (Browser.document.fullscreenElement != null) {
                Browser.document.exitFullscreen();
            }
        }
        return enable;
    }

    private function get_size():Vec2 {
        return new Vec2(__canvas.width, __canvas.height);
    }

    private function set_size(value:Vec2):Vec2 {
        __canvas.width  = Std.int(value.x);
        __canvas.height = Std.int(value.y);
        return value;
    }

    /** Expose the underlying canvas element for external use. */
    public function getCanvas():CanvasElement {
        return __canvas;
    }
}
#end
