package;

import cpp.RawPointer;
import cpp.UInt32;
import cpp.ConstCharStar;

// ------------------------------------------------------------------
// Opaque ALC types — forward-declared in alc.h as opaque structs.
// ------------------------------------------------------------------

@:include("AL/alc.h")
@:native("ALCdevice")
extern class ALCdevice {}
typedef ALCDevicePtr = RawPointer<ALCdevice>;

@:include("AL/alc.h")
@:native("ALCcontext")
extern class ALCcontext {}
typedef ALCContextPtr = RawPointer<ALCcontext>;

// ------------------------------------------------------------------
// OAL — wraps ALC (device/context) + AL (buffers/sources) + the
//        stb_vorbis OGG loader helper.
//
// Build note: links OpenAL32.lib and compiles stb_vorbis_impl.c.
// ------------------------------------------------------------------

@:keep
@:buildXml('
<target id="haxe" if="windows">
    <lib name="${haxelib:haxe-native}/lib/x64/OpenAL32.lib"/>
</target>
<files id="haxe">
    <file name="${haxelib:haxe-native}/src/stb/stb_vorbis_impl.c"/>
    <file name="${haxelib:haxe-native}/src/openal_efx_impl.c"/>
</files>')
@:include("AL/al.h")
@:include("AL/alc.h")
@:include("AL/efx.h")
@:include("openal_ogg.h")
@:include("openal_efx.h")
extern class OAL {

    // ----------------------------------------------------------------
    // ALC — device / context management
    // ----------------------------------------------------------------

    /**
     * Open the named playback device.
     * Pass null to open the default OS audio device.
     */
    @:native("alcOpenDevice")
    static function openDevice(devicename:ConstCharStar):ALCDevicePtr;

    /** Close a device previously opened with openDevice(). */
    @:native("alcCloseDevice")
    static function closeDevice(device:ALCDevicePtr):Bool;

    /**
     * Create a context on the given device.
     * Pass null for attrlist to use default settings
     * (44100 Hz, stereo, etc. chosen by the driver).
     */
    @:native("alcCreateContext")
    static function createContext(device:ALCDevicePtr, attrlist:RawPointer<Int>):ALCContextPtr;

    /**
     * Make context the active context for the calling thread.
     * Pass null to detach the current context.
     */
    @:native("alcMakeContextCurrent")
    static function makeContextCurrent(context:ALCContextPtr):Bool;

    /** Resume processing for a suspended context. */
    @:native("alcProcessContext")
    static function processContext(context:ALCContextPtr):Void;

    /** Suspend processing for a context. */
    @:native("alcSuspendContext")
    static function suspendContext(context:ALCContextPtr):Void;

    /** Destroy a context. The context must not be current. */
    @:native("alcDestroyContext")
    static function destroyContext(context:ALCContextPtr):Void;

    // ----------------------------------------------------------------
    // AL — error
    // ----------------------------------------------------------------

    /** Obtain the current error code and reset the error state. */
    @:native("alGetError")
    static function getError():Int;

    // ----------------------------------------------------------------
    // AL constants — Buffer formats
    // ----------------------------------------------------------------

    @:native("AL_FORMAT_MONO8")    static var FORMAT_MONO8   (default, null):Int;
    @:native("AL_FORMAT_MONO16")   static var FORMAT_MONO16  (default, null):Int;
    @:native("AL_FORMAT_STEREO8")  static var FORMAT_STEREO8 (default, null):Int;
    @:native("AL_FORMAT_STEREO16") static var FORMAT_STEREO16(default, null):Int;

    // ----------------------------------------------------------------
    // AL constants — Source parameters
    // ----------------------------------------------------------------

    @:native("AL_BUFFER")       static var BUFFER      (default, null):Int;
    @:native("AL_LOOPING")      static var LOOPING     (default, null):Int;
    @:native("AL_GAIN")         static var GAIN        (default, null):Int;
    @:native("AL_PITCH")        static var PITCH       (default, null):Int;
    @:native("AL_SOURCE_STATE") static var SOURCE_STATE(default, null):Int;

    // ----------------------------------------------------------------
    // AL constants — Source states
    // ----------------------------------------------------------------

    @:native("AL_INITIAL") static var INITIAL(default, null):Int;
    @:native("AL_PLAYING") static var PLAYING(default, null):Int;
    @:native("AL_PAUSED")  static var PAUSED (default, null):Int;
    @:native("AL_STOPPED") static var STOPPED(default, null):Int;

    // ----------------------------------------------------------------
    // AL constants — Booleans / None
    // ----------------------------------------------------------------

    @:native("AL_TRUE")     static var TRUE    (default, null):Int;
    @:native("AL_FALSE")    static var FALSE   (default, null):Int;
    @:native("AL_NONE")     static var NONE    (default, null):Int;
    @:native("AL_NO_ERROR") static var NO_ERROR(default, null):Int;

    // ----------------------------------------------------------------
    // AL — Listener
    // (Use AL_GAIN with listenerf() to set overall output volume)
    // ----------------------------------------------------------------

    /** Set a scalar float listener property (e.g. AL_GAIN). */
    @:native("alListenerf")
    static function listenerf(param:Int, value:Float):Void;

    // ----------------------------------------------------------------
    // AL — Buffers
    // ----------------------------------------------------------------

    /**
     * Generate one buffer ID.
     * Wraps alGenBuffers(1, &id) for a single-buffer convenience call.
     */
    static inline function genBuffer():UInt32 {
        var id:UInt32 = 0;
        untyped __cpp__("alGenBuffers(1, &{0})", id);
        return id;
    }

    /**
     * Delete one buffer.
     * Wraps alDeleteBuffers(1, &id).
     */
    static inline function deleteBuffer(id:UInt32):Void {
        untyped __cpp__("alDeleteBuffers(1, &{0})", id);
    }

    /**
     * Upload raw PCM data into an already-generated buffer.
     * data must be a C pointer to the PCM bytes (e.g. short* from stb_vorbis).
     * size is the data size in **bytes** (not samples).
     * freq is the sample rate in Hz.
     */
    static inline function bufferData(buffer:UInt32, format:Int, data:cpp.RawPointer<cpp.Int16>, size:Int, freq:Int):Void {
        untyped __cpp__("alBufferData({0}, {1}, (const ALvoid*){2}, {3}, {4})", buffer, format, data, size, freq);
    }

    // ----------------------------------------------------------------
    // AL — Sources
    // ----------------------------------------------------------------

    /**
     * Generate one source ID.
     * Wraps alGenSources(1, &id).
     */
    static inline function genSource():UInt32 {
        var id:UInt32 = 0;
        untyped __cpp__("alGenSources(1, &{0})", id);
        return id;
    }

    /**
     * Delete one source.
     * Wraps alDeleteSources(1, &id).
     */
    static inline function deleteSource(id:UInt32):Void {
        untyped __cpp__("alDeleteSources(1, &{0})", id);
    }

    /** Set a scalar float source property (e.g. AL_GAIN, AL_PITCH). */
    @:native("alSourcef")
    static function sourcef(source:UInt32, param:Int, value:Float):Void;

    /** Set an integer source property (e.g. AL_BUFFER, AL_LOOPING). */
    @:native("alSourcei")
    static function sourcei(source:UInt32, param:Int, value:Int):Void;

    /**
     * Get an integer source property (e.g. AL_SOURCE_STATE).
     * Returns the value directly without needing an output pointer.
     */
    static inline function getSourcei(source:UInt32, param:Int):Int {
        var v:Int = 0;
        untyped __cpp__("alGetSourcei({0}, {1}, &{2})", source, param, v);
        return v;
    }

    /** Play (or restart) a source — sets state to AL_PLAYING. */
    @:native("alSourcePlay")
    static function sourcePlay(source:UInt32):Void;

    /** Pause a source — sets state to AL_PAUSED. */
    @:native("alSourcePause")
    static function sourcePause(source:UInt32):Void;

    /** Stop a source — sets state to AL_STOPPED. */
    @:native("alSourceStop")
    static function sourceStop(source:UInt32):Void;

    /** Rewind a source to AL_INITIAL without starting playback. */
    @:native("alSourceRewind")
    static function sourceRewind(source:UInt32):Void;

    // ----------------------------------------------------------------
    // stb_vorbis helper — decode a whole .ogg file to 16-bit PCM
    // (implemented in src/stb/stb_vorbis_impl.c)
    // ----------------------------------------------------------------

    /**
     * Decode a .ogg file from disk into interleaved 16-bit signed PCM.
     *
     * Returns the number of samples decoded **per channel**, or -1 on failure.
     * On success, pcmOut is allocated on the heap; call freeOggPcm() when done.
     * channelsOut and sampleRateOut are populated on success.
     */
    static inline function loadOgg(path:String,
                                   pcmOut:cpp.RawPointer<cpp.RawPointer<cpp.Int16>>,
                                   channelsOut:cpp.RawPointer<Int>,
                                   sampleRateOut:cpp.RawPointer<Int>):Int {
        return untyped __cpp__("openal_load_ogg({0}, {1}, {2}, {3})",
            @:privateAccess path.__s, pcmOut, channelsOut, sampleRateOut);
    }

    /** Free PCM memory returned by loadOgg(). */
    static inline function freeOggPcm(pcm:cpp.RawPointer<cpp.Int16>):Void {
        untyped __cpp__("openal_free_ogg_pcm({0})", pcm);
    }

    // ----------------------------------------------------------------
    // EFX — ALC_EXT_EFX (effects / reverb / echo / etc.)
    //
    // Must call efxInit() after the context is current.  All efx*
    // calls are safe to call even when EFX is unavailable — the C
    // layer just silently no-ops.
    // ----------------------------------------------------------------

    // EFX — Effect type constants (used with efxEffecti + EFFECT_TYPE)
    @:native("AL_EFFECT_TYPE")          static var EFFECT_TYPE         (default, null):Int;
    @:native("AL_EFFECT_NULL")          static var EFFECT_NULL         (default, null):Int;
    @:native("AL_EFFECT_REVERB")        static var EFFECT_REVERB       (default, null):Int;
    @:native("AL_EFFECT_CHORUS")        static var EFFECT_CHORUS       (default, null):Int;
    @:native("AL_EFFECT_DISTORTION")    static var EFFECT_DISTORTION   (default, null):Int;
    @:native("AL_EFFECT_ECHO")          static var EFFECT_ECHO         (default, null):Int;
    @:native("AL_EFFECT_FLANGER")       static var EFFECT_FLANGER      (default, null):Int;
    @:native("AL_EFFECT_PITCH_SHIFTER") static var EFFECT_PITCH_SHIFTER(default, null):Int;
    @:native("AL_EFFECT_RING_MODULATOR")static var EFFECT_RING_MODULATOR(default, null):Int;
    @:native("AL_EFFECT_AUTOWAH")       static var EFFECT_AUTOWAH      (default, null):Int;

    // EFX — Reverb parameters
    @:native("AL_REVERB_DENSITY")      static var REVERB_DENSITY     (default, null):Int;
    @:native("AL_REVERB_DIFFUSION")    static var REVERB_DIFFUSION   (default, null):Int;
    @:native("AL_REVERB_DECAY_TIME")   static var REVERB_DECAY_TIME  (default, null):Int;
    @:native("AL_REVERB_LATE_REVERB_GAIN") static var REVERB_LATE_GAIN(default, null):Int;

    // EFX — Echo parameters
    @:native("AL_ECHO_DELAY")    static var ECHO_DELAY   (default, null):Int;
    @:native("AL_ECHO_LRDELAY")  static var ECHO_LRDELAY (default, null):Int;
    @:native("AL_ECHO_FEEDBACK") static var ECHO_FEEDBACK(default, null):Int;
    @:native("AL_ECHO_SPREAD")   static var ECHO_SPREAD  (default, null):Int;

    // EFX — Chorus parameters
    @:native("AL_CHORUS_RATE")     static var CHORUS_RATE    (default, null):Int;
    @:native("AL_CHORUS_DEPTH")    static var CHORUS_DEPTH   (default, null):Int;
    @:native("AL_CHORUS_FEEDBACK") static var CHORUS_FEEDBACK(default, null):Int;

    // EFX — Flanger parameters
    @:native("AL_FLANGER_RATE")     static var FLANGER_RATE    (default, null):Int;
    @:native("AL_FLANGER_DEPTH")    static var FLANGER_DEPTH   (default, null):Int;
    @:native("AL_FLANGER_FEEDBACK") static var FLANGER_FEEDBACK(default, null):Int;

    // EFX — Distortion parameters
    @:native("AL_DISTORTION_EDGE") static var DISTORTION_EDGE(default, null):Int;
    @:native("AL_DISTORTION_GAIN") static var DISTORTION_GAIN(default, null):Int;

    // EFX — Ring modulator parameters
    @:native("AL_RING_MODULATOR_FREQUENCY") static var RING_MOD_FREQUENCY(default, null):Int;
    @:native("AL_RING_MODULATOR_WAVEFORM")  static var RING_MOD_WAVEFORM (default, null):Int;
    @:native("AL_RING_MODULATOR_SINUSOID")  static var RING_MOD_SINUSOID (default, null):Int;

    // EFX — Pitch shifter parameters
    @:native("AL_PITCH_SHIFTER_COARSE_TUNE") static var PITCH_COARSE_TUNE(default, null):Int;

    // EFX — Autowah parameters
    @:native("AL_AUTOWAH_ATTACK_TIME") static var AUTOWAH_ATTACK_TIME(default, null):Int;
    @:native("AL_AUTOWAH_RESONANCE")   static var AUTOWAH_RESONANCE  (default, null):Int;
    @:native("AL_AUTOWAH_PEAK_GAIN")   static var AUTOWAH_PEAK_GAIN  (default, null):Int;

    /**
     * Load EFX function pointers for the given device.
     * Must be called after makeContextCurrent().
     * Returns true if EFX is fully available.
     */
    static inline function efxInit(device:ALCDevicePtr):Bool {
        return untyped __cpp__("openal_efx_init({0}) != 0", device);
    }

    /** Create one EFX effect object and return its ID. */
    static inline function efxGenEffect():UInt32 {
        return untyped __cpp__("(unsigned int)openal_efx_gen_effect()");
    }

    /** Delete an EFX effect object. */
    static inline function efxDeleteEffect(effect:UInt32):Void {
        untyped __cpp__("openal_efx_delete_effect({0})", effect);
    }

    /** Set an integer property on an effect object (e.g. EFFECT_TYPE). */
    static inline function efxEffecti(effect:UInt32, param:Int, value:Int):Void {
        untyped __cpp__("openal_efx_effecti({0}, {1}, {2})", effect, param, value);
    }

    /** Set a float property on an effect object. */
    static inline function efxEffectf(effect:UInt32, param:Int, value:Float):Void {
        untyped __cpp__("openal_efx_effectf({0}, {1}, (float){2})", effect, param, value);
    }

    /** Create one auxiliary effect slot and return its ID. */
    static inline function efxGenSlot():UInt32 {
        return untyped __cpp__("(unsigned int)openal_efx_gen_slot()");
    }

    /** Delete an auxiliary effect slot. */
    static inline function efxDeleteSlot(slot:UInt32):Void {
        untyped __cpp__("openal_efx_delete_slot({0})", slot);
    }

    /**
     * Attach an effect to an auxiliary slot.
     * Pass effect=0 to detach and silence the slot.
     */
    static inline function efxSlotEffect(slot:UInt32, effect:UInt32):Void {
        untyped __cpp__("openal_efx_slot_effect({0}, {1})", slot, effect);
    }

    /** Route a source's wet signal through the given aux slot (send 0). */
    static inline function efxSourceConnect(source:UInt32, slot:UInt32):Void {
        untyped __cpp__("openal_efx_source_connect({0}, {1})", source, slot);
    }

    /** Remove the aux send from a source. */
    static inline function efxSourceDisconnect(source:UInt32):Void {
        untyped __cpp__("openal_efx_source_disconnect({0})", source);
    }
}
