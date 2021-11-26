/*
var softSnap = { |val|
	var rounded, parts = 8;
	val = val * parts;
	rounded = val.round;
	val = rounded + ((val - rounded) * ((rounded - val) * 2).abs.pow(4));
	val / parts;
};
*/
var softSnapScale = { |val, start=1, end=8, curve=4|
	//Snap with curvature
	//Rescales from 1->parts
	var env = Env((start, start + 0.5 .. end), 0.5/(end - start), [curve, curve.neg]);
//	env.plot;
	IEnvGen.kr(env, val);
};

SynthDef(\combShifter, {
	var snd = In.ar(\in.kr(0), 4);
	var trill = In.kr(\trillBus.kr(0), 5);
	var amp = In.kr(\envFollowBus.kr(0), 4);
	var roll = In.kr(\imuBus.kr(0), 1);
	var pitch = \pitch.kr(50.dup(4), 0.75, true); //lag 0.75 = lop~ 1
	//Pitch multiplier from single-finger trill
	var pitchmul = trill[0];
	var amt = amp.linlin(0, 1, trill[2], trill[3]);
	pitchmul = softSnapScale.value(pitchmul, 1, 8);

	snd = snd + DelayC.ar(snd, 0.1, (pitch * 8).reciprocal * pitchmul, amt);
	Out.ar(\out.kr(0), snd);
}).add;


//FIXME
SynthDef(\volume, {
	var snd = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0), 1);
	var imuPitch = In.kr(\imuBus.kr(0), 1);

	snd = snd * \preamp.ir(1);

	//Single-finger control
	snd = snd * trill; //TODO lag
	snd = snd * 2.pow(imuPitch.linlin(-0.3, 0.4, -1, 1)); //TODO wider zero

	ReplaceOut.ar(\out.kr(0), snd);
}).add;


//FIXME
SynthDef(\compressor, {
	var snd = In.ar(\in.kr(0), 4);
	var trill = In.kr(\trillBus.kr(0) + 1, 2);
	var imuPitch = In.kr(\imuBus.kr(0), 1);
	var amp = In.kr(\envFollowBus.kr(0), 4);

	//TODO check trill hi, lo order
	//TODO set range
	//TODO lag
	var compdb = (trill[0] - trill[1]).linlin(0, 0.5, \dbHi.ir(0), \dbLo.ir(-32));
	var speed = trill[1];

	//TODO compress snd
	//TODO makeup gain

	Out.ar(\out.kr(0), snd);
});