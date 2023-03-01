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

	Server.default = ~belaServer;
	~server = Server.default;
	~server.options.maxLogins = 2;
};

//These settings should be the same for both ScoreClock and Bela server
~server.options.reservedNumControlBusChannels = 256;
~server.options.numOutputBusChannels = 6;
~server.options.numInputBusChannels = 4;

if (isRendering or: { ~respawnAll ?? false }) {
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

		//Reset trigger bus, for trillFilter and others
		reset: Bus('control', 99, 1),

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
			#[input, mapping, output].do { |key|
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
		~synths[\trillInput] = SynthDef(\bubbleTrillInput, {
			var trills = ~modules.build(\trillInput);
			trills.do { |trill, i|
				trill.size.postln;
				ReplaceOut.kr(NamedControl.kr("out%".format(i)), trill);
			}
		}).play(~groups.global, ~ctlBus[\trill].collect({ |bus, i|
			["out%".format(i), bus]
		}).flatten).register(true);
	};
	//----GLOBAL------//


	~synths[\globals] = SynthDef(\bubbleGlobals, {
		|switchPin, switchBus, playGroup, setupGroup, busSavePin, imuBus, resetBus|

		var imu, switch = ~modules.build(\simpleButton, switchPin);
		//Load bus values on synth start and on demand
		var busLoadTrig = \busLoad.tr(0) + Impulse.kr(0);
		//Toggle play/setup
		~modules.build(\nodePauseController2, switch, playGroup, setupGroup);
		//Save/Load/Quit
		~modules.build(\bubbleUtils, busSavePin, busLoadTrig);
		//IMU
		imu = ~modules.build(\imuInput,
			\imuCalibrate.tr(0), \imuCalibrateBus.kr(0),
			\imuSave.tr(0), \imuSaveBus.kr(0),
			\imuLoad.tr(0)
		);
		//Send a reset on synth start for synths to pick up loaded bus values
		ReplaceOut.kr(resetBus, Impulse.kr(0) + busLoadTrig);
		ReplaceOut.kr(imuBus, imu);
		ReplaceOut.kr(switchBus, switch);

	}).play(~groups.global, [
		\switchPin, ~buttonPins[\switch],
		\switchBus, ~ctlBus[\btnSwitch],
		\playGroup, ~groups[\play],
		\setupGroup, ~groups[\setup],
		\busSavePin, ~buttonPins[\small],
		\imuBus, ~ctlBus[\imu],
		\imuCalibrateBus, ~ctlBus[\imuCalibrate],
		\imuSaveBus, ~ctlBus[\imuSave],
		\resetBus, ~ctlBus[\reset]
	], \addToTail);



	//------------SETUP-------------//

	~synths[\setup] = SynthDef(\bubbleSetup, {
		|calibrateBus, calibratePin, saveBus, savePin, ledBus, imuBus|
		//Route keyUp to calibration bus
		ReplaceOut.kr(calibrateBus, ~modules.build(\trigButton, calibratePin));
		//Route keyDn to save bus
		ReplaceOut.kr(saveBus, ~modules.build(\trigButton, savePin));
		//Route imu to leds
		~modules.build(\imuBusToLed, imuBus);

	}, \ir ! 6).play(~groups.setup, [
		\calibratePin, ~buttonPins.keyUp,
		\savePin, ~buttonPins.keyDn,
		\calibrateBus, ~ctlBus.imuCalibrate,
		\saveBus, ~ctlBus.imuSave,
		\imuBus, ~ctlBus.imu,
	], \addToHead);

	~synths[\trillRoutingSetup] = Synth(\trillRouting, [
		//Use first buses, output on all of them (4 x 5 ch)
		\trillBus, ~ctlBus.trill[0], //first trill bus
		\out, ~ctlBus[\trillRoutingSetup][0],
		\resetBus, ~ctlBus[\reset]
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


	//------------PLAY--------------//

	//IMU mapping
	~synths[\imuPitchAmp] = ~buffers.getSynth(\imuPitchAmp, [
		\in, ~ctlBus[\imuPitch],
		\out, ~ctlBus[\imuPitchAmp]
	], ~groups.input, \addToTail);


	//IMU mapping, unused
	/*
	~synths[\imuRollFreq] = ~buffers.getSynth(\imuRollFreq, [
		\in, ~ctlBus[\imuRoll],
		\out, ~ctlBus[\imuRollFreq]
	], ~groups.input, \addToTail);
	*/

	//Three routing defs, red green blue
	~synths[\trillRouting] = nil ! 3;
	#[trillRed, trillGreen, trillBlue].do { |key, i|
		~synths[\trillRouting][i] = Synth(\trillRouting, [
			//Use first buses, output on all of them (4 x 5 ch)
			\trillBus, ~ctlBus.trill[0], //first trill bus
			\out, ~ctlBus[key][0],
			\resetBus, ~ctlBus[\reset]
		], ~groups.input, \addToTail);
	};



	~synths[\playControllers] = SynthDef(\bubblePlayControllers, {
		|ledBus, ledResetBus, keyUpPin, keyUpBus, keyDnPin, keyDnBus, redNode, greenNode, blueNode|

		var keyUp, keyDn;

		keyUp = In.kr(keyUpBus, 1);
		keyDn = In.kr(keyDnBus, 1);

		//Key up to bus, toggle state 1/2 with short press. TODO do we need a nullbus here?
		ReplaceOut.kr(keyUpBus, ~modules.build(\threeStateToggle, keyUpPin, keyUp));
		//Key down to bus, short/double/long press
		ReplaceOut.kr(keyDnBus, ~modules.build(\threeStateKey, keyDnPin, keyDn));
		//And get input from keyUp bus

		//Pause trill routing nodes depending on state
		~modules.build(\nodePauseController, keyUp, redNode, greenNode, blueNode);
		//Display three states as rgb leds
		~modules.build(\threeStateToLedBus, keyUp, ledBus);
		//Display LED values from ledBus
		~modules.build(\ledBus, ledBus, ledResetBus);


	}, \ir ! 6).play(~groups.input, [
		\ledBus, ~ctlBus[\leds],
		\ledResetBus, ~ctlBus[\btnSwitch],
		\keyUpPin, ~buttonPins[\keyUp],
		\keyUpBus, ~ctlBus[\keyUp],
		\keyDnPin, ~buttonPins[\keyDn],
		\keyDnBus, ~ctlBus[\keyDn],
		\redNode, ~synths[\trillRouting][0],
		\greenNode, ~synths[\trillRouting][1],
		\blueNode, ~synths[\trillRouting][2]
	], \addToTail);



	~synths[\playOutput] = SynthDef(\bubblePlayOutput, {
		|outbus=0, directOutBus=2, volumeTrillBus=5, imuPitchAmpBus=0, preamp=1, imuPitchBus=0, imuRollBus=0|

		var snd = ~modules.build(\bbIn, directOutBus);
		var envFollow = ~modules.build(\envFollow, snd);
		var volumeTrill = In.kr(volumeTrillBus, 20);
		var imuPitchAmp = In.kr(imuPitchAmpBus, 1);


		snd = snd.collect { |ch, i|
			~modules.build(\volume, ch, volumeTrill[i * 5], imuPitchAmp, preamp)
		};

		~modules.build(\bbOut, snd, imuPitchBus, imuRollBus, outbus)

	}, (\ir ! 4) ++ [\kr, \ir, \ir]).play(~groups.output, [
		\preamp, 6,
		\outbus, 0,
		\directOutBus, 2,
		\volumeTrillBus, ~ctlBus[\trillRed][0],
		\imuPitchAmpBus, ~ctlBus[\imuPitchAmp],
		\imuPitchBus, ~ctlBus[\imuPitch],
		\imuRollBus, ~ctlBus[\imuRoll]
	]);




}.forkIfNeeded;

