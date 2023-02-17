// Borrowed from SoftKneeCompressor/wslib
var peak = { |in, controlAmp, thresh = -10, ratio = 1, knee = 6, makeUp = 0|
	var db, reduction, frac;

	var ratio_inv = 1 - ratio;
	var ratio_m1 = ratio - 1;
	var fracDenom = 2 * knee.max(1e-12);

	makeUp = ( (thresh.neg * ratio_inv) * makeUp ).dbamp; // autogain

	//ej samma
	db =  controlAmp.ampdb;

	//ej samma
	frac = ((db+(knee-thresh))/fracDenom).clip(0,1);

	ratio = 1 + (frac * ratio_m1);
	thresh = thresh - ( (1-frac) * knee );

	reduction = ((thresh - db).min(0) * ratio_inv).dbamp;

	reduction * in * makeUp;
};

SynthDef(\compressor4x, {
	var snd = In.ar(\in.kr(0), 4);
	var trill = In.kr(\trillBus.kr(0) + 2, 2); //FIXME + 2??
	var amp = In.kr(\ampBus.kr(0), 4);

	//TODO check trill hi, lo order
	//TODO set range
	//TODO lag
	var thresh = (trill[0] - trill[1]).linlin(0, 0.5, \dbHi.ir(0), \dbLo.ir(-32)).lag(0.01);
	var makeup = trill.mean.linlin(0, 0.5, 0, 0.88).lag(0.01);

	peak.(snd, amp, thresh, \ratio.ir(4), \knee.ir(6), makeup);

	//TODO compress snd
	//TODO makeup gain
	//TODO replaceOut

	ReplaceOut.ar(\out.kr(0), snd);
}).add;


