SynthDef(\bbIn, {

	var snd = SoundIn.ar([0, 1, 3, 2]); //Hardcoded but should never change, right?

	Out.ar(\directOut.kr(2), snd);

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\bbOut, {
	var in = In.ar(\in.kr(0), 4);
	var out = Mix.fill(4, { |i|
		Pan2.ar(in[i], NamedControl.kr("pan%".format(i+1)));
	});

	out[0] = out[0].neg; //Sounds better (maybe faulty wiring?) to invert phase on first channel

	out = BLowCut.ar(out, 32, 2);

	//Direct out, route to 2-5
	//FIXME: This should probably be taken from direct input
	//Out.ar(\directOut.kr(2), in);
	//Speaker out
	Out.ar(\out.kr(0), out);
}).add;

