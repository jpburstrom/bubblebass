var clock = TempoClock.default;
var isRendering = false;
if (Server.default == Server.named[\ScoreDummy]) {
	isRendering = true;
	~server = Server.default;
} {
	~isBela = Platform.architecture == \AArch64;
	if (~isBela.not and: { ~belaServer.isNil }) {
		~belaServer = Server.remote(\bela, NetAddr("bela", 57110), ServerOptions());
		~belaServer.notify = true;
		~belaServer.startAliveThread
	};

	~server = Server.default;
	//Kludge
	//Server.default = ~belaServer;
	//~server = ~belaServer;
	//~server.options.maxLogins = 2;
};

//These settings should be the same for both ScoreClock and Bela server
~server.options.reservedNumControlBusChannels = 256;
~server.options.numOutputBusChannels = 6;
~server.options.numInputBusChannels = 4;

if (isRendering or: { ~respawnAll }) {
	~server.newBusAllocators;
	~server.newBufferAllocators;
};

{

	//Respawn everything - set to false to not respawn trill synth
	//when working interactively/remotely
	//(because it crashes when respawning)
	var respawnAll = ~respawnAll ? false;

	if (respawnAll and: { isRendering.not } ) {
		~server.freeAll;
		~server.initTree;
		~server.notify = true;
		~server.startAliveThread;
		~server.newBusAllocators;
		~server.newBufferAllocators;
	};


	//Buffers used for parameter mapping
	if (isRendering.not) {
		~buffers.do(_.free);
	};
	~buffers = "buffers.scd".loadRelative[0];
	//FIXME
	//For some reason the first loaded buffer doesn't work, so we load a dummy here
	~buffers.addMapping(\dummy, -0.2, 0.2, 0, \allPassCurve);
	~buffers.addMapping(\imuRollFreq, -0.2, 0.2, 0, \allPassCurve);
	~buffers.addMapping(\imuPitchAmp, -0.4, 0.3);

	//Modules
	"modules.scd".loadRelative;
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
		//5..84: Trill

		//Imu as 3-channel bus + separate channels
		//for convenience
		imu: Bus('control', 85, 3),
		imuPitch: Bus('control', 85, 1),
		imuRoll: Bus('control', 86, 1),
		imuYaw: Bus('control', 87, 1),

		pitch: Bus('control', 88, 4),
		envFollow: Bus('control', 92, 4),
		leds: Bus('control', 96, 3),

		//---SETUP---
		//100-119: \trillRoutingSetup

		imuCalibrate: Bus('control', 120, 1),
		imuSave: Bus('control', 121, 1),

		imuPitchAmp: Bus('control', 128, 1),
		imuRollFreq: Bus('control', 129, 1),

		null: Bus('control', 224, 32)
	);

	~buttonPins = (
		small: 12,
		keyUp: 13,
		keyDn: 15,
		switch: 5
	);

	//Make 4-item arrays of buses
	value {
		var offset = 5;
		#[trill, trillRed, trillGreen, trillBlue].do { |key, index|
			~ctlBus[key] = 4.collect { |num|
				Bus('control', offset + (5 * ((index * 4) + num)), 5);
			}
		}
	};

	~ctlBus[\trillRoutingSetup] = 4.collect { |num|
		Bus('control', 100 + (5 * num), 5);
	};

	~audioBus = (
		main: Bus.audio(s, 4),
		pitchTracker: Bus.audio(s, 4)
	);

	//Allocate groups
	if (respawnAll or: ~groups.isNil or: { ~groups[\input].isPlaying.not }) {
		if (isRendering.not) {
			~groups.do(_.free);
		};
		~groups = ();
		~synths = ();
		s.makeBundle(nil, {
			#[global, setup, play].do {|key|
				~groups[key] = Group(s, \addToTail);
			};
			#[input, analysis, prefx, level, postfx, output].do { |key|
				~groups[key] = Group(~groups[\play],  \addToTail).register(true);
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
		//TODO move to globals?
		~synths[\trillInput] = SynthDef(\myTrillInput, {
			var trills = ~modules.build(\trillInput);
			trills.do { |trill, i|
				trill.size.postln;
				Out.kr(NamedControl.kr("out%".format(i)), trill);
			}
		}).play(~groups.global, ~ctlBus[\trill].collect({ |bus, i|
			["out%".format(i), bus]
		}).flatten).register(true);
	};
	//----GLOBAL------//


	~synths[\globals] = SynthDef(\globals, {
		|switchPin, switchBus, playGroup, setupGroup, busSavePin, imuBus|

		var imu, switch = ~modules.build(\simpleButton, switchPin);
		//Toggle play/setup
		~modules.build(\nodePauseController2, switch, playGroup, setupGroup);
		//Save/Load/Quit
		~modules.build(\bubbleUtils, busSavePin);
		//IMU
		imu = ~modules.build(\imuInput,
			\imuCalibrate.tr(0), \imuCalibrateBus.kr(0),
			\imuSave.tr(0), \imuSaveBus.kr(0),
			\imuLoad.tr(0)
		);
		Out.kr(imuBus, imu);
		Out.kr(switchBus, switch);

	}).play(~groups.global, [
		\switchPin, ~buttonPins[\switch],
		\switchBus, ~ctlBus[\btnSwitch],
		\playGroup, ~groups[\play],
		\setupGroup, ~groups[\setup],
		\busSavePin, ~buttonPins[\small],
		\imuCalibrateBus, ~ctlBus[\imuCalibrate],
		\imuSaveBus, ~ctlBus[\imuSave]
	], \addToTail);


	//------------SETUP-------------//

	~synths[\trillRoutingSetup] = Synth(\trillRouting, [
		//Use first buses, output on all of them (4 x 5 ch)
		\trillBus, ~ctlBus.trill[0], //first trill bus
		\out, ~ctlBus[\trillRoutingSetup][0],
		\nullbus, ~ctlBus[\null]
	], ~groups.setup, \addToTail);

	~synths[\testTone] = nil ! 4;

	4.do { |i|
		var freq = (36 + (i * 7)).midicps;
		~synths[\testTone][i] = Synth(\testTone, [
			\freq, freq,
			\out, 0, //Direct stereo output
			\trillBus, ~ctlBus[\trillRoutingSetup][i]
		], ~groups.setup, \addToTail);
	};

	~synths[\imuCalibrate] = Synth(\trigButton, [
		\pin, ~buttonPins.keyUp, \outbus, ~ctlBus.imuCalibrate
	], ~groups.setup, \addToTail);

	~synths[\imuSave] = Synth(\trigButton, [
		\pin, ~buttonPins.keyDn, \outbus, ~ctlBus.imuSave
	], ~groups.setup, \addToTail);

	~synths[\imuLed] = Synth(\ledImuToBus, [
		\imubus, ~ctlBus.imu, \out, ~ctlBus[\leds]
	], ~groups.setup, \addToTail);

	//------------PLAY--------------//
/*
	//Audio input
	~synths[\bbIn] = Synth(\bbIn, [
		\out, ~audioBus.main, \directOut, 2
	], ~groups.input);

	//Keys and buttons
	~synths[\keyUp] = Synth(\threeStateToggle, [\pin, 13, \outbus, ~ctlBus.keyUp, \nullbus, ~ctlBus[\null]], ~groups.input);
	~synths[\keyDn] = Synth(\threeStateKey, [\pin, 15, \outbus, ~ctlBus.keyDn], ~groups.input);

	~synths[\j] = Synth(\ledBus,
		[\inbus, ~ctlBus[\leds], \resetBus, ~ctlBus[\btnSwitch]],
	~groups.output);
	~synths[\ledLog] = Synth(\ledLog2ToBus, [\out, ~ctlBus[\leds], \inbus, ~ctlBus[\keyUp]], ~groups.output);

	//Three routing defs, red green blue
	~synths[\trillRouting] = nil ! 3;
	#[trillRed, trillGreen, trillBlue].do { |key, i|
		~synths[\trillRouting][i] = Synth(\trillRouting, [
			//Use first buses, output on all of them (4 x 5 ch)
			\trillBus, ~ctlBus.trill[0], //first trill bus
			\out, ~ctlBus[key][0],
			\nullbus, ~ctlBus[\null]
		], ~groups.input, \addToTail);
	};


	//Input from keyUp button, pausing inactive routing synthDefs
	~synths[\nodePauseController] = Synth(\nodePauseController,
		[#[node1, node2, node3, inbus], ~synths[\trillRouting] ++ ~ctlBus.keyUp].flop.flat,
		~groups.input, \addToTail
	);

	//IMU mapping
	~synths[\imuPitchAmp] = ~buffers.getSynth(\imuPitchAmp, [
		\in, ~ctlBus[\imuPitch],
		\out, ~ctlBus[\imuPitchAmp]
	], ~groups.input, \addToTail);


	//IMU mapping
	/*
	~synths[\imuRollFreq] = ~buffers.getSynth(\imuRollFreq, [
		\in, ~ctlBus[\imuRoll],
		\out, ~ctlBus[\imuRollFreq]
	], ~groups.input, \addToTail);
	*/

	//Placeholders for synths
	#[envFollow, volume, saw].do { |key|
		~synths[key] = nil ! 4;
	};

	4.do { |i|

		~synths[\envFollow][i] = Synth(\envFollow, [
			\in, ~audioBus.main.subBus(i),
			\out, ~ctlBus.envFollow.subBus(i),
		], ~groups.analysis, \addToTail);

		/*
		~synths[\pitchTracker][i] = Synth(\pitchTrackerKr, [
			\in, ~audioBus.main.subBus(i),
			\out, ~audioBus.pitchTracker.subBus(i),
			\inAmp, ~ctlBus.envFollow.subBus(i),
			\outPitch, ~ctlBus.pitch.subBus(i),
			\ffreq, #[32.7, 48.99, 73.41, 110][i]
		], ~groups.analysis, \addToTail);

		~synths[\saw][i] = Synth(\pitchSawFilter, [
			\in, ~audioBus.pitchTracker.subBus(i),
			\out, ~audioBus[\main].subBus(i),
			\trillBus, ~ctlBus.trillGreen[i],
			\pitchBus, ~ctlBus.pitch.subBus(i),
			\gain, 1
		], ~groups.prefx, \addToTail);
		*/


		~synths[\volume][i] = Synth(\volume, [
			\in, ~audioBus[\main].subBus(i),
			\out, ~audioBus[\main].subBus(i),
			\imuPitchAmp, ~ctlBus[\imuPitchAmp], //pitch
			\trillBus, ~ctlBus[\trillRed][i],
			\preamp, 6
		], ~groups.level, \addToTail);

	};

	/*
	~synths[\pitchTracker] = Synth(\pitchTrackerFaust, [
		\in, ~audioBus.main,
		\out, ~audioBus.pitchTracker,
		\inAmp, ~ctlBus.envFollow,
		\outPitch, ~ctlBus.pitch,
		\ffreq, [32.7, 48.99, 73.41, 110]
	], ~groups.analysis, \addToTail);
	*/

	//------------FX-----------------

