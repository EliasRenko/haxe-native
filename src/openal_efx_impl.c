/*
 * openal_efx_impl.c
 *
 * EFX function pointers are loaded at runtime via alGetProcAddress because
 * the EFX entry points are NOT exported by the DLL's import library — they
 * must be queried after a context has been made current.
 */

#include <stddef.h>
#include "openal_efx.h"
#include "AL/efx.h"

/* ------------------------------------------------------------------ */
/* Static function pointer table                                       */
/* ------------------------------------------------------------------ */

static LPALGENEFFECTS              s_genEffects = NULL;
static LPALDELETEEFFECTS           s_delEffects = NULL;
static LPALEFFECTI                 s_effecti    = NULL;
static LPALEFFECTF                 s_effectf    = NULL;

static LPALGENAUXILIARYEFFECTSLOTS   s_genSlots = NULL;
static LPALDELETEAUXILIARYEFFECTSLOTS s_delSlots = NULL;
static LPALAUXILIARYEFFECTSLOTI      s_sloti    = NULL;

/* ------------------------------------------------------------------ */

int openal_efx_init(ALCdevice* device)
{
    if (!alcIsExtensionPresent(device, "ALC_EXT_EFX"))
        return 0;

    s_genEffects = (LPALGENEFFECTS)          alGetProcAddress("alGenEffects");
    s_delEffects = (LPALDELETEEFFECTS)       alGetProcAddress("alDeleteEffects");
    s_effecti    = (LPALEFFECTI)             alGetProcAddress("alEffecti");
    s_effectf    = (LPALEFFECTF)             alGetProcAddress("alEffectf");
    s_genSlots   = (LPALGENAUXILIARYEFFECTSLOTS)   alGetProcAddress("alGenAuxiliaryEffectSlots");
    s_delSlots   = (LPALDELETEAUXILIARYEFFECTSLOTS) alGetProcAddress("alDeleteAuxiliaryEffectSlots");
    s_sloti      = (LPALAUXILIARYEFFECTSLOTI) alGetProcAddress("alAuxiliaryEffectSloti");

    return (s_genEffects && s_delEffects && s_effecti && s_effectf &&
            s_genSlots  && s_delSlots   && s_sloti) ? 1 : 0;
}

/* ------------------------------------------------------------------ */

unsigned int openal_efx_gen_effect(void)
{
    ALuint id = 0;
    if (s_genEffects) s_genEffects(1, &id);
    return (unsigned int)id;
}

void openal_efx_delete_effect(unsigned int effect)
{
    ALuint id = (ALuint)effect;
    if (s_delEffects) s_delEffects(1, &id);
}

void openal_efx_effecti(unsigned int effect, int param, int value)
{
    if (s_effecti) s_effecti((ALuint)effect, (ALenum)param, (ALint)value);
}

void openal_efx_effectf(unsigned int effect, int param, float value)
{
    if (s_effectf) s_effectf((ALuint)effect, (ALenum)param, (ALfloat)value);
}

/* ------------------------------------------------------------------ */

unsigned int openal_efx_gen_slot(void)
{
    ALuint id = 0;
    if (s_genSlots) s_genSlots(1, &id);
    return (unsigned int)id;
}

void openal_efx_delete_slot(unsigned int slot)
{
    ALuint id = (ALuint)slot;
    if (s_delSlots) s_delSlots(1, &id);
}

void openal_efx_slot_effect(unsigned int slot, unsigned int effect)
{
    /* effect=0 (AL_NONE) detaches any current effect from the slot */
    if (s_sloti)
        s_sloti((ALuint)slot, AL_EFFECTSLOT_EFFECT, (ALint)effect);
}

/* ------------------------------------------------------------------ */

void openal_efx_source_connect(unsigned int source, unsigned int slot)
{
    /* Wire the wet (post-effect) output of 'slot' back to the source send 0 */
    alSource3i((ALuint)source, AL_AUXILIARY_SEND_FILTER,
               (ALint)slot, 0, AL_FILTER_NULL);
}

void openal_efx_source_disconnect(unsigned int source)
{
    alSource3i((ALuint)source, AL_AUXILIARY_SEND_FILTER,
               AL_EFFECTSLOT_NULL, 0, AL_FILTER_NULL);
}
