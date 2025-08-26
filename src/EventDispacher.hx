package;

typedef Callback<T> = T -> UInt -> Void;

typedef Listener<T> = {
	var func:Callback<T>;
	var type:UInt;
	var priority:UInt;
}

class EventDispacher<T> {
	
	// Privates
	private var __listeners:Array<Listener<T>> = new Array<Listener<T>>();
	
	public function new() {}
	
	public function addListener(listener:Callback<T>, type:UInt = 0, priority:UInt = 0):Void {
		var eventListener:Listener<T> = {
			func: listener,
			type: type,
			priority: priority
		}
		
		for (i in 0...__listeners.length) {
			if (priority > __listeners[i].priority) {
				__listeners.insert(i, eventListener);
				return;
			}
		}
		
		__listeners.push(eventListener);
	}

	public function clearListeners():Void {
		var i:Int = __listeners.length - 1;

		while (i > -1) {
			__listeners.pop();
			i --;
		}
	}
	
	public function dispatchEvent(value:T, type:UInt = 0):Void {
		for (i in 0...__listeners.length) {
			if (__listeners[i].type == type || __listeners[i].type == 0) {
				__listeners[i].func(value, type);
			}
		}
	}
	
	public function hasListener(listener:Callback<T>):Bool {
		for (i in 0...__listeners.length) {
			if (Reflect.compareMethods(__listeners[i].func, listener)) return true;
		}
		
		return false;
	}
	
	public function removeListener(listener:Callback<T>):Void {
		var i:Int = __listeners.length - 1;

		while (i > -1) {
			if (Reflect.compareMethods(__listeners[i].func, listener)) {
				__listeners.splice(i, 1);
			}

			i --;
		}
	}
}