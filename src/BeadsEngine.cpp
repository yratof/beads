#include "BeadsEngine.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <new>

#include "beads/dsp/processor.h"
#include "beads/dsp/synth.h"

namespace {

constexpr int kChunk = 16;
constexpr size_t kBankBytes = 262144;
constexpr size_t kBanks = 3;
constexpr size_t kReverbSamples = 32768;

float Clamp(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

float Sanitize(float x) {
  if (x != x || x > 8.0f || x < -8.0f) return 0.0f;
  return x;
}

beads::RandomizedParameter MakeParam(
    float base, float atten, float cv, bool has_cv) {
  beads::RandomizedParameter p;
  p.base = base;
  p.attenuverter = Clamp(atten, -1.0f, 1.0f);
  p.cv = cv;
  p.has_cv = has_cv;
  return p;
}

}  // namespace

BeadsControls BeadsControlsDefault() {
  BeadsControls c;
  c.density = 0.22f;
  c.density_cv = 0.0f;
  c.time = 0.35f;
  c.time_atten = 0.0f;
  c.time_cv = 0.0f;
  c.size = 0.45f;
  c.size_atten = 0.0f;
  c.size_cv = 0.0f;
  c.shape = 0.55f;
  c.shape_atten = 0.0f;
  c.shape_cv = 0.0f;
  c.pitch = 0.0f;
  c.pitch_atten = 0.0f;
  c.pitch_cv = 0.0f;
  c.feedback = 0.2f;
  c.dry_wet = 1.0f;
  c.reverb = 0.25f;
  c.time_cv_on = false;
  c.size_cv_on = false;
  c.shape_cv_on = false;
  c.pitch_cv_on = false;
  c.freeze = false;
  c.seed = false;
  c.seed_lock = true;
  c.gate = false;
  c.clock_in = false;
  c.mono = false;
  c.output_gate = false;
  c.synth = false;
  c.media = beads::Processor::MEDIA_DIGITAL;
  return c;
}

struct BeadsEngine::Impl {
  Impl() : processor(nullptr), synth(nullptr), delay(nullptr), reverb(nullptr),
           previous_gate(stmlib::GATE_FLAG_LOW),
           applied_media(beads::Processor::MEDIA_DIGITAL),
           applied_mono(false),
           ready(false) {}

  beads::Processor* processor;
  beads::Synth* synth;
  uint8_t* delay;
  uint16_t* reverb;
  stmlib::GateFlags previous_gate;
  beads::Processor::Media applied_media;
  bool applied_mono;
  bool ready;

