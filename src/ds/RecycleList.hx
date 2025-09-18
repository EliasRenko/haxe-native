package ds;

import core.Object;
import ds.List;

class RecycleList<T:Object> extends List<T> {

	//** Publics.
	
	/**
	 * The count of the active members inside the list.
	 */
	public var activeCount(get, null):Int;
	
	/**
	 * The count of the passive members inside the list.
	 */
	public var passiveCount(get, null):Int;
	
	//** Privates.
	
	private var __passiveMembers:Array<T>;
	
	public function new(?length:Int, ?fixed:Bool) {

		super(length, fixed);
		
		//** Create a new passive members vector.
		
		__passiveMembers = new Array<T>();
	}
	
	public function insert(object:T):T {

		//** If object is active...
		
		if (object.active) { //** Define metadata: privateAccess.

			return null;
		}
		
		//** Push a new object with a new passive index into the passive members array.
		
		@:privateAccess object.__passiveIndex = __passiveMembers.push(object) - 1; //** Define metadata: privateAccess.
		
		//** Return.
		
		return object;
	}
	
	public function restore(object:T):T {

		if (object == null) {

			if (passiveCount == 0) return null;

			return restoreAt(passiveCount - 1);
		}

		//** Return.
		
		return restoreAt(@:privateAccess object.__passiveIndex); //** Define metadata: privateAccess.
	}
	
	public function restoreAt(index:Int):T {

		//** If the object is active...
		
		if (index == -1) {

			//** Return.
			
			return null;
		}
		
		//** Null the active index of the object.
		
		@:privateAccess __passiveMembers[index].__passiveIndex = -1; //** Define metadata: privateAccess.
		
		//** Add the object to the passive members array.
		
		var _object:T = add(__passiveMembers[index]);
		
		//** If index is lesser than the lenght of the members... 
		
		if (index < __passiveMembers.length - 1) {

			//** Assign the last object on the list to the index.
			
			__passiveMembers[index] = __passiveMembers[members.length - 1];
			
			//** Assign the index to the object.
			
			@:privateAccess __passiveMembers[index].__passiveIndex = index; //** Define metadata: privateAccess.
		}
		
		//** Pop the last passive member.
		
		__passiveMembers.pop();
		
		//** Return.
		
		return _object;
	}
	
	public function recycle(object:T):Bool {

		if (object.active) { //** Define metadata: privateAccess.

			@:privateAccess object.__index = -1; //** Define metadata: privateAccess.
			
			@:privateAccess object.__passiveIndex = __passiveMembers.push(object) - 1; //** Define metadata: privateAccess.
			
			@:privateAccess removeAt(object.index); //** Define metadata: privateAccess.
			
			return true;
		}
		
		return false;
	}
	
	override public function removeAt(index:Int):Void {

		super.removeAt(index);
	}
	
	override public function forEach(func:T -> Void):Void {

		super.forEach(func);
		
		for (i in 0...passiveCount) {

			if (members[i] == null) {

				continue;
			}
			
			func(__passiveMembers[i]);
		}
	}
	
	public function forEachActive(func:T -> Void):Void {

		super.forEach(func);
	}
	
	public function forEachPassive(func:T -> Void):Void {

		for (i in 0...passiveCount) {

			if (members[i] == null) {

				continue;
			}
			
			func(__passiveMembers[i]);
		}
	}
	
	//** Getters and Setters.
	
	private function get_activeCount():Int {

		return members.length;
	}
	
	override private function get_count():Int {

		return members.length + __passiveMembers.length;
	}
	
	private function get_passiveCount():Int {
		
		return __passiveMembers.length;
	}
}