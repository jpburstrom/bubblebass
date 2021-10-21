//Display scope for bubblebass buses

var win, sliders, numbers, synth, func, buses, popup;

buses = (spkr: Bus(), direct: Bus(\audio, 2, 4), main: { ~audioBus.main });

~ctlBus.keysValuesDo({ |k, item|
	if (item.isArray) {
		item.do { |bus, i|
			buses["% %".format(k, i + 1).asSymbol] = bus;
		}
	} {
		buses[k] = item;
	}
});

sliders = 5.collect { Slider().orientation_(\vertical) };
numbers = 5.collect { NumberBox() };
~server.notify = true;

win = Window.new.front.layout_(VLayout(
	GridLayout.rows(sliders, numbers),
	popup = ListView().items_(buses.keys.asArray.sort).action_({ |v|
		var bus = buses[v.item].value;
		synth.free; func.free;
		func = OSCFunc({ |msg|
			defer {
				sliders.do { |sl, i|
					msg[i+3] !? { |val|
						sl.value = val;
						numbers[i].value = val;
						numbers[i].enabled = true;
						sl.enabled = true;
					} ?? {
						sl.value = 0;
						numbers[i].value = -1;
						numbers[i].enabled = false;
						sl.enabled = false;
					};
				}
			}
		}, '/busViewer', ~server.addr);

		synth = SynthDef(\busViewer, {

			var sig;
			if (bus.rate == \control) {
				sig = In.kr(bus.index, bus.numChannels);
			} {
				sig = A2K.kr(RMS.ar(In.ar(bus.index, bus.numChannels), 5));
			};
			SendReply.kr(Impulse.kr(5), '/busViewer', sig);
		}).play(addAction:\addToTail);
	})
));
win.onClose = { synth.free; func.free };

popup.valueAction = 0;