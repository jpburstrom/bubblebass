
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
	//var trig = MouseButton.kr(lag:0);
	var trig = DigitalIn.kr(\pin.kr(0));
	var timer = Sweep.kr(Trig1.kr(trig, debounceTime));
	var btnPressed = Latch.kr(1, trig);
	var btnState;

	trig = Gate.kr(trig, timer > debounceTime);

	//4 = double
	btnState = (btnPressed * Latch.kr(Timer.kr(trig) < doubleTime, trig) * 4);
	//2 = single
	btnState = btnState + (2 * btnState.not * btnPressed * trig.not * (timer > doubleTime));

	//8 = long
	btnState = btnState + Gate.kr((timer > longTime) * 8, trig);

	btnState.poll;


	//Trig at double + long time, filter out zeroes
	btnState = Latch.kr(btnState, Trig1.kr(timer>doubleTime * btnState) + Trig1.kr(timer > longTime));

	Out.kr(\outbus.kr, btnState);

}).add;

SynthDef(\simpleButton, {
	Out.kr(\outbus.kr, DigitalIn.kr(\pin.kr(0)));
}).add;


