# Audio asset credits

## Waveform samples (lead_square.wav, bass_triangle.wav)

Single-cycle waveforms from **AKWF — Adventure Kid Waveforms** by Kristoffer Ekstrand.

- Source: https://github.com/KristofferKarlAxelEkstrand/AKWF-FREE
- License: **CC0 / Public Domain** — "To the extent possible under law, Kristoffer
  Ekstrand has waived all copyright and related or neighboring rights to AKWF Waveforms."
- No attribution is required, but it's recorded here as good practice.

Files used:
- `lead_square.wav`  ← `AKWF/AKWF_bw_squrounded/AKWF_rAsymSqu_01.wav` (rounded square — ingredient lead)
- `bass_triangle.wav` ← `AKWF/AKWF_bw_tri/AKWF_tri_0001.wav` (triangle — milk tonic bass)

Each is a 600-sample, 44.1 kHz, 16-bit mono single cycle → base frequency 73.5 Hz.
They are looped and retuned with `AudioStreamPlayer.pitch_scale` to play any note.
