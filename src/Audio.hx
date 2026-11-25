package;

import cpp.RawPointer;
import haxe.io.Bytes;
import data.SoundData;
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

    /** Load a sound from resource SoundData. */
    public function loadSound(soundData:SoundData, predecode:Bool = true):Sound {
        if (soundData == null) throw "SoundData must not be null";
        if (!soundData.allocated) throw "SoundData has been disposed";
        return loadBytes(soundData.bytes, predecode, soundData.src);
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