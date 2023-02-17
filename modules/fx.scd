//FIXME
~modules.addModule(\volume, (
	desc: "Control volume with trill and IMU",
	rates: #[audio, control, control, scalar, scalar, scalar],
	func: { |snd, trill, imuPitchAmp, preamp=1, trillLag=0.25, ampLag=0.1|

		snd = snd * preamp;

		//Single-finger control
		snd = snd * trill.cubed.lag(trillLag);
		snd = snd * imuPitchAmp.lag(ampLag);

		snd
	}
));

~modules.addModule(\pitchSawFilter, (
	sizes: [1, 5, 1, 1],
	rates: #[audio, control, control, scalar],
	func: { |sig, trill, imuPitch, gain=1|
		var trillFreq = trill[2..3];
		var amp = trill[0].lag(0.01) * \gain.kr(1);
		var mul = 4 * trillFreq.mean.lag(3);
		var freq = (LFNoise1.ar(TRand.kr(0.05, 1.0, trill[4]), mul, mul + 1) * imuPitch.lag(0.01)).max(5).min(4800).lag(0.1);

		sig = BPF.ar(sig, freq, 0.05);
		sig * amp
	}
));

//TODO
/*
~modules.addModule(\tanhLimiter, (
	func: {
	var snd = In.ar(\in.kr(0), 1);
	var trill = In.kr(\trillBus.kr(0) + 2, 2);
	var val = (trill[0] - trill[1]).abs.linlin(0, 0.75, 5, 2);
	//val.poll(1, "tanh");

	snd = (snd * val).tanh / val;

	ReplaceOut.ar(\out.kr(0), snd);
}
)).add;
*/


~modules.addModule(\trill2FingerGain, (
	sizes: [1, 5],
	func: { |snd, trill|
		var val = ~modules.build(\trill2Fingers, trill, 1, 5);
		//Using a custom non-upsampled limiter here
		//https://github.com/nhthn/supercollider-safety-limiter
		//snd = SafetyLimiter.ar(snd * val) / val;
		snd * val;
	}
));


~modules.addModule(\allPass, (
	func: { |snd, freq|
		// var imuFreq = In.kr(\imuRollFreq.kr(0), 1).lag(0.3);
		snd + BAllPass.ar(snd, freq, 1);
	}
));

