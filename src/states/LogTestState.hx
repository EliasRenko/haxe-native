package states;

import State;
import App;

class LogTestState extends State {
    
    private var frameCount:Int = 0;
    
    public function new(app:App) {
        super("LogTestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        
        trace("=== Log System Test Starting ===");
        
        // Test different log priorities and categories
        app.log.setGlobalLogLevel(1); // DEBUG level
        
        // Enable specific categories (using numeric values)
        app.log.enableCategory(0); // APPLICATION
        app.log.enableCategory(3); // SYSTEM  
        app.log.enableCategory(6); // RENDER
        
        // Test logging at different levels with engine categories
        app.log.verbose(Log.CATEGORY_ENGINE, "This is a verbose message - very detailed");
        app.log.debug(Log.CATEGORY_ENGINE, "This is a debug message - development info");
        app.log.info(Log.CATEGORY_ENGINE, "This is an info message - general information");
        app.log.warn(Log.CATEGORY_ENGINE, "This is a warning message - something might be wrong");
        app.log.error(Log.CATEGORY_ENGINE, "This is an error message - something went wrong");
        app.log.critical(Log.CATEGORY_ENGINE, "This is a critical message - system failure!");
        
        // Test with different categories
        app.log.info(Log.CATEGORY_RENDERER, "Renderer initialized successfully");
        app.log.debug(Log.CATEGORY_PERFORMANCE, "Performance test starting");
        app.log.warn(Log.CATEGORY_TILEMAP, "Tilemap optimization active");
        
        // Change global level and test filtering
        trace("Setting global log level to WARN - debug/info messages should be filtered out");
        app.log.setGlobalLogLevel(4); // WARN level
        
        // These should be filtered out
        app.log.debug(Log.CATEGORY_ENGINE, "This debug message should be filtered out by global level");
        app.log.warn(Log.CATEGORY_ENGINE, "This warning should still appear");
        
        // Test category disable/enable
        trace("Disabling ENGINE category - messages should stop");
        app.log.disableCategory(Log.CATEGORY_ENGINE);
        app.log.error(Log.CATEGORY_ENGINE, "This error should be filtered out by category disable");
        app.log.error(Log.CATEGORY_RENDERER, "But this renderer error should still show");
        
        // Re-enable for demo switching
        app.log.enableCategory(Log.CATEGORY_ENGINE);
        app.log.info(Log.CATEGORY_ENGINE, "Logging test completed - will auto-switch to TilemapFast demo");
        
        trace("=== Log System Test Complete ===");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        frameCount++;
        
        // Auto-switch to TilemapFast test after a few seconds
        if (frameCount > 300) { // ~5 seconds at 60fps
            trace("Auto-switching to TilemapFast test state");
            app.switchToStateByName("TilemapFastTestState");
        }
    }
    
    override public function render(renderer:Dynamic):Void {
        super.render(renderer);
        // This state is just for logging demonstration - no visual rendering needed
    }
}
