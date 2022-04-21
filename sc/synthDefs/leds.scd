(
var rgb = [8, 9, 11];

SynthDef(\allLedsOff, {
	rgb.do { |i| DigitalOut.kr(i, 0) };
	FreeSelf.kr(Impulse.kr(0))
}).add;


SynthDef(\allLedsOn, {
	rgb.do { |i| DigitalOut.kr(i, 1) };
	FreeSelf.kr(Impulse.kr(0))
}).add;

SynthDef(\ledCount3, {
	var count = \count.ir(0);
	rgb.do { |pin, i|
		DigitalOut.kr(pin, BinaryOpUGen('==', i + 1, count))
	};
	FreeSelf.kr(Impulse.kr(0))
}).add;

SynthDef(\ledCount7, {
	var count = \count.ir(0);
	rgb.do { |pin, i|
		var n = 2.pow(i);
		DigitalOut.kr(pin, BinaryOpUGen('==', n, n & count))
	};
	FreeSelf.kr(Impulse.kr(0))
}).add;

SynthDef(\ledBus, {
	var bus = In.kr(\inbus.ir(0), 3);
	rgb.do { |pin, i|
		DigitalOut.kr(pin, bus[i])
	}
}).add;

SynthDef(\ledLog2ToBus, {
	var outvals, val = In.kr(\inbus.kr(0), 1);
	val = val.log2;
	outvals = 3.collect { |i|
		BinaryOpUGen('==', i + 1, val)
	};
	Out.kr(\out.kr(0), Select.kr(Changed.kr(val), [In.kr(\out.kr, 3), outvals]));
}).add;

SynthDef(\ledImuToBus, {
	var val = In.kr(\imubus.kr(0), 3);
	val = val.abs * 2; //.linlin(0, 0.5, 0, 1)
	val = LFPulse.ar(50, 0, val);
	rgb.do { |pin, i|
		DigitalOut.ar(pin, val[i])
	};
}).add;

)
/*
a = Bus(\control, 127, 1);
b = Bus(\control, 128, 3);

Synth(\ledBus, [\bus, b.index])
Synth(\ledLog2ToBus, [\out, b.index, \inbus, a.index]);

a.set(8)
a.get


b = Bus(\control, 128, 3);
b.set(0,0,0)
b.get
*/