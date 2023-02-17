SynthDef(\testTone, {
	var trill = In.kr(\trillBus.kr(0), 5);
	var amp = trill[0];
	var pan = trill[2..3].mean.linlin(0.2, 0.8, 0, 1);
	var snd = SinOsc.ar(\freq.kr(110));
	snd = snd * amp * \gain.ir(0.1);
	snd = Pan2.ar(snd, pan);
	Out.ar(\out.kr(0), snd)
}).add;
