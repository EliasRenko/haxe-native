package;

import SDL;
import GL;
import Renderer;
import State;
import states.TilemapTestState;
import sys.FileSystem;
import cpp.UInt64;
import cpp.Pointer;
import cpp.NativeString;
import data.TextureData;
import loaders.TGALoader;

typedef Resources = __Resources;

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
    
    public function new() {
        // Constructor - initialize basic properties
        __resources = new __Resources(this);
    }
    
    public function init():Bool {
        trace("Initializing application...");
        
        // Initialize SDL video
        if (!SDL.init(SDL.INIT_VIDEO)) {
            trace("Failed to initialize SDL: " + SDL.getError());
            return false;
        }
        
        // Set OpenGL attributes (3.3 Core)
        SDL.setAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_PROFILE_MASK, SDL.GL_CONTEXT_PROFILE_CORE);
        
        // Create window
        __window = SDL.createWindow("Clean SDL Engine", WINDOW_WIDTH, WINDOW_HEIGHT, SDL.WINDOW_OPENGL);
        if (__window == null) {
            trace("Failed to create window: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        trace("Window created successfully");
        
        // Create OpenGL context
        __context = SDL.createContext(__window);
        if (__context == null) {
            trace("Failed to create OpenGL context: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        SDL.makeCurrent(__window, __context);
        
        // Load OpenGL functions
        var gladResult = GL.gladLoadGLLoader(SDL.getProcAddress);
        if (gladResult == 0) {
            trace("Failed to load OpenGL functions");
            SDL.quit();
            return false;
        }
        
        trace("OpenGL loaded successfully");
        trace("OpenGL Version: " + GL.version.major + "." + GL.version.minor);
        
        // Set viewport to match window size
        GL.viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
        
        // Create renderer
        trace("About to create renderer...");
        __renderer = new Renderer(this, WINDOW_WIDTH, WINDOW_HEIGHT);
        trace("Renderer created successfully!");
        
        // Preload assets from preload.txt BEFORE creating states
        trace("Preloading assets...");
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
                        trace("Successfully preloaded " + results.length + " assets");
                        
                        // NOW create and setup tilemap test state after assets are loaded
                        trace("Setting up tilemap test state with preloaded assets...");
                        var tilemapTestState = new TilemapTestState(this);
                        addState(tilemapTestState);
                        trace("Tilemap test state setup complete");
                    })
                    .onError(function(error:String) {
                        trace("Failed to preload some assets: " + error);
                    });
            })
            .onError(function(error:String) {
                trace("Failed to load preload.txt: " + error);
            });
        
        trace("Application initialized successfully!");
        return true;
    }
    
    public function run():Void {
        if (__renderer == null) {
            trace("Error: Application not initialized! Call init() first.");
            return;
        }
        
        trace("Starting main loop... (Close the window to exit)");

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
        
        trace("Main loop ended");
    }
    
    private function handleEvents():Void {
        // Poll SDL events
        var event = SDL.getEvent();
        while (SDL.pollEvent(event)) {
            if (event.value.type == SDL.EVENT_QUIT) {
                trace("Quit event received");
                __active = false;
            } else if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                trace("Window close requested");
                __active = false;
            }
            // TODO: Add more event handling (keyboard, mouse, etc.)
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
            trace("Warning: Attempted to add null state");
            return null;
        }
        
        states.push(state);
        trace("Added state '" + state.name + "' to app (total states: " + states.length + ")");
        
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
            trace("Removed state '" + state.name + "' from app");
            
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
            trace("Warning: Attempted to switch to state '" + state.name + "' that is not in states array");
            return false;
        }
        
        // Deactivate current state
        if (currentState != null) {
            currentState.onDeactivate();
        }
        
        // Switch to new state
        currentState = state;
        currentState.onActivate();
        
        trace("Switched to state '" + state.name + "'");
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
        trace("Warning: State '" + name + "' not found");
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
        trace("Cleaning up application...");
        
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
        
        SDL.quit();
        
        trace("Application cleanup complete");
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

            trace("Loaded file: " + fullPath + " with size: " + size.toInt() + " bytes");
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
                
                trace("Loaded texture: " + fullPath + " (" + textureData.width + "x" + textureData.height + ")");
                resolve(textureData);
                
            } catch (e:Dynamic) {
                reject("Failed to parse TGA file: " + e);
            }
            
            SDL.free(ptrData);
        });
    }
    
    public function cleanup():Void {
        trace("Cleaning up resources...");
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
        trace('Cleared $count cached resources');
    }
}
