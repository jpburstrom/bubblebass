~modules.addModule(\digitalOut, (
	desc: "Wrapper for Bela DigitalOut UGen",
	func: value {
		var fallbackBus;
		{ |pin, val, rate=\kr|
			if (~isBela.not and: { ~server != ~belaServer }) {
				var key = "digitalOut_%".format(pin);
				fallbackBus ?? {
					fallbackBus = (
						kr: Bus.control(~server, 32),
						ar: Bus.audio(~server, 32)
					)
				};
				"Can't use DigitalOut, fallback to fake bus".warn;
				Out.perform(rate, fallbackBus[rate].subBus(pin).index, val);
			} {
				DigitalOut.perform(rate, pin, val);
			}
		}
	}
));

~modules.addModule(\allLedsSet, (
	desc: "Loop over leds with an input",
	func: { |input, freeSynth=false, rate=\kr, rgbPins=#[8, 9, 11]|
		rgbPins.size.do { |i| ~modules.build(\digitalOut, rgbPins[i], input.value(i), rate) };
		if (freeSynth) {
			FreeSelf.kr(Impulse.kr(0));
		}
	}
));

~modules.addModule(\allLedsOff, (
	desc: "Turn off all leds and free synth",
	func: {	|freeSynth=false|
		~modules.build(\allLedsSet, 0, freeSynth);
	}
));

~modules.addModule(\allLedsOn, (
	desc: "Turn on all leds and free synth",
	func: {	|freeSynth=false|
		~modules.build(\allLedsSet, 1, freeSynth);
	}
));


~modules.addModule(\ledCount3, (
	desc: "Display a led (rgb) according to value of count (1-3)",
	func: { |count=0, freeSynth=false|
		~modules.build(\allLedsSet, { |i|
			BinaryOpUGen('==', i + 1, count)
		}, freeSynth)
	}
));


~modules.addModule(\ledCount7, (
	desc: "Display a binary value (1-7)",
	func: { |count=0, freeSynth=false|
		~modules.build(\allLedsSet, { |i|
			var n = 1 << i;
			BinaryOpUGen('==', n, n & count)
		}, freeSynth)
	}
));


~modules.addModule(\ledBus, (
	desc: "Display LED values from 3 buses",
	func: { |inBus=0, resetBus=0, freeSynth=false|
		var bus = In.kr(inBus, 3);
		var reset = Changed.kr(In.kr(resetBus));
		~modules.build(\allLedsSet, { |i|
			(bus[i] - reset).abs
		}, freeSynth)
	}
));


~modules.addModule(\threeStateToLed, (
	desc: "Display incoming value [2,4,8] as [r,g,b]",
	func: { |val=1|
		var outvals;
		val = val >> 2;
		~modules.build(\allLedsSet, { |i|
			BinaryOpUGen('==', i, val)
		});
	}
));

~modules.addModule(\threeStateToLedBus, (
	desc: "Display incoming value [2,4,8] over three buses, to use with \ledBus module",
	func: { |val=1, outbus=0, rate=\kr|
		var outvals;
		val = val >> 2;
		Out.perform(rate, outbus, 3.collect({ |i|
			BinaryOpUGen('==', i, val)
		}).postln);
	}
));


~modules.addModule(\imuBusToLed, (
	desc: "Display values from IMU bus as [r, g, b] pulse freq",
	func: { |imuBus=0|
		var val = In.kr(imuBus, 3).abs * 2; //.linlin(0, 0.5, 0, 1)
		val = LFPulse.ar(50, 0, val).postln;
		~modules.build(\allLedsSet, { |i| val[i] }, false, \ar);
	}

));


