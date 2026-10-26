// SuperCollider unit generator. The audio thread calls BeadsEngine,
// which calls Emilie Gillet's Beads DSP.

#include "SC_PlugIn.h"

#include "BeadsEngine.h"

static InterfaceTable* ft;

struct Beads : public Unit {
  BeadsEngine* engine;
};

extern "C" {

void Beads_next(Beads* unit, int n);
void Beads_Ctor(Beads* unit, int);
void Beads_Dtor(Beads* unit);

void Beads_next(Beads* unit, int n) {
  BeadsControls c = BeadsControlsDefault();
  const float* in_l = IN(0);
  const float* in_r = IN(1);
  c.density = IN0(2);
  c.density_cv = IN0(3);
  c.time = IN0(4);
  c.time_atten = IN0(5);
  c.time_cv = IN0(6);
  c.time_cv_on = IN0(7) > 0.5f;
  c.size = IN0(8);
  c.size_atten = IN0(9);
  c.size_cv = IN0(10);
  c.size_cv_on = IN0(11) > 0.5f;
  c.shape = IN0(12);
  c.shape_atten = IN0(13);
  c.shape_cv = IN0(14);
  c.shape_cv_on = IN0(15) > 0.5f;
  c.pitch = IN0(16);
  c.pitch_atten = IN0(17);
  c.pitch_cv = IN0(18);
  c.pitch_cv_on = IN0(19) > 0.5f;
  c.feedback = IN0(20);
  c.dry_wet = IN0(21);
  c.reverb = IN0(22);
  c.freeze = IN0(23) > 0.5f;
  c.seed = IN0(24) > 0.5f;
  c.seed_lock = IN0(25) > 0.5f;
  c.gate = IN0(26) > 0.5f;
  c.clock_in = IN0(27) > 0.5f;
  c.media = static_cast<int>(IN0(28));
  c.mono = IN0(29) > 0.5f;
  c.output_gate = IN0(30) > 0.5f;
  c.synth = IN0(31) > 0.5f;

  unit->engine->process(in_l, in_r, OUT(0), OUT(1), n, c);
}

void Beads_Ctor(Beads* unit, int) {
  SETCALC(Beads_next);
  unit->engine = new BeadsEngine();
  Beads_next(unit, 1);
}

void Beads_Dtor(Beads* unit) {
  delete unit->engine;
  unit->engine = nullptr;
}

}  // extern "C"

PluginLoad(Beads) {
  ft = inTable;
  DefineDtorUnit(Beads);
}
