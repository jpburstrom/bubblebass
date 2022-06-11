SynthDef(\bbIn, {

	var snd = SoundIn.ar([0, 1, 3, 2]); //Hardcoded but should never change, right?

	Out.ar(\directOut.kr(2), snd);

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\bbOut, {
	var in = In.ar(\in.kr(0), 4);
	var out = in.sum;

	//---FYR---

	var amp = Amplitude.ar(out, 0.01, 0.1);
	var ampFast = amp.lag(0.5);
	var ampSlow = amp.lag(5);
	var ampDiff = (ampFast - ampSlow).abs;

	var tilt = In.kr(\rollBus.kr(0), 1);
	var shelf = In.kr(\pitchBus.kr(0), 1);


	out = BHiShelf.ar(out, 500, 1, shelf.linlin(-0.2, 0.2, -24, 0));

	/* FYYYYR
	out = FreqShift.ar(out, 0,
		(LFSaw.ar(ampDiff.linlin(0, 0.05, 0.1, 0.01)).range(0, 2pi) + tilt.linlin(-0.2, 0.2, -pi, pi)).wrap(0, 2pi)
		);
	*/

	//out = FreqShift.ar(out.neg, 0, tilt.linlin(-0.2, 0.2, -pi, pi).wrap(0, 2pi));



	out = BLowCut.ar(out, 32, 2);
	out = SafetyLimiter.ar(out, 0.2, 0.1) * 0.5;

	//Direct out, route to 2-5
	//FIXME: This should probably be taken from direct input
	//Out.ar(\directOut.kr(2), in);
	//Speaker out
	//Sounds better to invert phase
	Out.ar(\out.kr(0), [out, out.neg]);
}).add;

