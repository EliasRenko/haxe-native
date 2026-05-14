package web;

#if js

import haxe.io.Bytes;
import js.Browser;
import js.html.CanvasElement;
import js.html.Element;
import js.html.KeyboardEvent;
import Scancode;
import js.html.MouseEvent;
import js.html.WheelEvent;
import js.html.TouchEvent;
import js.html.ClipboardEvent;
import js.html.webgl.WebGL2RenderingContext as RenderingContext;

/**
 * Web runtime — mirrors the public API of the native Runtime class.
 *
 * Differences from native:
 *  - No SDL; uses browser DOM APIs.
 *  - run() drives the loop via requestAnimationFrame (non-blocking).
 *  - Events are wired as DOM event listeners; the same virtual callbacks
 *    (onKeyDown, onMouseButtonDown, etc.) are invoked.
 *  - loadBytes() uses a synchronous XMLHttpRequest for API compatibility.
 *  - Logging routes to browser console.
 */
class Runtime {

    public var WINDOW_TITLE:String  = "Runtime";
    public var WINDOW_WIDTH:Int     = 640;
    public var WINDOW_HEIGHT:Int    = 480;

    // Publics
    public var active(get, null):Bool;
    public var window(get, null):Window;

    // Privates
    private var __active:Bool = false;
    private var __window:Window;

    public function new() {}

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    public function init():Void {

        // Find parent element
        var parentElement:Element = js.Browser.document.getElementById("canvas");
        if (parentElement == null) throw 'Canvas element with id "canvas" has not been found.';

        var canvas:CanvasElement = Browser.document.createCanvasElement();
        canvas.width  = WINDOW_WIDTH;
        canvas.height = WINDOW_HEIGHT;

        // Prevent context menu on right-click so mouse events work cleanly
        canvas.addEventListener("contextmenu", function(e:js.html.MouseEvent) e.preventDefault());

        parentElement.appendChild(canvas);

        __window = new Window(canvas);

        // Initialise WebGL2
        var gl:RenderingContext = cast canvas.getContextWebGL2({ antialias: false, alpha: false, depth: true });
        if (gl == null) {
            logError(19, "Failed to create WebGL2 context. Browser may not support WebGL2.");
            return;
        }

        GL.context = gl;

        // Update page title
        Browser.document.title = WINDOW_TITLE;

        // Set initial viewport
        GL.viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

        logInfo(19, "[WebGL2] Context created successfully.");

        // Wire up DOM events
        __registerEvents(canvas);
    }

    public function release():Void {
        logInfo(19, "Finalizing web runtime.");
        __active = false;
    }

    public function run():Void {
        __active = true;
        Browser.window.requestAnimationFrame(__loop);
    }

    private function __loop(timestamp:Float):Void {
        if (!__active) return;

        update();
        render();

        Browser.window.requestAnimationFrame(__loop);
    }

    public function swapBuffers():Void {
        // No-op on web — the browser handles buffer swapping automatically after each frame
    }

    // Override in subclasses
    public function update():Void {}
    public function render():Void {}

    public function getTicks():Float {
        return Browser.window.performance.now();
    }

    // -------------------------------------------------------------------------
    // File I/O (synchronous XHR for API compatibility with native)
    // -------------------------------------------------------------------------

    public function loadBytes(path:String):Bytes {
        var xhr = new js.html.XMLHttpRequest();
        xhr.open("GET", path, false); // synchronous
        xhr.overrideMimeType("text/plain; charset=x-user-defined");
        xhr.send();

        if (xhr.status != 200 && xhr.status != 0) {
            throw "Failed to load file: " + path + " (HTTP " + xhr.status + ")";
        }

        var response:String = xhr.responseText;
        var bytes = Bytes.alloc(response.length);
        for (i in 0...response.length) {
            bytes.set(i, response.charCodeAt(i) & 0xFF);
        }
        return bytes;
    }

    public function saveBytes(path:String, data:String):Bool {
        // Web cannot write to the file system directly.
        // Trigger a browser download as a fallback.
        var blob = new js.html.Blob([data], { type: "text/plain" });
        var url  = js.html.URL.createObjectURL(blob);
        var a    = (cast Browser.document.createElement("a") : js.html.AnchorElement);
        a.href     = url;
        a.download = path;
        a.click();
        js.html.URL.revokeObjectURL(url);
        return true;
    }

    // -------------------------------------------------------------------------
    // Text input
    // -------------------------------------------------------------------------

    public function startTextInput(canvas:CanvasElement):Void {
        // A hidden <input> element could be used for IME support;
        // for now keyboard events are sufficient.
    }

    public function stopTextInput(canvas:CanvasElement):Void {}

