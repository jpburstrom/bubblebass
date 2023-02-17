
//Small btn = pin 12
//keyUp = pin 13
//keyDn = pin 15
//Switch = pin 5

//Listens to input from button, keeps states according to button gestures:
//1 - Button trig
//2 - short press
//4 - double press
//8 - long press

~modules.addModule(\digitalIn, (
	desc: "Wrapper for Bela DigitalIn UGen",
	func: { |pin|
		if (~isBela.not and: { ~server != ~belaServer }) {
			var key = "digitalIn_%".format(pin);
			"Can't use DigitalIn, fallback to control %".format(key).warn;
			key.asSymbol.kr(0);
		} {
			DigitalIn.kr(pin)
		}
	}
));


~modules.addModule(\threeStateKey, (
	desc: "Listen to input from button, keep states according to button gestures: 2-short 4-double 8-long",
	sizes: 1,
	func: { |pin|

		var doubleTime = 0.25;
		var longTime = 0.5;
		var debounceTime = 0.01;
		//
		//var rawButton = MouseButton.kr(lag:0);
		var rawButton = ~modules.build(\digitalIn, pin);
		var trig = Trig1.kr(rawButton, debounceTime);
		var timer = Sweep.kr(trig);
		var btnInited = Latch.kr(1, trig);
		var btnState;

		var btnPressed = Gate.kr(rawButton, timer > debounceTime);

		//4 = double
		btnState = (btnInited * Latch.kr(Timer.kr(trig) < doubleTime, trig) * 4);
		//2 = single
		btnState = btnState + (2 * btnState.not * btnInited * btnPressed.not * (timer > doubleTime));

		//8 = long
		btnState = btnState + Gate.kr((timer > longTime) * 8, btnPressed);

		//Trig at trig + double + long time, filter out zeroes
		btnState = trig + Latch.kr(btnState, Trig1.kr(timer>doubleTime * btnState) + Trig1.kr(timer > longTime));

		btnState
	}
)
);

//Listens to input from button, keeps states according to button gestures:
//short press toggles between 2 and 4
//8 - long press
~modules.addModule(\threeStateToggle, (
	desc: "Listen to input from button, keep states according to button gestures: short toggles 2-4, 8 on long press"
,	func: { |pin|

		var longTime = 0.5;
		var debounceTime = 0.01;

		//var rawButton = MouseButton.kr(lag:0);
		var rawButton =  ~modules.build(\digitalIn, pin);
		var trig = Trig1.kr(rawButton, debounceTime);
		var timer = Sweep.kr(trig);
		//Toggle between 2 & 4, output zero until triggered
		var tgl = ToggleFF.kr(trig) * 2 + Latch.kr(2, trig);
		var btnState;

		var buttonPressed = Gate.kr(rawButton, timer > debounceTime);

		//8 = long
		btnState = Gate.kr((timer > longTime) * 8, buttonPressed);

		//2 = toggle off, 4= toggle on
		btnState = btnState + (btnState.not * Demand.kr(trig, btnState, Dseq([2, 4], inf)));


		//Trig at double + long time, filter out zeroes
		btnState = Latch.kr(btnState, Impulse.kr(0) + buttonPressed.not + Trig1.kr(timer > longTime));

		btnState;
	}
)
);

~modules.addModule(\simpleButton, (
	desc: "Button for momentary or switch use",
	func: { |pin|
		~modules.build(\digitalIn, pin)
	}
));

~modules.addModule(\trigButton, (
	desc: "Trig button, outputting high value for dur (0.1) duration",
	func: { |pin, dur=0.1|
		Trig.kr(~modules.build(\digitalIn, pin), dur);
	}
));

//
~modules.addModule(\nodePauseController, (
	desc: "Get input from threeState SynthDefs, toggle three nodes according to active state",
	rates: \control,
	sizes: 1,
	specs: (
		sig: ControlSpec(0, 8, step: 1)
	),
	func: { |sig, node1, node2, node3|
		Pause.kr(sig.composeBinaryOp('==', 2), node1);
		Pause.kr(sig.composeBinaryOp('==', 4), node2);
		Pause.kr(sig.composeBinaryOp('==', 8), node3);

	}
));

//Get input from threeState SynthDefs above, pause synthdefs according to active state
~modules.addModule(\nodePauseController2, (
	desc: "Get input from threeState SynthDefs, toggle two nodes according to active state",
	specs: (
		sig: ControlSpec(0, 1, step: 1)
	),
	func: { |sig, node1, node2|

		Pause.kr(sig, node1);
		Pause.kr(1 - sig, node2);
	}
));



~modules.addModule(\bubbleUtils, (
	desc: "Save and quit from a digitalIn pin. Load automatically by default.",
	func: { |pin, load=1, quitDuration=1.5|
		var trig = ~modules.build(\digitalIn, pin);
		var save = Trig.kr(trig);
		var quit = (Sweep.kr(save) * trig) > quitDuration;
		BubbleUtils.kr(save, load, quit)
	}
));

