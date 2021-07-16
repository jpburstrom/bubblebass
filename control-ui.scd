var views = ();
var btnSpec = ControlSpec(0, 1, step:1);
var addr = NetAddr("localhost", 5677);
var win = Window("Bubblebass", Window.availableBounds.width_(400)).layout_(VLayout());
var model = ();
var oscFunc = OSCFunc({ |msg|
	model[msg[1]][msg[2]] = msg[3];
}, "/param");
[
	volume: [
		'mute': btnSpec
	],
	main: [
		'preamp-1': [1, 4],
		'preamp-2': [1, 4],
		'preamp-3': [1, 4],
		'preamp-4': [1, 4],
	],
	limiter: [
		strength: [0, 1],
		thresh: [-60, 0, \db],
		threshLim: [-60, 0, \db],
		makeupGain: [0, 24, \db],
		knee: [0, 18, \db],
		att: [1, 100],
		rel: [1, 1000]
	]
].pairsDo { |gName, group|
	var v, sliders = List();
	var updater = ();
	model[gName] = EnvironmentRedirect().dispatch_( {|k, v|
		var path = "/%/%".format(gName, k);
		addr.sendMsg(path, v);
		defer { updater[k].value(v) };

	});
	group.pairsDo { |n, range, i|
		var spec = range.asSpec;
		var nbx;
		sliders.add(View().fixedWidth_(80).layout_(VLayout(
			StaticText().string_(n).font_(Font.sansSerif.size_(10)),
			if (spec == btnSpec) {
				var x = CheckBox().action_({ |b|
					model[gName][n] = b.value;
				});
				updater[n] = { |v| x.value = v };
				x
			} {
				var x = Slider().orientation_(\vertical).action_({ |sl|
					var val = spec.map(sl.value);
					if (val != model[gName][n]) {
						nbx.value = val;
						model[gName][n] = val;
					}
				}).alt_scale_(0.01);
				updater[n] = { |v|
					nbx.value = v;
					x.value = spec.unmap(v);
				};
				x

			},
			if (spec != btnSpec) {
				nbx = NumberBox().action_({|b|
					model[gName][n] = b.value;
				}).clipLo_(spec.clipLo).clipHi_(spec.clipHi)

			}
		)));
	};
	v = View().layout_(VLayout(
		StaticText().string_(gName.toUpper),
		View().layout_(HLayout(*sliders))
	));
	win.layout.add(v);
};
win.layout.add(View().layout_(HLayout(
	Button().states_([["Sync"]]).action_({
		addr.sendMsg("/sync")
	}),
	Button().states_([["Save"]]).action_({
		addr.sendMsg("/save")
	}),
	Button().states_([["Load"]]).action_({
		addr.sendMsg("/load")
	}),
	nil
)));
win.layout.add(nil);
win.view.palette_(QPalette.light);
win.front;
win.onClose_({ oscFunc.free; });
addr.sendMsg("/sync");