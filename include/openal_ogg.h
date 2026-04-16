#pragma once
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Decode a whole .ogg file to interleaved 16-bit signed PCM via stb_vorbis.
 * Returns the number of samples per channel (>= 0), or -1 on failure.
 * On success, *pcm_out is heap-allocated; free it with openal_free_ogg_pcm().
 */
int openal_load_ogg(const char* path,
                    short**     pcm_out,
                    int*        channels_out,
                    int*        sample_rate_out);

/** Free PCM memory returned by openal_load_ogg(). */
void openal_free_ogg_pcm(short* pcm);

#ifdef __cplusplus
}
#endif
