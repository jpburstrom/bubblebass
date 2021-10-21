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
	var bus = In.kr(\bus.ir(0), 3).poll;
	rgb.do { |pin, i|
		DigitalOut.kr(pin, bus[i].poll)
	}
}).add;

);

/*
Synth(\ledBus, [\bus, 128])

b = Bus(\control, 128, 3);
b.set(0,0,0)
b.get
*/