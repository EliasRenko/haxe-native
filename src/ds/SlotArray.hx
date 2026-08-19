package ds;

/**
 * Contiguous slot storage with O(1) add/remove/get and stable integer IDs.
 * Freed IDs are recycled via a free-list stack, so no other IDs are affected
 * by removals. Default capacity: 8 slots.
 */
class SlotArray<T> {

    private var _slots:Array<T>;
    private var _freeList:Array<Int>;
    private var _count:Int = 0;

    public var count(get, never):Int;
    private inline function get_count():Int return _count;

    public function new(initialCapacity:Int = 8) {
        _slots = [];
        _slots.resize(initialCapacity);       // pre-fills with null
        _freeList = [];
        var i = initialCapacity - 1;
        while (i >= 0) _freeList.push(i--);  // slot 0 popped first
    }

    /** Add an item. Returns a stable id valid until remove() is called with it. */
    public function add(item:T):Int {
        var id = (_freeList.length > 0) ? _freeList.pop() : _slots.length;
        if (id == _slots.length) _slots.push(cast null); // grow by 1 if needed
        _slots[id] = item;
        _count++;
        return id;
    }

    /** Remove item at id. Slot is cleared and id is recycled for future adds. */
    public function remove(id:Int):Void {
        if (!isValid(id)) return;
        _slots[id] = cast null;
        _freeList.push(id);
        _count--;
    }

    public inline function get(id:Int):T {
        return (id >= 0 && id < _slots.length) ? _slots[id] : cast null;
    }

    public inline function isValid(id:Int):Bool {
        return id >= 0 && id < _slots.length && _slots[id] != null;
    }

    /** Returns the slot id of the given item, or -1 if not found. */
    public function indexOf(item:T):Int {
        for (i in 0..._slots.length) {
            if (_slots[i] == item) return i;
        }
        return -1;
    }

    /** Iterates only live (non-null) slots. */
    public function iterator():Iterator<T> {
        var i = 0;
        var slots = _slots;
        return {
            hasNext: function() {
                while (i < slots.length && slots[i] == null) i++;
                return i < slots.length;
            },
            next: function() return slots[i++]
        };
    }
}