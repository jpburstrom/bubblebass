~modules.addModule(\imuInput, (
	desc: "Input from IMU to bus with calibration and save stuff",
	//TODO how to do with triggers and stuff? Is this a synthDef?
	func: {
		var calibrate = \calibrate.tr(0) + In.kr(\calibrateBus.kr(0));
		var save = \save.tr(0) + In.kr(\saveBus.kr(0));
		var data = BNO.orientationKr(calibrate, \load.tr(0), save);
		Out.kr(\out.kr(0), data);
	}
));



~modules.addModule(\trillInput, (
	desc: "Input 4 trills, output to buses with pos scaling",
	func: { |posMul=(-0.9), posAdd=0.95, noiseThreshold=0.02, prescaler=4, addresses=#[0x20,0x21,0x22,0x23]|
		addresses.do { |add, i|
			var vals = TrillCentroids.kr(1, add, noiseThreshold, prescaler)[0..4];
			//Fix edges + invert scale - TODO make this part of Centroids class?
			vals[1] = vals[1] * posMul + posAdd;
			vals[3] = vals[3] * posMul + posAdd;
			//Output in reverse order - 0 is uppermost, 3 lowest
			Out.kr(NamedControl.kr("out%".format(3 - i)), vals[0..4]);
		}
	}
));

~modules.addModule(\trill2Fingers, (
	desc: "Get a pinch value from 2 fingers",
	sizes: [5, 1, 1, 1, 1],
	func: { |trill, outMin=0, outMax=1, inMin=0, inMax=0.75|
		(trill[2] - trill[3]).abs.linlin(inMin, inMax, outMax, outMin);
	}
));

~modules.addModule(\trillFilter, (
	desc: "Filter for single trill, UGen version based on SynthDef trillRouting",
	sizes: [5, 4, 1],
	func: { |trill, resetVals, reset|
		var args = trill ++ resetVals ++ reset;
		TrillFilter.kr(*args);
	}
));