  void ProcessEven(
      const float* in_l,
      const float* in_r,
      float* out_l,
      float* out_r,
      int n,
      const BeadsControls& controls);
};

BeadsEngine::BeadsEngine() : impl_(new Impl) {
  impl_->delay = static_cast<uint8_t*>(std::calloc(kBanks * kBankBytes, 1));
  impl_->reverb = static_cast<uint16_t*>(
      std::calloc(kReverbSamples, sizeof(uint16_t)));
  if (!impl_->delay || !impl_->reverb) return;

  uint8_t* buffers[3] = {
    impl_->delay,
    impl_->delay + kBankBytes,
    impl_->delay + 2 * kBankBytes
  };

  impl_->processor = new beads::Processor();
  impl_->synth = new beads::Synth();
  impl_->processor->Init(buffers, impl_->reverb);
  impl_->synth->Init(impl_->reverb);
  impl_->ready = true;
}

BeadsEngine::~BeadsEngine() {
  delete impl_->processor;
  delete impl_->synth;
  std::free(impl_->delay);
  std::free(impl_->reverb);
  delete impl_;
}

void BeadsEngine::process(
    const float* in_l,
    const float* in_r,
    float* out_l,
    float* out_r,
    int n,
    const BeadsControls& controls) {
  if (n <= 0) return;
  if (!impl_->ready) {
    std::fill(out_l, out_l + n, 0.0f);
    std::fill(out_r, out_r + n, 0.0f);
    return;
  }

  if (n == 1) {
    const float in_l2[2] = {in_l[0], in_l[0]};
    const float in_r2[2] = {in_r[0], in_r[0]};
    float out_l2[2];
    float out_r2[2];
    impl_->ProcessEven(in_l2, in_r2, out_l2, out_r2, 2, controls);
    out_l[0] = out_l2[0];
    out_r[0] = out_r2[0];
    return;
  }

  const int even = n & ~1;
  impl_->ProcessEven(in_l, in_r, out_l, out_r, even, controls);
  if (even != n) {
    out_l[n - 1] = out_l[even - 1];
    out_r[n - 1] = out_r[even - 1];
  }
}

void BeadsEngine::Impl::ProcessEven(
    const float* in_l,
    const float* in_r,
    float* out_l,
    float* out_r,
    int n,
    const BeadsControls& controls) {
  const int media_index = std::max(0, std::min(3, controls.media));
  const beads::Processor::Media media =
      static_cast<beads::Processor::Media>(media_index);
  const bool mono = controls.mono;

  if (!controls.synth && (media != applied_media || mono != applied_mono)) {
    processor->Configure(media, mono);
    applied_media = media;
    applied_mono = mono;
  }

  beads::Parameters parameters;
  parameters.time = MakeParam(
      Clamp(controls.time, 0.0f, 1.0f),
      controls.time_atten,
      Clamp(controls.time_cv, -1.6f, 1.6f),
      controls.time_cv_on);
  parameters.size = MakeParam(
      Clamp(controls.size, 0.0f, 1.0f),
      controls.size_atten,
      Clamp(controls.size_cv, -1.6f, 1.6f),
      controls.size_cv_on);
  parameters.shape = MakeParam(
      Clamp(controls.shape, 0.0f, 1.0f),
      controls.shape_atten,
      Clamp(controls.shape_cv, -1.6f, 1.6f),
      controls.shape_cv_on);
  parameters.pitch = MakeParam(
      Clamp(controls.pitch, -24.0f, 24.0f),
      controls.pitch_atten,
      Clamp(controls.pitch_cv, -60.0f, 60.0f),
      controls.pitch_cv_on);
  parameters.monophonic_mode = false;

  beads::ModulatedParameter density;
  density.base = Clamp(controls.density, 0.0f, 1.0f);
  density.cv = Clamp(controls.density_cv, -1.0f, 1.0f);

  beads::Processor::MixParameters mix;
  mix.feedback = Clamp(controls.feedback, 0.0f, 1.0f);
  mix.dry_wet = Clamp(controls.dry_wet, 0.0f, 1.0f);
  mix.reverb_amount = Clamp(controls.reverb, 0.0f, 1.0f);
  mix.output_gate = controls.output_gate;

  beads::SeedButtonState seed_button = beads::SEED_BUTTON_STATE_OFF;
  if (controls.seed) {
    seed_button = beads::SEED_BUTTON_STATE_ON;
  } else if (controls.seed_lock) {
    seed_button = beads::SEED_BUTTON_STATE_LOCKED;
  }

  const beads::Synth::Resolution resolution =
      static_cast<beads::Synth::Resolution>(media_index);

  int done = 0;
  while (done < n) {
    const int chunk = std::min(kChunk, n - done);

    beads::FloatFrame in_frames[kChunk];
    beads::FloatFrame out_frames[kChunk];
    bool freeze[kChunk];
    stmlib::GateFlags seed_flags[kChunk];

    for (int i = 0; i < chunk; ++i) {
      in_frames[i].l = Sanitize(in_l[done + i]);
      in_frames[i].r = Sanitize(in_r[done + i]);
      freeze[i] = controls.freeze;
      if (controls.clock_in) {
        previous_gate = seed_flags[i] = stmlib::ExtractGateFlags(
            previous_gate, controls.gate);
      }
    }

    const stmlib::GateFlags* seed_input = controls.clock_in ? seed_flags : nullptr;

    if (controls.synth) {
      synth->Render(
          seed_button,
          seed_input,
          freeze,
          resolution,
          density,
          parameters,
          mix,
          out_frames,
          static_cast<size_t>(chunk));
    } else {
      processor->Process(
          seed_button,
          seed_input,
          freeze,
          density,
          parameters,
          mix,
          in_frames,
          out_frames,
          static_cast<size_t>(chunk));
    }

    for (int i = 0; i < chunk; ++i) {
      out_l[done + i] = out_frames[i].l;
      out_r[done + i] = out_frames[i].r;
    }
    done += chunk;
  }
}
