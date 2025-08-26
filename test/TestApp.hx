package test;

import SDL;

/**
 * Minimal app for testing that doesn't require full OpenGL initialization
 */
class TestApp {
    
    private var window:Window;
    private var isInitialized:Bool = false;
    
    public function new() {
        // Constructor
    }
    
    public function initForTesting():Bool {
        trace("Initializing minimal test environment...");
        
        // Initialize SDL video for basic window tests
        if (!SDL.init(SDL.INIT_VIDEO)) {
            trace("Failed to initialize SDL: " + SDL.getError());
            return false;
        }
        
        trace("SDL initialized for testing");
        
        // Create a minimal window for window management tests
        // We don't need OpenGL context for basic Promise/utility tests
        window = SDL.createWindow("Engine Test Window", 400, 300, SDL.WINDOW_HIDDEN);
        if (window == null) {
            trace("Failed to create test window: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        trace("Test window created (hidden)");
        
        isInitialized = true;
        return true;
    }
    
    public function cleanup():Void {
        trace("Cleaning up test environment...");
        
        // In SDL3, windows are typically cleaned up automatically on SDL.quit()
        // or we might need a different function name
        window = null;
        
        if (isInitialized) {
            SDL.quit();
            isInitialized = false;
        }
        
        trace("Test environment cleanup complete");
    }
    
    // Getters for tests that need window access
    public function getWindow():Window {
        return window;
    }
    
    public function isReady():Bool {
        return isInitialized && window != null;
    }
}
