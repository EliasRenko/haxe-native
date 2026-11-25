import SDLMixer;
import SDLMixer.MixerAudioSpec;
import SDLMixer.MixerAudioFormat;

@:include("SDL3/SDL.h")
@:buildXml('
<target id="haxe" if="windows">
  <lib name="${haxelib:haxe-native}/lib/x64/SDL3.lib"/>
</target>
')
private extern class SDLTest {
    @:native("SDL_GetError")
    static function getError():cpp.ConstCharStar;
}

class SDLMixerSmoke {
    static function check(ok:Bool, operation:String):Void {
        if (!ok) throw operation + ": " + SDLTest.getError().toString();
    }

    static function main():Void {
        check(SDLMixer.init(), "MIX_Init");
        var spec:cpp.RawPointer<MixerAudioSpec> = untyped __cpp__("new SDL_AudioSpec{}");
        cpp.Pointer.fromRaw(spec).ref.format = MixerAudioFormat.F32;
        cpp.Pointer.fromRaw(spec).ref.channels = 2;
        cpp.Pointer.fromRaw(spec).ref.freq = 48000;
        var offlineMixer = SDLMixer.createMixer(spec);
        check(offlineMixer != null, "MIX_CreateMixer");
        check(SDLMixer.getMixerFormat(offlineMixer, spec), "MIX_GetMixerFormat");
        check(cpp.Pointer.fromRaw(spec).ref.channels == 2, "mixer channel count");
        check(cpp.Pointer.fromRaw(spec).ref.freq == 48000, "mixer sample rate");
        var offlineAudio = SDLMixer.createSineWaveAudio(offlineMixer, 440, 0.5, 1000);
        check(offlineAudio != null, "MIX_CreateSineWaveAudio");
        check(SDLMixer.playAudio(offlineMixer, offlineAudio), "MIX_PlayAudio");
        var buffer = haxe.io.Bytes.alloc(4096);
        var bufferPtr = cpp.NativeArray.address(buffer.getData(), 0).rawCast();
        check(SDLMixer.generate(offlineMixer, bufferPtr, buffer.length) == buffer.length, "MIX_Generate");
        var nonzero = false;
        for (i in 0...buffer.length) if (buffer.get(i) != 0) nonzero = true;
        check(nonzero, "generated audio is silent");
        SDLMixer.destroyAudio(offlineAudio);
        SDLMixer.destroyMixer(offlineMixer);
        untyped __cpp__("delete {0}", spec);
        var mixer = SDLMixer.createMixerDevice(SDLMixer.DEFAULT_PLAYBACK_DEVICE, null);
        check(mixer != null, "MIX_CreateMixerDevice");
        var args = Sys.args();
        if (args.length > 0) {
            var fileAudio = SDLMixer.loadAudio(mixer, args[0], true);
            check(fileAudio != null, "MIX_LoadAudio");
            SDLMixer.destroyAudio(fileAudio);
        }
        var audio = SDLMixer.createSineWaveAudio(mixer, 440, 0.5, 10000);
        check(audio != null, "MIX_CreateSineWaveAudio");
        var track = SDLMixer.createTrack(mixer);
        check(track != null, "MIX_CreateTrack");
        check(SDLMixer.setTrackAudio(track, audio), "MIX_SetTrackAudio");
        check(SDLMixer.setTrackGain(track, 0.5), "MIX_SetTrackGain");
        check(Math.abs(SDLMixer.getTrackGain(track) - 0.5) < 0.001, "MIX_GetTrackGain");
        check(SDLMixer.playTrack(track, 0), "MIX_PlayTrack");
        check(SDLMixer.pauseTrack(track), "MIX_PauseTrack");
        check(SDLMixer.trackPaused(track), "MIX_TrackPaused");
        check(SDLMixer.resumeTrack(track), "MIX_ResumeTrack");
        check(SDLMixer.stopTrack(track, 0), "MIX_StopTrack");
        check(!SDLMixer.trackPlaying(track), "MIX_TrackPlaying");
        SDLMixer.destroyTrack(track);
        SDLMixer.destroyAudio(audio);
        SDLMixer.destroyMixer(mixer);
        SDLMixer.quit();
        trace("SDL_mixer smoke test passed");
    }
}
