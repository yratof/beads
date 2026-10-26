// Host wrapper around the Beads DSP.
// The DSP itself is Emilie Gillet's, in vendor/beads (MIT).

#ifndef BEADS_ENGINE_H_
#define BEADS_ENGINE_H_

#include <cstddef>

struct BeadsControls {
  float density;
  float density_cv;
  float time;
  float time_atten;
  float time_cv;
  float size;
  float size_atten;
  float size_cv;
  float shape;
  float shape_atten;
  float shape_cv;
  float pitch;
  float pitch_atten;
  float pitch_cv;
  float feedback;
  float dry_wet;
  float reverb;
  bool time_cv_on;
  bool size_cv_on;
  bool shape_cv_on;
  bool pitch_cv_on;
  bool freeze;
  bool seed;
  bool seed_lock;
  bool gate;
  bool clock_in;
  bool mono;
  bool output_gate;
  bool synth;
  int media;
};

BeadsControls BeadsControlsDefault();

class BeadsEngine {
 public:
  BeadsEngine();
  ~BeadsEngine();

  BeadsEngine(const BeadsEngine&) = delete;
  BeadsEngine& operator=(const BeadsEngine&) = delete;

  // n is any block size. Tape modes need an even count internally;
  // a trailing odd sample is copied from the previous output.
  void process(
      const float* in_l,
      const float* in_r,
      float* out_l,
      float* out_r,
      int n,
      const BeadsControls& controls);

 private:
  struct Impl;
  Impl* impl_;
};

#endif  // BEADS_ENGINE_H_
