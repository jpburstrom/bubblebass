~isBela = Platform.architecture == \AArch64;
if (~isBela.not and: { ~belaServer.isNil }) {
	~belaServer = Server.remote(\bela, NetAddr("bela.local", 57110), ServerOptions());
	Server.default = ~belaServer;
	~belaServer.notify = true;
	~belaServer.startAliveThread
};

~server = Server.default;
~server.options.reservedNumControlBusChannels = 256;
~server.options.maxLogins = 2;



~server.waitForBoot {

	//Respawn everything - set to false to not respawn trill synth
	//when working interactively/remotely
	//(because it crashes when respawning)
	var respawn = false;


	//SynthDefs
	"synthDefs/*.scd".resolveRelative.pathMatch.do(_.load);
	~server.sync;

	//Let's handle indexes ourselves for now
	//This doesn't work on remote server, where each client has its own allocated space
	//so let's ignore it for now
	//see s.options.reservedNumControlBusChannels
	// ~server.controlBusAllocator.reserve(0, 256);

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
	if (respawn or: ~groups.isNil or: { ~groups[\input].isPlaying.not }) {
		~groups.do(_.free);
		~groups = ();
		~synths = ();
		s.makeBundle(nil, {
			#[input, analysis, fx1, fx2, fx3, fx4, level, output].do { |key|
				~groups[key] = Group(addAction: \addToTail).register(true);
			}
		});
	};
	s.sync;

	//Avoid respawning trill synth if possible
	~synths.keysValuesDo { |k, v|
		if (k != \trillInput) {
			v.free;
		}
	};

	if (respawn or: ~synths[\trillInput].isPlaying.not) {
		~synths[\trillInput] = Synth(\trillInput, ~ctlBus.trill.collect({ |bus, i| ["out%".format(i), bus] }).flatten, ~groups.input).register(true);
	};

	~synths[\bbIn] = Synth(\bbIn, [\out, ~audioBus.main], ~groups.input);
	~synths[\imuInput] = Synth(\imuInput, [\out, ~ctlBus.imu], ~groups.input);


	~synths[\bbOut] = Synth(\bbOut, [\in, ~audioBus.main, \out, 0, \directOut, 2], ~groups.output);
}

