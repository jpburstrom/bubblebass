AD
{ SafetyLimiter.ar(BHiShelf.ar(SoundIn.ar(3).dup, 500, 1, -22) * 6) * -0.5 }.play
GC
{ SafetyLimiter.ar(BHiShelf.ar(SoundIn.ar(0).dup, 500, 1, -22) * 6) * -0.5 }.play


//Med sinOsc
(
{
	var snd = SoundIn.ar((0..3)).sum;
	//filter
	//var fq = DelayC.ar(snd, 0.1, SoundIn.ar(2).range(0, 0.1));
	var amp = Amplitude.ar(snd, 0.01, 0.1).lag(1).poll;
	var int = Integrator.ar(amp, 0.99).poll;
	snd = BHiShelf.ar(snd, 500, 1, -22);
	//preamp + invert phase
	snd = snd * -9;
	snd = FreqShift.ar(snd, 0, SinOsc.ar(amp.linlin(0, 0.33, 0.01, 0.1)).range(0, 2pi));
	//post
	SafetyLimiter.ar(HPF.ar(snd.dup, 50)) * 0.31

}.play
)

//Osc freq påverkas av amplitudskifte
s.latency = 0
Spec.add(\phase, [0, 2pi])
(
Ndef(\test, {
	var snd = SoundIn.ar((0..3)).asArray.sum;
	//filter
	//var fq = DelayC.ar(snd, 0.1, SoundIn.ar(2).range(0, 0.1));
	var amp = Amplitude.ar(snd, 0.01, 0.1);
	var ampFast = amp.lag(0.5);
	var ampSlow = amp.lag(5);
	var ampDiff = (ampFast - ampSlow).abs;
	snd = BHiShelf.ar(snd, 500, 1, -12);
	//preamp + invert phase
	snd = snd * -9;
	snd = FreqShift.ar(snd, 0, LFSaw.ar(ampDiff.linlin(0, 0.05, 0.1, 0.001)).range(0, 2pi));
	//post
	SafetyLimiter.ar(HPF.ar(snd.dup, 50)) * 0.31

}).gui.play
)

CmdPeriod.freeRemote = true