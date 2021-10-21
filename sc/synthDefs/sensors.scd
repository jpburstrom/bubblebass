SynthDef(\imuInput, {
	var data = BNO.orientationKr(\calibrate.tr(0), \load.tr(0), \save.tr(0));
	Out.kr(\out.kr(0), data);
}).add;

SynthDef(\trillInput, {
	4.do { |i|
		var vals = TrillCentroids.kr(1, 0x20 + i, 0.02, 4)[0..4];
		//Fix edges - TODO make this part of Centroids class?
		vals[1].linlin(0.05, 0.95, 0, 1);
		vals[3].linlin(0.05, 0.95, 0, 1);
		Out.kr(NamedControl.kr("out%".format(i)), vals[0..4]);
	}
}).add;


//------Trill Multitouch filter-----
//Input: 5-channel bus
//Output: 3 buses (2ch, 2ch, 1ch) corresponding to 1-3 fingers,
//3 fingers = trig


//If trill[0] == 0, do nothing.
//If going back to 0 during waitTime, cancel wait and do nothing
//After checks, Set trill[0] to 0
//All the time:
//if trill[0] == 1, Open gate to first bus, send location + touchSize
//if 2, Open gate to second bus, send location x2 (no touchSize)
//if 3, send trig to third bus, 1 channel
// raising, wait
SynthDef(\trillMultiTouchFilter, {
	var sweep, waitTime = 0.05; //wait time until numFingers is set, 50 ms
	//Get trill data from separate SynthDef, use only first 5
	var trill = In.kr(\trillBus.kr, 5);
	//Test data
	//var trill = Demand.kr(Impulse.kr(2), 0, Dseq([[0, 0, 0, 0], [1, 1, 0, 0], [1, 2, 0, 0], [1, 3, 0, 0], [2, 4, 0, 0], [1, 5, 0, 0]], inf));
	var aboveZero = trill[0] > 0;
	var reset = Changed.kr(aboveZero);
	var initDone = Sweep.kr(reset) > waitTime;
	//Get Max

	//If going from 0 to higher, wait waitTime and keep track of maximum value
	//When wait is over, latch max value as current numFingers until fingers are released
	var numFingers = Latch.kr(RunningMax.kr(trill[0], aboveZero.not), initDone) * (Sweep.kr(reset) > waitTime) * aboveZero;

	//Send a 5-channel signal, [1f loc, 1f touch, 2f loc, 2f loc, 3f trig]
	Out.kr(\out.kr, [
		//Send index 1 & 2 to bus1 if numFingers == 1, otherwise hold last value
		Gate.kr([1,2].collect(trill[_]), BinaryOpUGen('==', numFingers, 1) * BinaryOpUGen('==', numFingers, trill[0])),

		//Send index 1 & 3 to bus2 if numFingers == 2, otherwise hold last value
		Gate.kr([1,3].collect(trill[_]), BinaryOpUGen('==', numFingers, 2) * BinaryOpUGen('==', numFingers, trill[0])),

		//Send trig to bus3 if numFingers == 3
		Trig.kr(BinaryOpUGen('==', numFingers, 3))
	].flatten)

}).add;



//Routing for a single trill
SynthDef(\trillRouting, {

	//Button sends 2,4,8 & trig(1), so we need to make that 0-2
	var outIndex = In.kr(\btnBus.kr(0), 1).log2 - 1;
	//Button index above selects the right bus index below
	var outbus = Select.kr(outIndex, [
		\outSingle.kr(0),
		\outDouble.kr(5),
		\outLong.kr(10)
	]);

	var trill = In.kr(\trillBus.kr(15), 5);
	Out.kr(outbus, trill);

}).add;

