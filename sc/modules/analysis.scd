~modules.addModule(\pitchTracker4_SC, (
	desc: "Pitch tracker loosely modeled after Roland GR-300, SC version",
	func: { |in, ffreq, inAmp|

	var square, trig, denom, pitch;
	var sig;
	var test;
	var maxFreq = 640;

	//Prefilter
	sig = BPF.ar(in, ffreq, 0.06); //Too narrow rq?
	//TODO add an adaptive filter - check the GR300 specs

	//Rectify
	square = (sig * 1e+07).clip(-1, 1) >= 0;
	//Square to +1 and -1 impulses
	sig = SOS.ar(square, 1, -1, 0, 0, 0);


	//Inverted trig for integrator below
	trig = BinaryOpUGen('!=', sig, 1);
	//Working integrator, see
	//https://github.com/supercollider/supercollider/issues/372
	//Here we create two sawtooth waves with half cycle offset
	sig = FOS.ar(DC.ar(1), DC.ar(1), DC.ar(0), [trig, BinaryOpUGen('!=', sig, -1)]);

	//Sample-and-hold both sawtooth waves halfway up
	//Sum and subtract a magic number
	//Denominator is sr / freq
	denom = A2K.kr(Latch.ar(sig, [1 - square, trig]).sum - 3).max(SampleRate.ir / maxFreq);

	sig = sig[0] / denom; // Final triangle wave
	pitch = max(0, SampleRate.ir / denom); //Pitch estimation

	//TODO bus output

	[pitch, K2A.ar(sig) * inAmp]

}));

//Pitch tracker from above, rebuilt in Faust
~modules.addModule(\pitchTracker4, (
	desc: "Pitch tracker loosely modeled after Roland GR-300, Faust version",
	rates: [\audio, \control, \control],
	sizes: [4, 4, 4],
	func: { |in, ffreq, inAmp|
		var pitch, sig, tracker;

		tracker = GRPitchTracker4.ar(
			*(in ++ ffreq)
		);
		//Group into 2 arrays: 4x pitch, 4x sawtooth wave
		#pitch, sig = tracker.clump(2).flop;

		[pitch, K2A.ar(sig) * inAmp]

	}
));

//Simple envelope follower
~modules.addModule(\envFollow, (
	desc: "Simple Slew-based envelope follower",
	rates: [\audio, \scalar, \scalar, \scalar],
	specs: (
		up: ControlSpec(20, 800, step: 0.1, default: 100), //arbitrary range, check this
		down: ControlSpec(0.1, 100, default: 2), //arbitrary range, check this
	),
	func: { |sig, up=100, down=2|
		sig = sig.abs;
		Slew.ar(sig, up, down);
	}
));

