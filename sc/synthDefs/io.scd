SynthDef(\bbIn, {

	var snd = SoundIn.ar((0..3)); //Hardcoded but should never change, right?

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\bbOut, {
	var in = In.ar(\in.kr(0), 4);
	//TODO make this 4 separate controls
	var out = Mix.fill(4, { |i|
		Pan2.ar(in[i], NamedControl.kr("pan%".format(i+1)));
	});

	//Direct out, route to 2-5
	Out.ar(\directOut.kr(2), in);
	//Speaker out
	Out.ar(\out.kr(0), out);
}).add;
