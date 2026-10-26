// Norns engine. Lua calls these commands; the synth runs the Beads UGen.

Engine_Beads : CroneEngine {
	var <synth;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		SynthDef(\beads, {
			arg out, inL, inR, amp = 0.8,
				density = 0.22, densityCv = 0,
				time = 0.02, timeAtten = 0, timeCv = 0, timeHasCv = 0,
				size = 0.45, sizeAtten = 0, sizeCv = 0, sizeHasCv = 0,
				shape = 0.55, shapeAtten = 0, shapeCv = 0, shapeHasCv = 0,
				pitch = 0, pitchAtten = 0, pitchCv = 0, pitchHasCv = 0,
				feedback = 0.2, dryWet = 1, reverb = 0.25,
				freeze = 0, seed = 0, seedLock = 1,
				gate = 0, clockIn = 0,
				media = 3, mono = 0, outputGate = 0, synth = 0;

			var inputL = In.ar(inL, 1);
			var inputR = In.ar(inR, 1);
			var sig = Beads.ar(
				inputL, inputR,
				density, densityCv,
				time, timeAtten, timeCv, timeHasCv,
				size, sizeAtten, sizeCv, sizeHasCv,
				shape, shapeAtten, shapeCv, shapeHasCv,
				pitch, pitchAtten, pitchCv, pitchHasCv,
				feedback, dryWet, reverb,
				freeze, seed, seedLock,
				gate, clockIn,
				media, mono, outputGate, synth
			);
			Out.ar(out, sig * amp);
		}).add;

		context.server.sync;

		synth = Synth.new(\beads, [
			\inL, context.in_b[0].index,
			\inR, context.in_b[1].index,
			\out, context.out_b.index
		], context.xg);

		this.addCommand("amp", "f", { |msg| synth.set(\amp, msg[1]); });
		this.addCommand("density", "f", { |msg| synth.set(\density, msg[1]); });
		this.addCommand("density_cv", "f", { |msg| synth.set(\densityCv, msg[1]); });
		this.addCommand("time", "f", { |msg| synth.set(\time, msg[1]); });
		this.addCommand("time_atten", "f", { |msg| synth.set(\timeAtten, msg[1]); });
		this.addCommand("time_cv", "f", { |msg| synth.set(\timeCv, msg[1]); });
		this.addCommand("time_cv_on", "f", { |msg| synth.set(\timeHasCv, msg[1]); });
		this.addCommand("size", "f", { |msg| synth.set(\size, msg[1]); });
		this.addCommand("size_atten", "f", { |msg| synth.set(\sizeAtten, msg[1]); });
		this.addCommand("size_cv", "f", { |msg| synth.set(\sizeCv, msg[1]); });
		this.addCommand("size_cv_on", "f", { |msg| synth.set(\sizeHasCv, msg[1]); });
		this.addCommand("shape", "f", { |msg| synth.set(\shape, msg[1]); });
		this.addCommand("shape_atten", "f", { |msg| synth.set(\shapeAtten, msg[1]); });
		this.addCommand("shape_cv", "f", { |msg| synth.set(\shapeCv, msg[1]); });
		this.addCommand("shape_cv_on", "f", { |msg| synth.set(\shapeHasCv, msg[1]); });
		this.addCommand("pitch", "f", { |msg| synth.set(\pitch, msg[1]); });
		this.addCommand("pitch_atten", "f", { |msg| synth.set(\pitchAtten, msg[1]); });
		this.addCommand("pitch_cv", "f", { |msg| synth.set(\pitchCv, msg[1]); });
		this.addCommand("pitch_cv_on", "f", { |msg| synth.set(\pitchHasCv, msg[1]); });
		this.addCommand("feedback", "f", { |msg| synth.set(\feedback, msg[1]); });
		this.addCommand("dry_wet", "f", { |msg| synth.set(\dryWet, msg[1]); });
		this.addCommand("reverb", "f", { |msg| synth.set(\reverb, msg[1]); });
		this.addCommand("freeze", "f", { |msg| synth.set(\freeze, msg[1]); });
		this.addCommand("seed", "f", { |msg| synth.set(\seed, msg[1]); });
		this.addCommand("seed_lock", "f", { |msg| synth.set(\seedLock, msg[1]); });
		this.addCommand("gate", "f", { |msg| synth.set(\gate, msg[1]); });
		this.addCommand("clock_in", "f", { |msg| synth.set(\clockIn, msg[1]); });
		this.addCommand("media", "f", { |msg| synth.set(\media, msg[1]); });
		this.addCommand("mono", "f", { |msg| synth.set(\mono, msg[1]); });
		this.addCommand("output_gate", "f", { |msg| synth.set(\outputGate, msg[1]); });
		this.addCommand("synth", "f", { |msg| synth.set(\synth, msg[1]); });
	}

	free {
		synth.free;
	}
}
