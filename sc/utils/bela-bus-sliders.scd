//Display scope for bubblebass buses

var win, sliders, numbers, synth, func, buses, audiobuses, clist, alist, listAction, serverBootAction;

listAction = { |bus|
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
};

audiobuses = (
	spkr: Bus(),
	direct: Bus(\audio, 2, 4),
	main: { ~audioBus.main },
	pitchTracker: { ~audioBus.pitchTracker },
	input: Bus('audio', 6, 4);


);
buses = ();

serverBootAction = {

	~ctlBus.keysValuesDo({ |k, item|
		if (item.isArray) {
			item.do { |bus, i|
				buses["% %".format(k, i + 1).asSymbol] = bus;
			}
		} {
			buses[k] = item;
		}
	});
	alist.items_(audiobuses.keys.asArray.sort);
	clist.items_(buses.keys.asArray.sort);
	clist.valueAction = 0;

}.inEnvir;


sliders = 5.collect { Slider().orientation_(\vertical) };
numbers = 5.collect { NumberBox() };
//~server.notify = true;

win = View().layout_(VLayout(
	GridLayout.rows(sliders, numbers),
	[alist = ListView().action_({ |v|
		listAction.(audiobuses[v.item].value)
	}), s:1],
	[clist = ListView().action_({ |v|
		listAction.(buses[v.item].value)
	}), s:2]
));
win.onClose = { synth.free; func.free; ServerBoot.remove(serverBootAction, ~belaServer) };

ServerBoot.add(serverBootAction, ~belaServer);
if (~belaServer.serverRunning) {
	serverBootAction.value;
};

win

