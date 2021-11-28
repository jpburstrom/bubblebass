SynthDef(\imuInput, {
	var calibrate = \calibrate.tr(0) + In.kr(\calibrateBus.kr(0));
	var save = \save.tr(0) + In.kr(\saveBus.kr(0))
	var data = BNO.orientationKr(calibrate, \load.tr(0), save);
	Out.kr(\out.kr(0), data);
}).add;


SynthDef(\trillInput, {
	4.do { |i|
		var vals = TrillCentroids.kr(1, 0x20 + i, 0.02, 4)[0..4];
		//Fix edges + invert scale - TODO make this part of Centroids class?
		vals[1] = vals[1].linlin(0.05, 0.95, 1, 0);
		vals[3] = vals[3].linlin(0.05, 0.95, 1, 0);
		//Output in reverse order - 0 is uppermost, 3 lowest
		Out.kr(NamedControl.kr("out%".format(3 - i)), vals[0..4]);
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

//Routing for all trills in a single button group/mode
SynthDef(\trillRouting, {

	var trills = In.kr(\trillBus.kr(15), 20);
	var outbusIndex = \out.kr(0); //Index of 4 x 5 channel bus
	var nullbusIndex = \nullBus.ir(224);

	//Loop over 4 trills
	#[0, 5, 10, 15].do { |count|

		var sweep, waitTime = 0.05; //wait time until numFingers is set, 50 ms
		//Get trill data from separate SynthDef, use only first 5
		var trill = trills[count..count+5];
		//Test data
		//var trill = Demand.kr(Impulse.kr(2), 0, Dseq([[0, 0, 0, 0], [1, 1, 0, 0], [1, 2, 0, 0], [1, 3, 0, 0], [2, 4, 0, 0], [1, 5, 0, 0]], inf));
		var aboveZero = trill[0] > 0;
		var reset = Changed.kr(aboveZero);
		var initDone = Sweep.kr(reset) > waitTime;
		//Get Max

		//If going from 0 to higher, wait waitTime and keep track of maximum numFingers
		//When wait is over, latch max value as current numFingers until fingers are released
		var numFingers = Latch.kr(RunningMax.kr(trill[0], aboveZero.not), initDone) * (Sweep.kr(reset) > waitTime) * aboveZero;

		//Send a 5-channel signal, [1f loc, 1f touch, 2f loc, 2f loc, 3f trig]
		//TODO: change to three out.kr

		var active1 = BinaryOpUGen('==', numFingers, 1) * BinaryOpUGen('==', trill[0], 1);
		var active2 = BinaryOpUGen('==', numFingers, 2) * BinaryOpUGen('==', trill[0], 2);

		//If 1 fingers, send to first two channels, otherwise to null
		ReplaceOut.kr(Select.kr(active1, [nullbusIndex, outbusIndex + count]), trill[[1,2]]);
		//If 2 fingers, send to channels 2-3, otherwise to null
		ReplaceOut.kr(Select.kr(active2, [nullbusIndex, outbusIndex + count + 2]), trill[[1,3]]);
		//If 3 fingers, send trig
		Out.kr(outbusIndex + count + 4, Trig.kr(BinaryOpUGen('==', numFingers, 3)));
	}

}).add;
