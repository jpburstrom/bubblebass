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

SynthDef(\freqShiftx4, {
	var snd = In.ar(0, 4);
	var yaw = In.kr(\imuBus.kr(0), 1);
	var lpFast = LPF.kr(yaw, 1);
	var lpSlow = LPF.kr(yaw, 0.1);
	var diff = (lpFast - lpSlow);
	var freq = diff.linlin(0, 0.2, -100, 100);

	var fx = BLowCut.ar(snd, freq.neg.max(5));

	//fx = FreqShift.ar(fx, freq);

	//ReplaceOut.ar(\out.kr, snd);
}).add;

/*
{ Out.ar(4, SinOsc.ar * 0.1) }.play(addAction: \addToTail)
x = List();
(

x.add(Synth(\combShifter), ~groups.fx1);
x.add(Synth(\freqShift), ~groups.fx1);
)
x.do(_.free)

~synths.keys

~synths[\keyDn].do(_.free)
*/


//FIXME
SynthDef(\volume, {
	var snd = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0), 1);
	var imuPitchAmp = In.kr(\imuPitchAmp.kr(0), 1);

	snd = snd * \preamp.ir(1);

	//Single-finger control
	snd = snd * trill.cubed.lag(\trillLag.kr(0.25));
	snd = snd * imuPitchAmp.lag(0.1);

	ReplaceOut.ar(\out.kr(0), snd);
}).add;


//TODO saw filter thing
SynthDef(\pitchSawFilter, {
	var sig = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0), 5);
	var pitch = In.kr(\pitchBus.kr(0), 1).lag(0.01);
	var trillFreq = trill[2..3];
	var amp = trill[0].lag(0.01) * \gain.kr(1);
	var mul = 4 * trillFreq.mean.lag(3);
	var freq = (LFNoise1.ar(TRand.kr(0.05, 1.0, trill[4]), mul, mul + 1) * pitch).max(5).min(4800).lag(0.1);

	sig = BPF.ar(sig, freq, 0.05);

	Out.ar(\out.kr(0), sig * amp)

}).add;

SynthDef(\tanhLimiter, {
	var snd = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0) + 2, 2);
	var val = (trill[0] - trill[1]).abs.linlin(0, 0.75, 5, 2);
	//val.poll(1, "tanh");

	snd = (snd * val).tanh / val;

	ReplaceOut.ar(\out.kr(0), snd);
}).add;

SynthDef(\preLimiterGain, {
	var snd = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0) + 2, 2);
	var val = (trill[0] - trill[1]).abs.linlin(0, 0.75, 5, 1);
	//Using a custom non-upsampled limiter here
	//https://github.com/nhthn/supercollider-safety-limiter
	//snd = SafetyLimiter.ar(snd * val) / val;
	ReplaceOut.ar(\out.kr(0), snd);
}).add;

SynthDef(\allPass, {
	var snd = In.ar(\in.kr(0), 4);
	var imuFreq = In.kr(\imuRollFreq.kr(0), 1).lag(0.3);
	snd = snd + BAllPass.ar(snd, imuFreq, 1);
	ReplaceOut.ar(\out.kr(0), snd);
}).add;

SynthDef(\fyr, {
	var snd = In.ar(\in.kr(0), 4);
	var amp = In.ar(\ampBus.kr(0), 1);
	var phase = LFSaw.ar(amp.linlin(0, 0.05, 0.1, 0.001)).range(0, 2pi);

	var fx = Hilbert.ar(snd) * (phase + [ 0.5*pi, 0.0 ]);
	ReplaceOut.ar(\out.kr, snd);
}).add;
