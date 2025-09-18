package ds;

import core.Object;

class List<T:Object> {
	
	// ** Publics.
	
	/**
	 * The maximum capacity of this group. Default is 0, meaning no max capacity.
	 */
	public var capacity(get, set):Int;
	
	/**
	 * The count of all members inside the list.
	 */
	public var count(get, null):Int;
	
	/**
	 * An array of all the members.
	 */
	public var members:Array<T>;
	
	// ** Privates.
	
	private var __capacity:Int = 0;
	
	public function new(?lenght:Int, ?fixed:Bool) {

		if (lenght > 0) {

			fixed = true;
		}
		
		// ** Create a new members vector.
		
		members = new Array<T>();
	}
	
	public function add(object:T):T {

		//** Check if the group is fixed...
		
		// if (members.fixed)
		// {
		// 	//** Return.
			
		// 	return object;
		// }
		
		//** If the object is already active...
		
		if (object.active) {

			//trace("Already active");
			
			//** Return.
			
			return null;
		}
		
		//** Check if the group is full...
		
		if (__capacity > 0 && count >= __capacity) {

			trace("Bigger");
			
			//** Return.
			
			return object;
		}
		
		//** Call init method.
		
		object.init();
		
		//** Set object as active.
		
		//** Push a new object with a new active index into the active members array.
		
		@:privateAccess object.__index = members.push(object) - 1; //** Define metadata: privateAccess.
		
		//** Return.
		
		return object;
	}
	
	/**
	 *  Adds an object at the specific index of this list. Will override any other object if not empty.
	 * 
	 * @param	index
	 * @param	object
	 * @return
	 */
	public function addAt(index:Int, object:T):T {

		//** If the object is already active...
		
		if (@:privateAccess object.active) {

			trace("Already active");
			
			//** Return.
			
			return object;
		}
		
		//** If the index id bigger than the lenght...
		
		if (index - 1 > members.length) {

			trace("Bigger");
			
			//** Check if the group is full...
			
			if (__capacity > 0 && count >= __capacity) {

				//** Return.
				
				return object;
			}
		}
		
		//** Call init method.
		
		object.init();
		
		//** Set object as active.
		
		//@:privateAccess object.__active = true; //** Define metadata: privateAccess.
		
		//** Set the active index of the object.
		
		@:privateAccess object.__index = index; //** Define metadata: privateAccess.
		
		//** Add the object into the array.
		
		members[index] = object;
		
		//** Return.
		
		return object;
	}

	public function clear():Void {
		
		while (members.length > 0) {

			members.pop();
		}
	}
	
	public function getMember(index:Int):T {

		//** Return.
		
		return members[index];
	}
	
	public function remove(object:T):Void {

		//** Call remove at method.
		
		@:privateAccess removeAt(object.__index); //** Define metadata: privateAccess.
	}
	
	public function removeAt(index:Int):Void {

		if (index == -1) {

			//trace(index);
			
			return;
		}
		
		//** Call release method.
		
		members[index].release();
		
		//** Null the active index of the object.
		
		@:privateAccess members[index].__index = -1; //** Define metadata: privateAccess.
		
		//** If index is lesser than the lenght of the members... 
		
		if (index < members.length - 1) {

			//** Assign the last object on the list to the index.
			
			members[index] = members[members.length - 1];
			
			//** Assign the index to the object.
			
			@:privateAccess members[index].__index = index; //** Define metadata: privateAccess.
		}
		
		//** Pop the last object on the list.
		
		members.pop();
	}
	
	public function pop():Void {

		removeAt(count - 1);
	}
	
	public function forEach(func:T -> Void):Void {

		for (i in 0...count) {

			if (members[i] == null) {

				continue;
			}
			
			func(members[i]);
		}
	}
	
	//** Getters and Setters.
	
	private function get_count():Int {

		return members.length;
	}
	
	private function get_capacity():Int {

		return __capacity;
	}
	
	private function set_capacity(value:Int):Int {

		return __capacity = value;
	}
}