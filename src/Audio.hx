package;

#if (cpp && !no_audio)
import cpp.RawPointer;
import haxe.io.Bytes;
import SDLMixer.MIX_Audio;
import SDLMixer.MIX_Mixer;
import SDLMixer.MIX_Track;

@:allow(Sound)
class Audio {
    private var __mixer:RawPointer<MIX_Mixer>;
    private var __sounds:Array<Sound> = [];

    /** SDL_mixer must already be initialized. */
    public function new() {
        __mixer = SDLMixer.createMixerDevice(SDLMixer.DEFAULT_PLAYBACK_DEVICE, null);
        if (__mixer == null) throw "Failed to create audio mixer: " + SDL.getError();
    }

    /** Load a sound. Each sound has its own track and can play alongside others. */
    public function load(path:String, predecode:Bool = true):Sound {
        if (__mixer == null) throw "Audio has been released";
        if (path == null || path.length == 0) throw "Audio path must not be empty";

        var data = SDLMixer.loadAudio(__mixer, path, predecode);
        if (data == null) throw 'Failed to load audio "$path": ' + SDL.getError();

        return createSound(data);
    }

    /** Load a sound from bytes such as data returned by Resources or Runtime.loadBytes. */
    public function loadBytes(bytes:Bytes, predecode:Bool = true, name:String = "byte data"):Sound {
        if (__mixer == null) throw "Audio has been released";
        if (bytes == null) throw "Audio bytes must not be null";
        if (bytes.length == 0) throw "Audio bytes must not be empty";

        var pointer = cpp.NativeArray.address(bytes.getData(), 0).rawCast();
        var io = SDLMixer.ioFromConstMem(pointer, bytes.length);
        if (io == null) throw 'Failed to create audio stream for "$name": ' + SDL.getError();

        var data = SDLMixer.loadAudioIO(__mixer, io, predecode, true);
        if (data == null) throw 'Failed to load audio "$name": ' + SDL.getError();

        return createSound(data);
    }

    private function createSound(data:RawPointer<MIX_Audio>):Sound {
        var track = SDLMixer.createTrack(__mixer);
        if (track == null) {
            var error = SDL.getError();
            SDLMixer.destroyAudio(data);
            throw "Failed to create audio track: " + error;
        }
        if (!SDLMixer.setTrackAudio(track, data)) {
            var error = SDL.getError();
            SDLMixer.destroyTrack(track);
            SDLMixer.destroyAudio(data);
            throw "Failed to assign audio to track: " + error;
        }

        var sound = new Sound(this);
        sound.__data = data;
        sound.__track = track;
        __sounds.push(sound);
        return sound;
    }

    /** Stop and release all sounds, then close the mixer. */
    public function release():Void {
        if (__mixer == null) return;
        while (__sounds.length > 0) __sounds[__sounds.length - 1].release();
        SDLMixer.destroyMixer(__mixer);
        __mixer = null;
    }

    private function __removeSound(sound:Sound):Void {
        __sounds.remove(sound);
    }
}

/** A loaded sound with one playback track. */
@:allow(Audio)
class Sound {
    public var playing(get, never):Bool;
    public var paused(get, never):Bool;
    public var volume(get, set):Float;

    private var __owner:Audio;
    private var __data:RawPointer<MIX_Audio>;
    private var __track:RawPointer<MIX_Track>;

    private function new(owner:Audio) {
        __owner = owner;
    }

    /** Start the sound from the beginning, even if it is already playing. */
    public function play():Void {
        __checkActive();
        if (!SDLMixer.playTrack(__track, 0)) throw "Failed to play sound: " + SDL.getError();
    }

    public function pause():Void {
        __checkActive();
        if (!SDLMixer.pauseTrack(__track)) throw "Failed to pause sound: " + SDL.getError();
    }

    public function resume():Void {
        __checkActive();
        if (!SDLMixer.resumeTrack(__track)) throw "Failed to resume sound: " + SDL.getError();
    }

    public function stop():Void {
        __checkActive();
        if (!SDLMixer.stopTrack(__track, 0)) throw "Failed to stop sound: " + SDL.getError();
    }

    /** Set the number of additional loops. Use -1 to loop indefinitely. */
    public function setLoops(loops:Int):Void {
        __checkActive();
        if (loops < -1) throw "Sound loop count must be -1 or greater";
        if (!SDLMixer.setTrackLoops(__track, loops))
            throw "Failed to set sound loops: " + SDL.getError();
    }

    public function release():Void {
        if (__track == null) return;
        SDLMixer.destroyTrack(__track);
        SDLMixer.destroyAudio(__data);
        __track = null;
        __data = null;
        __owner.__removeSound(this);
        __owner = null;
    }

    private function __checkActive():Void {
        if (__track == null) throw "Sound has been released";
    }

    private function get_playing():Bool {
        __checkActive();
        return SDLMixer.trackPlaying(__track);
    }

    private function get_paused():Bool {
        __checkActive();
        return SDLMixer.trackPaused(__track);
    }

    private function get_volume():Float {
        __checkActive();
        return SDLMixer.getTrackGain(__track);
    }

    private function set_volume(value:Float):Float {
        __checkActive();
        if (!Math.isFinite(value) || value < 0 || value > 1)
            throw "Sound volume must be between 0 and 1";
        if (!SDLMixer.setTrackGain(__track, value)) throw "Failed to set sound volume: " + SDL.getError();
        return value;
    }
}
#end