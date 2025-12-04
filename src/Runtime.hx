package;

import haxe.io.BytesData;
import haxe.io.Bytes;
import cpp.RawPointer;
import cpp.NativeArray;

import SDL;
import GL;
import Renderer;
import Log;
import cpp.UInt64;
import cpp.Pointer;

typedef PathInfo = SDL_PathInfo;

class Runtime {

    public var WINDOW_TITLE:String = "Runtime";
    public var WINDOW_WIDTH:Int = 640;
    public var WINDOW_HEIGHT:Int = 480;

    // Publics
    public var active(get, null):Bool;
    public var vsync(get, set):Int;
    public var window(get, null):Window;

    // Privates
    private var __active:Bool = false;
    private var __window:Window;
    private var __context:GLContext;

    // TODO: Move log to App
    private var __log:Log;
    
    public function new() {}
    
    public function init():Bool {
        // Initialize SDL video
        if (!SDL.init(SDL.INIT_VIDEO)) {
            __log.error(0, "Failed to initialize SDL video: " + SDL.getError());
            return false;
        }

        // Initialize SDL audio
        #if !no_audio
        if (!SDL.init(SDL.INIT_AUDIO)) {
            __log.error(0, "Failed to initialize SDL audio: " + SDL.getError());
            return false;
        }
        #end

        // Initialize SDL joystick
        #if !no_joystick
        if (!SDL.init(SDL.INIT_JOYSTICK)) {
            __log.error(0, "Failed to initialize SDL joystick: " + SDL.getError());
            return false;
        }
        #end

        // Initialize gamepad
        #if !no_gamepad
        if (!SDL.init(SDL.INIT_GAMEPAD)) {
            __log.error(0, "Failed to initialize SDL gamepad: " + SDL.getError());
            return false;
        }
        #end

        #if !no_haptic
        // Initialize SDL haptic
        if (!SDL.init(SDL.INIT_HAPTIC)) {
            __log.error(0, "Failed to initialize SDL haptic: " + SDL.getError());
            return false;
        }
        #end
        
        // Set OpenGL attributes (3.3 Core)
        SDL.setAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_PROFILE_MASK, SDL.GL_CONTEXT_PROFILE_CORE);
        
        // Create window
        __window = new Window(SDL.createWindow(WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT, SDL.WINDOW_OPENGL | SDL.WINDOW_RESIZABLE));
        if (__window.ptr == null) {
            __log.error(0, "Failed to create window: " + SDL.getError());
            release();
            return false;
        }
        
        // Create OpenGL context
        __context = SDL.createContext(__window.ptr);
        if (__context == null) {
            __log.error(0, "Failed to create OpenGL context: " + SDL.getError());
            release();
            return false;
        }
        
        SDL.makeCurrent(__window.ptr, __context);
        
        // Load OpenGL functions
        var gladResult = GL.gladLoadGLLoader(SDL.getProcAddress);
        if (gladResult == 0) {
            __log.error(0, "Failed to load OpenGL functions");
            release();
            return false;
        }
        
        SDL.logInfo(0, "[OpenGL] " + "OpenGL version: " + GL.version.major + "." + GL.version.minor + " has been loaded.");
        
        // Set viewport to match window size
        GL.viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

