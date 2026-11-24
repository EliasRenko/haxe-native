package;

#if (cpp && !no_audio)
import cpp.ConstCharStar;
import cpp.Float32;
import cpp.Int64;
import cpp.RawPointer;
import cpp.UInt32;

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Mixer")
extern class MIX_Mixer {}

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Audio")
extern class MIX_Audio {}

@:include("SDL3/SDL_mixer.h")
@:native("MIX_Track")
extern class MIX_Track {}

@:include("SDL3/SDL.h")
@:native("SDL_AudioFormat")
extern enum abstract MixerAudioFormat(Int) {
    @:native("SDL_AUDIO_U8") var U8;
    @:native("SDL_AUDIO_S16") var S16;
    @:native("SDL_AUDIO_S32") var S32;
    @:native("SDL_AUDIO_F32") var F32;
}

@:include("SDL3/SDL.h")
@:native("SDL_AudioSpec")
@:structAccess
extern class MixerAudioSpec {
    public var format:MixerAudioFormat;
    public var channels:Int;
    public var freq:Int;
}

/**
 * Low-level SDL3_mixer bindings. Check false/null results with SDL.getError().
 * Callers own mixers, audio and tracks and must destroy them before MIX_Quit.
 */
@:include("SDL3/SDL_mixer.h")
@:buildXml('
<files id="haxe">
  <compilerflag value="-I${haxelib:haxe-native}/include"/>
</files>
<target id="haxe" if="windows">
  <lib name="${haxelib:haxe-native}/lib/x64/SDL3.lib"/>
  <lib name="${haxelib:haxe-native}/lib/x64/SDL3_mixer.lib"/>
</target>
')
extern class SDLMixer {
    @:native("SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK")
    public static var DEFAULT_PLAYBACK_DEVICE(default, never):UInt32;

    @:native("MIX_Version")
    public static function version():Int;
    @:native("MIX_Init")
    public static function init():Bool;
    @:native("MIX_Quit")
    public static function quit():Void;

    @:native("MIX_CreateMixerDevice")
    public static function createMixerDevice(device:UInt32, spec:RawPointer<MixerAudioSpec>):RawPointer<MIX_Mixer>;
    @:native("MIX_CreateMixer")
    public static function createMixer(spec:RawPointer<MixerAudioSpec>):RawPointer<MIX_Mixer>;
    @:native("MIX_DestroyMixer")
    public static function destroyMixer(mixer:RawPointer<MIX_Mixer>):Void;
    @:native("MIX_GetMixerFormat")
    public static function getMixerFormat(mixer:RawPointer<MIX_Mixer>, spec:RawPointer<MixerAudioSpec>):Bool;
    @:native("MIX_SetMixerGain")
    public static function setMixerGain(mixer:RawPointer<MIX_Mixer>, gain:Float32):Bool;
    @:native("MIX_GetMixerGain")
    public static function getMixerGain(mixer:RawPointer<MIX_Mixer>):Float32;

    @:native("MIX_LoadAudio")
    public static function loadAudio(mixer:RawPointer<MIX_Mixer>, path:ConstCharStar, predecode:Bool):RawPointer<MIX_Audio>;
    @:native("MIX_CreateSineWaveAudio")
    public static function createSineWaveAudio(mixer:RawPointer<MIX_Mixer>, hz:Int, amplitude:Float32, ms:Int64):RawPointer<MIX_Audio>;
    @:native("MIX_DestroyAudio")
    public static function destroyAudio(audio:RawPointer<MIX_Audio>):Void;
    @:native("MIX_GetAudioDuration")
    public static function getAudioDuration(audio:RawPointer<MIX_Audio>):Int64;

    @:native("MIX_CreateTrack")
    public static function createTrack(mixer:RawPointer<MIX_Mixer>):RawPointer<MIX_Track>;
    @:native("MIX_DestroyTrack")
    public static function destroyTrack(track:RawPointer<MIX_Track>):Void;
    @:native("MIX_SetTrackAudio")
    public static function setTrackAudio(track:RawPointer<MIX_Track>, audio:RawPointer<MIX_Audio>):Bool;
    @:native("MIX_PlayTrack")
    public static function playTrack(track:RawPointer<MIX_Track>, options:UInt32):Bool;
    @:native("MIX_PlayAudio")
    public static function playAudio(mixer:RawPointer<MIX_Mixer>, audio:RawPointer<MIX_Audio>):Bool;
    @:native("MIX_StopTrack")
    public static function stopTrack(track:RawPointer<MIX_Track>, fadeOutFrames:Int64):Bool;
    @:native("MIX_PauseTrack")
    public static function pauseTrack(track:RawPointer<MIX_Track>):Bool;
    @:native("MIX_ResumeTrack")
    public static function resumeTrack(track:RawPointer<MIX_Track>):Bool;
    @:native("MIX_TrackPlaying")
    public static function trackPlaying(track:RawPointer<MIX_Track>):Bool;
    @:native("MIX_TrackPaused")
    public static function trackPaused(track:RawPointer<MIX_Track>):Bool;
    @:native("MIX_SetTrackGain")
    public static function setTrackGain(track:RawPointer<MIX_Track>, gain:Float32):Bool;
    @:native("MIX_GetTrackGain")
    public static function getTrackGain(track:RawPointer<MIX_Track>):Float32;
    @:native("MIX_SetTrackLoops")
    public static function setTrackLoops(track:RawPointer<MIX_Track>, loops:Int):Bool;
    @:native("MIX_SetTrackPlaybackPosition")
    public static function setTrackPlaybackPosition(track:RawPointer<MIX_Track>, frames:Int64):Bool;
    @:native("MIX_GetTrackPlaybackPosition")
    public static function getTrackPlaybackPosition(track:RawPointer<MIX_Track>):Int64;
    @:native("MIX_TrackMSToFrames")
    public static function trackMSToFrames(track:RawPointer<MIX_Track>, ms:Int64):Int64;
    @:native("MIX_TrackFramesToMS")
    public static function trackFramesToMS(track:RawPointer<MIX_Track>, frames:Int64):Int64;
    @:native("MIX_Generate")
    public static function generate(mixer:RawPointer<MIX_Mixer>, buffer:RawPointer<cpp.Void>, length:Int):Int;
}
#end
