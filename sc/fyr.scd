AD
{ SafetyLimiter.ar(BHiShelf.ar(SoundIn.ar(3).dup, 500, 1, -22) * 6) * -0.5 }.play
GC
{ SafetyLimiter.ar(BHiShelf.ar(SoundIn.ar(0).dup, 500, 1, -22) * 6) * -0.5 }.play



(
{
	var snd = SoundIn.ar((0..3)).sum;
	//filter
	//var fq = DelayC.ar(snd, 0.1, SoundIn.ar(2).range(0, 0.1));
	var amp = Amplitude.ar(snd, 0.01, 0.1);
	snd = BHiShelf.ar(snd, 500, 1, -22);
	//preamp + invert phase
	snd = snd * -9;
	snd = FreqShift.ar(snd, 0, SinOsc.ar(0.1).range(0, 2pi));
	//post
	SafetyLimiter.ar(HPF.ar(snd, 50)) * 0.5
}.play
)

CmdPeriod.freeRemote = true