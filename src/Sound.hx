package;

import cpp.RawPointer;
import SDLMixer.MIX_Audio;
import SDLMixer.MIX_Track;

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