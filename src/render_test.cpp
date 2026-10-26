// Offline render of the Beads engine. Confirms the DSP runs and makes sound.

#include "BeadsEngine.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr int kSampleRate = 48000;

void WriteWav(
    const std::string& path,
    const std::vector<float>& left,
    const std::vector<float>& right) {
  const uint32_t frames = static_cast<uint32_t>(left.size());
  const uint16_t channels = 2;
  const uint16_t bits = 16;
  const uint32_t data_bytes = frames * channels * (bits / 8);
  FILE* f = std::fopen(path.c_str(), "wb");
  if (!f) {
    std::perror(path.c_str());
    return;
  }
  const auto write_u16 = [&](uint16_t v) {
    std::fwrite(&v, 2, 1, f);
  };
  const auto write_u32 = [&](uint32_t v) {
    std::fwrite(&v, 4, 1, f);
  };
  std::fwrite("RIFF", 1, 4, f);
  write_u32(36 + data_bytes);
  std::fwrite("WAVE", 1, 4, f);
  std::fwrite("fmt ", 1, 4, f);
  write_u32(16);
  write_u16(1);
  write_u16(channels);
  write_u32(kSampleRate);
  write_u32(kSampleRate * channels * bits / 8);
  write_u16(channels * bits / 8);
  write_u16(bits);
  std::fwrite("data", 1, 4, f);
  write_u32(data_bytes);
  for (uint32_t i = 0; i < frames; ++i) {
    const auto sample = [](float x) {
      if (x > 1.0f) x = 1.0f;
      if (x < -1.0f) x = -1.0f;
      return static_cast<int16_t>(std::lrintf(x * 32767.0f));
    };
    const int16_t l = sample(left[i]);
    const int16_t r = sample(right[i]);
    std::fwrite(&l, 2, 1, f);
    std::fwrite(&r, 2, 1, f);
  }
  std::fclose(f);
}

struct Stats {
  double rms = 0.0;
  float peak = 0.0f;
  int non_finite = 0;
};

Stats Measure(const std::vector<float>& left, const std::vector<float>& right, int begin, int end) {
  Stats s;
  double sum = 0.0;
  int count = 0;
  for (int i = begin; i < end; ++i) {
    const float l = left[i];
    const float r = right[i];
    if (l != l || r != r || l > 1.0e6f || l < -1.0e6f || r > 1.0e6f || r < -1.0e6f) {
      s.non_finite += 1;
      continue;
    }
    const float a = std::max(std::fabs(l), std::fabs(r));
    if (a > s.peak) s.peak = a;
    sum += static_cast<double>(l) * l + static_cast<double>(r) * r;
    count += 2;
  }
  s.rms = count ? std::sqrt(sum / count) : 0.0;
  return s;
}

void Render(
    BeadsEngine& engine,
    const BeadsControls& controls,
    int frames,
    bool freeze_after,
    int freeze_frame,
    std::vector<float>* left,
    std::vector<float>* right) {
  left->assign(frames, 0.0f);
  right->assign(frames, 0.0f);
  constexpr int kBlock = 64;
  std::vector<float> in_l(kBlock), in_r(kBlock), out_l(kBlock), out_r(kBlock);
  for (int i = 0; i < frames; i += kBlock) {
    const int n = std::min(kBlock, frames - i);
    BeadsControls block = controls;
    if (freeze_after && i >= freeze_frame) block.freeze = true;
    for (int s = 0; s < n; ++s) {
      const int t = i + s;
      if (freeze_after && t >= freeze_frame) {
        in_l[s] = 0.0f;
        in_r[s] = 0.0f;
      } else {
        const float phase = 2.0f * 3.14159265f * static_cast<float>(t) / kSampleRate;
        in_l[s] = 0.45f * std::sin(phase * 220.0f);
        in_r[s] = 0.35f * std::sin(phase * 277.0f);
      }
    }
    engine.process(in_l.data(), in_r.data(), out_l.data(), out_r.data(), n, block);
    for (int s = 0; s < n; ++s) {
      (*left)[i + s] = out_l[s];
      (*right)[i + s] = out_r[s];
    }
  }
}

}  // namespace

int main() {
  int failures = 0;
  BeadsEngine engine;

  BeadsControls granular = BeadsControlsDefault();
  granular.synth = false;
  granular.media = 3;
  granular.seed_lock = true;
  granular.dry_wet = 1.0f;
  granular.reverb = 0.15f;
  granular.feedback = 0.15f;
  // Time is a position in the 4 second buffer. Keep it near the record head
  // so the test reads audio that has actually been captured.
  granular.time = 0.02f;

  const int frames = kSampleRate * 2;
  std::vector<float> left, right;
  Render(engine, granular, frames, true, kSampleRate, &left, &right);
  const Stats live = Measure(left, right, 0, kSampleRate);
  const Stats frozen = Measure(left, right, kSampleRate, frames);
  std::printf(
      "granular 16-bit, live half: rms %.4f peak %.3f bad %d\n",
      live.rms, live.peak, live.non_finite);
  std::printf(
      "granular 16-bit, frozen half: rms %.4f peak %.3f bad %d\n",
      frozen.rms, frozen.peak, frozen.non_finite);
  WriteWav("beads_granular.wav", left, right);
  if (frozen.non_finite || frozen.rms < 0.01 || frozen.peak > 2.0f) {
    std::printf("FAIL granular render\n");
    failures += 1;
  }

  const char* names[] = {"dirty tape", "clean tape", "clouds", "16-bit"};
  for (int media = 0; media < 4; ++media) {
    BeadsControls c = granular;
    c.media = media;
    c.reverb = 0.0f;
    Render(engine, c, kSampleRate / 2, true, kSampleRate / 4, &left, &right);
    const Stats s = Measure(left, right, kSampleRate / 4, kSampleRate / 2);
    std::printf(
        "media %s: rms %.4f peak %.3f bad %d\n",
        names[media], s.rms, s.peak, s.non_finite);
    if (s.non_finite || s.peak > 2.0f) {
      std::printf("FAIL media %s\n", names[media]);
      failures += 1;
    }
  }

  BeadsEngine synth_engine;
  BeadsControls synth = BeadsControlsDefault();
  synth.synth = true;
  synth.media = 3;
  synth.seed_lock = true;
  synth.dry_wet = 1.0f;
  synth.feedback = 0.4f;
  synth.reverb = 0.2f;
  synth.density = 0.3f;
  Render(synth_engine, synth, kSampleRate, false, 0, &left, &right);
  const Stats synth_stats = Measure(left, right, kSampleRate / 2, kSampleRate);
  std::printf(
      "wavetable: rms %.4f peak %.3f bad %d\n",
      synth_stats.rms, synth_stats.peak, synth_stats.non_finite);
  WriteWav("beads_synth.wav", left, right);
  if (synth_stats.non_finite || synth_stats.rms < 0.01 || synth_stats.peak > 2.0f) {
    std::printf("FAIL wavetable render\n");
    failures += 1;
  }

  if (failures) {
    std::printf("%d failure(s)\n", failures);
    return 1;
  }
  std::printf("ok\n");
  return 0;
}
