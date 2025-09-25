package;

import haxe.io.Bytes;

import SDL;
import GL;
import Renderer;
import State;
import Log;
import Input;
import Resources;
import cpp.UInt64;
import cpp.Pointer;

class Runtime {

    public var WINDOW_TITLE:String = "Engine";
    public var WINDOW_WIDTH:Int = 640;
    public var WINDOW_HEIGHT:Int = 480;

    // Publics
    public var active(get, null):Bool;
    public var resources(get, null):Resources;
    public var renderer(get, null):Renderer;
    public var log(get, null):Log;
    public var input(get, null):Input;
    public var vsync(get, set):Int;

    // State Management
    public var states:Array<State> = [];
    public var currentState:State = null;

    // Privates
    private var __active:Bool = false;
    private var __window:Window;
    private var __context:GLContext;
    private var __renderer:Renderer;

    // Timing variables for deltaTime calculation
    private var __lastTime:Float = 0.0;
    private var __currentTime:Float = 0.0;

    private var __input:Input;
    private var __resources:Resources;
    private var __log:Log;
    
    
    public function new() {}
    
    public function init():Bool {
        __log.engineInfo("Initializing application...");
        
        // Initialize SDL video and gamepad
        if (!SDL.init(SDL.INIT_VIDEO)) {
            __log.engineError("Failed to initialize SDL: " + SDL.getError());
            return false;
        }
        
        // Initialize gamepad subsystem
        if (!SDL.initSubSystem(SDL.INIT_GAMEPAD)) {
            __log.engineWarn("Failed to initialize SDL gamepad subsystem: " + SDL.getError());
            __log.engineInfo("Continuing without gamepad support");
        } else {
            __log.engineInfo("SDL gamepad subsystem initialized successfully");
        }
        
        // Set OpenGL attributes (3.3 Core)
        SDL.setAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_PROFILE_MASK, SDL.GL_CONTEXT_PROFILE_CORE);
        
        // Create window
        __window = new Window(SDL.createWindow(WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT, SDL.WINDOW_OPENGL));
        if (__window.ptr == null) {
            __log.engineError("Failed to create window: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        __log.engineInfo("Window created successfully");
        
        // Create OpenGL context
        __context = SDL.createContext(__window.ptr);
        if (__context == null) {
            __log.engineError("Failed to create OpenGL context: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        SDL.makeCurrent(__window.ptr, __context);
        
        // Load OpenGL functions
        var gladResult = GL.gladLoadGLLoader(SDL.getProcAddress);
        if (gladResult == 0) {
            __log.engineError("Failed to load OpenGL functions");
            SDL.quit();
            return false;
        }
        __log.engineInfo("OpenGL loaded successfully");
        __log.engineInfo("OpenGL Version: " + GL.version.major + "." + GL.version.minor);
        
        // Set viewport to match window size
        GL.viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
        
        //__renderer = new Renderer(this, WINDOW_WIDTH, WINDOW_HEIGHT);

        preload();

        return true;
    }

    public function release():Void {
        __log.engineInfo("Cleaning up application...");
        
        // Deactivate current state
        if (currentState != null) {
            currentState.onDeactivate();
        }
        
        // Clean up all states
        for (state in states) {
            state.clearEntities(__renderer);
        }
        states = [];
        currentState = null;
        
        // Release resources first
        if (__resources != null) {
            __resources.release();
            __resources = null;
        }

        // Release input system
        if (__input != null) {
            __input.release();
            __input = null;
        }
        
        if (__renderer != null) {
            __renderer.release();
            __renderer = null;
        }
        
        __log.engineInfo("Application cleanup complete");
        
        // Quit gamepad subsystem before main SDL quit
        if (SDL.wasInit(SDL.INIT_GAMEPAD) != 0) {
            SDL.quitSubSystem(SDL.INIT_GAMEPAD);
            __log.engineInfo("SDL gamepad subsystem shut down");
        }
        
        // Cleanup log system last
        if (__log != null) {
            __log.cleanup();
            __log = null;
        }

        SDL.quit();
    }

    public function preload():Void {
        // Preload assets here
    }
    
    public function run():Void {
        if (__renderer == null) {
            __log.engineError("Error: Application not initialized! Call init() first.");
            return;
        }

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
    
    private function handleEvents():Void {
        var event = SDL.getEvent();
        while (SDL.pollEvent(event)) {
            if (event.value.type == SDL.EVENT_QUIT) {
                __active = false;
            } 

            if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                __active = false;
            }
            
            __handleGamepadInputEvents(event);
            __handleKeyboardInputEvents(event);
            __handleMouseInputEvents(event);
        }
    }

    public function startTextInput(window:WindowPtr) {
        SDL.startTextInput(window);
    }
    
    public function stopTextInput(window:WindowPtr) {
        SDL.stopTextInput(window);
    }

    private function __handleGamepadInputEvents(event:Pointer<Event>):Void {
        
    }

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

    public function update():Void {
        // Use a fixed deltaTime for stable animation (60 FPS target)
        var deltaTime:Float = 1.0 / 60.0; // 0.0167 seconds per frame
        
        // Update input system
        if (__input != null) {
            __input.update();
        }
        
        // Update current state if one is active
        if (currentState != null && currentState.active) {
            currentState.update(deltaTime);
        }
        
        // Post-update input (clear pressed/released states)
        if (__input != null) {
            __input.postUpdate();
        }
    }
    
    private function render():Void {
        __renderer.clearScreen();
        __renderer.initializeRenderState();
        
        if (currentState != null && currentState.active) {
            currentState.render(__renderer);
        }
    }

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

    public function getLastSDLError():String {
        return SDL.getError();
    }

    // Getters and setters
    public function getRenderer():Renderer {
        return __renderer;
    }
    
    public function getWindow():Dynamic {
        return __window;
    }
    
    private function get_active():Bool {
        return __active;
    }
    
    private function get_renderer():Renderer {
        return __renderer;
    }
    
    private function get_resources():Resources {
        return __resources;
    }
    
    private function get_log():Log {
        return __log;
    }
    
    private function get_input():Input {
        return __input;
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