/*
	~synths[\allPass] = Synth(\allPass, [
		\in, ~audioBus[\main],
		\out, ~audioBus[\main],
		\imuRollFreq, ~ctlBus[\imuRollFreq]
	], ~groups.postfx, \addToTail);
	*/

	[\preLimiterGain, \fyr].do { |key|
		~synths[key] = nil ! 4;
	};

	4.do { |i|
/*
		~synths[\fyr][i] = Synth(\fyr, [
			\in, ~audioBus[\main].subBus(i),
			\out, ~audioBus[\main].subBus(i),
			\ampBus, ~ctlBus.[\envFollow].subBus(i)
		], ~groups.postfx, \addToTail);
		*/

		~synths[\preLimiterGain][i] = Synth(\preLimiterGain, [
			\in, ~audioBus[\main].subBus(i),
			\out, ~audioBus[\main].subBus(i),
			\trillBus, ~ctlBus.trillRed[i]
		], ~groups.postfx, \addToTail);
	};



	//Red 1-4
	/*
	~synths[\compressor] = Synth(\compressor4x, [
		\in, ~audioBus[\main],
		\trillBus, ~ctlBus[\trillRed][0],
		\ampBus, ~ctlBus[\envFollow],
		\ratio, 4,
		\knee, 6,
		\dbHi, 0,
		\dbLo, -32
	], ~groups.prefx, \addToTail);
	*/



	//TODO Map synths to buses


	//~synths[\test] = Synth(\bbFxTest, nil, ~groups.fx1)
	//.mapn(\amount, ~ctlBus[\trillMTSingle][0], 5);



	~synths[\bbOut] = Synth(\bbOut, [\in, ~audioBus.main, \out, 0, \rollBus, ~ctlBus[\imuRoll], \pitchBus, ~ctlBus[\imuPitch]], ~groups.output);
*/
}.forkIfNeeded;