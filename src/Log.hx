import SDL;

private class __Log {
    private var __parent:AppNative;
    private var __enabledCategories:Map<Int, Bool> = new Map<Int, Bool>();
    
    // SDL Log Categories (using integers directly since they're not in SDL3 bindings)
    public static inline var CATEGORY_APPLICATION:Int = 0;
    public static inline var CATEGORY_ERROR:Int = 1;
    public static inline var CATEGORY_ASSERT:Int = 2;
    public static inline var CATEGORY_SYSTEM:Int = 3;
    public static inline var CATEGORY_AUDIO:Int = 4;
    public static inline var CATEGORY_VIDEO:Int = 5;
    public static inline var CATEGORY_RENDER:Int = 6;
    public static inline var CATEGORY_INPUT:Int = 7;
    public static inline var CATEGORY_TEST:Int = 8;
    
    // Custom engine categories
    public static inline var CATEGORY_ENGINE:Int = 100;
    public static inline var CATEGORY_RENDERER:Int = 101;
    public static inline var CATEGORY_RESOURCES:Int = 102;
    public static inline var CATEGORY_TILEMAP:Int = 103;
    public static inline var CATEGORY_PERFORMANCE:Int = 104;
    public static inline var CATEGORY_STATE:Int = 105;
    public static inline var CATEGORY_EVENTS:Int = 106;
    
    public function new(app:AppNative) {
        this.__parent = app;
    }
    
    // === INITIALIZATION & CONFIGURATION ===
    
    public function init():Void {
        // Set up basic logging
        SDL.setLogOutputFunction(null, null);
        
        // Enable common categories
        enableCategory(CATEGORY_APPLICATION);
        enableCategory(CATEGORY_ERROR);
        enableCategory(CATEGORY_ENGINE);
        enableCategory(CATEGORY_RENDERER);
        enableCategory(CATEGORY_SYSTEM);
        enableCategory(CATEGORY_INPUT);
        enableCategory(CATEGORY_EVENTS);
        
        info(CATEGORY_ENGINE, "Log system initialized");
    }
    
    public function enableCategory(category:Int, enabled:Bool = true):Void {
        __enabledCategories.set(category, enabled);
        if (enabled) {
            // Ensure the category has at least info level when enabled
            var currentPriority = SDL.getLogPriority(category);
            if (currentPriority > cast(SDL.LOG_PRIORITY_INFO, Int)) {
                SDL.setLogPriority(category, SDL.LOG_PRIORITY_INFO);
            }
        }
    }
    
    public function disableCategory(category:Int):Void {
        enableCategory(category, false);
    }
    
    public function isCategoryEnabled(category:Int):Bool {
        return __enabledCategories.exists(category) && __enabledCategories.get(category) == true;
    }
    
    // === LOGGING METHODS ===
    
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
            case __Log.CATEGORY_APPLICATION: return "APP";
            case __Log.CATEGORY_ERROR: return "ERROR";
            case __Log.CATEGORY_ASSERT: return "ASSERT";
            case __Log.CATEGORY_SYSTEM: return "SYSTEM";
            case __Log.CATEGORY_AUDIO: return "AUDIO";
            case __Log.CATEGORY_VIDEO: return "VIDEO";
            case __Log.CATEGORY_RENDER: return "RENDER";
            case __Log.CATEGORY_INPUT: return "INPUT";
            case __Log.CATEGORY_TEST: return "TEST";
            case __Log.CATEGORY_ENGINE: return "ENGINE";
            case __Log.CATEGORY_RENDERER: return "RENDERER";
            case __Log.CATEGORY_RESOURCES: return "RESOURCES";
            case __Log.CATEGORY_TILEMAP: return "TILEMAP";
            case __Log.CATEGORY_PERFORMANCE: return "PERF";
            case __Log.CATEGORY_STATE: return "STATE";
            case __Log.CATEGORY_EVENTS: return "EVENTS";
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

typedef Log = __Log;