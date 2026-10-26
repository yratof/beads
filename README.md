# Beads for norns

A norns script that runs the Beads granular processor. The sound is Emilie Gillet's DSP from the [eurorack](https://github.com/pichenettes/eurorack/tree/master/beads) repository, wrapped as a SuperCollider engine. The Lua file is the panel: encoders, keys, and the params menu.

Beads records incoming audio into a buffer about four seconds long and plays it back as grains. With the seed running, density sets a periodic rate toward the left and a random spray toward the right. The middle waits for a tap or a clock. Pushing size to the top crossfades into the delay. The wavetable source is the internal oscillator Beads uses when nothing is patched into the module.

## Install

The folder on the norns has to be named `beads`, because the entry file is `beads.lua`. From maiden:

```
;install https://github.com/yratof/beads
```

The engine is a SuperCollider plugin, so it has to be compiled on the norns once. SSH in (`ssh we@norns.local`) and run:

```sh
cd ~/dust/code/beads
./build.sh
mkdir -p ~/.local/share/SuperCollider/Extensions/Beads
cp build/Beads.so ~/.local/share/SuperCollider/Extensions/Beads/
cp src/Beads.sc.txt ~/.local/share/SuperCollider/Extensions/Beads/Beads.sc
```

`build.sh` looks for the SuperCollider headers in `/usr/local/include/SuperCollider`, which is where a current norns image keeps them. Sleep and wake so SuperCollider loads the plugin and `lib/Engine_Beads.sc`. Select `beads`.

Leave `src/Beads.sc.txt` where it is. sclang compiles every `.sc` file under `dust`, and a second copy of the `Beads` class stops the server from booting.

If the headers are missing, set `SC_PATH` to a SuperCollider checkout of the same version maiden prints at boot (current norns is 3.13) and run `./build.sh` again. A plugin built against the wrong headers is refused when the server starts.

With no headers, `./build.sh` only builds the offline render test (`build/beads_render`), which writes `beads_granular.wav` and `beads_synth.wav`.

## Playing it

| Control | Does |
| --- | --- |
| E1 | Page: grain, spread, mix, tone, preset |
| E2 | Pick a control on the page |
| E3 | Change it |
| K2 | Freeze the buffer |
| K3 | Seed. A tap arms the clock (grains wait for taps). Hold K3 to go back to free running |

Grain is density, time, size, shape, and pitch. Time is a position in the buffer: low values are the audio that just arrived, high values are older. Pitch is semitones, from two octaves down to two octaves up.

Spread is the attenurandomizer on each of those, except density. At noon nothing extra happens. Away from noon, with no CV patched, the grain parameter is randomized. Positive and negative feel different: one is a steady wander, the other is occasional jumps. The CV rows in the params menu are the patched-jack behavior.

Mix is feedback, dry/wet, reverb, and output level. In wavetable mode, feedback picks the waveform bank.

Tone is the quality (dirty tape, clean tape, the Clouds-style setting, 16-bit), stereo or mono, audio input or wavetable, the norns clock as a seed clock, and whether the right output is audio or a gate.

Preset recalls settings described in the Beads manual. Feedback is the manual's test patch (dry/wet open, size at noon, density at 9 o'clock, shape at 2, time fully down, pitch up a semitone). Delay, slice, and comb are the delay section. Reverse is a backwards grain. Tap is one grain per seed press. Wavetable is the internal oscillator. Melody turns the pitch spread fully up so pitch CV tracks a keyboard.

MIDI defaults to pitch. Notes transpose around middle C. `pitch + seed` also holds the seed button for as long as a note is down.

Send audio to the norns inputs and turn the input up on the LEVELS page. Switch source to wavetable to hear Beads with nothing connected.

## License

The DSP in `vendor/beads` and `vendor/stmlib` is Copyright Emilie Gillet and released under the MIT license. The notice at the top of those files needs to stay with any copy. See `vendor/stmlib/LICENSE`. The norns script, SuperCollider engine, and build files are Copyright Andrew Smith and released under the same MIT license. See `LICENSE`.