        return true;
    }

    public function release():Void {
        __log.info(0, "Finalizing runtime.");
        
        // Cleanup log system last
        if (__log != null) {
            __log.release();
            __log = null;
        }

        SDL.quit();
    }

    public function run():Void {
        __active = true;
        var frameCount = 0;

        while (__active) {
            frameCount++;
            
            // Handle events
            handleEvents();
            
            // Update application logic
            update();
            
            // Render frame
            render();
            
            // Swap buffers
            SDL.swapWindow(__window.ptr);
        }
        
        release();
    }

    private function update():Void {}
    private function render():Void {}

    public function loadBytes(path:String):Bytes {
        
        var size:UInt64 = 0;
        var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
        var ptrData = SDL.loadFile(path, ptrSize.ptr);

        if (ptrData == null) {
            throw "Failed to open file: " + path;
        }

        var bytes = Bytes.alloc(size.toInt());
        for (i in 0...size.toInt()) {
            bytes.set(i, ptrData[i]);
        }
        
        SDL.free(ptrData);
        return bytes;
    }

    public function saveBytes(path:String, data:String):Bool {

        var bytes = Bytes.ofString(data);
        var dataPtr = NativeArray.address(bytes.getData(), 0); 
        var dataSize = bytes.length;

        var result = SDL.saveFile(path, dataPtr, dataSize);
        if (!result) {
            __log.error(0, "Failed to save file: " + path + " - ERROR: " + SDL.getError());
        }
        return result;
    }

    // public function getPathInfo(path:String):PathInfo {
    //     var pathInfo:SDL_PathInfo = untyped __cpp__("SDL_PathInfo()");
    //     var infoPtr:Pointer<SDL_PathInfo> = untyped __cpp__("&{0}", pathInfo);
    //     if (SDL.getPathInfo(path, infoPtr.ptr)) {
    //         return pathInfo;
    //     }
    //     return null;
    // }

    // public function pathExists(path:String):Bool {
	// 	if (getPathInfo(path) != null) {
    //         return true;
    //     }
    //     return false;
	// }

    // Event handling
    private function handleEvents():Void {
        var event = SDL.getEvent();
        while (SDL.pollEvent(event)) {
            // TODO: Handle various system events
            if (event.value.type == SDL.EVENT_QUIT) {
                __active = false;
            } 

            if (event.value.type == SDL.EVENT_WINDOW_MAXIMIZED) {
                
            }

            if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                __active = false;
            }
            
            __handleSystemEvents(event);
            __handleDisplayEvents(event);
            __handleWindowEvents(event);
            __handleKeyboardInputEvents(event);
            __handleMouseInputEvents(event);
            __handleJoystickInputEvents(event);
            __handleGamepadInputEvents(event);
            __handleFingerEvents(event);
            __handleClipboardEvents(event);
        }
    }

    public function startTextInput(window:WindowPtr) {
        SDL.startTextInput(window);
    }
    
    public function stopTextInput(window:WindowPtr) {
        SDL.stopTextInput(window);
    }

    // System events
    // LOCALE_CHANGED & SYSTEM_THEME_CHANGED are not handled
    private function __handleSystemEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_SystemEventType.QUIT:
                __active = false;
            case SDL_SystemEventType.TERMINATING:
                onTermination();
            case SDL_SystemEventType.LOW_MEMORY:
                onLowMemory();
            case SDL_SystemEventType.WILL_ENTER_BACKGROUND:
                willEnterBackground();
            case SDL_SystemEventType.DID_ENTER_BACKGROUND:
                didEnterBackground();
            case SDL_SystemEventType.WILL_ENTER_FOREGROUND:
                willEnterForeground();
            case SDL_SystemEventType.DID_ENTER_FOREGROUND:
                didEnterForeground();
            default:
                // Other events can be ignored here
        }
    }

    // Display events
    private function __handleDisplayEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_DisplayEventType.DISPLAY_ORIENTATION:
                onDisplayOrientationChanged(event.value.display.displayID, event.value.display.data1); // data1 = orientation
            case SDL_DisplayEventType.DISPLAY_ADDED:
                onDisplayAdded(event.value.display.displayID);
            case SDL_DisplayEventType.DISPLAY_REMOVED:
                onDisplayRemoved(event.value.display.displayID);
            case SDL_DisplayEventType.DISPLAY_MOVED:
                onDisplayMoved(event.value.display.displayID, event.value.display.data1, event.value.display.data2); // data1,data2 = x,y
            case SDL_DisplayEventType.DISPLAY_DESKTOP_MODE_CHANGED:
                var mode:Pointer<SDL_DisplayMode> = SDL.getDesktopDisplayMode(event.value.display.displayID);
                onDisplayDesktopModeChanged(event.value.display.displayID, mode.value);
            case SDL_DisplayEventType.DISPLAY_CURRENT_MODE_CHANGED:
                var mode:Pointer<SDL_DisplayMode> = SDL.getCurrentDisplayMode(event.value.display.displayID);
                onDisplayCurrentModeChanged(event.value.display.displayID, mode.value);
            case SDL_DisplayEventType.DISPLAY_CONTENT_SCALE_CHANGED:
                var scale:Float = SDL.getDisplayContentScale(event.value.display.displayID);
                onDisplayContentScaleChanged(event.value.display.displayID, scale);
            default:
                // Other events can be ignored here
        }
    }

    // Window events
    // SDL_EVENT_WINDOW_METAL_VIEW_RESIZED is not handled
    private function __handleWindowEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_WindowEventType.WINDOW_SHOWN:
                onWindowShown(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_HIDDEN:
                onWindowHidden(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_EXPOSED:
                onWindowExposed(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_MOVED:
                onWindowMoved(event.value.window.windowID, event.value.window.data1, event.value.window.data2); // data1,data2 = x,y
            case SDL_WindowEventType.WINDOW_RESIZED:
                onWindowResized(event.value.window.windowID, event.value.window.data1, event.value.window.data2); // data1,data2 = width,height
            case SDL_WindowEventType.WINDOW_PIXEL_SIZE_CHANGED:
                onWindowPixelSizeChanged(event.value.window.windowID, event.value.window.data1, event.value.window.data2); // data1,data2 = pixelWidth,pixelHeight
            case SDL_WindowEventType.WINDOW_MINIMIZED:
                onWindowMinimized(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_MAXIMIZED:
                onWindowMaximized(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_RESTORED:
                onWindowRestored(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_MOUSE_ENTER:
                onWindowMouseEnter(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_MOUSE_LEAVE:
                onWindowMouseLeave(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_FOCUS_GAINED:
                onWindowFocusGained(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_FOCUS_LOST:
                onWindowFocusLost(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_CLOSE_REQUESTED:
                onWindowCloseRequested(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_HIT_TEST:
                onWindowHitTest(event.value.window.windowID, event.value.window.data1, event.value.window.data2); // data1,data2 = x,y
            case SDL_WindowEventType.WINDOW_ICCPROF_CHANGED:
                onWindowICCProfileChanged(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_DISPLAY_CHANGED:
                onWindowDisplayChanged(event.value.window.windowID, event.value.window.data1); // data1 = displayIndex
            case SDL_WindowEventType.WINDOW_DISPLAY_SCALE_CHANGED:
                var windowPtr = SDL.getWindowFromID(event.value.window.windowID);
                var scale = SDL.getWindowDisplayScale(windowPtr);
                onWindowDisplayScaleChanged(event.value.window.windowID, scale);
            case SDL_WindowEventType.WINDOW_SAFE_AREA_CHANGED:
                //var safeArea:SDL_Rect = {x:0, y:0, w:0, h:0};
                //SDL.getWindowSafeArea(event.value.window.windowID, Pointer.addressOf(safeArea));
                //onWindowSafeAreaChanged(event.value.window.windowID, safeArea);
            case SDL_WindowEventType.WINDOW_OCCLUDED:
                onWindowOccluded(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_ENTER_FULLSCREEN:
                onWindowEnterFullscreen(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_LEAVE_FULLSCREEN:
                onWindowLeaveFullscreen(event.value.window.windowID);
            case SDL_WindowEventType.WINDOW_DESTROYED:
                onWindowDestroyed(event.value.window.windowID);
           case SDL_WindowEventType.WINDOW_HDR_STATE_CHANGED:
                var hdrEnabled:Bool = event.value.window.data1 != 0;
                onWindowHDRStateChanged(event.value.window.windowID, hdrEnabled);
            default:
                // Other events can be ignored here
        }
    }

    // Keyboard events
    private function __handleKeyboardInputEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_KeyboardEventType.KEY_DOWN:
                onKeyDown(event.value.key.key, event.value.key.scancode, event.value.key.repeat, event.value.key.mod, event.value.key.windowID);
            case SDL_KeyboardEventType.KEY_UP:
                onKeyUp(event.value.key.key, event.value.key.scancode, event.value.key.repeat, event.value.key.mod, event.value.key.windowID);
            case SDL_KeyboardEventType.TEXT_INPUT:
                onTextInput(event.value.text.text, event.value.text.timestamp, event.value.text.windowID);
            case SDL_KeyboardEventType.TEXT_EDITING:
                // TODO: Implement text editing event handling
            case SDL_KeyboardEventType.KEYMAP_CHANGED:
                // TODO: Implement keymap changed event handling
            case SDL_KeyboardEventType.KEYBOARD_ADDED:
                // TODO: Implement keyboard added event handling
            case SDL_KeyboardEventType.KEYBOARD_REMOVED:
                // TODO: Implement keyboard removed event handling
            default:
                // Other events can be ignored here
        }
    }

    // Mouse events
    private function __handleMouseInputEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_MouseEventType.MOUSE_BUTTON_DOWN:
                onMouseButtonDown(event.value.button.x, event.value.button.y, event.value.button.button, event.value.button.windowID);
            case SDL_MouseEventType.MOUSE_BUTTON_UP:
                onMouseButtonUp(event.value.button.x, event.value.button.y, event.value.button.button, event.value.button.windowID);
            case SDL_MouseEventType.MOUSE_MOTION:
                onMouseMotion(event.value.motion.x, event.value.motion.y, event.value.motion.xrel, event.value.motion.yrel, event.value.motion.windowID);
            case SDL_MouseEventType.MOUSE_WHEEL:
                onMouseWheel(event.value.wheel.x, event.value.wheel.y, event.value.wheel.windowID);
            case SDL_MouseEventType.MOUSE_ADDED:
                onMouseAdded(event.value.mdevice.which);
            case SDL_MouseEventType.MOUSE_REMOVED:
                onMouseRemoved(event.value.mdevice.which);
            default:
                // Other events can be ignored here
        }
    }

    // Joystick events
    private function __handleJoystickInputEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_JoystickEventType.JOYSTICK_AXIS_MOTION:
                onJoyAxisMotion(event.value.jaxis.which, event.value.jaxis.axis, event.value.jaxis.value);
            case SDL_JoystickEventType.JOYSTICK_BALL_MOTION:
                onJoyBallMotion(event.value.jball.which, event.value.jball.ball, event.value.jball.xrel, event.value.jball.yrel);
            case SDL_JoystickEventType.JOYSTICK_HAT_MOTION:
                onJoyHatMotion(event.value.jhat.which, event.value.jhat.hat, event.value.jhat.value);
            case SDL_JoystickEventType.JOYSTICK_BUTTON_DOWN:
                onJoyButtonDown(event.value.jbutton.which, event.value.jbutton.button);
            case SDL_JoystickEventType.JOYSTICK_BUTTON_UP:
                onJoyButtonUp(event.value.jbutton.which, event.value.jbutton.button);
            case SDL_JoystickEventType.JOYSTICK_ADDED:
                onJoyDeviceAdded(event.value.jdevice.which);
            case SDL_JoystickEventType.JOYSTICK_REMOVED:
                onJoyDeviceRemoved(event.value.jdevice.which);
            case SDL_JoystickEventType.JOYSTICK_BATTERY_UPDATED:
                onJoyBatteryUpdated(event.value.jbattery.which, event.value.jbattery.percent);
            case SDL_JoystickEventType.JOYSTICK_UPDATE_COMPLETE:
                onJoyUpdateComplete(event.value.jdevice.which);
            default:
                // Other events can be ignored here
        }
    }

    // Gamepad events
    private function __handleGamepadInputEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_GamepadEventType.GAMEPAD_BUTTON_DOWN:
                onGamepadButtonDown(event.value.gbutton.which, event.value.gbutton.button);
            case SDL_GamepadEventType.GAMEPAD_BUTTON_UP:
                onGamepadButtonUp(event.value.gbutton.which, event.value.gbutton.button);
            case SDL_GamepadEventType.GAMEPAD_AXIS_MOTION:
                onGamepadAxisMotion(event.value.gaxis.which, event.value.gaxis.axis, event.value.gaxis.value);
            case SDL_GamepadEventType.GAMEPAD_ADDED:
                onGamepadDeviceAdded(event.value.gdevice.which);
            case SDL_GamepadEventType.GAMEPAD_REMOVED:
                onGamepadDeviceRemoved(event.value.gdevice.which);
            case SDL_GamepadEventType.GAMEPAD_REMAPPED:
                onGamepadRemapped(event.value.gdevice.which);
            case SDL_GamepadEventType.GAMEPAD_TOUCHPAD_DOWN:
                onGamepadTouchpadDown(event.value.gtouchpad.which, event.value.gtouchpad.touchpad, event.value.gtouchpad.finger, event.value.gtouchpad.x, event.value.gtouchpad.y, event.value.gtouchpad.pressure);
            case SDL_GamepadEventType.GAMEPAD_TOUCHPAD_UP:
                onGamepadTouchpadUp(event.value.gtouchpad.which, event.value.gtouchpad.touchpad, event.value.gtouchpad.finger, event.value.gtouchpad.x, event.value.gtouchpad.y, event.value.gtouchpad.pressure);
            case SDL_GamepadEventType.GAMEPAD_TOUCHPAD_MOTION:
                onGamepadTouchpadMotion(event.value.gtouchpad.which, event.value.gtouchpad.touchpad, event.value.gtouchpad.finger, event.value.gtouchpad.x, event.value.gtouchpad.y, event.value.gtouchpad.pressure);
            case SDL_GamepadEventType.GAMEPAD_SENSOR_UPDATE:
                onGamepadSensorUpdate(event.value.gsensor.which, event.value.gsensor.sensor, event.value.gsensor.data[0], event.value.gsensor.data[1], event.value.gsensor.data[2]);
            case SDL_GamepadEventType.GAMEPAD_UPDATE_COMPLETE:
                onGamepadUpdateComplete(event.value.gdevice.which);
            case SDL_GamepadEventType.GAMEPAD_STEAM_HANDLE_UPDATED:
                onGamepadSteamHandleUpdated(event.value.gdevice.which);
            default:
                // Other events can be ignored here
        }
    }

    // Touch Finger events
    private function __handleFingerEvents(event:Pointer<Event>):Void {
        switch (event.value.type) {
            case SDL_FingerEventType.FINGER_DOWN:
                onFingerDown(event.value.tfinger.touchID, event.value.tfinger.fingerID, event.value.tfinger.x, event.value.tfinger.y, event.value.tfinger.dx, event.value.tfinger.dy, event.value.tfinger.pressure);
            case SDL_FingerEventType.FINGER_UP:
                onFingerUp(event.value.tfinger.touchID, event.value.tfinger.fingerID, event.value.tfinger.x, event.value.tfinger.y, event.value.tfinger.dx, event.value.tfinger.dy, event.value.tfinger.pressure);
            case SDL_FingerEventType.FINGER_MOTION:
                onFingerMotion(event.value.tfinger.touchID, event.value.tfinger.fingerID, event.value.tfinger.x, event.value.tfinger.y, event.value.tfinger.dx, event.value.tfinger.dy, event.value.tfinger.pressure);
            case SDL_FingerEventType.FINGER_CANCELED:
                onFingerCanceled(event.value.tfinger.touchID, event.value.tfinger.fingerID, event.value.tfinger.x, event.value.tfinger.y, event.value.tfinger.dx, event.value.tfinger.dy, event.value.tfinger.pressure);
            default:
                // Other events can be ignored here
        }
    }

    // Clipboard events
    private function __handleClipboardEvents(event:Pointer<Event>):Void {
        if (event.value.type == SDL_ClipboardEventType.CLIPBOARD_UPDATE) {
            var clipboardText = SDL.getClipboardText();
            onClipboardUpdate(clipboardText);
        }
    }

    // System event handlers
    private function onTermination():Void {}
    private function onLowMemory():Void {}
    private function willEnterBackground():Void {}
    private function didEnterBackground():Void {}
    private function willEnterForeground():Void {}
    private function didEnterForeground():Void {}

    // Window event handlers
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
    private function onWindowHitTest(windowId:Int, x:Int, y:Int):Void {}
    private function onWindowICCProfileChanged(windowId:Int):Void {}
    private function onWindowDisplayChanged(windowId:Int, displayIndex:Int):Void {}
    private function onWindowDisplayScaleChanged(windowId:Int, scale:Float):Void {}
    private function onWindowSafeAreaChanged(windowId:Int, safeArea:SDL_Rect):Void {}
    private function onWindowOccluded(windowId:Int):Void {}
    private function onWindowEnterFullscreen(windowId:Int):Void {}
    private function onWindowLeaveFullscreen(windowId:Int):Void {}
    private function onWindowDestroyed(windowId:Int):Void {}
    private function onWindowHDRStateChanged(windowId:Int, hdrEnabled:Bool):Void {}

    // Display event handlers
    private function onDisplayOrientationChanged(displayId:Int, orientation:SDL_DisplayOrientation):Void {}
    private function onDisplayAdded(displayId:Int):Void {}
    private function onDisplayRemoved(displayId:Int):Void {}
    private function onDisplayMoved(displayId:Int, x:Int, y:Int):Void {}
    private function onDisplayDesktopModeChanged(displayId:Int, mode:SDL_DisplayMode):Void {}
    private function onDisplayCurrentModeChanged(displayId:Int, mode:SDL_DisplayMode):Void {}
    private function onDisplayContentScaleChanged(displayId:Int, scale:Float):Void {}

    // Keyboard event handlers
    private function onKeyDown(keycode:Int, scancode:Int, repeat:Bool, mod:SDL_Keymod, windowId:Int):Void {}
    private function onKeyUp(keycode:Int, scancode:Int, repeat:Bool, mod:SDL_Keymod, windowId:Int):Void {}
    private function onTextInput(text:String, timestamp:Float, window_id:Int) {}

    // Mouse event handlers
    private function onMouseButtonDown(x:Float, y:Float, button:Int, windowId:Int):Void {}
    private function onMouseButtonUp(x:Float, y:Float, button:Int, windowId:Int):Void {}
    private function onMouseMotion(x:Float, y:Float, xrel:Float, yrel:Float, windowId:Int):Void {}
    private function onMouseWheel(x:Float, y:Float, windowId:Int):Void {}
    private function onMouseAdded(deviceId:Int):Void {}
    private function onMouseRemoved(deviceId:Int):Void {}

    // Joystick event handlers
    private function onJoyAxisMotion(joystickId:Int, axis:Int, value:Int):Void {}
    private function onJoyBallMotion(joystickId:Int, ball:Int, xrel:Int, yrel:Int):Void {}
    private function onJoyHatMotion(joystickId:Int, hat:Int, value:Int):Void {}
    private function onJoyButtonDown(joystickId:Int, button:Int):Void {}
    private function onJoyButtonUp(joystickId:Int, button:Int):Void {}
    private function onJoyDeviceAdded(deviceId:Int):Void {}
    private function onJoyDeviceRemoved(deviceId:Int):Void {}
    private function onJoyBatteryUpdated(joystickId:Int, batteryLevel:Int):Void {}
    private function onJoyUpdateComplete(joystickId:Int):Void {}

    // Gamepad event handlers
    private function onGamepadAxisMotion(gamepadId:Int, axis:Int, value:Int):Void {}
    private function onGamepadButtonDown(gamepadId:Int, button:Int):Void {}
    private function onGamepadButtonUp(gamepadId:Int, button:Int):Void {}
    private function onGamepadDeviceAdded(deviceId:Int):Void {}
    private function onGamepadDeviceRemoved(deviceId:Int):Void {}
    private function onGamepadRemapped(deviceId:Int):Void {}
    private function onGamepadTouchpadDown(deviceId:Int, touchpadId:Int, fingerId:Int, x:Float, y:Float, pressure:Float):Void {}
    private function onGamepadTouchpadUp(deviceId:Int, touchpadId:Int, fingerId:Int, x:Float, y:Float, pressure:Float):Void {}
    private function onGamepadTouchpadMotion(deviceId:Int, touchpadId:Int, fingerId:Int, x:Float, y:Float, pressure:Float):Void {}
    private function onGamepadSensorUpdate(deviceId:Int, sensorId:Int, data1:Float, data2:Float, data3:Float):Void {}
    private function onGamepadUpdateComplete(deviceId:Int):Void {}
    private function onGamepadSteamHandleUpdated(deviceId:Int):Void {}

    // Touch event handlers
    private function onFingerDown(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerUp(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerMotion(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}
    private function onFingerCanceled(touchId:Int, fingerId:Int, x:Float, y:Float, dx:Float, dy:Float, pressure:Float):Void {}

    // Clipboard event handler
    private function onClipboardUpdate(clipboardText:String):Void {}

    // Log functions
    // Priority hierarchy (low to high): TRACE (0) < VERBOSE (1) < DEBUG (2) < INFO (3) < WARN (4) < ERROR (5) < CRITICAL (6)
    public function logTrace(category:Int, message:String):Void {
        SDL.logTrace(category, message);
    }

    public function logVerbose(category:Int, message:String):Void {
        SDL.logVerbose(category, message);
    }

    public function logDebug(category:Int, message:String):Void {
        SDL.logDebug(category, message);
    }

    public function logInfo(category:Int, message:String):Void {
        SDL.logInfo(category, message);
    }

    public function logWarn(category:Int, message:String):Void {
        SDL.logWarn(category, message);
    }

    public function logError(category:Int, message:String):Void {
        SDL.logError(category, message);
    }

    public function logCritical(category:Int, message:String):Void {
        SDL.logCritical(category, message);
    }

    public function getLogPriority(category:Int):Int {
        return SDL.getLogPriority(category);
    }

    public function setLogPriority(category:Int, priority:SDL_LogPriority):Void {
        SDL.setLogPriority(category, priority);
    }

    public function resetLogPriorities():Void {
        SDL.resetLogPriorities();
    }

    public function getLastSDLError():String {
        return SDL.getError();
    }

    // Getters and setters
    public function get_window():Window {
        return __window;
    }
    
    private function get_active():Bool {
        return __active;
    }

	private function get_vsync():Int {
        var interval:Int = 0;
        SDL.getSwapInterval(cpp.Pointer.addressOf(interval));
		return interval;
	}

    private function set_vsync(value:Int):Int {
        SDL.setSwapInterval(value);
		return value;
    }
}
