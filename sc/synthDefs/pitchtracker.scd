SynthDef(\pitchTracker, {

	var square, trig, denom, pitch;
	var sig, insig = SinOsc.ar(20);
	var test;
	var maxFreq = 320;

	//Prefilter
	sig = BPF.ar(insig, 32.7, 0.06); //Too narrow rq?
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
	denom = (Latch.ar(sig, [1 - square, trig]).sum - 3).max(SampleRate.ir / maxFreq);

	sig = sig / denom.poll; // Final triangle wave
	pitch = max(0, SampleRate.ir / denom); //Pitch estimation

	//TODO bus output

}).play
