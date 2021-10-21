b = Buffer.read(s, "/Users/johannes/projects/komp-2020/AudioSculpt/Parallella skeenden.wav");
b.normalize;
Spec.add(\amount, [0, 1])
(
Ndef(\slewDist, {
	var fx, input = SinOsc.ar(420);
	var amt = \amount.kr(0);
	var rate = amt.linlin(0, 1, 900, 10).poll;
	input - (OnePole.ar(Slew.ar(input, rate, rate), amt.linexp(0, 1, 0.01, 0.9999)) * amt.sqrt);
}).edit;
);

TrillCentroids
TrillRaw