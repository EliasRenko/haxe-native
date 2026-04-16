#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "AL/alc.h"
#include "AL/al.h"

/**
 * openal_efx.h — thin C wrappers around EFX (ALC_EXT_EFX).
 *
 * The EFX functions are not linked — they are loaded at runtime via
 * alGetProcAddress in openal_efx_init().  Call openal_efx_init() once
 * after making a context current and check its return value before
 * using any other function here.
 */

/**
 * Load EFX function pointers for the given device.
 * Returns 1 if the extension is present and all pointers loaded successfully,
 * 0 otherwise (EFX unavailable on this device/driver).
 */
int openal_efx_init(ALCdevice* device);

/* ------------------------------------------------------------------ */
/* Effect object management                                            */
/* ------------------------------------------------------------------ */

/** Create one AL effect object. Returns the ALuint ID (0 on failure). */
unsigned int openal_efx_gen_effect(void);

/** Delete an AL effect object created with openal_efx_gen_effect(). */
void openal_efx_delete_effect(unsigned int effect);

/** Set an integer property on an effect (e.g. AL_EFFECT_TYPE, AL_PITCH_SHIFTER_COARSE_TUNE). */
void openal_efx_effecti(unsigned int effect, int param, int value);

/** Set a float property on an effect. */
void openal_efx_effectf(unsigned int effect, int param, float value);

/* ------------------------------------------------------------------ */
/* Auxiliary effect slot management                                    */
/* ------------------------------------------------------------------ */

/** Create one auxiliary effect slot. Returns the ALuint ID (0 on failure). */
unsigned int openal_efx_gen_slot(void);

/** Delete an auxiliary effect slot. */
void openal_efx_delete_slot(unsigned int slot);

/**
 * Attach an effect to an auxiliary slot.
 * Pass effect=0 (AL_NONE) to detach any current effect from the slot.
 */
void openal_efx_slot_effect(unsigned int slot, unsigned int effect);

/* ------------------------------------------------------------------ */
/* Source routing                                                      */
/* ------------------------------------------------------------------ */

/**
 * Route a source's wet signal through the given auxiliary slot (send index 0).
 * Call once after creating source + slot; then toggle effects via
 * openal_efx_slot_effect() without re-routing the source.
 */
void openal_efx_source_connect(unsigned int source, unsigned int slot);

/**
 * Remove the auxiliary send routing from a source (sends to AL_EFFECTSLOT_NULL).
 */
void openal_efx_source_disconnect(unsigned int source);

#ifdef __cplusplus
}
#endif
