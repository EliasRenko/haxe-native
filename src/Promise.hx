package;

import haxe.Timer;

class Promise<T> {

    // Public properties
    public var isComplete(get, null):Bool;
    public var state(get, null):PromiseState;
    public var result(get, null):T;
    public var error(get, null):String;
    public var time(get, null):Float;

    // Private properties
    private var __completeListeners:EventDispacher<T>;
    private var __errorListeners:EventDispacher<String>;
    
    private var __state:PromiseState = ON_QUEUE;
    private var __result:T;
    private var __error:String;
    private var __time:Float = 0;
    private var __funcToRun:((T)->Void, (String)->Void)->Void;

    public function new(func:((T)->Void, (String)->Void)->Void, shouldRun:Bool = true) {
        __funcToRun = func;

        if (shouldRun) {
            run();
        }
    }

    // static methods
    public static function resolve<U>(value:U):Promise<U> {
        return new Promise<U>(function(resolve, reject) {
            resolve(value);
        });
    }

    public static function reject<U>(error:String):Promise<U> {
        return new Promise<U>(function(resolve, reject) {
            reject(error);
        });
    }

    public static function all<U>(promises:Array<Promise<U>>):Promise<Array<U>> {
        var count:Int = 0;
        var results:Array<U> = [];
        var hasError:Bool = false;

        return new Promise<Array<U>>(function(resolve, reject) {
            
            if (promises.length == 0) {
                resolve([]);
                return;
            }

            var checkComplete = function() {
                if (count == promises.length && !hasError) {
                    resolve(results);
                }
            };

            for (i in 0...promises.length) {
                if (promises[i] == null) {
                    results[i] = null;
                    count++;
                    checkComplete();
                    continue;
                }

                promises[i]
                    .then(function(result:U) {
                        if (!hasError) {
                            results[i] = result;
                            count++;
                            checkComplete();
                        }
                    })
                    .onError(function(error:String) {
                        if (!hasError) {
                            hasError = true;
                            reject(error);
                        }
                    });
            }
        });
    }

    // Instance methods
    public function run():Void {
        __time = Timer.stamp();

        if (__state == ON_QUEUE) {
            __state = PENDING;
            __funcToRun(__resolve, __reject);
        }
    }

    public function then(onResolve:(T)->Void):Promise<T> {
        if (__state == COMPLETE) {
            onResolve(__result);
        } else if (__state == PENDING || __state == ON_QUEUE) {
            if (__completeListeners == null) {
                __completeListeners = new EventDispacher();
            }
            __completeListeners.addListener(function(value:T, ?type:UInt) onResolve(value));
        }
        return this;
    }

    public function onError(onReject:(String)->Void):Promise<T> {
        if (__state == REJECTED) {
            onReject(__error);
        } else if (__state == PENDING || __state == ON_QUEUE) {
            if (__errorListeners == null) {
                __errorListeners = new EventDispacher();
            }
            __errorListeners.addListener(function(error:String, ?type:UInt) onReject(error));
        }
        return this;
    }

    public function finally(onFinally:()->Void):Promise<T> {
        var executeFinally = function() {
            if (onFinally != null) onFinally();
        };
        
        this.then(function(_) executeFinally())
            .onError(function(_) executeFinally());
        
        return this;
    }

    // Private methods
    private function __resolve(result:T):Void {
        if (__state != PENDING) return; // Prevent multiple resolutions
        
        __time = Timer.stamp() - __time;
        __state = COMPLETE;
        __result = result;

        if (__completeListeners != null) {
            __completeListeners.dispatchEvent(__result, 0);
        }
    }

    private function __reject(error:String):Void {
        if (__state != PENDING) return; // Prevent multiple rejections
        
        __time = Timer.stamp() - __time;
        __state = REJECTED;
        __error = error;

        if (__errorListeners != null) {
            __errorListeners.dispatchEvent(__error, 0);
        } else {
            trace('Unhandled Promise rejection: ' + error);
        }
    }

    // Setters and getters

    private function get_isComplete():Bool {
        return __state == COMPLETE || __state == REJECTED;
    }

    private function get_state():PromiseState {
        return __state;
    }

    private function get_result():T {
        return __result;
    }

    private function get_error():String {
        return __error;
    }

    private function get_time():Float {
        return __time;
    }
}

enum PromiseState {
    ON_QUEUE;
    PENDING;
    COMPLETE;
    REJECTED;
}