~modules.addModule(\imuInput, (
	desc: "Input from IMU to bus with calibration and save stuff",
	//TODO how to do with triggers and stuff? Is this a synthDef?
	func: { |calibrateTrig, calibrateBus, saveTrig, saveBus, loadTrig|
		var calibrate = calibrateTrig + In.kr(calibrateBus);
		var save = saveTrig + In.kr(saveBus);
		var data = BNO.orientationKr(calibrate, loadTrig, save);
		data
	}
));

~modules.addModule(\trillCentroids, (
	desc: "Wrapper for TrillCentroids UGen",
	func: { |i2c_address=0x20, noiseThreshold=0.02, prescaler=4, resetBaseline=0, i2c_bus=1, size=5|
		~modules.build(\ifBela, {
			TrillCentroids.kr(i2c_bus, i2c_address, noiseThreshold, prescaler, resetBaseline).keep(size);
		}, {
			var key = "trill_%".format(i2c_address - 0x20);
			"Can't use TrillCentroids, fallback to control %".format(key).warn;
			NamedControl(key, 0.dup(size));
		});
	}
));

~modules.addModule(\trillInput, (
	desc: "Input 4 trills, output to buses with pos scaling",
	func: { |posMul=(-0.9), posAdd=0.95, noiseThreshold=0.02, prescaler=4, addresses=#[0x23,0x22,0x21,0x20]|
		addresses.collect { |addr, i|
			var vals = ~modules.build(\trillCentroids, addr, noiseThreshold, prescaler);
			//Fix edges + invert scale - TODO make this part of Centroids class?
			vals[1] = vals[1] * posMul + posAdd;
			vals[3] = vals[3] * posMul + posAdd;
			vals;
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
	sizes: [5, 4],
	func: { |trill, resetVals|
		var args = trill ++ resetVals;
		TrillFilter.kr(*args);
	}
));


