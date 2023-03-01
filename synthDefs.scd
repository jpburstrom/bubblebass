//SynthDefs for BubbleBass

//Testtone etc
"synthDefs/setup.scd".loadRelative;


//Module/UGen version
SynthDef(\trillRouting, {

	var trills = In.kr(\trillBus.kr(15), 20);
	var outbusIndex = \out.kr(0); //Index of first bus in a consecutive group of 4 x 5 channels
	//Reset out values to current bus value. Needs to happen on synth start
	//as well as on every BubbleUtils load
	var reset = \reset.tr(0) + In.kr(\resetBus.kr(0)) + Impulse.kr(0);
	var trillBusSize = 5;
	var resetValSize = 4;
	//Loop over 4 trills
	trills.clump(trillBusSize).do { |trill, i|

		var thisBusIndex = outbusIndex + (i * trillBusSize);

		//Get input from output bus
		var resetVals = In.kr(thisBusIndex, resetValSize);

		var vals = ~modules.build(\trillFilter, trill, resetVals);


		ReplaceOut.kr(thisBusIndex, vals);
	}

}).add;