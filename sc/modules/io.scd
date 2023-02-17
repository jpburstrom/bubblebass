~modules.addModule(\bbIn, (
	desc: "Audio input",
	func: { |directOutBus=2, inputs=#[0, 1, 3, 2]|

		var snd = SoundIn.ar(inputs); //Hardcoded but should never change, right?

		Out.ar(\directOut.kr(2), snd);

		snd
	}
));

~modules.addModule(\bbOut, (
	desc: "Audio output, TODO simplify",
	sizes: [4],
	func: { |in, pitchBus, rollBus, outbus=0|
		var out = in;

		//---FYR---

		var amp = Amplitude.ar(out, 0.01, 0.1);
		var ampFast = amp.lag(0.5);
		var ampSlow = amp.lag(5);
		var ampDiff = (ampFast - ampSlow).abs;

		var tilt = In.kr(rollBus, 1);
		var shelf = In.kr(pitchBus, 1);


		//Här någon typ av waveshaping, per sträng
		out = out.tanh;
		//Compander verkar vara en rätt så bra
		out = Compander.ar(out, out, 0.3, 1, 0.25, 0.1, 1);

		//MONO BELOW
		out = out.sum;

		//Mappar roll till kort delay. TEST
		//out = DelayC.ar(out, 0.01, tilt.abs.linlin(0, 0.2, 0, 0.01).lag(0.1));

		//Open shelf when moving forwards
		out = BHiShelf.ar(out, 500, 1, shelf.linlin(-0.2, 0.2, -32, 0));

		//A small adjustment to make it a bit less boxy
		out = BPeakEQ.ar(out, 800, 1, -6);

		/* FYYYYR
		out = FreqShift.ar(out, 0,
		(LFSaw.ar(ampDiff.linlin(0, 0.05, 0.1, 0.01)).range(0, 2pi) + tilt.linlin(-0.2, 0.2, -pi, pi)).wrap(0, 2pi)
		);
		*/

		//out = FreqShift.ar(out.neg, 0, tilt.linlin(-0.2, 0.2, -pi, pi).wrap(0, 2pi));



		//Low cut filter to protect speakers. Previously a steeper filter at 32Hz.
		//might need further tweaking
		out = BLowCut.ar(out, 64, 1);
		//out = SafetyLimiter.ar(out, 0.2, 0.1) * 0.5;



		out = out.tanh * 0.667;

		//Direct out, route to 2-5
		//FIXME: This should probably be taken from direct input
		//Out.ar(\directOut.kr(2), in);
		//Speaker out
		Out.ar(outbus, out.dup);
	}
));

