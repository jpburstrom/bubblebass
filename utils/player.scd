{ |recordingPath, audiobuses|

	var el = ();
	var settings=(
		currentGroup: \input,
		currentBus: \input,
		addAction: \addToTail,
		filter: "{ |in| in }",
		path: nil,
		syn: nil,
		buffer: nil,
	);

	var listdir = { |dir, pattern="*.{wav,aiff}"|
		var out = "bash -c \"ssh root@bela 'ls %/%\'\" &".format(dir, pattern).unixCmdGetStdOutLines;
		out
	};

	var updateFiles = {
		var files = listdir.value(recordingPath);
		settings.files = ();
		el.fileList.items = files.collect { |path|
			var key = path.basename.asSymbol;
			settings.files[key] = path;
			key
		};
		el.fileList.valueAction_(0);
	};
	var stop = {
		settings.syn.free;
	};

	var play = {
		if (settings.syn.isPlaying) {
			stop.value
		};
		fork {
			var buf;
			var c = CondVar();
			var path = recordingPath +/+ settings.path;
			var numChannels = nil; //how do we?
			settings.postln;
			Buffer.read(~belaServer, path, 0, 1, { |b|
				numChannels = b.numChannels;
				c.signalOne;
				b.free;
			});

			c.waitFor(5, { numChannels.notNil });

			if (numChannels.isNil) {
				"Couldn't load file".warn;
			} {

				buf = Buffer.cueSoundFile(~belaServer, path, 0, numChannels);
				s.sync;
				settings.syn = SynthDef(\bubblePlayer, {
					var snd = DiskIn.ar(numChannels, buf, 1);
					snd = snd * \amp.kr(1);
					snd = settings.filter.interpret.value(snd);
					ReplaceOut.ar(\bus.kr(0), snd)
				}).play(~groups[settings.currentGroup].value, [bus: audiobuses[settings.currentBus].value.debug("bus")],
					settings.addAction);

				settings.syn.register(true).onFree({
					buf.free
				});
			}
		}
	};

	var updateGroupPosition = {
		if (settings.syn.isPlaying) {
			if (settings.addAction == \addToTail) {
				settings.syn.moveToTail(~groups[settings.currentGroup]);
			} {
				settings.syn.moveToHead(~groups[settings.currentGroup]);
			}
		};
	}.inEnvir;



	var win = el.use {
		Window().layout_(VLayout(
			StaticText().string_("Play through bus"),
			~busList = ListView().items_(audiobuses.keys.asArray.sort).action_({ |v|
				settings.currentBus = v.items[v.value];
				if (settings.syn.isPlaying) {
					settings.syn.set(\bus, audiobuses[settings.currentBus].value);
				};
			}),
			HLayout(
				StaticText().string_("Play in group"),
				Button().states_([["Tail"], ["Head"]]).action_({ |btn|
					settings.addAction = #[addToTail, addToHead][btn.value];
					updateGroupPosition.value;
				})
			),
			~groupList = ListView().items_(topEnvironment[\groups].keys.asArray.sort).action_({ |v|
				settings.currentGroup = v.items[v.value];
				updateGroupPosition.value;
			}),
			StaticText().string_("Recordings"),
			~fileList = ListView().action_({ |v|
				settings.path = v.items[v.value];
			}),
			~filterView = TextView().string_(settings.filter).font_(Font.monospace),

			Button().states_([["Update filter"]]).action_({
				settings.filter = el.filterView.string;
				if (settings.syn.isPlaying) {
					play.value
				};
			}),

			HLayout(
				~playBtn = Button().states_([["Play"], ["Stop"]]).action_({ |btn|
					if (btn.value == 1) {
						play.value
					} {
						stop.value
					}
				}),
				~refreshBtn = Button().states_([["Refresh"]]).action_(updateFiles);
			)
		));
	};
	el.groupList.value = el.groupList.items.indexOf(settings.currentGroup);
	el.busList.value = el.busList.items.indexOf(settings.currentBus);
	win.onClose = stop;
	win.front;

	updateFiles.value;
	el.postln;

}
