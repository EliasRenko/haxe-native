package;

import cpp.Pointer;
import cpp.Star;
import cpp.UInt32;
import cpp.UInt64;
import cpp.Int64;
import cpp.ConstCharStar;

// SDL audio types (SDL_AudioDeviceID is Uint32 per SDL3 header)
typedef SDL_AudioDeviceID = UInt32;

/**
 * SDL_AudioSpec describes an audio format (format, channels, sample rate).
 * Pass a pointer to this struct where SDL_mixer expects const SDL_AudioSpec*.
 */
@:unreflective
@:structAccess
@:include("SDL3/SDL_mixer.h")
@:native("SDL_AudioSpec")
extern class SDL_AudioSpec {
    var format:Int;    // SDL_AudioFormat (Uint16 underlying type)
    var channels:Int;
    var freq:Int;
}

// SDL_AudioStream — opaque SDL3 type used for streaming audio input on tracks
@:include("SDL3/SDL_mixer.h")
@:native("SDL_AudioStream")
extern class SDL_AudioStream {}
typedef AudioStreamPtr = Pointer<SDL_AudioStream>;

// ------------------------------------------------------------------
// Opaque SDL_mixer types
// ------------------------------------------------------------------

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Mixer")
extern class MIX_Mixer {}
typedef MixerPtr = Pointer<MIX_Mixer>;

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Audio")
extern class MIX_Audio {}
typedef MixAudioPtr = Pointer<MIX_Audio>;

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Track")
extern class MIX_Track {}
typedef TrackPtr = Pointer<MIX_Track>;

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Group")
extern class MIX_Group {}
typedef GroupPtr = Pointer<MIX_Group>;

// ------------------------------------------------------------------
// SDL_mixer value structs
// ------------------------------------------------------------------

/** Per-channel gain for stereo panning. Set left + right to 1.0 for unity. */
@:unreflective
@:structAccess
@:include("SDL3/SDL_mixer.h")
@:native("MIX_StereoGains")
extern class MIX_StereoGains {
    var left:Float;
    var right:Float;
}

/** 3D position in a right-handed coordinate system (same as OpenGL/OpenAL). */
@:unreflective
@:structAccess
@:include("SDL3/SDL_mixer.h")
@:native("MIX_Point3D")
extern class MIX_Point3D {
    var x:Float;  // negative = left,    positive = right
    var y:Float;  // negative = down,    positive = up
    var z:Float;  // negative = forward, positive = back
}

// ------------------------------------------------------------------
// Main SDL_mixer extern class
// ------------------------------------------------------------------

/**
 * SDL_mixer 3.x externs for Haxe/HXCPP.
 *
 * Typical usage:
 *   MIX.init();
 *   var mixer = MIX.createMixerDevice(MIX.defaultPlaybackDevice(), null);
 *   var audio  = MIX.loadAudio(mixer, "sound.wav", false);
 *   var track  = MIX.createTrack(mixer);
 *   MIX.setTrackAudio(track, audio);
 *   MIX.playTrack(track, 0);  // 0 = default play options
 *   ...
 *   MIX.destroyTrack(track);
 *   MIX.destroyAudio(audio);
 *   MIX.destroyMixer(mixer);
 *   MIX.quit();
 */
