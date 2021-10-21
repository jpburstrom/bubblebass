SynthDef(\bbIn, {

	var snd = SoundIn.ar((0..3)); //Hardcoded but should never change, right?

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\bbOut, {
	var in = In.ar(\in.kr(0), 4);
	//TODO make this 4 separate controls
	var pan = \pan4.kr(0.5.dup(4)).linlin(0, 1, -1, 1);
	var out = Mix.fill(4, { |i|
		Pan2.ar(in[i], pan[i]);
	});

	//Direct out, route to 2-5
	Out.ar(\directOut.kr(2), in);
	//Speaker out
	Out.ar(\out.kr(0), out);
}).add;
