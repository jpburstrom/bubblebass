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
	var respawnAll = false;

	if (respawnAll) {
		~server.freeAll;
		~server.initTree;
		~server.notify = true;
		~server.startAliveThread;
	};


	//SynthDefs
	"synthDefs/*.scd".resolveRelative.pathMatch.do(_.load);
	~server.sync;

	//Let's handle indexes ourselves for now
	//This doesn't work on remote server, where each client has its own allocated space
	//so let's ignore it for now
	//see s.options.reservedNumControlBusChannels
	// ~server.controlBusAllocator.reserve(0, 256);

	~ctlBus = (
		btnSwitch: Bus('control', 1, 1),
		keyUp: Bus('control', 3, 1),
		keyDn: Bus('control', 4, 1),
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
	if (respawnAll or: ~groups.isNil or: { ~groups[\input].isPlaying.not }) {
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
			//.do because some values are arrays
			v.do(_.free);
		}
	};


	if (respawnAll or: ~synths[\trillInput].isPlaying.not) {
		~synths[\trillInput] = Synth(\trillInput, ~ctlBus.trill.collect({ |bus, i| ["out%".format(i), bus] }).flatten, ~groups.input).register(true);
	};

	~synths[\bbIn] = Synth(\bbIn, [\out, ~audioBus.main], ~groups.input);
	~synths[\imuInput] = Synth(\imuInput, [\out, ~ctlBus.imu], ~groups.input);
	~synths[\keyUp] = Synth(\threeStateKey, [\pin, 13, \outbus, ~ctlBus.keyUp], ~groups.input);
	~synths[\keyDn] = Synth(\threeStateKey, [\pin, 15, \outbus, ~ctlBus.keyDn], ~groups.input);
	~synths[\btnSwitch] = Synth(\simpleButton, [\pin, 5, \outbus, ~ctlBus[\btnSwitch]], ~groups.input);

	~synths[\trillRouting] = nil ! 4;
	~synths[\trillMT] = Array(12);
	~synths[\pitchTracker] = nil ! 4;
	~synths[\envFollow] = nil ! 4;

	//trill(1..4) -> trillRouting(1..4) ->>> trillMultiTouchFilter(1..12)
	4.do { |i|

		~synths[\pitchTracker][i] = Synth(\pitchTracker, [
			\in, ~audioBus.main.subBus(i),
			\out, ~ctlBus.pitch.subBus(i),
			\ffreq, #[32.7, 48.99, 73.41, 110][i]
		], ~groups.analysis, \addToTail);

		~synths[\envFollow][i] = Synth(\envFollow, [
			\in, ~audioBus.main.subBus(i),
			\out, ~ctlBus.envFollow.subBus(i),
		], ~groups.analysis, \addToTail);

		~synths[\trillRouting][i] = Synth(\trillRouting, [
			\btnBus, ~ctlBus.keyUp,
			\trillBus, ~ctlBus.trill[i],
			\outSingle, ~ctlBus.trillSingle[i],
			\outDouble, ~ctlBus.trillDouble[i],
			\outLong, ~ctlBus.trillLong[i]
		], ~groups.input, \addToTail);

		["Single", "Double", "Long"].do { |keyState, ksIdx|
			~synths[\trillMT].add(Synth(\trillMultiTouchFilter, [
				\trillBus, ~ctlBus["trill%".format(keyState).asSymbol][i],
				\out, ~ctlBus["trillMT%".format(keyState).asSymbol][i]
			], ~groups.input, \addToTail)
			)
		}

	};

	//TODO Map synths to buses


	~synths[\test] = Synth(\bbFxTest, nil, ~groups.fx1)
	.mapn(\amount, ~ctlBus[\trillMTSingle][0], 5);



	~synths[\bbOut] = Synth(\bbOut, [\in, ~audioBus.main, \out, 0, \directOut, 2], ~groups.output);
}

{ SinOsc.ar(220) }.play(outbus: ~audioBus.main)