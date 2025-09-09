package;

import SDL;
import GL;
import Renderer;
import State;
import states.TilemapTestState;
import states.TilemapFastTestState;
import states.LogTestState;
import sys.FileSystem;
import cpp.UInt64;
import cpp.Pointer;
import cpp.NativeString;
import data.TextureData;
import loaders.TGALoader;

typedef Resources = __Resources;
typedef Log = __Log;

typedef Resource = {
    var type:String;
    var data:Dynamic;
    var size:Int;
}

class App {

    // Window dimensions - change these to adjust window size
    public static inline var WINDOW_WIDTH:Int = 640;
    public static inline var WINDOW_HEIGHT:Int = 480;

    // Publics
    public var active(get, null):Bool;
    public var resources(get, null):Resources;
    public var renderer(get, null):Renderer;
    public var log(get, null):Log;

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

    private var __resources:__Resources;
    private var __log:__Log;
    
    public function new() {
        // Constructor - initialize basic properties
        __log = new __Log(this);
        __resources = new __Resources(this);
    }
    
    public function init():Bool {
        // Configure logging: disable all categories except ENGINE for cleaner output
        __log.disableCategory(21); // CATEGORY_RENDERER
        __log.disableCategory(22); // CATEGORY_RESOURCES
        __log.disableCategory(23); // CATEGORY_TILEMAP
        __log.disableCategory(24); // CATEGORY_PERFORMANCE
        __log.disableCategory(25); // CATEGORY_STATE
        __log.disableCategory(26); // CATEGORY_EVENTS
        
        __log.engineInfo("Initializing application...");
        
        // Initialize SDL video
        if (!SDL.init(SDL.INIT_VIDEO)) {
            __log.engineError("Failed to initialize SDL: " + SDL.getError());
            return false;
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
            if (event.value.type == SDL.EVENT_QUIT) {
                __log.engineInfo("Quit event received");
                __active = false;
            } else if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                __log.engineInfo("Window close requested");
                __active = false;
            }
            
            // Gamepad/Controller Events
            else if (event.value.type == SDL.EVENT_GAMEPAD_ADDED) {
                // trace("Gamepad connected"); // Disabled - EVENTS category
                // TODO: Open gamepad and store reference
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_REMOVED) {
                // trace("Gamepad disconnected"); // Disabled - EVENTS category
                // TODO: Close gamepad and clean up reference
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_BUTTON_DOWN) {
                // trace("Gamepad button pressed"); // Disabled - EVENTS category
                // TODO: Access button data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_BUTTON_UP) {
                // trace("Gamepad button released"); // Disabled - EVENTS category
                // TODO: Access button data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_GAMEPAD_AXIS_MOTION) {
                // trace("Gamepad axis motion"); // Disabled - EVENTS category
                // TODO: Access axis data when SDL bindings are complete
            }
            
            // Keyboard Events
            else if (event.value.type == SDL.EVENT_KEY_DOWN) {
                // trace("Key pressed"); // Disabled - EVENTS category
                // TODO: Access key data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_KEY_UP) {
                // trace("Key released"); // Disabled - EVENTS category
                // TODO: Access key data when SDL bindings are complete
            }
            
            // Mouse Events
            else if (event.value.type == SDL.EVENT_MOUSE_BUTTON_DOWN) {
                // trace("Mouse button pressed"); // Disabled - EVENTS category
                // TODO: Access mouse data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_MOUSE_BUTTON_UP) {
                // trace("Mouse button released"); // Disabled - EVENTS category
                // TODO: Access mouse data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_MOUSE_MOTION) {
                // Only log significant movement to avoid spam
                // trace("Mouse motion"); // Disabled - EVENTS category
                // TODO: Access mouse data when SDL bindings are complete
            }
            else if (event.value.type == SDL.EVENT_MOUSE_WHEEL) {
                // trace("Mouse wheel"); // Disabled - EVENTS category
                // TODO: Access wheel data when SDL bindings are complete
            }
        }
    }
    
    private function update():Void {
        // Use a fixed deltaTime for stable animation (60 FPS target)
        var deltaTime:Float = 1.0 / 60.0; // 0.0167 seconds per frame
        
        // Update current state if one is active
        if (currentState != null && currentState.active) {
            currentState.update(deltaTime);
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
        
        if (__renderer != null) {
            __renderer.cleanup();
            __renderer = null;
        }
        
        __log.engineInfo("Application cleanup complete");
        
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
}

private class __Log {
    // Log categories - SDL3 standard categories
    public static inline var CATEGORY_APPLICATION:Int = 0;
    public static inline var CATEGORY_ERROR:Int = 1;
    public static inline var CATEGORY_ASSERT:Int = 2;
    public static inline var CATEGORY_SYSTEM:Int = 3;
    public static inline var CATEGORY_AUDIO:Int = 4;
    public static inline var CATEGORY_VIDEO:Int = 5;
    public static inline var CATEGORY_RENDER:Int = 6;
    public static inline var CATEGORY_INPUT:Int = 7;
    public static inline var CATEGORY_TEST:Int = 8;
    public static inline var CATEGORY_CUSTOM:Int = 19; // First available custom category
    
    // Engine-specific categories
    public static inline var CATEGORY_ENGINE:Int = 20;
    public static inline var CATEGORY_RENDERER:Int = 21;
    public static inline var CATEGORY_RESOURCES:Int = 22;
    public static inline var CATEGORY_TILEMAP:Int = 23;
    public static inline var CATEGORY_PERFORMANCE:Int = 24;
    public static inline var CATEGORY_STATE:Int = 25;
    public static inline var CATEGORY_EVENTS:Int = 26;
    
    // Log level flags for enabling/disabling categories
    private var __enabledCategories:Map<Int, Bool> = new Map<Int, Bool>();
    private var __globalLogLevel:Int;
    private var __parent:App;
    
    public function new(app:App) {
        this.__parent = app;
        
        // Initialize SDL logging system
        SDL.resetLogPriorities();
        
        // Set default global log level to INFO (shows INFO, WARN, ERROR, CRITICAL)
        __globalLogLevel = 3; // INFO level
        
        // Enable all engine categories by default
        enableCategory(CATEGORY_ENGINE);
        enableCategory(CATEGORY_RENDERER);
        enableCategory(CATEGORY_RESOURCES);
        enableCategory(CATEGORY_TILEMAP);
        enableCategory(CATEGORY_PERFORMANCE);
        enableCategory(CATEGORY_STATE);
        enableCategory(CATEGORY_EVENTS);
        
        // Enable SDL system categories at WARN level and above
        SDL.setLogPriority(CATEGORY_APPLICATION, SDL.LOG_PRIORITY_WARN);
        SDL.setLogPriority(CATEGORY_ERROR, SDL.LOG_PRIORITY_ERROR);
        SDL.setLogPriority(CATEGORY_SYSTEM, SDL.LOG_PRIORITY_WARN);
        SDL.setLogPriority(CATEGORY_AUDIO, SDL.LOG_PRIORITY_WARN);
        SDL.setLogPriority(CATEGORY_VIDEO, SDL.LOG_PRIORITY_WARN);
        SDL.setLogPriority(CATEGORY_RENDER, SDL.LOG_PRIORITY_WARN);
        SDL.setLogPriority(CATEGORY_INPUT, SDL.LOG_PRIORITY_WARN);
        
        // Log system initialization
        info(CATEGORY_ENGINE, "Log system initialized");
    }
    
    // === CONFIGURATION METHODS ===
    
    public function setGlobalLogLevel(priority:Int):Void {
        __globalLogLevel = priority;
        info(CATEGORY_ENGINE, "Global log level set to " + priority);
    }
    
    public function setCategoryLevel(category:Int, priority:Int):Void {
        info(CATEGORY_ENGINE, "Category " + getCategoryName(category) + " level set to " + priority);
    }
    
    public function enableCategory(category:Int):Void {
        __enabledCategories.set(category, true);
        SDL.setLogPriority(category, SDL.LOG_PRIORITY_VERBOSE); // Enable all levels for this category
    }
    
    public function disableCategory(category:Int):Void {
        __enabledCategories.set(category, false);
        // Disable by setting to maximum priority level (only critical messages pass)
        SDL.setLogPriority(category, SDL.LOG_PRIORITY_CRITICAL);
    }
    
    public function isCategoryEnabled(category:Int):Bool {
        return __enabledCategories.exists(category) && __enabledCategories.get(category);
    }
    
    // === LOGGING METHODS ===
    
    public function trace(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logTrace(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function verbose(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logVerbose(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function debug(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logDebug(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function info(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logInfo(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function warn(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logWarn(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function error(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logError(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    public function critical(category:Int, message:String):Void {
        if (isCategoryEnabled(category)) {
            SDL.logCritical(category, "[" + getCategoryName(category) + "] " + message);
        }
    }
    
    // Convenience methods for common categories
    public function engineInfo(message:String):Void { info(CATEGORY_ENGINE, message); }
    public function engineWarn(message:String):Void { warn(CATEGORY_ENGINE, message); }
    public function engineError(message:String):Void { error(CATEGORY_ENGINE, message); }
    
    public function rendererInfo(message:String):Void { info(CATEGORY_RENDERER, message); }
    public function rendererDebug(message:String):Void { debug(CATEGORY_RENDERER, message); }
    public function rendererWarn(message:String):Void { warn(CATEGORY_RENDERER, message); }
    
    public function tilemapInfo(message:String):Void { info(CATEGORY_TILEMAP, message); }
    public function tilemapDebug(message:String):Void { debug(CATEGORY_TILEMAP, message); }
    public function tilemapPerf(message:String):Void { info(CATEGORY_PERFORMANCE, message); }
    
    public function stateInfo(message:String):Void { info(CATEGORY_STATE, message); }
    public function eventInfo(message:String):Void { info(CATEGORY_EVENTS, message); }
    
    // === UTILITY METHODS ===
    
    private function getCategoryName(category:Int):String {
        switch (category) {
            case CATEGORY_APPLICATION: return "APP";
            case CATEGORY_ERROR: return "ERROR";
            case CATEGORY_ASSERT: return "ASSERT";
            case CATEGORY_SYSTEM: return "SYSTEM";
            case CATEGORY_AUDIO: return "AUDIO";
            case CATEGORY_VIDEO: return "VIDEO";
            case CATEGORY_RENDER: return "RENDER";
            case CATEGORY_INPUT: return "INPUT";
            case CATEGORY_TEST: return "TEST";
            case CATEGORY_ENGINE: return "ENGINE";
            case CATEGORY_RENDERER: return "RENDERER";
            case CATEGORY_RESOURCES: return "RESOURCES";
            case CATEGORY_TILEMAP: return "TILEMAP";
            case CATEGORY_PERFORMANCE: return "PERF";
            case CATEGORY_STATE: return "STATE";
            case CATEGORY_EVENTS: return "EVENTS";
            default: return "CUSTOM" + category;
        }
    }
    
    private function getPriorityName(priority:SDL_LogPriority):String {
        if (priority == SDL.LOG_PRIORITY_TRACE) return "TRACE";
        if (priority == SDL.LOG_PRIORITY_VERBOSE) return "VERBOSE";
        if (priority == SDL.LOG_PRIORITY_DEBUG) return "DEBUG";
        if (priority == SDL.LOG_PRIORITY_INFO) return "INFO";
        if (priority == SDL.LOG_PRIORITY_WARN) return "WARN";
        if (priority == SDL.LOG_PRIORITY_ERROR) return "ERROR";
        if (priority == SDL.LOG_PRIORITY_CRITICAL) return "CRITICAL";
        return "UNKNOWN";
    }
    
    public function getDebugInfo():String {
        var info = "=== LOG SYSTEM DEBUG INFO ===\n";
        info += "Global log level: set\n";
        info += "Enabled categories:\n";
        
        for (category in __enabledCategories.keys()) {
            if (__enabledCategories.get(category)) {
                var currentLevel = SDL.getLogPriority(category);
                info += "  " + getCategoryName(category) + " (level: " + currentLevel + ")\n";
            }
        }
        
        return info;
    }
    
    public function cleanup():Void {
        info(CATEGORY_ENGINE, "Log system shutting down");
        __enabledCategories.clear();
        SDL.resetLogPriorities();
    }
}

private class __Resources {
    // Privates
    private var __resources:Map<String, Resource> = new Map<String, Resource>();
    private var __parent:App;
    private var __resourceFolder:String;

    public function new(app:App, resourceFolder:String = "res") {
        this.__parent = app;
        this.__resourceFolder = resourceFolder;
    }

    public function cached(name:String):Bool {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            return true;
        }
        return false;
    }

    public function exists(path:String):Bool {
        var fullPath = __resourceFolder + "/" + path;
        try {
            return FileSystem.exists(fullPath);
        } catch (e:Dynamic) {
            return false;
        }
    }

    public function getText(name:String):String {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            var _resource:Resource = __resources.get(fullPath);
            if (_resource == null) {
                return null;
            }
            return cast(_resource.data, String);
        }
        return null;
    }

    public function getTexture(name:String):TextureData {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            var _resource:Resource = __resources.get(fullPath);
            if (_resource == null || _resource.type != 'texture') {
                return null;
            }
            return cast(_resource.data, TextureData);
        }
        return null;
    }

    public function loadText(path:String, cache:Bool = true):Promise<String> {
        var fullPath = __resourceFolder + "/" + path;
        return new Promise<String>((resolve, reject) -> {

            var size:UInt64 = 0; // Size in bytes
            var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
            var ptrData = SDL.loadFile(fullPath, ptrSize.ptr);
            if (ptrData == null) {
                reject("Failed to open file: " + fullPath);
            }

            var data:String = NativeString.fromPointer(ptrData);
            if (cache) __resources.set(fullPath, {type: 'text', data: data, size: size.toInt()});
            resolve(data);

            // trace("Loaded file: " + fullPath + " with size: " + size.toInt() + " bytes"); // Disabled - RESOURCES category
            SDL.free(ptrData);
        });
    }

    public function loadShader(vertexPath:String, fragmentPath:String, cache:Bool = true):Promise<{vertex:String, fragment:String}> {
        return new Promise<{vertex:String, fragment:String}>((resolve, reject) -> {
            var vertexPromise = loadText(vertexPath, cache);
            var fragmentPromise = loadText(fragmentPath, cache);
            
            Promise.all([vertexPromise, fragmentPromise])
                .then(function(results:Array<String>) {
                    resolve({
                        vertex: results[0],
                        fragment: results[1]
                    });
                })
                .onError(function(error:String) {
                    reject(error);
                });
        });
    }

    public function loadTexture(path:String, cache:Bool = true):Promise<TextureData> {
        var fullPath = __resourceFolder + "/" + path;
        return new Promise<TextureData>((resolve, reject) -> {
            
            var size:UInt64 = 0;
            var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
            var ptrData = SDL.loadFile(fullPath, ptrSize.ptr);
            if (ptrData == null) {
                reject("Failed to open texture file: " + fullPath);
                return;
            }

            try {
                // Convert raw data to Haxe Bytes
                var bytes = haxe.io.Bytes.alloc(size.toInt());
                for (i in 0...size.toInt()) {
                    bytes.set(i, ptrData[i]);
                }
                
                // Parse TGA
                var textureData = TGALoader.loadFromBytes(bytes);
                
                if (cache) {
                    __resources.set(fullPath, {type: 'texture', data: textureData, size: size.toInt()});
                }
                
                // trace("Loaded texture: " + fullPath + " (" + textureData.width + "x" + textureData.height + ")"); // Disabled - RESOURCES category
                resolve(textureData);
                
            } catch (e:Dynamic) {
                reject("Failed to parse TGA file: " + e);
            }
            
            SDL.free(ptrData);
        });
    }
    
    public function cleanup():Void {
        // trace("Cleaning up resources..."); // Disabled - RESOURCES category
        var count = 0;
        for (key in __resources.keys()) {
            var resource = __resources.get(key);
            if (resource != null) {
                count++;
                // Dispose texture data if it's a texture
                if (resource.type == 'texture') {
                    var textureData:TextureData = cast(resource.data, TextureData);
                    if (textureData != null) {
                        textureData.dispose();
                    }
                }
                // For text resources, data is just a String reference, no special cleanup needed
                // Future: Add specific cleanup for other resource types
            }
        }
        __resources.clear();
        // trace('Cleared $count cached resources'); // Disabled - RESOURCES category
    }
}