@:keep
@:buildXml('
<target id="haxe" if="windows">
   <lib name="lib/x64/SDL3_mixer.lib"/>
</target>')
@:include("SDL3/SDL_mixer.h")
extern class MIX {

    // ----------------------------------------------------------------
    // Init / Quit
    // ----------------------------------------------------------------

    /** Returns the SDL_mixer linked-library version number. */
    @:native("MIX_Version")
    static function version():Int;

    /** Initialize SDL_mixer. Must be called before any other MIX function. */
    @:native("MIX_Init")
    static function init():Bool;

    /** Shut down SDL_mixer and free all its resources. */
    @:native("MIX_Quit")
    static function quit():Void;

    // ----------------------------------------------------------------
    // Decoders
    // ----------------------------------------------------------------

    @:native("MIX_GetNumAudioDecoders")
    static function getNumAudioDecoders():Int;

    @:native("MIX_GetAudioDecoder")
    static function getAudioDecoder(index:Int):ConstCharStar;

    // ----------------------------------------------------------------
    // Mixer creation / destruction
    // ----------------------------------------------------------------

    /**
     * Create a mixer that plays to an audio device.
     * Pass MIX.defaultPlaybackDevice() for devid to use the system default.
     * Pass null for spec to let SDL_mixer choose the best format.
     */
    @:native("MIX_CreateMixerDevice")
    static function createMixerDevice(devid:SDL_AudioDeviceID, spec:Star<SDL_AudioSpec>):MixerPtr;

    /**
     * Create a mixer that renders to a memory buffer instead of a device.
     * spec must not be null.
     */
    @:native("MIX_CreateMixer")
    static function createMixer(spec:Star<SDL_AudioSpec>):MixerPtr;

    /** Destroy a mixer and close its audio device. */
    @:native("MIX_DestroyMixer")
    static function destroyMixer(mixer:MixerPtr):Void;

    @:native("MIX_GetMixerProperties")
    static function getMixerProperties(mixer:MixerPtr):UInt64;

    @:native("MIX_GetMixerFormat")
    static function getMixerFormat(mixer:MixerPtr, spec:Star<SDL_AudioSpec>):Bool;

    @:native("MIX_LockMixer")
    static function lockMixer(mixer:MixerPtr):Void;

    @:native("MIX_UnlockMixer")
    static function unlockMixer(mixer:MixerPtr):Void;

    /** Master gain for all tracks on this mixer. 1.0 = full volume. */
    @:native("MIX_SetMixerGain")
    static function setMixerGain(mixer:MixerPtr, gain:Float):Bool;

    @:native("MIX_GetMixerGain")
    static function getMixerGain(mixer:MixerPtr):Float;

    /** Speed / pitch ratio for the whole mixer. 1.0 = normal speed. */
    @:native("MIX_SetMixerFrequencyRatio")
    static function setMixerFrequencyRatio(mixer:MixerPtr, ratio:Float):Bool;

    @:native("MIX_GetMixerFrequencyRatio")
    static function getMixerFrequencyRatio(mixer:MixerPtr):Float;

    // ----------------------------------------------------------------
    // Audio data loading / destruction
    // ----------------------------------------------------------------

    /**
     * Load an audio file from the filesystem.
     * Set predecode=true to decompress up front (uses more RAM, less CPU per
     * playback); false to decode on the fly from the compressed data.
     */
    @:native("MIX_LoadAudio")
    static function loadAudio(mixer:MixerPtr, path:ConstCharStar, predecode:Bool):MixAudioPtr;

    /** Free a previously loaded MIX_Audio. */
    @:native("MIX_DestroyAudio")
    static function destroyAudio(audio:MixAudioPtr):Void;

    /** Duration of audio data in sample frames, or -1 if unknown. */
    @:native("MIX_GetAudioDuration")
    static function getAudioDuration(audio:MixAudioPtr):Int64;

    @:native("MIX_GetAudioFormat")
    static function getAudioFormat(audio:MixAudioPtr, spec:Star<SDL_AudioSpec>):Bool;

    @:native("MIX_GetAudioProperties")
    static function getAudioProperties(audio:MixAudioPtr):UInt64;

    /** Convert milliseconds to sample frames for the given MIX_Audio's format. */
    @:native("MIX_AudioMSToFrames")
    static function audioMSToFrames(audio:MixAudioPtr, ms:Int64):Int64;

    @:native("MIX_AudioFramesToMS")
    static function audioFramesToMS(audio:MixAudioPtr, frames:Int64):Int64;

    // ----------------------------------------------------------------
    // Track creation / destruction
    // ----------------------------------------------------------------

    /**
     * Create a new track on the given mixer.
     * Each track is an independent audio source that gets mixed together.
     */
    @:native("MIX_CreateTrack")
    static function createTrack(mixer:MixerPtr):TrackPtr;

    /** Destroy a track. */
    @:native("MIX_DestroyTrack")
    static function destroyTrack(track:TrackPtr):Void;

    @:native("MIX_GetTrackProperties")
    static function getTrackProperties(track:TrackPtr):UInt64;

    @:native("MIX_GetTrackMixer")
    static function getTrackMixer(track:TrackPtr):MixerPtr;

    // ----------------------------------------------------------------
    // Track input assignment
    // ----------------------------------------------------------------

    /** Assign a loaded MIX_Audio to this track as its sound source. */
    @:native("MIX_SetTrackAudio")
    static function setTrackAudio(track:TrackPtr, audio:MixAudioPtr):Bool;

    /** Assign an SDL_AudioStream (streaming PCM) as this track's source. */
    @:native("MIX_SetTrackAudioStream")
    static function setTrackAudioStream(track:TrackPtr, stream:AudioStreamPtr):Bool;

    /** Retrieve the MIX_Audio currently assigned to this track (or null). */
    @:native("MIX_GetTrackAudio")
    static function getTrackAudio(track:TrackPtr):MixAudioPtr;

    /** Retrieve the SDL_AudioStream currently assigned to this track (or null). */
    @:native("MIX_GetTrackAudioStream")
    static function getTrackAudioStream(track:TrackPtr):AudioStreamPtr;

    // ----------------------------------------------------------------
    // Track tagging (group multiple tracks by name)
    // ----------------------------------------------------------------

    @:native("MIX_TagTrack")
    static function tagTrack(track:TrackPtr, tag:ConstCharStar):Bool;

    @:native("MIX_UntagTrack")
    static function untagTrack(track:TrackPtr, tag:ConstCharStar):Void;

    // ----------------------------------------------------------------
    // Track state queries
    // ----------------------------------------------------------------

    @:native("MIX_TrackPlaying")
    static function trackPlaying(track:TrackPtr):Bool;

    @:native("MIX_TrackPaused")
    static function trackPaused(track:TrackPtr):Bool;

    /** Current playback position in sample frames. */
    @:native("MIX_GetTrackPlaybackPosition")
    static function getTrackPlaybackPosition(track:TrackPtr):Int64;

    @:native("MIX_SetTrackPlaybackPosition")
    static function setTrackPlaybackPosition(track:TrackPtr, frames:Int64):Bool;

    /** Sample frames remaining to be mixed, or -1 if unknown. */
    @:native("MIX_GetTrackRemaining")
    static function getTrackRemaining(track:TrackPtr):Int64;

    /**
     * Frames left in the current fade (<0 = fading out, >0 = fading in, 0 = no fade).
     */
    @:native("MIX_GetTrackFadeFrames")
    static function getTrackFadeFrames(track:TrackPtr):Int64;

    /** Pending loop count. -1 = infinite looping. */
    @:native("MIX_GetTrackLoops")
    static function getTrackLoops(track:TrackPtr):Int;

    /** Change the remaining loop count while playing. -1 = infinite. */
    @:native("MIX_SetTrackLoops")
    static function setTrackLoops(track:TrackPtr, numLoops:Int):Bool;

    // ----------------------------------------------------------------
    // Track audio properties
    // ----------------------------------------------------------------

    /** Per-track volume gain. 1.0 = full volume, 0.0 = silence. */
    @:native("MIX_SetTrackGain")
    static function setTrackGain(track:TrackPtr, gain:Float):Bool;

    @:native("MIX_GetTrackGain")
    static function getTrackGain(track:TrackPtr):Float;

    /** Set gain for all tracks with a given tag. */
    @:native("MIX_SetTagGain")
    static function setTagGain(mixer:MixerPtr, tag:ConstCharStar, gain:Float):Bool;

    /** Per-track speed / pitch ratio. 1.0 = normal speed. */
    @:native("MIX_SetTrackFrequencyRatio")
    static function setTrackFrequencyRatio(track:TrackPtr, ratio:Float):Bool;

    @:native("MIX_GetTrackFrequencyRatio")
    static function getTrackFrequencyRatio(track:TrackPtr):Float;

    /**
     * Force stereo output with left/right panning.
     * Example: gains.left=0.3, gains.right=0.7 pans toward the right.
     */
    @:native("MIX_SetTrackStereo")
    static function setTrackStereo(track:TrackPtr, gains:Star<MIX_StereoGains>):Bool;

    /** Set 3D spatial position. Distance from origin attenuates volume. */
    @:native("MIX_SetTrack3DPosition")
    static function setTrack3DPosition(track:TrackPtr, position:Star<MIX_Point3D>):Bool;

    @:native("MIX_GetTrack3DPosition")
    static function getTrack3DPosition(track:TrackPtr, position:Star<MIX_Point3D>):Bool;

    // ----------------------------------------------------------------
    // Playback control
    // ----------------------------------------------------------------

    /**
     * Start (or restart) a track.
     * options is an SDL_PropertiesID (UInt64) with play parameters, or 0 for defaults.
     * Common option keys: MIX.PROP_PLAY_LOOPS, MIX.PROP_PLAY_FADE_IN_MS, etc.
     */
    @:native("MIX_PlayTrack")
    static function playTrack(track:TrackPtr, options:UInt64):Bool;

    /** Start all tracks tagged with `tag` simultaneously. */
    @:native("MIX_PlayTag")
    static function playTag(mixer:MixerPtr, tag:ConstCharStar, options:UInt64):Bool;

    /**
     * Quick one-shot: play a MIX_Audio without managing a track manually.
     * SDL_mixer picks an internal track automatically.
     */
    @:native("MIX_PlayAudio")
    static function playAudio(mixer:MixerPtr, audio:MixAudioPtr):Bool;

    /** Stop a track, optionally fading out over `fadeOutFrames` sample frames (0 = immediate). */
    @:native("MIX_StopTrack")
    static function stopTrack(track:TrackPtr, fadeOutFrames:Int64):Bool;

    /** Stop all tracks on a mixer, optionally fading out over `fadeOutMs` milliseconds. */
    @:native("MIX_StopAllTracks")
    static function stopAllTracks(mixer:MixerPtr, fadeOutMs:Int64):Bool;

    /** Stop all tracks with a given tag, with optional fade-out in ms. */
    @:native("MIX_StopTag")
    static function stopTag(mixer:MixerPtr, tag:ConstCharStar, fadeOutMs:Int64):Bool;

    @:native("MIX_PauseTrack")
    static function pauseTrack(track:TrackPtr):Bool;

    @:native("MIX_PauseAllTracks")
    static function pauseAllTracks(mixer:MixerPtr):Bool;

    @:native("MIX_PauseTag")
    static function pauseTag(mixer:MixerPtr, tag:ConstCharStar):Bool;

    @:native("MIX_ResumeTrack")
    static function resumeTrack(track:TrackPtr):Bool;

    @:native("MIX_ResumeAllTracks")
    static function resumeAllTracks(mixer:MixerPtr):Bool;

    @:native("MIX_ResumeTag")
    static function resumeTag(mixer:MixerPtr, tag:ConstCharStar):Bool;

    // ----------------------------------------------------------------
    // Time conversion helpers
    // ----------------------------------------------------------------

    /** Convert ms to sample frames using a track's current input format. */
    @:native("MIX_TrackMSToFrames")
    static function trackMSToFrames(track:TrackPtr, ms:Int64):Int64;

    @:native("MIX_TrackFramesToMS")
    static function trackFramesToMS(track:TrackPtr, frames:Int64):Int64;

    /** Convert ms to sample frames at an explicit sample rate. */
    @:native("MIX_MSToFrames")
    static function msToFrames(sampleRate:Int, ms:Int64):Int64;

    @:native("MIX_FramesToMS")
    static function framesToMS(sampleRate:Int, frames:Int64):Int64;

    // ----------------------------------------------------------------
    // Convenience helpers
    // ----------------------------------------------------------------

    /**
     * Returns the SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK constant (0xFFFFFFFF).
     * Pass this to createMixerDevice to open the system default output device.
     */
    static inline function defaultPlaybackDevice():SDL_AudioDeviceID {
        return untyped __cpp__("SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK");
    }

    // Play options property key strings (pass to SDL_SetNumberProperty before MIX_PlayTrack)
    static inline var PROP_PLAY_LOOPS:String              = "SDL_mixer.play.loops";
    static inline var PROP_PLAY_MAX_MS:String             = "SDL_mixer.play.max_milliseconds";
    static inline var PROP_PLAY_START_MS:String           = "SDL_mixer.play.start_millisecond";
    static inline var PROP_PLAY_LOOP_START_MS:String      = "SDL_mixer.play.loop_start_millisecond";
    static inline var PROP_PLAY_FADE_IN_MS:String         = "SDL_mixer.play.fade_in_milliseconds";
    static inline var PROP_PLAY_FADE_IN_START_GAIN:String = "SDL_mixer.play.fade_in_start_gain";
    static inline var PROP_PLAY_HALT_WHEN_EXHAUSTED:String = "SDL_mixer.play.halt_when_exhausted";
}
