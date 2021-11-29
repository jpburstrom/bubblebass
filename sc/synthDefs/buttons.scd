
//Small btn = pin 12
//keyUp = pin 13
//keyDn = pin 15
//Switch = pin 5

//Listens to input from button, keeps states according to button gestures:
//1 - Button trig
//2 - short press
//4 - double press
//8 - long press

SynthDef(\threeStateKey, {

	var doubleTime = 0.25;
	var longTime = 0.5;
	var debounceTime = 0.01;
	//
	//var rawButton = MouseButton.kr(lag:0);
	var rawButton = DigitalIn.kr(\pin.kr(0));
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

	Out.kr(\outbus.kr, btnState);

}).add;

SynthDef(\threeStateToggle, {

	var longTime = 0.5;
	var debounceTime = 0.01;

	//var rawButton = MouseButton.kr(lag:0);
	var rawButton = DigitalIn.kr(\pin.kr(0));
	var trig = Trig1.kr(rawButton, debounceTime);
	var timer = Sweep.kr(trig);
	//Toggle between 2 & 4, output zero until triggered
	var tgl = ToggleFF.kr(trig) * 2 + Latch.kr(2, trig);
	var btnState;

	var buttonPressed = Gate.kr(rawButton, timer > debounceTime);
	var btnInited = Latch.kr(1, trig);
	//Don't output until inited
	var outbus = Select.kr(btnInited, [\nullbus.kr(224), \outbus.kr]);


	//8 = long
	btnState = Gate.kr((timer > longTime) * 8, buttonPressed);

	//2 = toggle off, 4= toggle on
	btnState = btnState + (btnState.not * Demand.kr(trig, btnState, Dseq([2, 4], inf)));


	//Trig at double + long time, filter out zeroes
	btnState = Latch.kr(btnState, Impulse.kr(0) + buttonPressed.not + Trig1.kr(timer > longTime));

	Out.kr(outbus, btnState);

}).add;

SynthDef(\simpleButton, {
	Out.kr(\outbus.kr, DigitalIn.kr(\pin.kr(0)));
}).add;

SynthDef(\trigButton, {
	Out.kr(\outbus.kr, Trig.kr(DigitalIn.kr(\pin.kr(0))));
}).add;

//Get input from threeState SynthDefs above, pause synthdefs according to active state
SynthDef(\nodePauseController, {
	var sig = In.kr(\inbus.kr(0));

	Pause.kr(sig.composeBinaryOp('==', 2), \node1.kr(0));
	Pause.kr(sig.composeBinaryOp('==', 4), \node2.kr(0));
	Pause.kr(sig.composeBinaryOp('==', 8), \node3.kr(0));

}).add;

//Get input from threeState SynthDefs above, pause synthdefs according to active state
SynthDef(\nodePauseController2, {
	var sig = In.kr(\inbus.kr(0));

	Pause.kr(sig, \node1.kr(0));
	Pause.kr(1 - sig, \node2.kr(0));

}).add;

SynthDef(\bubbleUtils, {
	var trig = DigitalIn.kr(\pin.kr(0));
	var save = Trig.kr(trig);
    var quit = (Sweep.kr(save) * trig) > 1.5;
    BubbleUtils.kr(save, 1, quit)
}).add;
