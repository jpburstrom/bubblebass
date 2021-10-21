s.waitForBoot {

	~server = Server.default;

	//SynthDefs
	"synthDefs/*.scd".resolveRelative.pathMatch.do(_.load);
	~server.sync;

	//Let's handle indexes ourselves for now
	~server.controlBusAllocator.reserve(0, 256);

	~ctlBus = (
		switch: Bus('control', 1, 1),
		keyUp: Bus('control', 3, 1),
		keyDown: Bus('control', 4, 1),
		//5..144: Trill
		imu: Bus('control', 145, 3),
		pitch: Bus('control', 148, 4),
		envFollow: Bus('control', 152, 4),
	);

	//Make 4-item arrays of buses
	value {
		var offset = 5;
		#[trill,
			trillSingle, trillDouble, trillLong,
			trillMTSingle, trillMTDouble, trillMTLong].do { |key, index|
			~ctlBus[key] = 4.collect { |num|
				Bus('control', offset + (5 * ((index * 4) + num)), 5);
			}
		}
	};

	~audioBus = (
		main: Bus.audio(s, 4);
	);


	//Allocate groups
	~groups = ();
	s.makeBundle(nil, {
		#[input, analysis, fx1, fx2, fx3, fx4, level, output].do { |key|
			~groups[key] = Group(addAction: \addToTail);
		}
	});
	s.sync;

	//Synths
	~synths = ();

	~synths[\bbIn] = Synth(\bbIn, [\out, ~audioBus.main], ~groups.input);
	~synths[\bbOut] = Synth(\bbOut, [\in, ~audioBus.main, \out, 0, \directOut, 2], ~groups.output);
}

