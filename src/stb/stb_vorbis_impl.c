/*
 * stb_vorbis implementation unit.
 *
 * Including stb_vorbis.c without STB_VORBIS_HEADER_ONLY produces the full
 * decoder implementation.  This file is compiled once so the linker sees
 * exactly one copy of every symbol.
 */

#define STB_VORBIS_IMPLEMENTATION
#include "stb/stb_vorbis.c"

#include <stdlib.h>

/*
 * Convenience wrapper used by OpenAL.hx / TestOpenALState.
 *
 * Decodes a whole .ogg file into 16-bit signed PCM.
 *
 * Returns the number of samples decoded per channel (>= 0), or -1 on failure.
 * On success *pcm_out is heap-allocated; free it with openal_free_ogg_pcm().
 * *channels_out and *sample_rate_out are set on success.
 */
int openal_load_ogg(const char* path,
                    short**     pcm_out,
                    int*        channels_out,
                    int*        sample_rate_out)
{
    return stb_vorbis_decode_filename(path, channels_out, sample_rate_out, pcm_out);
}

/* Free PCM data returned by openal_load_ogg(). */
void openal_free_ogg_pcm(short* pcm)
{
    if (pcm) free(pcm);
}
