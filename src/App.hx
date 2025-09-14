package;

import SDL;
import GL;
import Renderer;
import State;
import Log;
import Input;
import Resources;
import data.Resource;
import states.TilemapTestState;
import states.TilemapFastTestState;
import states.LogTestState;
import sys.FileSystem;
import cpp.UInt64;
import cpp.Pointer;
import cpp.NativeString;
import data.TextureData;
import loaders.TGALoader;
import haxe.ds.Vector;

class App {

    // Window dimensions - change these to adjust window size
    public static inline var WINDOW_WIDTH:Int = 640;
    public static inline var WINDOW_HEIGHT:Int = 480;

    // Publics
    public var active(get, null):Bool;
    public var resources(get, null):Resources;
    public var renderer(get, null):Renderer;
    public var log(get, null):Log;
    public var input(get, null):Input;

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
    
    public function new() {
        // Constructor - initialize basic properties
        __log = new Log(this);
        __resources = new Resources(this);
        __input = new Input(this);
    }
    
    public function init():Bool {
        // Configure logging: disable all categories except ENGINE for cleaner output
        __log.disableCategory(21); // CATEGORY_RENDERER
        __log.disableCategory(22); // CATEGORY_RESOURCES
        __log.disableCategory(23); // CATEGORY_TILEMAP
        __log.disableCategory(24); // CATEGORY_PERFORMANCE
        __log.disableCategory(25); // CATEGORY_STATE
        __log.disableCategory(26); // CATEGORY_EVENTS
        
        // Enable INPUT category to see gamepad events
        __log.enableCategory(Log.CATEGORY_INPUT);
        
        __log.engineInfo("Initializing application...");
        
        // Debug: Print SDL gamepad event constants
        __log.info(Log.CATEGORY_INPUT, "SDL Constants - GAMEPAD_BUTTON_DOWN: " + SDL.EVENT_GAMEPAD_BUTTON_DOWN);
        __log.info(Log.CATEGORY_INPUT, "SDL Constants - GAMEPAD_BUTTON_UP: " + SDL.EVENT_GAMEPAD_BUTTON_UP);
        __log.info(Log.CATEGORY_INPUT, "SDL Constants - GAMEPAD_ADDED: " + SDL.EVENT_GAMEPAD_ADDED);
        __log.info(Log.CATEGORY_INPUT, "SDL Constants - GAMEPAD_REMOVED: " + SDL.EVENT_GAMEPAD_REMOVED);
        __log.info(Log.CATEGORY_INPUT, "SDL Constants - GAMEPAD_AXIS_MOTION: " + SDL.EVENT_GAMEPAD_AXIS_MOTION);
        
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
        __window = SDL.createWindow("Clean SDL Engine", WINDOW_WIDTH, WINDOW_HEIGHT, SDL.WINDOW_OPENGL);
        if (__window == null) {
            __log.engineError("Failed to create window: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        __log.engineInfo("Window created successfully");
        
        // Create OpenGL context
        __context = SDL.createContext(__window);
        if (__context == null) {
            __log.engineError("Failed to create OpenGL context: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        SDL.makeCurrent(__window, __context);
        
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
        
        // Create renderer
        __log.engineInfo("About to create renderer...");
        __renderer = new Renderer(this, WINDOW_WIDTH, WINDOW_HEIGHT);
        __log.engineInfo("Renderer created successfully!");
        
        // Initialize input system
        __log.engineInfo("Initializing input system...");
        __input.init();
        
        // Preload assets from preload.txt BEFORE creating states
        __log.engineInfo("Preloading assets...");
        resources.loadText("preload.txt")
            .then(function(source:String) {
                var files:Array<Promise<Dynamic>> = new Array<Promise<Dynamic>>();
                var lines:Array<String> = source.split("\n");
                var regex:EReg = ~/[^\s]+/;

                for (line in lines) {
                    // Skip empty lines and comments
                    line = StringTools.trim(line);
                    if (line.length == 0 || line.charAt(0) == "#") {
                        continue;
                    }
                    
                    if (regex.match(line)) {
                        var path:String = regex.matched(0);
                        var ext = haxe.io.Path.extension(path);
                        switch (ext) {
                            case "tga": {
                                files.push(__resources.loadTexture(path));
                            }
                            case "vert" | "frag": {
                                files.push(__resources.loadText(path));
                            }
                            default: {
                                //files.push(__resources.loadText(path));
                                throw 'Unsupported resource type: ' + ext + ' for file: ' + path;
                            }
                        }
                    }
                }
                
                // Wait for all assets to load
                Promise.all(files)
                    .then(function(results:Array<Dynamic>) {
                        __log.engineInfo("Successfully preloaded " + results.length + " assets");
                        
                        // Add both states but start with the TilemapFast state for visual demo
                        __log.engineInfo("Setting up states...");
                        var logTestState = new states.LogTestState(this);
                        addState(logTestState);
                        
                        // Add and activate TilemapFastTestState for immediate visual feedback
                        var tilemapFastState = new states.TilemapFastTestState(this);
                        addState(tilemapFastState);
                        
                        // Activate the TilemapFastTestState to start rendering
                        switchToState(tilemapFastState);
                        
                        __log.engineInfo("TilemapFastTestState is now active - should see tilemap rendering");
                    })
                    .onError(function(error:String) {
                        __log.engineError("Failed to preload some assets: " + error);
                    });
            })
            .onError(function(error:String) {
                __log.engineError("Failed to load preload.txt: " + error);
            });
        
        __log.engineInfo("Application initialized successfully!");
        return true;
    }
    
    public function run():Void {
        if (__renderer == null) {
            __log.engineError("Error: Application not initialized! Call init() first.");
            return;
        }
        
        __log.engineInfo("Starting main loop... (Close the window to exit)");

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
            SDL.swapWindow(__window);
        }
        
        __log.engineInfo("Main loop ended");
    }
    
    private function handleEvents():Void {
        // Poll SDL events
        var event = SDL.getEvent();
        while (SDL.pollEvent(event)) {
            // Debug: Log all event types
            if (event.value.type != SDL.EVENT_MOUSE_MOTION) { // Skip mouse motion to reduce spam
                __log.info(Log.CATEGORY_INPUT, "DEBUG: Event type: " + event.value.type);
            }
            
            if (event.value.type == SDL.EVENT_QUIT) {
                __log.engineInfo("Quit event received");
                __active = false;
            } else if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                __log.engineInfo("Window close requested");
                __active = false;
            }
            
            // Gamepad/Controller Events
            else if (event.value.type == SDL.EVENT_GAMEPAD_ADDED) {
                __input.onGamepadConnected();
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_REMOVED) {
                __input.onGamepadDisconnected();
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_BUTTON_DOWN) {
                __log.info(Log.CATEGORY_INPUT, "DEBUG: Gamepad button down event received!");
                __input.onGamepadButtonPressed(event);
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_BUTTON_UP) {
                __log.info(Log.CATEGORY_INPUT, "DEBUG: Gamepad button up event received!");
                __input.onGamepadButtonReleased(event);
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_AXIS_MOTION) {
                __input.onGamepadAxisMotion(event);
            }
            
            // Keyboard Events
            else if (event.value.type == SDL.EVENT_KEY_DOWN) {
                __input.onKeyPressed(event);
            }
            else if (event.value.type == SDL.EVENT_KEY_UP) {
                __input.onKeyReleased(event);
            }
            
            // Mouse Events
            else if (event.value.type == SDL.EVENT_MOUSE_BUTTON_DOWN) {
                __input.onMouseButtonPressed(event);
            }
            else if (event.value.type == SDL.EVENT_MOUSE_BUTTON_UP) {
                __input.onMouseButtonReleased(event);
            }
            else if (event.value.type == SDL.EVENT_MOUSE_MOTION) {
                __input.onMouseMotion(event);
            }
            else if (event.value.type == SDL.EVENT_MOUSE_WHEEL) {
                __input.onMouseWheel(event);
            }
        }
    }
    
    private function update():Void {
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
        // Clear screen using renderer pipeline
        __renderer.clearScreen();
        __renderer.initializeRenderState();
        
        // Render current state if one is active
        if (currentState != null && currentState.active) {
            currentState.render(__renderer);
        }
        
        // Note: Buffer swap is handled in the main loop
    }

    // ===== STATE MANAGEMENT METHODS =====

    /**
     * Add a state to the states array
     */
    public function addState(state:State):State {
        if (state == null) {
            __log.engineWarn("Warning: Attempted to add null state");
            return null;
        }
        
        states.push(state);
        __log.engineInfo("Added state '" + state.name + "' to app (total states: " + states.length + ")");
        
        // If no current state, make this the current one
        if (currentState == null) {
            switchToState(state);
        }
        
        return state;
    }
    
    /**
     * Remove a state from the states array
     */
    public function removeState(state:State):Bool {
        if (state == null) return false;
        
        var removed = states.remove(state);
        if (removed) {
            __log.engineInfo("Removed state '" + state.name + "' from app");
            
            // If this was the current state, deactivate it
            if (currentState == state) {
                currentState.onDeactivate();
                currentState = null;
                
                // Switch to first available state if any
                if (states.length > 0) {
                    switchToState(states[0]);
                }
            }
            
            // Clean up the state
            state.clearEntities(__renderer);
        }
        
        return removed;
    }
    
    /**
     * Remove state by name
     */
    public function removeStateByName(name:String):Bool {
        for (state in states) {
            if (state.name == name) {
                return removeState(state);
            }
        }
        return false;
    }
    
    /**
     * Switch to a specific state
     */
    public function switchToState(state:State):Bool {
        if (state == null) {
            trace("Warning: Attempted to switch to null state");
            return false;
        }
        
        // Check if state exists in our states array
        var stateExists = false;
        for (s in states) {
            if (s == state) {
                stateExists = true;
                break;
            }
        }
        
        if (!stateExists) {
            __log.engineWarn("Warning: Attempted to switch to state '" + state.name + "' that is not in states array");
            return false;
        }
        
        // Deactivate current state
        if (currentState != null) {
            currentState.onDeactivate();
        }
        
        // Switch to new state
        currentState = state;
        currentState.onActivate();
        
        __log.engineInfo("Switched to state '" + state.name + "'");
        return true;
    }
    
    /**
     * Switch to state by name
     */
    public function switchToStateByName(name:String):Bool {
        for (state in states) {
            if (state.name == name) {
                return switchToState(state);
            }
        }
        __log.engineWarn("Warning: State '" + name + "' not found");
        return false;
    }
    
    /**
     * Get state by name
     */
    public function getState(name:String):State {
        for (state in states) {
            if (state.name == name) {
                return state;
            }
        }
        return null;
    }
    
    /**
     * Get debug info about all states
     */
    public function getStatesDebugInfo():String {
        var info = "=== STATES DEBUG INFO ===\n";
        info += "Total states: " + states.length + "\n";
        info += "Current state: " + (currentState != null ? currentState.name : "none") + "\n";
        
        for (i in 0...states.length) {
            var state = states[i];
            var current = (state == currentState) ? " [CURRENT]" : "";
            info += "  " + i + ": " + state.getDebugInfo() + current + "\n";
        }
        
        return info;
    }
    
    public function cleanup():Void {
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
        
        // Cleanup resources first
        if (__resources != null) {
            __resources.cleanup();
            __resources = null;
        }
        
        // Cleanup input system
        if (__input != null) {
            __input.cleanup();
            __input = null;
        }
        
        if (__renderer != null) {
            __renderer.cleanup();
            __renderer = null;
        }
        
        __log.engineInfo("Application cleanup complete");
        
        // Quit gamepad subsystem before main SDL quit
        if (SDL.wasInit(SDL.INIT_GAMEPAD) != 0) {
            SDL.quitSubSystem(SDL.INIT_GAMEPAD);
            __log.engineInfo("SDL gamepad subsystem shut down");
        }
        
        SDL.quit();
        
        // Cleanup log system last
        if (__log != null) {
            __log.cleanup();
            __log = null;
        }
    }
    
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
}
