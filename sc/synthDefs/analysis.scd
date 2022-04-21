SynthDef(\pitchTracker, {

	var square, trig, denom, pitch;
	var sig, insig = In.ar(\in.kr(0), 1);
	var test;
	var maxFreq = 640;

	//Prefilter
	sig = BPF.ar(insig, \ffreq.kr(32.7), 0.06); //Too narrow rq?
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

	Out.kr(\outPitch.kr(0), pitch);


	Out.ar(\out.kr(0), sig * In.kr(\inAmp.kr(0), 1));

}).add;

SynthDef(\pitchTrackerKr, {

	var square, trig, denom, pitch;
	var sig, insig = In.ar(\in.kr(0), 1);
	var test;
	var maxFreq = 640;
	var aaFilterFreq = 500; //Control sample rate / 3

	//Prefilter
	sig = BPF.kr(A2K.kr(LPF.ar(insig, aaFilterFreq)), \ffreq.kr(32.7), 0.06); //Too narrow rq?
	//TODO add an adaptive filter - check the GR300 specs

	//Rectify
	square = (sig * 1e+07).clip(-1, 1) >= 0;
	//Square to +1 and -1 impulses
	sig = SOS.kr(square, 1, -1, 0, 0, 0);


	//Inverted trig for integrator below
	trig = BinaryOpUGen('!=', sig, 1);
	//Working integrator, see
	//https://github.com/supercollider/supercollider/issues/372
	//Here we create two sawtooth waves with half cycle offset
	sig = FOS.kr(DC.kr(1), DC.kr(1), DC.kr(0), [trig, BinaryOpUGen('!=', sig, -1)]);

	//Sample-and-hold both sawtooth waves halfway up
	//Sum and subtract a magic number
	//Denominator is sr / freq
	denom = (Latch.kr(sig, [1 - square, trig]).sum - 3).max(SampleRate.ir / maxFreq);

	sig = sig[0] / denom; // Final triangle wave
	pitch = max(0, SampleRate.ir / denom); //Pitch estimation

	//TODO bus output

	Out.kr(\outPitch.kr(0), pitch);


	Out.ar(\out.kr(0), K2A.ar(sig) * In.kr(\inAmp.kr(0), 1));

}).add;


SynthDef(\pitchTrackerFaust, {
	var pitch, sig, insig = In.ar(\in.kr(0), 4);
	var ffreq = \ffreq.kr([32.7, 48.99, 73.41, 110]);
	var tracker = GRPitchTracker4.ar(
		*(insig ++ ffreq)
	);
	//Group into 2 arrays: 4x pitch, 4x sawtooth wave
	#pitch, sig = tracker.clump(2).flop;

	Out.kr(\outPitch.kr(0), pitch);
	Out.ar(\out.kr(0),  K2A.ar(sig) * In.kr(\inAmp.kr(0), 4));
}).add;


SynthDef(\envFollow, {
	var sig = In.ar(\in.kr(0), 1);
	sig = sig.abs;
	sig = Slew.ar(sig, \up.ir(100), \down.ir(2));
	Out.kr(\out.kr(0), sig);
}).add;