    // -------------------------------------------------------------------------
    // DOM event wiring
    // -------------------------------------------------------------------------

    private function __registerEvents(canvas:CanvasElement):Void {
        // Make canvas focusable so keyboard events are received
        canvas.tabIndex = 0;
        canvas.focus();

        // Keyboard
        canvas.addEventListener("keydown", function(e:KeyboardEvent) {
            var mod = (e.shiftKey ? 1 : 0) | (e.ctrlKey ? 64 : 0) | (e.altKey ? 256 : 0) | (e.metaKey ? 1024 : 0);
            onKeyDown(e.keyCode, __scancodeFromKeyboard(e), e.repeat, mod, 0);
            e.preventDefault();
        });

        canvas.addEventListener("keyup", function(e:KeyboardEvent) {
            var mod = (e.shiftKey ? 1 : 0) | (e.ctrlKey ? 64 : 0) | (e.altKey ? 256 : 0) | (e.metaKey ? 1024 : 0);
            onKeyUp(e.keyCode, __scancodeFromKeyboard(e), false, mod, 0);
        });

        canvas.addEventListener("keypress", function(e:KeyboardEvent) {
            if (e.key.length == 1) {
                onTextInput(e.key, 0.0);
            }
        });

        // Mouse
        canvas.addEventListener("mousedown", function(e:MouseEvent) {
            canvas.focus();
            var pos = __canvasPos(canvas, e.clientX, e.clientY);
            onMouseButtonDown(pos.x, pos.y, e.button, 0);
            e.preventDefault();
        });

        canvas.addEventListener("mouseup", function(e:MouseEvent) {
            var pos = __canvasPos(canvas, e.clientX, e.clientY);
            onMouseButtonUp(pos.x, pos.y, e.button, 0);
        });

        canvas.addEventListener("mousemove", function(e:MouseEvent) {
            var pos = __canvasPos(canvas, e.clientX, e.clientY);
            onMouseMotion(pos.x, pos.y, e.movementX, e.movementY, 0);
        });

        canvas.addEventListener("wheel", function(e:WheelEvent) {
            onMouseWheel(e.deltaX, e.deltaY, 0);
            e.preventDefault();
        }, { passive: false });

        // Touch
        canvas.addEventListener("touchstart", function(e:TouchEvent) {
            e.preventDefault();
            for (i in 0...e.changedTouches.length) {
                var t = e.changedTouches.item(i);
                var pos = __canvasPos(canvas, t.clientX, t.clientY);
                onFingerDown(0, t.identifier, pos.x / canvas.width, pos.y / canvas.height, 0, 0, t.force);
            }
        }, { passive: false });

        canvas.addEventListener("touchend", function(e:TouchEvent) {
            e.preventDefault();
            for (i in 0...e.changedTouches.length) {
                var t = e.changedTouches.item(i);
                var pos = __canvasPos(canvas, t.clientX, t.clientY);
                onFingerUp(0, t.identifier, pos.x / canvas.width, pos.y / canvas.height, 0, 0, t.force);
            }
        }, { passive: false });

        canvas.addEventListener("touchmove", function(e:TouchEvent) {
            e.preventDefault();
            for (i in 0...e.changedTouches.length) {
                var t = e.changedTouches.item(i);
                var pos = __canvasPos(canvas, t.clientX, t.clientY);
                onFingerMotion(0, t.identifier, pos.x / canvas.width, pos.y / canvas.height, 0, 0, t.force);
            }
        }, { passive: false });

        // Clipboard
        Browser.window.addEventListener("paste", function(e:Dynamic) {
            var text:String = e.clipboardData != null ? e.clipboardData.getData("text") : "";
            onClipboardUpdate(text);
        });

        // Window visibility / focus
        Browser.window.addEventListener("focus",  function(_) onWindowFocusGained(0));

        Browser.window.addEventListener("blur",   function(_) onWindowFocusLost(0));

        Browser.window.addEventListener("resize", function(_) {
            var w = canvas.clientWidth;
            var h = canvas.clientHeight;
            onWindowResized(0, w, h);
        });
    }

    private function __canvasPos(canvas:CanvasElement, clientX:Float, clientY:Float):{x:Float, y:Float} {
        var rect = canvas.getBoundingClientRect();
        var scaleX = canvas.width  / rect.width;
        var scaleY = canvas.height / rect.height;
        return { x: (clientX - rect.left) * scaleX, y: (clientY - rect.top) * scaleY };
    }

    private function __scancodeFromKeyboard(e:KeyboardEvent):Int {
        return Scancode.fromWebCode((e : Dynamic).code);
    }

