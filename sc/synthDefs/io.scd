SynthDef(\bbIn, {

	var snd = SoundIn.ar([0, 1, 3, 2]); //Hardcoded but should never change, right?

	Out.ar(\directOut.kr(2), snd);

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\bbOut, {
	var in = In.ar(\in.kr(0), 4);
	var out = in.sum;
	out = BLowCut.ar(out, 32, 2);

	out = SafetyLimiter.ar(out, 0.2, 0.1);

	//Direct out, route to 2-5
	//FIXME: This should probably be taken from direct input
	//Out.ar(\directOut.kr(2), in);
	//Speaker out
	//Sounds better (maybe faulty wiring?) to invert phase on first channel
	Out.ar(\out.kr(0), [out.neg, out]);
}).add;