    // -------------------------------------------------------------------------
    // Virtual event handlers (override in subclasses)
    // Mirrors the native Runtime's event handler surface.
    // -------------------------------------------------------------------------

    // System
    private function onTermination():Void {}
    private function onLowMemory():Void {}
    private function willEnterBackground():Void {}
    private function didEnterBackground():Void {}
    private function willEnterForeground():Void {}
    private function didEnterForeground():Void {}

    // Window
    private function onWindowShown(windowId:Int):Void {}
    private function onWindowHidden(windowId:Int):Void {}
    private function onWindowExposed(windowId:Int):Void {}
    private function onWindowMoved(windowId:Int, x:Int, y:Int):Void {}
    private function onWindowResized(windowId:Int, width:Int, height:Int):Void {}
    private function onWindowPixelSizeChanged(windowId:Int, pixelWidth:Int, pixelHeight:Int):Void {}
    private function onWindowMinimized(windowId:Int):Void {}
    private function onWindowMaximized(windowId:Int):Void {}
    private function onWindowRestored(windowId:Int):Void {}
    private function onWindowMouseEnter(windowId:Int):Void {}
    private function onWindowMouseLeave(windowId:Int):Void {}
    private function onWindowFocusGained(windowId:Int):Void {}
    private function onWindowFocusLost(windowId:Int):Void {}
    private function onWindowCloseRequested(windowId:Int):Void {}
    private function onWindowEnterFullscreen(windowId:Int):Void {}
    private function onWindowLeaveFullscreen(windowId:Int):Void {}
    private function onWindowDestroyed(windowId:Int):Void {}

    // Display (no direct web equivalents — kept for API parity)
    private function onDisplayOrientationChanged(displayId:Int, orientation:Int):Void {}
    private function onDisplayAdded(displayId:Int):Void {}
    private function onDisplayRemoved(displayId:Int):Void {}
    private function onDisplayContentScaleChanged(displayId:Int, scale:Float):Void {}

    // Keyboard — mod is a bitmask matching SDL_Keymod: shift=1, ctrl=64, alt=256, meta=1024
    private function onKeyDown(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {}
    private function onKeyUp(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {}
    private function onTextInput(text:String, timestamp:Float):Void {}

    // Mouse — button: 0=left, 1=middle, 2=right (matching DOM)
    private function onMouseButtonDown(x:Float, y:Float, button:Int, windowId:Int):Void {}
    private function onMouseButtonUp(x:Float, y:Float, button:Int, windowId:Int):Void {}
    private function onMouseMotion(x:Float, y:Float, xrel:Float, yrel:Float, windowId:Int):Void {}
    private function onMouseWheel(x:Float, y:Float, windowId:Int):Void {}
    private function onMouseAdded(deviceId:Int):Void {}
    private function onMouseRemoved(deviceId:Int):Void {}

    // Touch
    private function onFingerDown(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerUp(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerMotion(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerCanceled(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}

    // Clipboard
    private function onClipboardUpdate(clipboardText:String):Void {}

    // -------------------------------------------------------------------------
    // Event pump — no-op on web (events are driven by DOM listeners)
    // -------------------------------------------------------------------------

    private function handleEvents():Void {}

    // -------------------------------------------------------------------------
    // Logging — routes to browser console
    // Priority hierarchy: TRACE(0) < VERBOSE(1) < DEBUG(2) < INFO(3) < WARN(4) < ERROR(5) < CRITICAL(6)
    // -------------------------------------------------------------------------

    public function logTrace(category:Int, message:String):Void    { js.Browser.console.log   ("[TRACE]["    + category + "] " + message); }
    public function logVerbose(category:Int, message:String):Void  { js.Browser.console.log   ("[VERBOSE]["  + category + "] " + message); }
    public function logDebug(category:Int, message:String):Void    { js.Browser.console.log   ("[DEBUG]["    + category + "] " + message); }
    public function logInfo(category:Int, message:String):Void     { js.Browser.console.info  ("[INFO]["     + category + "] " + message); }
    public function logWarn(category:Int, message:String):Void     { js.Browser.console.warn  ("[WARN]["     + category + "] " + message); }
    public function logError(category:Int, message:String):Void    { js.Browser.console.error ("[ERROR]["    + category + "] " + message); }
    public function logCritical(category:Int, message:String):Void { js.Browser.console.error ("[CRITICAL][" + category + "] " + message); }

    public function getLogPriority(category:Int):Int           { return 0; }
    public function setLogPriority(category:Int, priority:Int):Void {}
    public function resetLogPriorities():Void {}

    // Getters and setters

    private function get_active():Bool  { return __active; }
    private function get_window():Window { return __window; }
}

#end
